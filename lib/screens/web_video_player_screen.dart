import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../services/web_stream_service.dart';
import '../services/tmdb_api_service.dart';

/// Web video player using iframe embeds.
/// Uses unique view type per instance to avoid factory caching issues.
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
  List<Map<String, dynamic>> _availableServers = [];
  String? _currentTitle;

  // Unique view type per instance to avoid global factory caching
  late final String _viewType;
  bool _factoryRegistered = false;

  // Reference to the div so we can update iframe src directly
  web.HTMLDivElement? _hostDiv;

  @override
  void initState() {
    super.initState();
    // Unique view type per widget instance
    _viewType = 'maxstream-player-${DateTime.now().millisecondsSinceEpoch}';

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _blockPopups();
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

  /// Block popups globally on the document
  void _blockPopups() {
    // Only inject once
    if (web.document.getElementById('maxstream-adblock') != null) return;

    final script = web.document.createElement('script') as web.HTMLScriptElement;
    script.id = 'maxstream-adblock';
    script.textContent = '''
      (function() {
        if (window._maxstreamAdBlockActive) return;
        window._maxstreamAdBlockActive = true;

        // Block window.open
        var origOpen = window.open;
        window.open = function() { return null; };

        // Block target=_blank on click
        document.addEventListener('click', function(e) {
          var el = e.target;
          while (el && el !== document) {
            if (el.tagName === 'A' && el.getAttribute('target') === '_blank') {
              e.preventDefault();
              e.stopPropagation();
              return false;
            }
            el = el.parentNode;
          }
        }, true);

        // Block setTimeout-based popups
        var origSetTimeout = window.setTimeout;
        window.setTimeout = function(fn, delay) {
          if (typeof fn === 'string' && fn.indexOf('window.open') !== -1) return;
          return origSetTimeout.call(window, fn, delay);
        };

        console.log('[AdBlock] Active');
      })();
    ''';
    web.document.head?.appendChild(script);
  }

  void _registerFactory() {
    if (_factoryRegistered) return;
    _factoryRegistered = true;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) {
        final div = web.document.createElement('div') as web.HTMLDivElement;
        div.style
          ..width = '100%'
          ..height = '100%'
          ..border = 'none'
          ..overflow = 'hidden'
          ..backgroundColor = 'black';
        _hostDiv = div;

        if (_streamUrl != null) {
          _createIframe(div, _streamUrl!);
        }
        return div;
      },
    );
  }

  void _createIframe(web.HTMLDivElement container, String url) {
    debugPrint('WebVideoPlayer: Creating iframe for $url');

    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
    iframe.src = url;
    iframe.style
      ..width = '100%'
      ..height = '100%'
      ..border = 'none'
      ..backgroundColor = 'black';
    iframe.setAttribute('allow', 'autoplay; fullscreen; picture-in-picture; encrypted-media');
    iframe.setAttribute('allowfullscreen', 'true');
    container.appendChild(iframe);
  }

  /// Replace the iframe with a new one pointing to a different URL
  void _replaceIframe(String url) {
    debugPrint('WebVideoPlayer: Replacing iframe with: $url');
    if (_hostDiv == null) return;

    // Remove old iframe
    while (_hostDiv!.firstChild != null) {
      _hostDiv!.removeChild(_hostDiv!.firstChild!);
    }
    // Create new iframe
    _createIframe(_hostDiv!, url);
  }

  Future<void> _loadStream() async {
    if (!mounted) return;
    debugPrint('WebVideoPlayer: Loading stream for TMDB ${widget.tmdbId} (movie=${widget.isMovie}, s${widget.season}e${widget.episode})');

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _loadMediaMetadata();
      debugPrint('WebVideoPlayer: Title=$_currentTitle');

      final result = await WebStreamService.resolveStream(
        tmdbId: widget.tmdbId,
        isMovie: widget.isMovie,
        season: widget.season,
        episode: widget.episode,
        title: _currentTitle ?? widget.title,
      );

      if (!mounted) return;

      if (result != null && result['url'] != null) {
        final url = result['url'] as String;
        debugPrint('WebVideoPlayer: Got URL: $url');
        setState(() {
          _streamUrl = url;
          _sourceName = result['source'] as String;
          _isLoading = false;
        });

        // If factory already registered and div exists, replace iframe directly
        if (_hostDiv != null) {
          _replaceIframe(url);
        } else {
          _registerFactory();
        }

        _discoverServers();
        return;
      }

      if (mounted) {
        setState(() {
          _error = 'No streaming sources found. Check your connection.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('WebVideoPlayer: Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load: $e';
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
      servers.add({'name': source['name'], 'url': url});
    }
    if (mounted) setState(() => _availableServers = servers);
  }

  void _switchServer(Map<String, dynamic> server) {
    final url = server['url'] as String;
    setState(() => _sourceName = server['name'] as String);
    _replaceIframe(url);
  }

  void _showServerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Server', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._availableServers.map((s) {
              final name = s['name'] as String;
              final sel = name == _sourceName;
              return ListTile(
                leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: sel ? Colors.red : Colors.grey),
                title: Text(name, style: TextStyle(color: sel ? Colors.white : Colors.grey[300])),
                onTap: () { Navigator.pop(ctx); if (!sel) _switchServer(s); },
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
            ? _buildError()
            : _isLoading
                ? _buildLoading()
                : _buildPlayer(),
      ),
    );
  }

  Widget _buildPlayer() {
    return Stack(
      children: [
        SizedBox.expand(child: HtmlElementView(viewType: _viewType)),
        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
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
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_currentTitle ?? widget.title, style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis),
                ),
                if (_sourceName != null)
                  GestureDetector(
                    onTap: _showServerPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.dns, color: Colors.white70, size: 14),
                        const SizedBox(width: 5),
                        Text(_sourceName!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Colors.red),
          const SizedBox(height: 16),
          Text('Loading ${widget.title}...', style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          const Text('Unable to Load Stream', style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Text(_error!, style: TextStyle(color: Colors.grey[300], fontSize: 16), textAlign: TextAlign.center)),
          const SizedBox(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            ElevatedButton(
              onPressed: () => setState(() { _error = null; _isLoading = true; _loadStream(); }),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _handleBack,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700], padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12)),
              child: const Text('Go Back', style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ]),
        ],
      ),
    );
  }
}
