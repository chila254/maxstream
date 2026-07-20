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
      "Access-Control-Allow-Headers": "Content-Type",
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
      return this.handleExtract(url, corsHeaders);
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

  async handleExtract(url, corsHeaders) {
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

        const streamUrl = await this.extractFromSource(embedUrl, source.name);

        if (streamUrl) {
          console.log(`Found stream from ${source.name}: ${streamUrl}`);
          return new Response(
            JSON.stringify({
              url: streamUrl,
              source: source.name,
              type: streamUrl.includes(".m3u8") ? "hls" : "direct",
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
      return m3u8Urls[m3u8Urls.length - 1];
    }

    // Try to find video source URLs
    const videoUrls = this.extractVideoUrls(html);
    if (videoUrls.length > 0) {
      return videoUrls[0];
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
            return playerM3u8[playerM3u8.length - 1];
          }
          const playerVideo = this.extractVideoUrls(playerHtml);
          if (playerVideo.length > 0) {
            return playerVideo[0];
          }
        }
      } catch (e) {
        continue;
      }
    }

    return null;
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
