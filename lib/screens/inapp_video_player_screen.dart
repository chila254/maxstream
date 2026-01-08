import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/embed_discovery_service.dart';

class InAppVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;

  const InAppVideoPlayerScreen({
    super.key,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<InAppVideoPlayerScreen> createState() => _InAppVideoPlayerScreenState();
}

class _InAppVideoPlayerScreenState extends State<InAppVideoPlayerScreen> {
  bool _isLoading = true;
  late Future<Map<String, dynamic>?> _streamFuture;

  @override
  void initState() {
    super.initState();

    _streamFuture = _getStreamData();

    // Force landscape for playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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

  Future<Map<String, dynamic>?> _getStreamData() async {
    // Get embed URL from Stremio providers
    final embedResult = await EmbedDiscoveryService.extractStream(
      widget.tmdbId,
      widget.isMovie,
      season: widget.season,
      episode: widget.episode,
    );

    if (embedResult == null || embedResult['streamUrl'] == null) {
      return null;
    }

    final embedUrl = embedResult['streamUrl'] as String;

    // Return embed URL directly - let WebView handle playback
    // This avoids URL extraction issues and lets the embed page's player handle everything
    return {
      'streamUrl': embedUrl,
      'source': embedResult['source'] ?? 'Unknown',
      'type': 'embed',
      'quality': embedResult['quality'] ?? '720p',
      'method': 'webview_embed',
      'message': 'Loading embed player...',
      'isPlayable': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _streamFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _loading();
          }

          if (snapshot.hasError) {
            return _errorView(snapshot.error.toString());
          }

          final streamData = snapshot.data;
          if (streamData == null || streamData['streamUrl'] == null) {
            return _errorView('No playable stream found');
          }

          final streamUrl = streamData['streamUrl'] as String;

          // Load embed URL in WebView
          return Stack(
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(streamUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  supportMultipleWindows: false,
                  useShouldOverrideUrlLoading: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                onWebViewCreated: (controller) {
                  // Controller ready for any future enhancements
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url.toString();

                  // Block gambling/ad sites
                  if (url.contains('1xbet') ||
                      url.contains('ads') ||
                      url.contains('pop')) {
                    return NavigationActionPolicy.CANCEL;
                  }

                  // Allow vidsrc domains
                  if (url.contains('vidsrc.me') || url.contains('vidsrc.icu')) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  // Block everything else
                  return NavigationActionPolicy.CANCEL;
                },
                onCreateWindow: (controller, createWindowRequest) async {
                  return false;
                },
                onLoadStart: (_, __) {
                  if (!_isLoading) return;
                  setState(() => _isLoading = true);
                },
                onLoadStop: (controller, url) async {
                  // Continuous blocking with mutation observer
                  await controller.evaluateJavascript(
                    source: """
                    const blockedKeywords = ['dating', 'adult', 'pop', '1xbet', 'ads'];
                    const allowedIframeDomains = ['vidsrc.icu', 'vidsrc.me'];

                    const observer = new MutationObserver(mutations => {
                      mutations.forEach(mutation => {
                        document.querySelectorAll('iframe, a').forEach(el => {
                          if(el.tagName === 'IFRAME') {
                            let src = el.src || '';
                            if(!allowedIframeDomains.some(domain => src.includes(domain))) {
                              el.remove();
                            }
                          }
                          if(el.tagName === 'A') {
                            let href = el.href || '';
                            if(blockedKeywords.some(keyword => href.includes(keyword))) {
                              el.remove();
                            }
                          }
                        });
                      });
                    });

                    observer.observe(document.body, {childList: true, subtree: true});
                  """,
                  );

                  setState(() => _isLoading = false);
                },
                onReceivedError: (controller, request, error) {
                  setState(() => _isLoading = false);
                },
              ),

              if (_isLoading) _loading(),

              Positioned(
                top: 16,
                left: 16,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _loading() {
    return const Center(child: CircularProgressIndicator(color: Colors.red));
  }

  Widget _errorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error, color: Colors.red, size: 64),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => setState(() {
              _streamFuture = _getStreamData();
            }),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
