import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fijkplayer/fijkplayer.dart';
import '../services/filmboom_service.dart';

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
  late Future<Map<String, dynamic>?> _streamFuture;
  final FijkPlayer _player = FijkPlayer();

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
    _player.release();
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
    debugPrint('Fetching stream for: ${widget.title}');

    // Get video URL directly from FilmBoom service
    final videoResult = await FilmBoomService.getVideoUrl(
      widget.title,
      season: widget.season,
      episode: widget.episode,
    );

    if (videoResult == null || videoResult['videoUrl'] == null) {
      debugPrint('Failed to get video URL from FilmBoom');
      return null;
    }

    debugPrint('Got video URL: ${videoResult['videoUrl']}');
    debugPrint('Quality: ${videoResult['quality']}');
    return videoResult;
  }

  Future<void> _initializePlayer(String url) async {
    await _player.setDataSource(url, autoPlay: true);
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
          if (streamData == null || streamData['videoUrl'] == null) {
            return _errorView('No playable stream found');
          }

          final videoUrl = streamData['videoUrl'] as String;

          return Stack(
            children: [
              FutureBuilder(
                future: _initializePlayer(videoUrl),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return FijkView(
                      player: _player,
                    );
                  }
                  return _loading();
                },
              ),
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
