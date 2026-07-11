import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../services/direct_m3u8_service.dart';
import '../services/vidlink_extractor.dart';
import '../services/prime_src_link_extractor.dart';

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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _useNativePlayer = false;
  String? _error;
  String? _currentSource;
  String _statusMessage = 'Initializing...';

  bool _extractingVidLink = false;
  String? _vidLinkEmbedUrl;

  // PrimeSrc WebView extraction state
  bool _extractingPrimeSrc = false;
  String? _primeSrcServerName;
  String? _primeSrcApiKey;
  List<Map<String, String>> _primeSrcServers = [];
  int _primeSrcServerIndex = 0;

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

  void _showStatus(String message) {
    debugPrint('M3U8Player: $message');
    if (mounted) {
      setState(() => _statusMessage = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.blue.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _loadStream() async {
    if (!mounted) return;

    setState(() {
      _error = null;
      _statusMessage = 'Starting stream search...';
    });

    try {
      // Step 1: Try PrimeSrc servers (Voe, Streamtape, etc.)
      _showStatus('Fetching servers from PrimeSrc...');
      Map<String, dynamic>? result;

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

      if (!mounted) return;

      if (result != null && result['url'] != null) {
        final url = result['url'] as String;
        final headers = (result['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{};
        final source = result['source'] as String? ?? 'Unknown';

        _showStatus('Found stream from $source! Initializing player...');
        await _initializePlayer(url, headers: headers, source: source);
        return;
      }

      // Step 2: Try PrimeSrc with WebView link resolution
      _showStatus('HTTP failed. Resolving links via WebView...');
      final servers = await DirectM3u8Service.fetchPrimeSrcServers(
        tmdbId: widget.tmdbId,
        type: widget.isMovie ? 'movie' : 'tv',
        season: widget.season,
        episode: widget.episode,
      );

      if (servers.isNotEmpty && mounted) {
        _showStatus('Found ${servers.length} servers. Resolving via WebView...');
        _primeSrcServers = servers;
        _primeSrcServerIndex = 0;
        _tryNextPrimeSrcServer();
        return;
      }

      // Step 3: VidLink extraction
      _showStatus('No PrimeSrc servers. Trying VidLink...');
      if (_startVidLinkExtraction()) return;

      // Step 3: All methods failed
      _showStatus('All sources failed');
      if (mounted) {
        setState(() {
          _error = 'No working streaming sources found.\n\n'
              '• Check your internet connection\n'
              '• Try again later\n'
              '• Content might be unavailable';
        });
      }
    } catch (e) {
      debugPrint('M3U8VideoPlayer: Error loading stream: $e');
      _showStatus('Error: $e');

      if (_startVidLinkExtraction()) return;

      if (mounted) {
        setState(() {
          _error = 'Failed to load stream: $e';
        });
      }
    }
  }

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

    _showStatus('Loading VidLink embed: $url');
    _vidLinkEmbedUrl = url;
    if (mounted) setState(() => _extractingVidLink = true);
    return true;
  }

  void _tryNextPrimeSrcServer() {
    if (_primeSrcServerIndex >= _primeSrcServers.length) {
      // All PrimeSrc servers tried, fall back to VidLink
      _showStatus('All PrimeSrc servers failed. Trying VidLink...');
      _startVidLinkExtraction();
      return;
    }

    final server = _primeSrcServers[_primeSrcServerIndex];
    _showStatus('Resolving ${server['name']} via WebView...');
    if (mounted) {
      setState(() {
        _extractingPrimeSrc = true;
        _primeSrcServerName = server['name'];
        _primeSrcApiKey = server['key'];
      });
    }
  }

  void _onPrimeSrcLinkResolved(String link) {
    if (!mounted) return;
    _showStatus('Got ${_primeSrcServerName} link: $link');
    setState(() => _extractingPrimeSrc = false);

    // Now extract stream from the resolved link using HTTP
    DirectM3u8Service.extractFromProviderUrl(_primeSrcServerName!, link)
        .then((result) {
      if (!mounted) return;
      if (result != null && result['url'] != null) {
        final url = result['url'] as String;
        final headers = (result['headers'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            const <String, String>{};
        _showStatus('Stream found from $_primeSrcServerName! Initializing...');
        _initializePlayer(url, headers: headers, source: _primeSrcServerName!);
      } else {
        // Try next server
        _primeSrcServerIndex++;
        _tryNextPrimeSrcServer();
      }
    });
  }

  void _onPrimeSrcLinkError(Object error) {
    debugPrint('M3U8VideoPlayer: PrimeSrc link failed: $error');
    _showStatus('$_primeSrcServerName link failed: $error');
    if (!mounted) return;
    setState(() => _extractingPrimeSrc = false);
    // Try next server
    _primeSrcServerIndex++;
    _tryNextPrimeSrcServer();
  }

  void _onVidLinkExtracted(String playlist, Map<String, String> headers) {
    if (!mounted) return;
    _showStatus('VidLink stream extracted! Initializing player...');
    setState(() => _extractingVidLink = false);
    _initializePlayer(playlist, headers: headers, source: 'VidLink');
  }

  void _onVidLinkError(Object error) {
    debugPrint('M3U8VideoPlayer: VidLink extraction failed: $error');
    _showStatus('VidLink extraction failed: $error');
    if (!mounted) return;
    setState(() {
      _extractingVidLink = false;
      _error = 'Failed to extract stream.\n\n'
          '• The source might be temporarily unavailable\n'
          '• Try again later\n\n'
          'Error: $error';
    });
  }

  Future<void> _initializePlayer(
    String m3u8Url, {
    Map<String, String> headers = const {},
    String source = 'Unknown',
  }) async {
    try {
      _showStatus('Initializing video player...');
      await _videoPlayerController?.dispose();
      _chewieController?.dispose();

      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(m3u8Url),
        httpHeaders: headers,
      );

      _showStatus('Loading video from: ${m3u8Url.substring(0, m3u8Url.length > 80 ? 80 : m3u8Url.length)}...');
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

      _showStatus('Playing from $source');
      if (mounted) {
        setState(() {
          _useNativePlayer = true;
          _currentSource = source;
        });
      }
    } catch (e) {
      debugPrint('M3U8VideoPlayer: Error initializing player: $e');
      _showStatus('Player error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize video player: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
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
      body: Stack(
        children: [
          // Main content: error, player, or loading
          _error != null
              ? _buildError()
              : _useNativePlayer && _chewieController != null
                  ? _buildPlayer()
                  : _buildLoading(),

          // Always-active VidLinkExtractor (hidden WebView)
          if (_extractingVidLink && _vidLinkEmbedUrl != null)
            VidLinkExtractor(
              key: const ValueKey('vidlink-extractor'),
              embedUrl: _vidLinkEmbedUrl!,
              onExtracted: _onVidLinkExtracted,
              onError: _onVidLinkError,
            ),

          // PrimeSrc link resolver (hidden WebView)
          if (_extractingPrimeSrc && _primeSrcApiKey != null)
            PrimeSrcLinkExtractor(
              key: ValueKey('primesrc-$_primeSrcApiKey'),
              apiKey: _primeSrcApiKey!,
              onResolved: _onPrimeSrcLinkResolved,
              onError: _onPrimeSrcLinkError,
            ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    return Stack(
      children: [
        Chewie(controller: _chewieController!),
        if (_currentSource != null)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _currentSource!,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
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
          Text(
            'Loading ${widget.title}...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Last status: $_statusMessage',
              style: const TextStyle(color: Colors.grey, fontSize: 11),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadStream,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Go Back',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
