/// Cloudflare Worker: MaxStream Stream Extractor
/// Extracts .m3u8 URLs server-side via HTTP requests and regex parsing.
/// No iframes, no popups, no ads.

const USER_AGENT =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36";

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

    if (url.pathname === "/") {
      return new Response(
        JSON.stringify({ status: "ok", service: "maxstream-extractor" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (url.pathname === "/api/extract") {
      return this.handleExtract(url, corsHeaders);
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
      return new Response(JSON.stringify({ error: "tmdb_id required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    console.log(`Extract: TMDB ${tmdbId} movie=${isMovie} s${season}e${episode}`);

    // Try VixSrc first (most reliable, no JS needed)
    try {
      const result = await this.extractVixSrc(tmdbId, isMovie, season, episode);
      if (result) {
        console.log(`VixSrc success: ${result.url}`);
        return new Response(JSON.stringify(result), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } catch (e) {
      console.log(`VixSrc failed: ${e.message}`);
    }

    // Try VidLink (fetch page, look for /api/b/ pattern)
    try {
      const result = await this.extractVidLink(tmdbId, isMovie, season, episode);
      if (result) {
        console.log(`VidLink success: ${result.url}`);
        return new Response(JSON.stringify(result), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } catch (e) {
      console.log(`VidLink failed: ${e.message}`);
    }

    // Try 2Embed
    try {
      const result = await this.extract2Embed(tmdbId, isMovie, season, episode);
      if (result) {
        console.log(`2Embed success: ${result.url}`);
        return new Response(JSON.stringify(result), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    } catch (e) {
      console.log(`2Embed failed: ${e.message}`);
    }

    return new Response(JSON.stringify({ error: "No stream found" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  },

  // === VixSrc Extractor ===
  // Flow: API -> embed page -> parse JS vars -> construct playlist URL
  async extractVixSrc(tmdbId, isMovie, season, episode) {
    const apiUrl = isMovie
      ? `https://vixsrc.to/api/movie/${tmdbId}?lang=en`
      : `https://vixsrc.to/api/tv/${tmdbId}/${season}/${episode}?lang=en`;

    console.log(`VixSrc API: ${apiUrl}`);

    // Step 1: Call API to get embed path
    const apiResp = await fetch(apiUrl, {
      headers: {
        "User-Agent": USER_AGENT,
        "Referer": "https://vixsrc.to",
        "X-Requested-With": "XMLHttpRequest",
      },
    });

    if (!apiResp.ok) throw new Error(`API ${apiResp.status}`);

    const apiData = await apiResp.json();
    let embedPath = (apiData.src || "").replace(/^\//, "");
    if (!embedPath) throw new Error("No embed path in API response");

    // Step 2: Fetch embed page
    const embedUrl = `https://vixsrc.to/${embedPath}`;
    console.log(`VixSrc embed: ${embedUrl}`);

    const embedResp = await fetch(embedUrl, {
      headers: {
        "User-Agent": USER_AGENT,
        "Referer": "https://vixsrc.to",
      },
    });

    if (!embedResp.ok) throw new Error(`Embed ${embedResp.status}`);

    const html = await embedResp.text();

    // Step 3: Parse JS variables from HTML
    // window.video = { id: '...' }
    const videoSection = html.split("window.video = {")[1] || "";
    const videoId = this.between(videoSection, "id: '", "'");

    // window.masterPlaylist ... 'token': '...' ... 'expires': '...'
    const playlistSection = html.split("window.masterPlaylist")[1] || "";
    const token = this.between(playlistSection, "'token': '", "'");
    const expires = this.between(playlistSection, "'expires': '", "'");

    if (!videoId || !token || !expires) {
      throw new Error("Could not parse player parameters");
    }

    // Step 4: Construct playlist URL
    const queryParts = [`token=${encodeURIComponent(token)}`, `expires=${encodeURIComponent(expires)}`, "lang=en"];
    if (html.includes("b=1")) queryParts.push("b=1");
    if (html.includes("window.canPlayFHD = true")) queryParts.push("h=1");

    const playlistUrl = `https://vixsrc.to/playlist/${videoId}?${queryParts.join("&")}`;
    console.log(`VixSrc playlist: ${playlistUrl}`);

    // Step 5: Verify it's a valid HLS playlist
    const playlistResp = await fetch(playlistUrl, {
      headers: {
        "User-Agent": USER_AGENT,
        "Referer": "https://vixsrc.to",
        "Origin": "https://vixsrc.to",
      },
    });

    if (!playlistResp.ok) throw new Error(`Playlist ${playlistResp.status}`);

    const playlistText = await playlistResp.text();
    if (!playlistText.trimStart().startsWith("#EXTM3U")) {
      throw new Error("Not a valid HLS playlist");
    }

    return {
      url: playlistUrl,
      source: "VixSrc",
      type: "hls",
      referer: "https://vixsrc.to",
    };
  },

  // === VidLink Extractor ===
  // VidLink is a React app - we need to find the /api/b/ endpoint
  async extractVidLink(tmdbId, isMovie, season, episode) {
    const pageUrl = isMovie
      ? `https://vidlink.pro/movie/${tmdbId}`
      : `https://vidlink.pro/tv/${tmdbId}/${season}/${episode}`;

    console.log(`VidLink page: ${pageUrl}`);

    const resp = await fetch(pageUrl, {
      headers: {
        "User-Agent": USER_AGENT,
        "Referer": "https://vidlink.pro",
      },
      redirect: "follow",
    });

    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);

    const html = await resp.text();

    // Look for /api/b/ URLs in the HTML
    const apiMatch = html.match(/["'](\/api\/b\/[^"']+)["']/);
    if (apiMatch) {
      const apiUrl = `https://vidlink.pro${apiMatch[1]}`;
      console.log(`VidLink API: ${apiUrl}`);

      const apiResp = await fetch(apiUrl, {
        headers: {
          "User-Agent": USER_AGENT,
          "Referer": pageUrl,
        },
      });

      if (apiResp.ok) {
        const data = await apiResp.json();
        const playlist = data?.stream?.playlist;
        if (playlist) {
          return {
            url: playlist.startsWith("http") ? playlist : `https://vidlink.pro${playlist}`,
            source: "VidLink",
            type: "hls",
            referer: "https://vidlink.pro",
          };
        }
      }
    }

    // Look for m3u8 URLs directly in the HTML
    const m3u8Urls = this.extractUrls(html, /\.m3u8/);
    if (m3u8Urls.length > 0) {
      return {
        url: m3u8Urls[0],
        source: "VidLink",
        type: "hls",
        referer: "https://vidlink.pro",
      };
    }

    // Look for iframes that might contain the player
    const iframeMatch = html.match(/iframe[^>]+src=["']([^"']+)["']/i);
    if (iframeMatch) {
      const iframeUrl = new URL(iframeMatch[1], pageUrl).href;
      console.log(`VidLink iframe: ${iframeUrl}`);

      const iframeResp = await fetch(iframeUrl, {
        headers: {
          "User-Agent": USER_AGENT,
          "Referer": pageUrl,
        },
      });

      if (iframeResp.ok) {
        const iframeHtml = await iframeResp.text();
        const iframeM3u8 = this.extractUrls(iframeHtml, /\.m3u8/);
        if (iframeM3u8.length > 0) {
          return {
            url: iframeM3u8[0],
            source: "VidLink",
            type: "hls",
            referer: "https://vidlink.pro",
          };
        }
      }
    }

    return null;
  },

  // === 2Embed Extractor ===
  async extract2Embed(tmdbId, isMovie, season, episode) {
    const pageUrl = isMovie
      ? `https://www.2embed.cc/embed/${tmdbId}`
      : `https://www.2embed.cc/embedtv/${tmdbId}&s=${season}&e=${episode}`;

    console.log(`2Embed page: ${pageUrl}`);

    const resp = await fetch(pageUrl, {
      headers: {
        "User-Agent": USER_AGENT,
        "Referer": "https://www.2embed.cc",
      },
      redirect: "follow",
    });

    if (!resp.ok) throw new Error(`HTTP ${resp.status}`);

    const html = await resp.text();

    // Look for iframes
    const iframeMatch = html.match(/iframe[^>]+src=["']([^"']+)["']/i);
    if (iframeMatch) {
      let iframeUrl = iframeMatch[1];
      if (!iframeUrl.startsWith("http")) {
        iframeUrl = new URL(iframeUrl, pageUrl).href;
      }

      console.log(`2Embed iframe: ${iframeUrl}`);

      const iframeResp = await fetch(iframeUrl, {
        headers: {
          "User-Agent": USER_AGENT,
          "Referer": pageUrl,
        },
      });

      if (iframeResp.ok) {
        const iframeHtml = await iframeResp.text();

        // Look for m3u8
        const m3u8Urls = this.extractUrls(iframeHtml, /\.m3u8/);
        if (m3u8Urls.length > 0) {
          return {
            url: m3u8Urls[0],
            source: "2Embed",
            type: "hls",
            referer: iframeUrl,
          };
        }

        // Look for video source
        const videoUrls = this.extractUrls(iframeHtml, /\.(mp4|webm)/);
        if (videoUrls.length > 0) {
          return {
            url: videoUrls[0],
            source: "2Embed",
            type: "direct",
            referer: iframeUrl,
          };
        }

        // Look for nested iframes
        const nestedIframe = iframeHtml.match(/iframe[^>]+src=["']([^"']+)["']/i);
        if (nestedIframe) {
          let nestedUrl = nestedIframe[1];
          if (!nestedUrl.startsWith("http")) {
            nestedUrl = new URL(nestedUrl, iframeUrl).href;
          }

          const nestedResp = await fetch(nestedUrl, {
            headers: {
              "User-Agent": USER_AGENT,
              "Referer": iframeUrl,
            },
          });

          if (nestedResp.ok) {
            const nestedHtml = await nestedResp.text();
            const nestedM3u8 = this.extractUrls(nestedHtml, /\.m3u8/);
            if (nestedM3u8.length > 0) {
              return {
                url: nestedM3u8[0],
                source: "2Embed",
                type: "hls",
                referer: nestedUrl,
              };
            }
          }
        }
      }
    }

    return null;
  },

  // === Utility Functions ===

  extractUrls(html, pattern) {
    const urls = new Set();
    const regex = new RegExp(`["'](https?://[^"'<>]*${pattern}[^"'<>]*)["']`, "gi");
    let match;
    while ((match = regex.exec(html)) !== null) {
      let url = match[1];
      if (url.startsWith("//")) url = "https:" + url;
      urls.add(url);
    }
    // Also check for relative URLs
    const relRegex = new RegExp(`["']([^"'<>]*${pattern}[^"'<>]*)["']`, "gi");
    while ((match = relRegex.exec(html)) !== null) {
      const url = match[1];
      if (url.startsWith("http") || url.startsWith("//")) {
        urls.add(url.startsWith("//") ? "https:" + url : url);
      }
    }
    return [...urls];
  },

  between(str, start, end) {
    const startIdx = str.indexOf(start);
    if (startIdx === -1) return null;
    const afterStart = str.substring(startIdx + start.length);
    const endIdx = afterStart.indexOf(end);
    if (endIdx === -1) return null;
    return afterStart.substring(0, endIdx);
  },
};
