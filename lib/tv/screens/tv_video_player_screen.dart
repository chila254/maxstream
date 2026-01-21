import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../../services/watch_history_service.dart';
import '../services/tv_scraper_service.dart';

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
  bool _isLoading = true;
  String? _error;

  // Native player variables
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();

    // Force landscape for TV playback
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _loadM3u8Stream();
  }

  Future<void> _loadM3u8Stream() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      debugPrint('TvVideoPlayer: Searching for stream: ${widget.title}');

      // Search for the TV channel using scraper
      final result = await TvScraperService.searchTvChannel(widget.title);

      if (result != null) {
        final m3u8Url = result['m3u8Url'] as String;
        debugPrint('TvVideoPlayer: Found m3u8 URL: $m3u8Url');

        // Verify URL is accessible
        final isValid = await TvScraperService.verifyM3u8Url(m3u8Url);

        if (isValid) {
          await _initializePlayer(m3u8Url);
        } else {
          if (mounted) {
            setState(() {
              _error =
                  'Stream URL is not accessible. Please try a different channel.';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _error =
                'Could not find stream for "${widget.title}". Try searching manually.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('TvVideoPlayer: Error loading stream: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading stream: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializePlayer(String m3u8Url) async {
    try {
      _videoPlayerController =
          VideoPlayerController.networkUrl(Uri.parse(m3u8Url))..addListener(() {
            if (mounted) {
              setState(() {});
            }
          });

      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        progressIndicatorDelay: const Duration(milliseconds: 200),
        hideControlsTimer: const Duration(seconds: 3),
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red.shade300,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey.shade700,
        ),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TvVideoPlayer: Error initializing player: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize video player: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _retryLoading() {
    _loadM3u8Stream();
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
        body: _chewieController != null
            ? _buildVideoPlayer()
            : _buildLoadingOrError(),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return SafeArea(
      child: Stack(
        children: [
          Chewie(controller: _chewieController!),
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
      ),
    );
  }

  Widget _buildLoadingOrError() {
    return Stack(
      children: [
        Container(color: Colors.black),
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
                  'Loading stream for ${widget.title}...',
                  style: TvTypography.bodyLarge,
                  textAlign: TextAlign.center,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Error: $_error',
                    style: TvTypography.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _retryLoading,
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
                  ),  // TODO: Use TvTypography
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
