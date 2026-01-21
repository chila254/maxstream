import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:dio/dio.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../utils/tv_utils.dart';
import '../../services/watch_history_service.dart';
import '../../services/m3u8_service.dart';

class TvVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;

  const TvVideoPlayerScreen({
    super.key,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<TvVideoPlayerScreen> createState() => _TvVideoPlayerScreenState();
}

class _TvVideoPlayerScreenState extends State<TvVideoPlayerScreen> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _streamData;
  int _currentServerIndex = 0;
  List<Map<String, dynamic>> _triedServers = [];

  // Native player variables
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _useNativePlayer = false;

  @override
  void initState() {
    super.initState();

    // Force landscape for TV playback
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
            if (mounted) {
              setState(() {
                _isLoading = true;
                _error = null;
              });
            }
            _injectAdBlocker();
          },
          onPageFinished: (String url) {
            _tryExtractVideoUrl();

            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _injectAdBlocker();
            _startPeriodicAdRemoval();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('WebView error: ${error.description}');

            if (error.description.contains('ERR_HTTP2_PROTOCOL_ERROR') ||
                error.description.contains('net::') ||
                error.description.contains('ERR_CONNECTION')) {
              debugPrint(
                'Network error (may be recoverable): ${error.description}',
              );
              _tryNextServer();
            } else {
              if (mounted) {
                setState(() {
                  _error = error.description;
                  _isLoading = false;
                });
              }
            }
          },
        ),
      );
  }

  void _injectAdBlocker() {
    _webViewController.runJavaScript('''
      (function() {
        // Remove common ad elements
        const adSelectors = [
          'iframe[src*="ads"]',
          '[class*="ad-"]',
          '[id*="ad-"]',
          '.advertisement',
          '.ads',
          '[data-ad-slot]',
          'script[src*="ads"]',
        ];
        adSelectors.forEach(selector => {
          document.querySelectorAll(selector).forEach(el => el.remove());
        });

        // Block event tracking
        window.gtag = function() {};
        window.dataLayer = [];
      })();
    ''');
  }

  void _startPeriodicAdRemoval() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _injectAdBlocker();
        _startPeriodicAdRemoval();
      }
    });
  }

  Future<void> _loadEmbeddedVideo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _tryNextServer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load embedded video: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _tryNextServer() async {
    // Get all available servers
    final servers = EmbeddedVideoService.getServers();

    // Skip servers we've already tried
    while (_currentServerIndex < servers.length) {
      final server = servers[_currentServerIndex];
      _currentServerIndex++;

      // Check if we already tried this server
      if (_triedServers.any((tried) => tried['name'] == server['name'])) {
        continue;
      }

      try {
        debugPrint('Trying server: ${server['name']}');

        final embedUrl = EmbeddedVideoService.buildEmbedUrl(
          server['baseUrl']!,
          widget.tmdbId,
          widget.season,
          widget.episode,
          widget.isMovie,
        );

        // Quick check if server responds
        final dio = EmbeddedVideoService.getDioClient();
        final response = await dio
            .head(embedUrl)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw DioException(
                  requestOptions: RequestOptions(path: embedUrl),
                  message: 'Connection timeout',
                  type: DioExceptionType.connectionTimeout,
                );
              },
            );

        if (response.statusCode == 200 || response.statusCode == 403) {
          _streamData = {
            'embedUrl': embedUrl,
            'title': 'Video Content',
            'quality': 'HD',
            'source': server['name'],
            'type': 'embed',
            'isPlayable': true,
          };

          if (mounted) {
            _loadStreamInWebView(_streamData!);
            // Set a timeout to ensure loading indicator disappears even if onPageFinished never fires
            Future.delayed(const Duration(seconds: 15), () {
              if (mounted && _isLoading) {
                debugPrint('Loading timeout - hiding loading indicator');
                setState(() {
                  _isLoading = false;
                });
              }
            });
          }
          return;
        }
      } on DioException catch (e) {
        _triedServers.add({'name': server['name'], 'error': e.message});
        debugPrint('Server ${server['name']} failed: ${e.message}');
        continue;
      }
    }

    // All servers failed
    if (mounted) {
      setState(() {
        _error = 'All servers failed. Please try again later.';
        _isLoading = false;
      });
    }
  }

  void _loadStreamInWebView(Map<String, dynamic> streamUrl) {
    final embedUrl = streamUrl['embedUrl'] ?? '';
    if (embedUrl.isNotEmpty) {
      _webViewController.loadRequest(Uri.parse(embedUrl));
    }
  }

  void _tryExtractVideoUrl() {
    _webViewController.runJavaScript('''
      (function() {
        const videoElement = document.querySelector('video');
        if (videoElement && videoElement.src) {
          window.flutter_inappwebview.callHandler('videoUrlFound', {
            url: videoElement.src,
            type: 'direct'
          });
        }

        const sources = document.querySelectorAll('video source');
        if (sources.length > 0) {
          const sourceUrl = sources[0].src;
          if (sourceUrl) {
            window.flutter_inappwebview.callHandler('videoUrlFound', {
              url: sourceUrl,
              type: 'source'
            });
          }
        }
      })();
    ''');
  }

  @override
  void dispose() {
    // Save watch history before closing
    if (_videoPlayerController != null && mounted) {
      final position = _videoPlayerController!.value.position;
      final duration = _videoPlayerController!.value.duration;
      if (position > Duration.zero && duration > Duration.zero) {
        WatchHistoryService.saveWatchProgress(
          tmdbId: widget.tmdbId,
          title: widget.title,
          isMovie: widget.isMovie,
          season: widget.season,
          episode: widget.episode,
          position: position,
          duration: duration,
        );
      }
    }

    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _chewieController?.pause();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _useNativePlayer && _chewieController != null
            ? _buildNativePlayer()
            : _buildWebPlayer(),
      ),
    );
  }

  Widget _buildNativePlayer() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(child: Chewie(controller: _chewieController!)),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebPlayer() {
    return Stack(
      children: [
        WebViewWidget(controller: _webViewController),
        if (_isLoading)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Colors.red,
                  strokeWidth: TvUtils.responsivePadding(4, context).toDouble(),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TvUtils.responsiveFontSize(18, context),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Error: $_error',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadEmbeddedVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
