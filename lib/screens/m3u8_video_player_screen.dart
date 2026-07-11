import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../services/direct_m3u8_service.dart';
import '../services/vidlink_extractor.dart';

class M3U8VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;

  const M3U8VideoPlayerScreen({
    super.key,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<M3U8VideoPlayerScreen> createState() => _M3U8VideoPlayerScreenState();
}

class _M3U8VideoPlayerScreenState extends State<M3U8VideoPlayerScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _streamData;
  final List<Map<String, dynamic>> _triedServers = [];
  bool _isSelectingServer = false;

  // Native extraction state for the preferred source.
  bool _extractingVidLink = false;
  String? _vidLinkEmbedUrl;

  // Native player variables
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _useNativePlayer = false;

  @override
  void initState() {
    super.initState();

    // Force landscape for playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _initializeWebView();
    _loadEmbeddedVideo();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _error = null;
              });
            }
            // Inject ad blocking immediately when page starts loading
            _injectAdBlocker();
          },
          onPageFinished: (String url) {
            // Try to extract video URL for native playback
            _tryExtractVideoUrl();

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            // Continue ad blocking after page loads
            _injectAdBlocker();
            _startPeriodicAdRemoval();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');

            // Subresources such as ads, analytics, subtitles, and media chunks
            // can fail while playback remains healthy. Only surface a main-frame
            // failure, and never change the selected server automatically.
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _error = error.description;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Block common ad domains and requests
            if (_isAdDomain(request.url) || _isAdRequest(request.url)) {
              debugPrint('Blocked ad request: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _loadEmbeddedVideo() async {
    _triedServers.clear();
    _isSelectingServer = false;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // First, try to fetch direct m3u8 URL
      await _tryDirectM3u8Stream();
    } catch (e) {
      setState(() {
        _error = 'Failed to load embedded video: $e';
        _isLoading = false;
      });
    }
  }

  /// Try to fetch direct m3u8 stream for movies/series
  Future<void> _tryDirectM3u8Stream() async {
    try {
      debugPrint('M3U8VideoPlayer: Attempting to fetch direct m3u8 stream...');

      late Map<String, dynamic>? result;

      if (widget.isMovie) {
        result = await DirectM3u8Service.fetchMovieStreamUrl(
          widget.title,
          null,
          widget.tmdbId,
        );
      } else {
        result = await DirectM3u8Service.fetchSeriesStreamUrl(
          widget.title,
          widget.season,
          widget.episode,
          widget.tmdbId,
        );
      }

      if (result != null && result['url'] != null) {
        final m3u8Url = result['url'] as String;
        final headers =
            (result['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{};
        debugPrint(
          'M3U8VideoPlayer: Found direct m3u8 stream from ${result['source']}: $m3u8Url',
        );

        _streamData = {
          'streamUrl': m3u8Url,
          'title': widget.title,
          'quality': 'HD',
          'source': result['source'] ?? 'Direct M3U8',
          'type': 'direct_m3u8',
          'headers': headers,
          'isPlayable': true,
        };

        // Attempt to play directly using native video player
        await _playDirectM3u8(m3u8Url, headers: headers);
        return;
      }

      debugPrint(
        'M3U8VideoPlayer: No direct m3u8 stream found, trying VidLink native extraction...',
      );
      // Extract VidLink's direct playlist and play it natively (no WebView).
      if (_startVidLinkExtraction()) return;

      debugPrint(
        'M3U8VideoPlayer: VidLink extraction unavailable, falling back to embed providers...',
      );
      // If extraction cannot start, try embed providers
      await _tryNextServer();
    } catch (e) {
      debugPrint('M3U8VideoPlayer: Error fetching direct m3u8: $e');
      // Try VidLink native extraction, then fall back to embed providers.
      if (_startVidLinkExtraction()) return;
      await _tryNextServer();
    }
  }

  /// Start hidden VidLink extraction. Returns true if extraction was initiated
  /// (callbacks will continue the flow), false if it could not be started.
  bool _startVidLinkExtraction() {
    if (_extractingVidLink) return true;

    final url = widget.isMovie
        ? DirectM3u8Service.generateMovieEmbedUrl(widget.tmdbId, 'VidLink')
        : DirectM3u8Service.generateTvEmbedUrl(
            widget.tmdbId,
            widget.season,
            widget.episode,
            'VidLink',
          );

    if (url.isEmpty) return false;

    _vidLinkEmbedUrl = url;
    if (mounted) setState(() => _extractingVidLink = true);
    return true;
  }

  void _onVidLinkExtracted(String playlist, Map<String, String> headers) {
    if (!mounted) return;
    setState(() => _extractingVidLink = false);
    _playDirectM3u8(playlist, headers: headers);
  }

  void _onVidLinkError(Object error) {
    debugPrint('M3U8VideoPlayer: VidLink native extraction failed: $error');
    if (!mounted) return;
    setState(() => _extractingVidLink = false);
    _tryNextServer();
  }

  /// Play direct m3u8 stream using native video player
  Future<void> _playDirectM3u8(
    String m3u8Url, {
    Map<String, String> headers = const {},
  }) async {
    try {
      debugPrint(
        'M3U8VideoPlayer: Initializing native player with m3u8: $m3u8Url',
      );

      // Dispose previous controllers
      await _videoPlayerController?.dispose();
      _chewieController?.dispose();

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(m3u8Url),
        httpHeaders: headers,
      );

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        showControlsOnInitialize: true,
        allowFullScreen: true,
        allowMuting: true,
        fullScreenByDefault: true,
        allowPlaybackSpeedChanging: true,
        hideControlsTimer: const Duration(seconds: 4),
        progressIndicatorDelay: const Duration(milliseconds: 150),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.white70,
          playedColorAtDragStart: Colors.red.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      _useNativePlayer = true;

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      debugPrint('M3U8VideoPlayer: Native player initialized successfully');
    } catch (e) {
      debugPrint('M3U8VideoPlayer: Error initializing native player: $e');
      // If native player fails, fall back to embed providers
      await _tryNextServer();
    }
  }

  Future<void> _tryNextServer() async {
    if (_isSelectingServer || _useNativePlayer || !mounted) return;
    _isSelectingServer = true;

    try {
      final embedProviders = DirectM3u8Service.getEmbedSources().map((source) {
        final sourceName = source['name'] ?? '';
        final url = widget.isMovie
            ? DirectM3u8Service.generateMovieEmbedUrl(widget.tmdbId, sourceName)
            : DirectM3u8Service.generateTvEmbedUrl(
                widget.tmdbId,
                widget.season,
                widget.episode,
                sourceName,
              );

        return {'name': sourceName, 'url': url, 'type': 'embed'};
      }).toList();

      // Try each provider
      for (final provider in embedProviders) {
        // Check if we already tried this provider
        if (_triedServers.any((tried) => tried['name'] == provider['name'])) {
          continue;
        }

        try {
          debugPrint('Trying source: ${provider['name']}');
          final embedUrl = provider['url'] as String;

          if (embedUrl.isEmpty) {
            debugPrint('Skipping ${provider['name']} - invalid URL');
            _triedServers.add(provider);
            continue;
          }

          _streamData = {
            'embedUrl': embedUrl,
            'title': widget.title,
            'quality': 'HD',
            'source': provider['name'],
            'type': 'embed',
            'isPlayable': true,
          };

          _triedServers.add(provider);

          // Load the embed URL in WebView. Do not preflight with HEAD: several
          // providers reject probes but work when loaded as a browser page.
          try {
            await _webViewController.loadRequest(Uri.parse(embedUrl));
          } catch (e) {
            debugPrint('Error loading request into WebView: $e');
            continue;
          }

          // Set a timeout to ensure loading indicator disappears even if onPageFinished never fires
          Future.delayed(const Duration(seconds: 20), () {
            if (mounted && _isLoading) {
              debugPrint('Loading timeout - hiding loading indicator');
              setState(() {
                _isLoading = false;
              });
            }
          });

          debugPrint('Successfully loaded embed from ${provider['name']}');
          return;
        } catch (e) {
          debugPrint('Provider ${provider['name']} failed: $e');
          _triedServers.add(provider);
          continue;
        }
      }

      // No sources worked
      if (mounted) {
        setState(() {
          _error =
              'No working streaming sources found. Please check:\n'
              '• Internet connection\n'
              '• Try again later\n'
              '• Content might be unavailable';
          _isLoading = false;
        });
      }
    } finally {
      _isSelectingServer = false;
    }
  }

  // Ad blocking methods
  void _injectAdBlocker() async {
    try {
      // Inject CSS to hide common ad elements
      const adBlockerCSS = '''
        /* Aggressive ad blocking - hide all known ad selectors */
        .ad, .ads, .advertisement, .advertising, .advert,
        [class*="ad-"], [class*="ads-"], [class*="advert"],
        [id*="ad-"], [id*="ads-"], [id*="advert"],
        .banner, .popup, .overlay, .modal, .lightbox,
        .sponsored, .promo, .promotion, .promoted,
        iframe[src*="ads"], iframe[src*="doubleclick"],
        iframe[src*="googlesyndication"], iframe[src*="amazon-ads"],
        iframe[src*="facebook"], iframe[src*="twitter"],
        div[style*="position: fixed"], div[style*="position:fixed"],
        div[style*="position: absolute"], div[style*="position:absolute"],
        .sticky-ad, .floating-ad, .bottom-ad, .top-ad,
        .video-ad, .ad-video, .ad-container, .ad-wrapper,
        .google-ad, .facebook-ad, .twitter-ad, .instagram-ad,
        .ad-banner, .ad-sidebar, .ad-footer, .ad-header,
        .interstitial, .interstitial-ad, .ad-interstitial,
        .pre-roll, .mid-roll, .post-roll, .ad-roll,
        .ad-break, .commercial-break, .commercial,
        .skip-ad, .ad-skip, .skip-button, .ad-skip-button,
        .close-ad, .ad-close, .close-button,
        .vast-ad, .vpaid-ad, .ima-ad,
        .jwplayer-ad, .video-js-ad, .plyr-ad,
        .ad-leaderboard, .ad-rectangle, .ad-square,
        .ad-mobile, .ad-desktop, .ad-responsive {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          height: 0 !important;
          width: 0 !important;
          position: absolute !important;
          left: -9999px !important;
          top: -9999px !important;
          z-index: -9999 !important;
          pointer-events: none !important;
        }

        /* Hide specific ad network elements */
        [data-ad], [data-ads], [data-advertisement], [data-advert],
        .ad-slot, .ad-unit, .ad-wrapper, .ad-container,
        .dfp-ad, .gpt-ad, .adsbygoogle, .adsense,
        .pubads, .video-ads, .ad-player, .ad-video-player,
        .google-ads, .facebook-ads, .twitter-ads,
        .ad-manager, .ad-server, .ad-network,
        .vast, .vpaid, .ima, .ad-tag,
        .ad-injection, .ad-placeholder, .ad-space {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
        }

        /* Hide popups, dialogs, and overlays */
        .popup, .modal, .overlay, .lightbox, .dialog,
        .alert, .notification, .tooltip, .popover,
        [role="dialog"], [role="alert"], [role="tooltip"],
        .cookie-banner, .cookie-notice, .gdpr-banner,
        .newsletter-popup, .subscribe-popup, .signup-modal {
          display: none !important;
          visibility: hidden !important;
        }

        /* Hide video player ads */
        .jwplayer .jw-ad, .video-js .vjs-ad,
        .plyr .plyr-ad, .ad-container, .ad-overlay,
        .video-ad-container, .ad-video-container {
          display: none !important;
        }

        /* Hide iframes that are likely ads */
        iframe[width="1"], iframe[height="1"],
        iframe[src*="googletag"], iframe[src*="pubads"],
        iframe[src*="doubleclick"], iframe[src*="amazon"],
        iframe[src*="facebook"], iframe[src*="twitter"],
        iframe[src*="instagram"], iframe[src*="pinterest"] {
          display: none !important;
        }
      ''';

      // Inject JavaScript to remove ads dynamically
      const adBlockerJS = '''
        (function() {
          'use strict';

          // Function to remove ad elements aggressively
          function removeAds() {
            const adSelectors = [
              // Basic ad selectors
              '.ad', '.ads', '.advertisement', '.advertising', '.advert',
              '[class*="ad-"]', '[class*="ads-"]', '[class*="advert"]',
              '[id*="ad-"]', '[id*="ads-"]', '[id*="advert"]',
              '.banner', '.popup', '.overlay', '.modal', '.lightbox',
              '.sponsored', '.promo', '.promotion', '.promoted',

              // Ad network iframes
              'iframe[src*="ads"]', 'iframe[src*="doubleclick"]',
              'iframe[src*="googlesyndication"]', 'iframe[src*="amazon-ads"]',
              'iframe[src*="facebook"]', 'iframe[src*="twitter"]',
              'iframe[src*="googletag"]', 'iframe[src*="pubads"]',

              // Specific ad elements
              '.google-ad', '.facebook-ad', '.twitter-ad', '.instagram-ad',
              '.ad-banner', '.ad-sidebar', '.ad-footer', '.ad-header',
              '.interstitial', '.interstitial-ad', '.ad-interstitial',
              '.pre-roll', '.mid-roll', '.post-roll', '.ad-roll',
              '.ad-break', '.commercial-break', '.commercial',

              // Ad controls
              '.skip-ad', '.ad-skip', '.skip-button', '.ad-skip-button',
              '.close-ad', '.ad-close', '.close-button',

              // Video player ads
              '.jwplayer .jw-ad', '.video-js .vjs-ad', '.plyr .plyr-ad',
              '.ad-container', '.ad-overlay', '.video-ad-container',

              // Data attributes
              '[data-ad]', '[data-ads]', '[data-advertisement]',
              '.ad-slot', '.ad-unit', '.ad-wrapper',
              '.dfp-ad', '.gpt-ad', '.adsbygoogle', '.adsense',

              // Popups and dialogs
              '.popup', '.modal', '.overlay', '.dialog', '.alert',
              '.cookie-banner', '.gdpr-banner', '.newsletter-popup'
            ];

            adSelectors.forEach(selector => {
              try {
                const elements = document.querySelectorAll(selector);
                elements.forEach(el => {
                  el.style.setProperty('display', 'none', 'important');
                  el.style.setProperty('visibility', 'hidden', 'important');
                  el.style.setProperty('opacity', '0', 'important');
                  el.style.setProperty('height', '0px', 'important');
                  el.style.setProperty('width', '0px', 'important');
                  el.style.setProperty('position', 'absolute', 'important');
                  el.style.setProperty('left', '-9999px', 'important');
                  el.style.setProperty('top', '-9999px', 'important');
                  el.style.setProperty('z-index', '-9999', 'important');
                  el.style.setProperty('pointer-events', 'none', 'important');
                  el.remove();
                });
              } catch(e) {}
            });

            // Remove fixed/sticky positioned elements that might be ads
            try {
              const allElements = document.querySelectorAll('*');
              allElements.forEach(el => {
                const style = window.getComputedStyle(el);
                if (style.position === 'fixed' || style.position === 'sticky' ||
                    style.position === 'absolute') {
                  const rect = el.getBoundingClientRect();
                  // Remove if it's likely an ad (small elements in corners or overlays)
                  if ((rect.width < 500 && rect.height < 300) &&
                      (rect.top < 100 || rect.bottom > window.innerHeight - 100 ||
                       rect.left < 100 || rect.right > window.innerWidth - 100 ||
                       rect.width === window.innerWidth || rect.height === window.innerHeight)) {
                    el.style.setProperty('display', 'none', 'important');
                    el.remove();
                  }
                }
              });
            } catch(e) {}

            // Remove ad iframes by source
            try {
              const iframes = document.querySelectorAll('iframe');
              iframes.forEach(iframe => {
                const src = iframe.src || '';
                if (src.includes('ads') || src.includes('doubleclick') ||
                    src.includes('googlesyndication') || src.includes('amazon') ||
                    src.includes('facebook') || src.includes('twitter') ||
                    src.includes('googletag') || src.includes('pubads') ||
                    (iframe.width === '1' && iframe.height === '1')) {
                  iframe.remove();
                }
              });
            } catch(e) {}

            // Auto-click skip buttons
            try {
              const skipSelectors = [
                '.skip-ad', '.ad-skip', '.skip-button', '.ad-skip-button',
                '.close-ad', '.ad-close', '.close-button',
                '[class*="skip"]', '[id*="skip"]',
                'button:contains("Skip")', 'a:contains("Skip")',
                'button:contains("Close")', 'a:contains("Close")'
              ];

              skipSelectors.forEach(selector => {
                try {
                  const elements = document.querySelectorAll(selector);
                  elements.forEach(el => {
                    if (el.offsetParent !== null) { // Only if visible
                      el.click();
                    }
                  });
                } catch(e) {}
              });
            } catch(e) {}
          }

          // Function to block ad network requests
          function blockAdRequests() {
            // Override XMLHttpRequest to block ad requests
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url) {
              if (url.includes('ads') || url.includes('doubleclick') ||
                  url.includes('googlesyndication') || url.includes('amazon-ads') ||
                  url.includes('facebook') || url.includes('twitter') ||
                  url.includes('googletag') || url.includes('pubads')) {
                return; // Block the request
              }
              return originalOpen.apply(this, arguments);
            };

            // Override fetch to block ad requests
            const originalFetch = window.fetch;
            window.fetch = function(url, options) {
              if (typeof url === 'string' && (
                  url.includes('ads') || url.includes('doubleclick') ||
                  url.includes('googlesyndication') || url.includes('amazon-ads') ||
                  url.includes('facebook') || url.includes('twitter') ||
                  url.includes('googletag') || url.includes('pubads'))) {
                return Promise.reject(new Error('Ad request blocked'));
              }
              return originalFetch.apply(this, arguments);
            };
          }

          // Run immediately
          removeAds();
          blockAdRequests();

          // Run repeatedly to catch dynamic ads
          setTimeout(removeAds, 500);
          setTimeout(removeAds, 1000);
          setTimeout(removeAds, 2000);
          setTimeout(removeAds, 3000);
          setTimeout(removeAds, 5000);
          setTimeout(removeAds, 10000);

          // Set up observer to watch for new ad elements
          const observer = new MutationObserver(function(mutations) {
            let shouldRemove = false;
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
                shouldRemove = true;
              }
            });
            if (shouldRemove) {
              setTimeout(removeAds, 100);
            }
          });

          if (document.body) {
            observer.observe(document.body, {
              childList: true,
              subtree: true
            });
          }

          // Override common ad functions
          window.google_ad_client = null;
          window.adsbygoogle = null;
          window.googletag = null;
          window.googletagmanager = null;

          // Disable ad-related localStorage/cookies
          try {
            localStorage.removeItem('ads');
            localStorage.removeItem('google_ads');
            document.cookie.split(';').forEach(c => {
              if (c.includes('ads') || c.includes('doubleclick')) {
                document.cookie = c.replace(/^ +/, '').replace(/=.*/, '=;expires=' + new Date().toUTCString() + ';path=/');
              }
            });
          } catch(e) {}

        })();
      ''';

      // Inject CSS
      await _webViewController.runJavaScript('''
        var style = document.createElement('style');
        style.type = 'text/css';
        style.innerHTML = `$adBlockerCSS`;
        document.head.appendChild(style);
      ''');

      // Inject JavaScript
      await _webViewController.runJavaScript(adBlockerJS);
    } catch (e) {
      debugPrint('Ad blocker injection failed: $e');
    }
  }

  void _startPeriodicAdRemoval() {
    // Continue removing ads periodically
    Future.delayed(const Duration(seconds: 2), () => _injectAdBlocker());
    Future.delayed(const Duration(seconds: 5), () => _injectAdBlocker());
    Future.delayed(const Duration(seconds: 10), () => _injectAdBlocker());
  }

  Future<void> _tryExtractVideoUrl() async {
    try {
      // Inject JavaScript to extract video URLs
      const extractScript = '''
        (function() {
          try {
            // Look for video elements
            const videos = document.querySelectorAll('video');
            for (let video of videos) {
              if (video.src && video.src.includes('.m3u8')) {
                return video.src;
              }
            }

            // Look for player configurations (common in embed players)
            const scripts = document.querySelectorAll('script');
            for (let script of scripts) {
              const content = script.innerHTML;
              const m3u8Match = content.match(/https?:\\/\\/[^"']*\\.m3u8[^"']*/);
              if (m3u8Match) {
                return m3u8Match[0];
              }
            }

            // Look for JW Player config
            if (window.jwplayer) {
              const playlist = window.jwplayer().getPlaylist();
              if (playlist && playlist[0] && playlist[0].sources) {
                for (let source of playlist[0].sources) {
                  if (source.file && source.file.includes('.m3u8')) {
                    return source.file;
                  }
                }
              }
            }

            // Look for Plyr player
            if (window.plyr) {
              const plyr = window.plyr;
              if (plyr.source && plyr.source.sources) {
                for (let source of plyr.source.sources) {
                  if (source.src && source.src.includes('.m3u8')) {
                    return source.src;
                  }
                }
              }
            }

            // Look for HTML5 video tag (Artplayer, native video)
            const video = document.querySelector('video');
            if (video && video.src) {
              return video.src;
            }
            if (video) {
              const source = video.querySelector('source');
              if (source && source.src) {
                return source.src;
              }
            }

            return null;
          } catch(e) {
            return null;
          }
        })();
      ''';

      final result = await _webViewController.runJavaScriptReturningResult(
        extractScript,
      );
      final extractedUrl = result.toString().replaceAll('"', '');

      if (extractedUrl.isNotEmpty && extractedUrl != 'null') {
        debugPrint('Extracted video URL: $extractedUrl');
        await _initializeNativePlayer(extractedUrl);
      }
    } catch (e) {
      debugPrint('Failed to extract video URL: $e');
    }
  }

  Future<void> _initializeNativePlayer(String videoUrl) async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        showControlsOnInitialize: true,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        hideControlsTimer: const Duration(seconds: 4),
        progressIndicatorDelay: const Duration(milliseconds: 150),
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.white70,
          playedColorAtDragStart: Colors.red.shade300,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      setState(() {
        _useNativePlayer = true;
      });
    } catch (e) {
      debugPrint('Failed to initialize native player: $e');
      // Fall back to WebView
    }
  }

  bool _isAdDomain(String url) {
    // List of common ad domains to block
    const adDomains = [
      'doubleclick.net',
      'googlesyndication.com',
      'googleadservices.com',
      'amazon-adsystem.com',
      'adsystem.amazon',
      'facebook.com/tr',
      'connect.facebook.net',
      'twitter.com/i/ads',
      'ads.twitter.com',
      'outbrain.com',
      'taboola.com',
      'criteo.com',
      'pubmatic.com',
      'openx.net',
      'adnxs.com',
      'media.net',
      'yieldmo.com',
      'spotxchange.com',
      'springserve.com',
      'aniview.com',
      'playground.xyz',
      'vidoomy.com',
      'content.ad',
      'adsystem.',
      'adserver.',
      'advertising.com',
      'adtech.',
      'adroll.com',
      'hotjar.com',
      'analytics.',
      'tracking.',
      'metrics.',
      'googletagmanager.com',
      'gtm.',
      'ads.',
      'ad.',
      'advert.',
      'promo.',
      'sponsored.',
    ];

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      return adDomains.any((domain) => host.contains(domain));
    } catch (e) {
      return false;
    }
  }

  bool _isAdRequest(String url) {
    // Block requests containing ad-related keywords in URL
    const adKeywords = [
      'ads',
      'advert',
      'promo',
      'sponsored',
      'doubleclick',
      'googlesyndication',
      'amazon-ads',
      'facebook',
      'twitter',
      'googletag',
      'pubads',
      'analytics',
      'tracking',
      'metrics',
      'hotjar',
      'criteo',
      'pubmatic',
      'openx',
      'adnxs',
      'media.net',
      'yieldmo',
      'spotxchange',
      'springserve',
      'aniview',
      'playground',
      'vidoomy',
      'taboola',
      'outbrain',
    ];

    final lowerUrl = url.toLowerCase();
    return adKeywords.any((keyword) => lowerUrl.contains(keyword));
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _useNativePlayer
          ? null
          : AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                _streamData?['title'] ?? widget.title,
                style: const TextStyle(color: Colors.white),
              ),
              actions: [
                if (_streamData != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        _useNativePlayer
                            ? 'Native Player'
                            : (_streamData!['source'] ?? 'Embedded'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading video',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error ?? 'Unknown error',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                    ),
                    child: const Text('Go Back'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadEmbeddedVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _useNativePlayer && _chewieController != null
          ? Chewie(controller: _chewieController!)
          : Stack(
              children: [
                if (_extractingVidLink && _vidLinkEmbedUrl != null)
                  VidLinkExtractor(
                    key: const ValueKey('vidlink-extractor'),
                    embedUrl: _vidLinkEmbedUrl!,
                    onExtracted: _onVidLinkExtracted,
                    onError: _onVidLinkError,
                  ),
                WebViewWidget(controller: _webViewController),
                if (_isLoading)
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.red),
                        SizedBox(height: 16),
                        Text(
                          'Loading embedded video...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
