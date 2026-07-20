/// Cloudflare Worker: Stream URL Extractor
/// Fetches embed sites server-side and extracts .m3u8 stream URLs.
/// No CORS issues, no iframe popups, no ads.

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

const EMBED_SOURCES = [
  {
    name: "VidLink",
    movieUrl: "https://vidlink.pro/movie/{id}",
    tvUrl: "https://vidlink.pro/tv/{id}/{season}/{episode}",
  },
  {
    name: "MultiEmbed",
    movieUrl: "https://multiembed.mov/?video_id={id}&tmdb=1",
    tvUrl:
      "https://multiembed.mov/?video_id={id}&tmdb=1&season={season}&episode={episode}",
  },
  {
    name: "VidStreaming",
    movieUrl: "https://vidstreaming.io/movie/{id}",
    tvUrl: "https://vidstreaming.io/tv/{id}/{season}/{episode}",
  },
];

export default {
  async fetch(request, env) {
    const corsHeaders = {
      "Access-Control-Allow-Origin": env.CORS_ORIGIN || "*",
      "Access-Control-Allow-Methods": "GET, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type, Range",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    const url = new URL(request.url);

    // Health check
    if (url.pathname === "/") {
      return new Response(
        JSON.stringify({ status: "ok", service: "maxstream-extractor" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Stream extraction endpoint
    if (url.pathname === "/api/extract") {
      return this.handleExtract(url, corsHeaders, env);
    }

    if (url.pathname === "/api/media") {
      return this.handleMediaProxy(request, url, corsHeaders, env);
    }

    // List available sources
    if (url.pathname === "/api/sources") {
      return new Response(
        JSON.stringify({
          sources: EMBED_SOURCES.map((s) => ({ name: s.name })),
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ error: "Not found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  },

  async handleExtract(url, corsHeaders, env) {
    const tmdbId = url.searchParams.get("tmdb_id");
    const isMovie = url.searchParams.get("is_movie") === "true";
    const season = parseInt(url.searchParams.get("season") || "1");
    const episode = parseInt(url.searchParams.get("episode") || "1");

    if (!tmdbId) {
      return new Response(
        JSON.stringify({ error: "tmdb_id is required" }),
        {
          status: 400,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    console.log(
      `Extracting: TMDB ${tmdbId} (movie=${isMovie}, s${season}e${episode})`
    );

    // Try each embed source
    for (const source of EMBED_SOURCES) {
      try {
        const embedUrl = isMovie
          ? source.movieUrl.replace("{id}", tmdbId)
          : source.tvUrl
              .replace("{id}", tmdbId)
              .replace("{season}", season.toString())
              .replace("{episode}", episode.toString());

        console.log(`Trying ${source.name}: ${embedUrl}`);

        const stream = await this.extractFromSource(embedUrl, source.name);

        if (stream) {
          console.log(`Found stream from ${source.name}: ${stream.url}`);
          const isHls = stream.url.includes(".m3u8");
          const playbackUrl = env.PROXY_SECRET
            ? await this.createMediaProxyUrl(
                url.origin,
                stream.url,
                stream.referer,
                isHls,
                env.PROXY_SECRET
              )
            : stream.url;
          return new Response(
            JSON.stringify({
              url: playbackUrl,
              source: source.name,
              type: isHls ? "hls" : "direct",
              proxied: Boolean(env.PROXY_SECRET),
            }),
            {
              headers: { ...corsHeaders, "Content-Type": "application/json" },
            }
          );
        }
      } catch (e) {
        console.log(`${source.name} failed: ${e.message}`);
        continue;
      }
    }

    return new Response(
      JSON.stringify({ error: "No stream found" }),
      {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  },

  async extractFromSource(embedUrl, sourceName) {
    // Fetch the embed page
    const response = await fetch(embedUrl, {
      headers: {
        "User-Agent": USER_AGENT,
        Referer: new URL(embedUrl).origin,
      },
      redirect: "follow",
    });

    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }

    const html = await response.text();

    // Extract .m3u8 URLs from the HTML
    const m3u8Urls = this.extractM3u8Urls(html);
    if (m3u8Urls.length > 0) {
      // Return the best quality (last one is usually highest)
      return {
        url: this.resolveUrl(embedUrl, m3u8Urls[m3u8Urls.length - 1]),
        referer: embedUrl,
      };
    }

    // Try to find video source URLs
    const videoUrls = this.extractVideoUrls(html);
    if (videoUrls.length > 0) {
      return { url: this.resolveUrl(embedUrl, videoUrls[0]), referer: embedUrl };
    }

    // Check for iframes pointing to player pages
    const iframeUrls = this.extractIframeUrls(html);
    for (const iframeUrl of iframeUrls) {
      try {
        const absoluteUrl = this.resolveUrl(embedUrl, iframeUrl);
        const playerResponse = await fetch(absoluteUrl, {
          headers: {
            "User-Agent": USER_AGENT,
            Referer: embedUrl,
          },
          redirect: "follow",
        });

        if (playerResponse.ok) {
          const playerHtml = await playerResponse.text();
          const playerM3u8 = this.extractM3u8Urls(playerHtml);
          if (playerM3u8.length > 0) {
            return {
              url: this.resolveUrl(
                absoluteUrl,
                playerM3u8[playerM3u8.length - 1]
              ),
              referer: absoluteUrl,
            };
          }
          const playerVideo = this.extractVideoUrls(playerHtml);
          if (playerVideo.length > 0) {
            return {
              url: this.resolveUrl(absoluteUrl, playerVideo[0]),
              referer: absoluteUrl,
            };
          }
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  },

  async handleMediaProxy(request, url, corsHeaders, env) {
    if (!env.PROXY_SECRET) {
      return new Response("Media proxy is not configured", {
        status: 503,
        headers: corsHeaders,
      });
    }
    const upstream = url.searchParams.get("url") || "";
    const referer = url.searchParams.get("referer") || "";
    const signature = url.searchParams.get("sig") || "";
    const forceHls = url.searchParams.get("hls") === "1";
    if (
      !this.isSafeMediaUrl(upstream) ||
      signature !== (await this.signMediaUrl(upstream, referer, env.PROXY_SECRET))
    ) {
      return new Response("Invalid media URL", {
        status: 403,
        headers: corsHeaders,
      });
    }

    const upstreamUrl = new URL(upstream);
    const headers = {
      "User-Agent": USER_AGENT,
      Accept: request.headers.get("Accept") || "*/*",
    };
    if (referer) {
      headers.Referer = referer;
      try {
        headers.Origin = new URL(referer).origin;
      } catch (_) {}
    }
    const range = request.headers.get("Range");
    if (range) headers.Range = range;

    const response = await fetch(upstreamUrl, {
      headers,
      redirect: "follow",
    });
    if (!response.ok && response.status !== 206) {
      return new Response(`Upstream HTTP ${response.status}`, {
        status: response.status,
        headers: corsHeaders,
      });
    }

    const contentType = response.headers.get("Content-Type") || "";
    const isHls =
      forceHls ||
      contentType.includes("mpegurl") ||
      new URL(response.url).pathname.toLowerCase().endsWith(".m3u8");
    if (isHls) {
      const playlist = await response.text();
      if (!playlist.trimStart().startsWith("#EXTM3U")) {
        return new Response("Upstream did not return an HLS playlist", {
          status: 502,
          headers: corsHeaders,
        });
      }
      const rewritten = await this.rewritePlaylist(
        playlist,
        response.url,
        referer,
        url.origin,
        env.PROXY_SECRET
      );
      return new Response(rewritten, {
        status: response.status,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/vnd.apple.mpegurl",
          "Cache-Control": "no-store",
        },
      });
    }

    const responseHeaders = {
      ...corsHeaders,
      "Content-Type": contentType || "application/octet-stream",
      "Cache-Control": "private, max-age=300",
      "Accept-Ranges": response.headers.get("Accept-Ranges") || "bytes",
      "Access-Control-Expose-Headers":
        "Content-Length, Content-Range, Accept-Ranges",
    };
    for (const name of ["Content-Length", "Content-Range"]) {
      const value = response.headers.get(name);
      if (value) responseHeaders[name] = value;
    }
    return new Response(response.body, {
      status: response.status,
      headers: responseHeaders,
    });
  },

  async rewritePlaylist(playlist, baseUrl, referer, workerOrigin, secret) {
    const lines = playlist.split(/\r?\n/);
    return (
      await Promise.all(
        lines.map(async (line) => {
          const trimmed = line.trim();
          if (!trimmed) return line;
          if (!trimmed.startsWith("#")) {
            const mediaUrl = new URL(trimmed, baseUrl).href;
            return this.createMediaProxyUrl(
              workerOrigin,
              mediaUrl,
              referer,
              new URL(mediaUrl).pathname.toLowerCase().endsWith(".m3u8"),
              secret
            );
          }
          const match = /URI=("([^"]+)"|([^,]+))/i.exec(line);
          if (!match) return line;
          const mediaUrl = new URL(match[2] || match[3], baseUrl).href;
          const proxyUrl = await this.createMediaProxyUrl(
            workerOrigin,
            mediaUrl,
            referer,
            new URL(mediaUrl).pathname.toLowerCase().endsWith(".m3u8"),
            secret
          );
          return line.replace(match[0], `URI="${proxyUrl}"`);
        })
      )
    ).join("\n");
  },

  async createMediaProxyUrl(origin, upstream, referer, isHls, secret) {
    const proxy = new URL("/api/media", origin);
    proxy.searchParams.set("url", upstream);
    proxy.searchParams.set("referer", referer || "");
    proxy.searchParams.set("sig", await this.signMediaUrl(upstream, referer, secret));
    if (isHls) proxy.searchParams.set("hls", "1");
    return proxy.href;
  },

  async signMediaUrl(upstream, referer, secret) {
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const bytes = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(`${upstream}\n${referer || ""}`)
    );
    return [...new Uint8Array(bytes)]
      .map((value) => value.toString(16).padStart(2, "0"))
      .join("");
  },

  isSafeMediaUrl(value) {
    try {
      const url = new URL(value);
      const host = url.hostname.toLowerCase();
      return (
        (url.protocol === "https:" || url.protocol === "http:") &&
        host !== "localhost" &&
        host !== "127.0.0.1" &&
        host !== "0.0.0.0" &&
        !host.endsWith(".local")
      );
    } catch (_) {
      return false;
    }
  },

  extractM3u8Urls(html) {
    const patterns = [
      /["'](https?:\/\/[^"']*\.m3u8[^"']*?)["']/gi,
      /["'](\/\/[^"']*\.m3u8[^"']*?)["']/gi,
      /["']([^"']*\.m3u8[^"']*?)["']/gi,
      /file\s*[:=]\s*["']([^"']*\.m3u8[^"']*?)["']/gi,
      /src\s*[:=]\s*["']([^"']*\.m3u8[^"']*?)["']/gi,
      /source\s*[:=]\s*["']([^"']*\.m3u8[^"']*?)["']/gi,
      /url\s*[:=]\s*["']([^"']*\.m3u8[^"']*?)["']/gi,
    ];

    const urls = new Set();
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(html)) !== null) {
        let url = match[1];
        if (url.startsWith("//")) url = "https:" + url;
        if (url.includes(".m3u8")) urls.add(url);
      }
    }
    return [...urls];
  },

  extractVideoUrls(html) {
    const patterns = [
      /["'](https?:\/\/[^"']*\.(mp4|webm|m3u8)[^"']*?)["']/gi,
      /file\s*[:=]\s*["']([^"']*\.(mp4|webm)[^"']*?)["']/gi,
      /src\s*[:=]\s*["']([^"']*\.(mp4|webm)[^"']*?)["']/gi,
    ];

    const urls = new Set();
    for (const pattern of patterns) {
      let match;
      while ((match = pattern.exec(html)) !== null) {
        let url = match[1];
        if (url.startsWith("//")) url = "https:" + url;
        urls.add(url);
      }
    }
    return [...urls];
  },

  extractIframeUrls(html) {
    const pattern = /iframe[^>]*src\s*=\s*["']([^"']+)["']/gi;
    const urls = [];
    let match;
    while ((match = pattern.exec(html)) !== null) {
      urls.push(match[1]);
    }
    return urls;
  },

  resolveUrl(base, relative) {
    try {
      return new URL(relative, base).href;
    } catch {
      return relative;
    }
  },
};
