import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/m3u8_service.dart';

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
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _error = null;
            });
            // Inject ad blocking immediately when page starts loading
            _injectAdBlocker();
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            // Continue ad blocking after page loads
            _injectAdBlocker();
            _startPeriodicAdRemoval();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');
            
            // HTTP/2 protocol errors are often recoverable with embed servers
            // Only show error if it's not a protocol-level issue
            if (error.description.contains('ERR_HTTP2_PROTOCOL_ERROR') ||
                error.description.contains('net::') ||
                error.description.contains('ERR_CONNECTION')) {
              debugPrint('M3U8VideoPlayerScreen: Network-level error (may be recoverable): ${error.description}');
              // Don't immediately fail - let the page try to recover
            } else {
              setState(() {
                _error = error.description;
                _isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Block common ad domains
            if (_isAdDomain(request.url)) {
              debugPrint('Blocked ad request: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
  }

  Future<void> _loadEmbeddedVideo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Try to get embedded video by TMDB ID
      final streamData = await EmbeddedVideoService.getEmbeddedVideo(
        widget.tmdbId,
        season: widget.season,
        episode: widget.episode,
        isMovie: widget.isMovie,
      );

      if (streamData == null) {
        // Fallback to search by title
        final searchData = await EmbeddedVideoService.searchAndGetEmbeddedVideo(
          widget.title,
          season: widget.season,
          episode: widget.episode,
          isMovie: widget.isMovie,
        );

        if (searchData != null) {
          _streamData = searchData;
        } else {
          setState(() {
            _error = 'No embedded video found for this content';
            _isLoading = false;
          });
          return;
        }
      } else {
        _streamData = streamData;
      }

      final embedUrl = _streamData!['embedUrl'] as String;

      // Load the embed URL in WebView
      await _webViewController.loadRequest(Uri.parse(embedUrl));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load embedded video: $e';
        _isLoading = false;
      });
    }
  }

  // Ad blocking methods
  void _injectAdBlocker() async {
    try {
      // Inject CSS to hide common ad elements
      const adBlockerCSS = '''
        /* Hide common ad selectors */
        .ad, .ads, .advertisement, .advertising,
        [class*="ad-"], [class*="ads-"], [class*="advert"],
        [id*="ad-"], [id*="ads-"], [id*="advert"],
        .banner, .popup, .overlay, .modal,
        .sponsored, .promo, .promotion,
        iframe[src*="ads"], iframe[src*="doubleclick"],
        iframe[src*="googlesyndication"], iframe[src*="amazon-ads"],
        div[style*="position: fixed"], div[style*="position:fixed"],
        .sticky-ad, .floating-ad, .bottom-ad, .top-ad,
        .video-ad, .ad-video, .ad-container,
        .google-ad, .facebook-ad, .twitter-ad,
        .ad-banner, .ad-sidebar, .ad-footer,
        .interstitial, .interstitial-ad,
        .pre-roll, .mid-roll, .post-roll,
        .ad-break, .commercial-break {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          height: 0 !important;
          width: 0 !important;
          position: absolute !important;
          left: -9999px !important;
          top: -9999px !important;
        }

        /* Hide specific ad network elements */
        [data-ad], [data-ads], [data-advertisement],
        .ad-slot, .ad-unit, .ad-wrapper,
        .dfp-ad, .gpt-ad, .adsbygoogle,
        .pubads, .video-ads, .ad-player {
          display: none !important;
        }

        /* Hide popups and overlays */
        .popup, .modal, .overlay, .lightbox,
        .dialog, .alert, .notification,
        [role="dialog"], [role="alert"] {
          display: none !important;
        }
      ''';

      // Inject JavaScript to remove ads dynamically
      const adBlockerJS = '''
        (function() {
          'use strict';

          // Function to remove ad elements
          function removeAds() {
            const adSelectors = [
              '.ad', '.ads', '.advertisement', '.advertising',
              '[class*="ad-"]', '[class*="ads-"]', '[class*="advert"]',
              '[id*="ad-"]', '[id*="ads-"]', '[id*="advert"]',
              '.banner', '.popup', '.overlay', '.modal',
              '.sponsored', '.promo', '.promotion',
              'iframe[src*="ads"]', 'iframe[src*="doubleclick"]',
              'iframe[src*="googlesyndication"]', 'iframe[src*="amazon-ads"]',
              '.google-ad', '.facebook-ad', '.twitter-ad',
              '.ad-banner', '.ad-sidebar', '.ad-footer',
              '.interstitial', '.interstitial-ad',
              '.pre-roll', '.mid-roll', '.post-roll',
              '.ad-break', '.commercial-break',
              '[data-ad]', '[data-ads]', '[data-advertisement]',
              '.ad-slot', '.ad-unit', '.ad-wrapper',
              '.dfp-ad', '.gpt-ad', '.adsbygoogle',
              '.pubads', '.video-ads', '.ad-player'
            ];

            adSelectors.forEach(selector => {
              try {
                const elements = document.querySelectorAll(selector);
                elements.forEach(el => {
                  el.style.display = 'none';
                  el.style.visibility = 'hidden';
                  el.style.opacity = '0';
                  el.style.height = '0px';
                  el.style.width = '0px';
                  el.style.position = 'absolute';
                  el.style.left = '-9999px';
                  el.style.top = '-9999px';
                  el.remove();
                });
              } catch(e) {}
            });

            // Remove fixed positioned elements that might be ads
            try {
              const allElements = document.querySelectorAll('*');
              allElements.forEach(el => {
                const style = window.getComputedStyle(el);
                if (style.position === 'fixed' || style.position === 'sticky') {
                  const rect = el.getBoundingClientRect();
                  // Remove if it's likely an ad (small elements in corners)
                  if ((rect.width < 400 && rect.height < 200) &&
                      (rect.top < 50 || rect.bottom > window.innerHeight - 50 ||
                       rect.left < 50 || rect.right > window.innerWidth - 50)) {
                    el.style.display = 'none';
                  }
                }
              });
            } catch(e) {}
          }

          // Run immediately
          removeAds();

          // Run again after a short delay
          setTimeout(removeAds, 1000);
          setTimeout(removeAds, 3000);
          setTimeout(removeAds, 5000);

          // Set up observer to watch for new ad elements
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.type === 'childList') {
                removeAds();
              }
            });
          });

          observer.observe(document.body, {
            childList: true,
            subtree: true
          });

          // Override common ad functions
          window.google_ad_client = null;
          window.adsbygoogle = null;
          window.googletag = null;

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
    ];

    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();

      return adDomains.any((domain) => host.contains(domain));
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
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
      appBar: AppBar(
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
                  _streamData!['source'] ?? 'Embedded',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
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
          : Stack(
              children: [
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
