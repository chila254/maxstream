import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import '../services/watch_history_service.dart';
import '../services/settings_service.dart';
import '../services/combined_stream_service.dart';

class InAppVideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;
  final String? posterUrl;
  final double? userRating;

  const InAppVideoPlayerScreen({
    super.key,
    this.videoUrl,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
    this.posterUrl,
    this.userRating,
  });

  @override
  State<InAppVideoPlayerScreen> createState() =>
      _InAppVideoPlayerScreenState();
}

class _InAppVideoPlayerScreenState extends State<InAppVideoPlayerScreen>
    with TickerProviderStateMixin {
  late InAppWebViewController _webViewController;
  bool _isPlayerReady = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  Timer? _controlsTimer;
  Timer? _progressTimer;
  Duration _lastPosition = Duration.zero;

  // Playback settings
  bool _showControls = true;
  bool _autoPlay = true;
  bool _rememberPosition = true;

  // Settings from SettingsService
  Map<String, dynamic> _playerSettings = {};

  // Stream source
  String? _streamSource;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _setupAnimations();
    _loadSettings();
    _loadWatchHistory();
    _initializePlayer();
  }

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      _playerSettings = await SettingsService.getAllPlayerSettings();

      // Apply player settings to state variables
      _autoPlay = _playerSettings['autoPlay'] ?? true;
      _rememberPosition = _playerSettings['rememberPosition'] ?? true;

      setState(() {});
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  /// Ad blocking JavaScript injection
  String _getAdBlockingScript() {
    return '''
    (function() {
      // Block common ad networks
      const adDomains = [
        'google', 'doubleclick', 'googlesyndication', 'googleadservices',
        'pagead', 'adsbygoogle', 'ads-service', 'ads', 'advertising',
        'adv', 'banner', 'amazon-adsystem', 'amazon', 'criteo', 'adzerk',
        'aol', 'yahoo', 'bing', 'facebook', 'fb', 'twitter', 'chartbeat',
        'rubicon', 'openx', 'pubmatic', 'appnexus', 'innity', 'adverticum'
      ];
      
      // Block ad iframes
      const iframes = document.querySelectorAll('iframe');
      iframes.forEach(function(iframe) {
        let shouldBlock = false;
        const src = iframe.src || '';
        const id = iframe.id || '';
        const className = iframe.className || '';
        
        adDomains.forEach(domain => {
          if (src.includes(domain) || id.includes(domain) || className.includes(domain)) {
            shouldBlock = true;
          }
        });
        
        if (shouldBlock || src.includes('ad') || src.includes('advertisement')) {
          iframe.style.display = 'none';
          iframe.remove();
        }
      });
      
      // Block ad divs
      const adClasses = ['ad', 'ads', 'advertisement', 'advert', 'banner', 'sponsor', 'ad-container'];
      const adDivs = document.querySelectorAll('[class*="ad"], [id*="ad"], [class*="sponsor"]');
      adDivs.forEach(function(div) {
        const className = div.className || '';
        const id = div.id || '';
        
        if (adClasses.some(cls => className.toLowerCase().includes(cls) || id.toLowerCase().includes(cls))) {
          div.style.display = 'none';
        }
      });
      
      // Block scripts from ad networks
      const scripts = document.querySelectorAll('script');
      scripts.forEach(function(script) {
        const src = script.src || '';
        let shouldBlock = false;
        
        adDomains.forEach(domain => {
          if (src.includes(domain)) {
            shouldBlock = true;
          }
        });
        
        if (shouldBlock) {
          script.remove();
        }
      });
      
      // Inject global ad blockers
      window.adsbygoogle = [];
      window.googletag = {
        cmd: [],
        defineSlot: function() { return this; },
        addService: function() { return this; },
        enableServices: function() { return this; },
        pubads: function() { return this; },
        display: function() { return this; }
      };
    })();
    ''';
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Extract stream URL using CombinedStreamService
      final streamResult = await CombinedStreamService.extractStream(
        widget.tmdbId,
        widget.isMovie,
        season: widget.season,
        episode: widget.episode,
      );

      String? bestUrl;
      if (streamResult != null && streamResult['streamUrl'] != null) {
        bestUrl = streamResult['streamUrl'];
        _streamSource = streamResult['source'];
        debugPrint(
          'InAppPlayer: Using extracted stream URL: $bestUrl from $_streamSource',
        );
      } else {
        bestUrl = widget.videoUrl;
        _streamSource = null;
        debugPrint('InAppPlayer: Using fallback video URL: $bestUrl');
      }

      if (bestUrl == null) {
        throw Exception('No video URL available');
      }

      // Build HTML5 video player with controls
      final htmlContent = _buildVideoHtml(bestUrl);

      if (!mounted) return;

      // Load HTML content
      await _webViewController.loadData(
        data: htmlContent,
        mimeType: 'text/html',
        encoding: 'utf8',
      );

      _startProgressTracking();
      _startControlsTimer();

      setState(() {
        _isPlayerReady = true;
        _isLoading = false;
      });

      _showControlsWithAnimation();
    } catch (e) {
      debugPrint('InAppPlayer error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load video. Please check your internet connection and try again.';
      });
    }
  }

  String _buildVideoHtml(String videoUrl) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        body {
          background: #000;
          width: 100%;
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        video {
          width: 100%;
          height: 100%;
          max-width: 100%;
          max-height: 100%;
          display: block;
        }
        .container {
          width: 100%;
          height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: #000;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <video 
          id="videoPlayer" 
          controls 
          autoplay 
          controlsList="nodownload"
          style="width: 100%; height: 100%;">
          <source src="$videoUrl" type="video/mp4">
          Your browser does not support the video tag.
        </video>
      </div>
      
      <script>
        ${_getAdBlockingScript()}
        
        // Save progress to Flutter
        const player = document.getElementById('videoPlayer');
        
        player.addEventListener('timeupdate', function() {
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'progressUpdate',
              position: player.currentTime,
              duration: player.duration
            }));
          }
        });
        
        player.addEventListener('play', function() {
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({action: 'play'}));
          }
        });
        
        player.addEventListener('pause', function() {
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({action: 'pause'}));
          }
        });
        
        // Run ad blocking on load
        window.addEventListener('load', function() {
          ${_getAdBlockingScript()}
        });
        
        // Run ad blocking periodically to catch dynamically loaded ads
        setInterval(function() {
          ${_getAdBlockingScript()}
        }, 2000);
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView for video playback
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              mixedContentMode:
                  AndroidMixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              // Add JavaScript channel for Flutter communication
              controller.addJavaScriptHandler(
                handlerName: 'Flutterplayer',
                callback: (args) {
                  if (args.isNotEmpty) {
                    try {
                      final data = args[0] as String;
                      _handlePlayerMessage(data);
                    } catch (e) {
                      debugPrint('Error handling player message: $e');
                    }
                  }
                },
              );
            },
            onLoadStop: (controller, url) {
              // Re-run ad blocking after page load
              controller.evaluateJavascript(
                source: _getAdBlockingScript(),
              );
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;
              
              // Block ad network URLs
              if (uri != null) {
                final uriString = uri.toString().toLowerCase();
                if (uriString.contains('google') ||
                    uriString.contains('doubleclick') ||
                    uriString.contains('ad') ||
                    uriString.contains('advertisement')) {
                  return NavigationActionPolicy.CANCEL;
                }
              }
              
              return NavigationActionPolicy.ALLOW;
            },
          ),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // Error overlay
          if (_errorMessage != null) _buildErrorOverlay(),

          // Controls
          _buildCustomControls(),
        ],
      ),
    );
  }

  Widget _buildCustomControls() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _showControls ? _controlsAnimation.value : 0.0,
          child: GestureDetector(
            onTap: _toggleControlsVisibility,
            child: Container(
              color: Colors.transparent,
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading ${widget.title}...',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializePlayer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePlayerMessage(String message) {
    try {
      debugPrint('Player message: $message');
      // Parse and handle player messages if needed
    } catch (e) {
      debugPrint('Error parsing player message: $e');
    }
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _showControlsWithAnimation();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _showControlsWithAnimation() {
    _controlsAnimationController.forward();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _startProgressTracking() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveWatchHistory();
    });
  }

  Future<void> _loadWatchHistory() async {
    _lastPosition = await WatchHistoryService.loadWatchPosition(
      widget.tmdbId,
      widget.isMovie,
      widget.season,
      widget.episode,
    );
  }

  Future<void> _saveWatchHistory() async {
    // Save position (InAppWebView doesn't provide direct position access)
    // This would be handled through JavaScript communication
    await WatchHistoryService.saveWatchProgress(
      tmdbId: widget.tmdbId,
      title: widget.title,
      isMovie: widget.isMovie,
      season: widget.season,
      episode: widget.episode,
      position: _lastPosition,
      duration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _saveWatchHistory();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();

    _controlsAnimationController.dispose();
    CombinedStreamService.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }
}
