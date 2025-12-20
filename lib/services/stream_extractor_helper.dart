/// Helper for stream URL extraction strategies
/// Provides debugging and alternative extraction methods
class StreamExtractorHelper {

  /// Get a comprehensive extraction JavaScript that handles various scenarios
  static String getExtractionScript() {
    return '''
      (function() {
        let streamUrl = null;
        let attempts = 0;
        const maxAttempts = 20;
        const startTime = Date.now();
        
        function sendStreamUrl(url) {
          if (url && url.trim() && url.length > 10) {
            const elapsed = Date.now() - startTime;
            console.log('✓ Stream URL found after ' + elapsed + 'ms: ' + url.substring(0, 100));
            StreamExtractor.postMessage(url);
          }
        }
        
        function extractStream() {
          attempts++;
          const elapsed = Date.now() - startTime;
          console.log('[' + elapsed + 'ms] Attempt ' + attempts + '/' + maxAttempts);
          
          // Priority 1: Direct player source (most reliable)
          try {
            if (window.player?.source) {
              streamUrl = window.player.source;
              if (streamUrl && streamUrl.startsWith('http')) {
                console.log('Found: window.player.source');
                return true;
              }
            }
          } catch (e) {}
          
          // Priority 2: Video elements
          try {
            const videos = document.querySelectorAll('video[src], video > source[src]');
            for (let video of videos) {
              let src = video.src || video.getAttribute('src');
              if (src && src.startsWith('http')) {
                console.log('Found: video element src');
                streamUrl = src;
                return true;
              }
            }
          } catch (e) {}
          
          // Priority 3: HLS/DASH manifests in script tags
          try {
            const scripts = Array.from(document.querySelectorAll('script'));
            for (let script of scripts) {
              const text = script.textContent || '';
              
              // Extract m3u8
              const m3u8 = text.match(/https?:\\/\\/[^\\s"'<>]+\\.m3u8[^\\s"'<>]*/i);
              if (m3u8 && !m3u8[0].includes('player.js')) {
                console.log('Found: m3u8 manifest');
                streamUrl = m3u8[0];
                return true;
              }
              
              // Extract mp4
              const mp4 = text.match(/https?:\\/\\/[^\\s"'<>]+\\.mp4[^\\s"'<>]*/i);
              if (mp4) {
                console.log('Found: mp4 video');
                streamUrl = mp4[0];
                return true;
              }
              
              // Extract mpd
              const mpd = text.match(/https?:\\/\\/[^\\s"'<>]+\\.mpd[^\\s"'<>]*/i);
              if (mpd) {
                console.log('Found: mpd manifest');
                streamUrl = mpd[0];
                return true;
              }
            }
          } catch (e) {
            console.log('Script search error: ' + e.message);
          }
          
          // Priority 4: Data attributes
          try {
            const elements = document.querySelectorAll('[data-src], [data-url], [data-file]');
            for (let el of elements) {
              let url = el.getAttribute('data-src') || el.getAttribute('data-url') || el.getAttribute('data-file');
              if (url && url.startsWith('http') && (url.includes('.m3u8') || url.includes('.mp4'))) {
                console.log('Found: data attribute url');
                streamUrl = url;
                return true;
              }
            }
          } catch (e) {}
          
          // Priority 5: Global window objects
          try {
            const common = ['player', 'videoPlayer', 'hlsPlayer', 'dashPlayer', 'config', 'playerConfig'];
            for (let key of common) {
              if (window[key]) {
                const obj = window[key];
                if (obj.url && typeof obj.url === 'string' && obj.url.startsWith('http')) {
                  console.log('Found: window.' + key + '.url');
                  streamUrl = obj.url;
                  return true;
                }
                if (obj.src && typeof obj.src === 'string' && obj.src.startsWith('http')) {
                  console.log('Found: window.' + key + '.src');
                  streamUrl = obj.src;
                  return true;
                }
                if (obj.source && typeof obj.source === 'string' && obj.source.startsWith('http')) {
                  console.log('Found: window.' + key + '.source');
                  streamUrl = obj.source;
                  return true;
                }
              }
            }
          } catch (e) {}
          
          return false;
        }
        
        // Main extraction loop
        if (extractStream()) {
          sendStreamUrl(streamUrl);
        } else if (attempts < maxAttempts) {
          const delay = attempts < 5 ? 250 : attempts < 10 ? 400 : 600;
          setTimeout(extractStream, delay);
        } else {
          console.log('Failed after ' + maxAttempts + ' attempts in ' + (Date.now() - startTime) + 'ms');
          console.log('Page: ' + window.location.hostname);
          StreamExtractor.postMessage('');
        }
      })();
    ''';
  }

  /// Get a fallback extraction script for stubborn providers
  static String getFallbackExtractionScript() {
    return '''
      (function() {
        let found = false;
        
        // Aggressive search through all window properties
        try {
          for (let key in window) {
            try {
              const val = window[key];
              if (typeof val === 'string' && val.startsWith('http') && 
                  (val.includes('.m3u8') || val.includes('.mp4') || val.includes('.mpd'))) {
                console.log('Fallback found: ' + key);
                StreamExtractor.postMessage(val);
                found = true;
                break;
              }
              if (typeof val === 'object' && val !== null) {
                for (let prop in val) {
                  try {
                    const innerVal = val[prop];
                    if (typeof innerVal === 'string' && innerVal.startsWith('http') && 
                        (innerVal.includes('.m3u8') || innerVal.includes('.mp4'))) {
                      console.log('Fallback found: window.' + key + '.' + prop);
                      StreamExtractor.postMessage(innerVal);
                      found = true;
                      break;
                    }
                  } catch (e) {}
                }
                if (found) break;
              }
            } catch (e) {}
          }
        } catch (e) {
          console.log('Fallback error: ' + e);
        }
        
        if (!found) {
          StreamExtractor.postMessage('');
        }
      })();
    ''';
  }
}
