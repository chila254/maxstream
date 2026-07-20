import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'dart:ui_web' as ui_web;
import '../services/web_stream_service.dart';
import '../services/tmdb_api_service.dart';

/// Web video player using hls.js for .m3u8 streams.
/// No iframes = no popup ads.
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
  String? _streamType;
  String? _currentTitle;

  late final String _viewType;
  bool _factoryRegistered = false;
  web.HTMLDivElement? _hostDiv;

  @override
  void initState() {
    super.initState();
    _viewType = 'maxstream-player-${DateTime.now().millisecondsSinceEpoch}';

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
          _createPlayer(div, _streamUrl!, _streamType ?? 'hls');
        }
        return div;
      },
    );
  }

  void _createPlayer(web.HTMLDivElement container, String url, String type) {
    debugPrint('WebVideoPlayer: Creating player for $url (type=$type)');

    // Create video element
    final video = web.document.createElement('video') as web.HTMLVideoElement;
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..backgroundColor = 'black';
    video.controls = true;
    video.autoplay = true;
    video.setAttribute('allowfullscreen', 'true');
    container.appendChild(video);

    if (type == 'hls' && url.contains('.m3u8')) {
      // Use hls.js for HLS streams
      _loadHlsJs(video, url);
    } else {
      // Direct video URL
      video.src = url;
      video.play();
    }
  }

  void _loadHlsJs(web.HTMLVideoElement video, String url) {
    // Load hls.js and initialize player all in one script
    final initScript = web.document.createElement('script') as web.HTMLScriptElement;
    initScript.textContent = '''
      (function() {
        var script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/hls.js@latest';
        script.onload = function() {
          var video = document.querySelector('video:last-of-type');
          if (!video) return;
          if (Hls.isSupported()) {
            var hls = new Hls({
              enableWorker: true,
              lowLatencyMode: false,
              maxBufferLength: 30,
              maxMaxBufferLength: 60,
            });
            hls.loadSource('$url');
            hls.attachMedia(video);
            hls.on(Hls.Events.MANIFEST_PARSED, function() {
              console.log('[Player] HLS loaded');
              video.play().catch(function(e) { console.log('[Player] Autoplay:', e); });
            });
            hls.on(Hls.Events.ERROR, function(event, data) {
              console.log('[Player] HLS error:', data.type, data.details);
              if (data.fatal) {
                if (data.type === Hls.ErrorTypes.NETWORK_ERROR) hls.startLoad();
                else if (data.type === Hls.ErrorTypes.MEDIA_ERROR) hls.recoverMediaError();
              }
            });
            window._hlsPlayer = hls;
          } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
            video.src = '$url';
            video.play().catch(function(e) { console.log('[Player] Autoplay:', e); });
          }
        };
        script.onerror = function() {
          console.log('[Player] hls.js load failed, trying native');
          var video = document.querySelector('video:last-of-type');
          if (video) { video.src = '$url'; }
        };
        document.head.appendChild(script);
      })();
    ''';
    web.document.body?.appendChild(initScript);
  }

  void _replacePlayer(String url, String type) {
    debugPrint('WebVideoPlayer: Replacing player with: $url (type=$type)');
    if (_hostDiv == null) return;

    while (_hostDiv!.firstChild != null) {
      _hostDiv!.removeChild(_hostDiv!.firstChild!);
    }
    _createPlayer(_hostDiv!, url, type);
  }

  Future<void> _loadStream() async {
    if (!mounted) return;
    debugPrint('WebVideoPlayer: Loading stream for TMDB ${widget.tmdbId}');

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
        final url = result['url'] as String;
        final type = result['type'] as String? ?? 'hls';
        debugPrint('WebVideoPlayer: Got URL: $url (type=$type)');
        setState(() {
          _streamUrl = url;
          _sourceName = result['source'] as String;
          _streamType = type;
          _isLoading = false;
        });

        if (_hostDiv != null) {
          _replacePlayer(url, type);
        } else {
          _registerFactory();
        }

        _registerFactory();
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.dns, color: Colors.white70, size: 14),
                      const SizedBox(width: 5),
                      Text(_sourceName!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ]),
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
