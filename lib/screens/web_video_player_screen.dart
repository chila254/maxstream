import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../services/web_stream_service.dart';
import '../services/tmdb_api_service.dart';

/// Web video player using HTML5 video / iframe embeds.
class WebVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;

  const WebVideoPlayerScreen({
    super.key,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
  });

  @override
  State<WebVideoPlayerScreen> createState() => _WebVideoPlayerScreenState();
}

class _WebVideoPlayerScreenState extends State<WebVideoPlayerScreen> {
  bool _isLoading = true;
  String? _error;
  String? _streamUrl;
  String? _sourceName;
  bool _isEmbed = false;
  List<Map<String, dynamic>> _availableServers = [];
  String? _currentTitle;

  static const String _viewType = 'maxstream-video-player';
  bool _registeredFactory = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadStream();
  }

  @override
  void dispose() {
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

  void _registerViewFactory() {
    if (_registeredFactory) return;
    _registeredFactory = true;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.style
          ..width = '100%'
          ..height = '100%'
          ..border = 'none'
          ..overflow = 'hidden';

        if (_streamUrl != null) {
          _embedContent(div, _streamUrl!, _isEmbed);
        }

        return div;
      },
    );
  }

  void _embedContent(web.HTMLDivElement container, String url, bool isEmbed) {
    while (container.firstChild != null) {
      container.removeChild(container.firstChild!);
    }

    // Inject ad-blocking CSS
    _injectAdBlockCss(container);

    if (isEmbed) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.src = url;
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = 'none';
      // Set attributes via setAttribute since CSS properties don't cover these
      iframe.setAttribute('allow', 'autoplay; fullscreen; picture-in-picture');
      iframe.setAttribute('allowfullscreen', 'true');
      iframe.setAttribute('referrerpolicy', 'no-referrer');
      iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin allow-presentation allow-popups-to-escape-sandbox');
      container.appendChild(iframe);
    } else {
      final video = web.document.createElement('video') as web.HTMLVideoElement;
      video.src = url;
      video.style
        ..width = '100%'
        ..height = '100%'
        ..objectFit = 'contain';
      video.autoplay = true;
      video.controls = true;
      video.setAttribute('allowfullscreen', 'true');
      container.appendChild(video);
    }

    // Inject ad-blocking MutationObserver script
    _injectAdBlockScript(container);
  }

  void _injectAdBlockCss(web.HTMLDivElement container) {
    final style = web.document.createElement('style') as web.HTMLStyleElement;
    style.textContent = '''
      .ad, .ads, .advert, .advertisement, .popup, .overlay-ad,
      [class*="ad-"], [class*="ads-"], [class*="advert"],
      [id*="ad-"], [id*="ads-"], [id*="advert"],
      [class*="popup"], [class*="modal-ad"], [class*="interstitial"],
      [class*="preroll"], [class*="midroll"], [class*="postroll"],
      [class*="sponsor"], [class*="promo"],
      .video-ad, .player-ad, .skip-ad, .ad-container {
        display: none !important;
        visibility: hidden !important;
        opacity: 0 !important;
        pointer-events: none !important;
        width: 0 !important;
        height: 0 !important;
      }
      video { width: 100% !important; height: 100% !important; }
      iframe { width: 100% !important; height: 100% !important; }
    ''';
    container.appendChild(style);
  }

  void _injectAdBlockScript(web.HTMLDivElement container) {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.textContent = '''
      (function() {
        var adSelectors = [
          '[class*="ad-"]', '[class*="ads"]', '[class*="advert"]',
          '[id*="ad-"]', '[id*="ads"]', '[id*="advert"]',
          '[class*="popup"]', '[class*="overlay"]', '[class*="interstitial"]',
          '[class*="preroll"]', '[class*="sponsor"]', '[class*="promo"]',
          '.video-ad', '.player-ad', '.skip-ad', '.ad-container'
        ];
        function removeAds(root) {
          adSelectors.forEach(function(sel) {
            try {
              root.querySelectorAll(sel).forEach(function(el) {
                if (el.tagName !== 'VIDEO' && el.tagName !== 'IFRAME') {
                  el.remove();
                }
              });
            } catch(e) {}
          });
          try {
            root.querySelectorAll('*').forEach(function(el) {
              var cs = window.getComputedStyle(el);
              if ((cs.position === 'fixed' || cs.position === 'absolute') &&
                  parseInt(cs.zIndex) > 9000 &&
                  el.tagName !== 'VIDEO' && el.tagName !== 'IFRAME') {
                el.remove();
              }
            });
          } catch(e) {}
        }
        removeAds(container);
        var observer = new MutationObserver(function(muts) {
          muts.forEach(function(m) {
            m.addedNodes.forEach(function(n) {
              if (n.nodeType === 1) removeAds(n);
            });
          });
        });
        observer.observe(container, { childList: true, subtree: true });
        setInterval(function() { removeAds(container); }, 2000);
      })();
    ''';
    container.appendChild(script);
  }

  Future<void> _loadStream() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadMediaMetadata();

      final result = await WebStreamService.resolveStream(
        tmdbId: widget.tmdbId,
        isMovie: widget.isMovie,
        season: widget.season,
        episode: widget.episode,
        title: _currentTitle ?? widget.title,
      );

      if (!mounted) return;

      if (result != null && result['url'] != null) {
        setState(() {
          _streamUrl = result['url'] as String;
          _sourceName = result['source'] as String;
          _isEmbed = result['isEmbed'] as bool? ?? false;
          _isLoading = false;
        });
        _registerViewFactory();
        _discoverServers();
        return;
      }

      if (mounted) {
        setState(() {
          _error = 'No working streaming sources found.\n\nCheck your internet connection and try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('WebVideoPlayer: Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load stream: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMediaMetadata() async {
    final id = int.tryParse(widget.tmdbId);
    if (id == null) return;

    final details = widget.isMovie
        ? await TmdbApiService.getMovieDetails(id)
        : await TmdbApiService.getSeriesDetails(id);

    if (details == null) return;

    if (widget.isMovie) {
      _currentTitle = details['title']?.toString() ?? widget.title;
    } else {
      final seriesTitle = details['name']?.toString() ?? widget.title;
      final episodes = await TmdbApiService.getSeasonEpisodes(id, widget.season);
      final ep = episodes
          .where((e) => ((e['episode_number'] as num?)?.toInt() ?? 0) == widget.episode)
          .firstOrNull;
      final epName = ep?['name']?.toString() ?? '';
      _currentTitle = epName.isNotEmpty
          ? '$seriesTitle - S${widget.season}E${widget.episode}: $epName'
          : '$seriesTitle - S${widget.season}E${widget.episode}';
    }
  }

  Future<void> _discoverServers() async {
    final sources = WebStreamService.getEmbedSources();
    final servers = <Map<String, dynamic>>[];
    for (final source in sources) {
      final url = widget.isMovie
          ? source['movieUrl']!.replaceAll('{id}', widget.tmdbId)
          : source['tvUrl']!
              .replaceAll('{id}', widget.tmdbId)
              .replaceAll('{season}', widget.season.toString())
              .replaceAll('{episode}', widget.episode.toString());
      servers.add({'name': source['name'], 'url': url, 'isEmbed': true});
    }
    if (mounted) setState(() => _availableServers = servers);
  }

  void _switchServer(Map<String, dynamic> server) {
    setState(() {
      _streamUrl = server['url'] as String;
      _sourceName = server['name'] as String;
      _isEmbed = server['isEmbed'] as bool? ?? true;
    });
    _registeredFactory = false;
    _registerViewFactory();
    if (mounted) setState(() {});
  }

  void _showServerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Server', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._availableServers.map((server) {
              final name = server['name'] as String;
              final isSelected = name == _sourceName;
              return ListTile(
                leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? Colors.red : Colors.grey),
                title: Text(name, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[300])),
                onTap: () {
                  Navigator.pop(context);
                  if (!isSelected) _switchServer(server);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _handleBack() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _error != null
            ? _buildErrorWidget()
            : _isLoading
                ? _buildLoadingWidget()
                : _buildPlayerWidget(),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    return Stack(
      children: [
        SizedBox.expand(child: HtmlElementView(viewType: _viewType)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _handleBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_currentTitle ?? widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
                if (_sourceName != null)
                  GestureDetector(
                    onTap: _showServerPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.dns, color: Colors.white70, size: 14),
                          const SizedBox(width: 5),
                          Text(_sourceName!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Stack(
      children: [
        Container(color: Colors.black),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 16),
              Text('Loading stream for ${widget.title}...', style: const TextStyle(color: Colors.white, fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Stack(
      children: [
        Container(color: Colors.black),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text('Unable to Load Stream', style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(_error!, style: TextStyle(color: Colors.grey[300], fontSize: 16), textAlign: TextAlign.center),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => setState(() { _error = null; _isLoading = true; _loadStream(); }),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                    child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _handleBack,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
                    child: const Text('Go Back', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
