import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../services/direct_m3u8_service.dart';
import '../services/watch_history_service.dart';

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

class _StreamQuality {
  const _StreamQuality({
    required this.label,
    required this.url,
    required this.height,
  });

  final String label;
  final String url;
  final int height;
}

class _StablePlayerControls extends StatefulWidget {
  const _StablePlayerControls({
    required this.controller,
    required this.onBack,
    required this.onQuality,
    required this.qualityLabel,
    required this.showQuality,
  });

  final VideoPlayerController controller;
  final VoidCallback onBack;
  final VoidCallback onQuality;
  final String qualityLabel;
  final bool showQuality;

  @override
  State<_StablePlayerControls> createState() => _StablePlayerControlsState();
}

class _StablePlayerControlsState extends State<_StablePlayerControls> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _restartHideTimer();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && widget.controller.value.isPlaying) {
        setState(() => _visible = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _visible = !_visible);
    if (_visible) _restartHideTimer();
  }

  void _togglePlayback() {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() => _visible = true);
    _restartHideTimer();
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            children: [
              if (_visible)
                const Positioned.fill(child: ColoredBox(color: Colors.black26)),
              if (_visible)
                Center(
                  child: IconButton(
                    iconSize: 58,
                    onPressed: _togglePlayback,
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (_visible)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              if (_visible)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          widget.controller,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          colors: const VideoProgressColors(
                            playedColor: Colors.red,
                            bufferedColor: Colors.white54,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              '${_format(value.position)} / ${_format(value.duration)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            IconButton(
                              tooltip: value.volume == 0 ? 'Unmute' : 'Mute',
                              onPressed: () => widget.controller.setVolume(
                                value.volume == 0 ? 1 : 0,
                              ),
                              icon: Icon(
                                value.volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white,
                              ),
                            ),
                            const Spacer(),
                            if (widget.showQuality)
                              TextButton.icon(
                                onPressed: widget.onQuality,
                                icon: const Icon(Icons.hd, color: Colors.white),
                                label: Text(
                                  widget.qualityLabel,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            IconButton(
                              tooltip: 'Fullscreen',
                              onPressed: () =>
                                  SystemChrome.setEnabledSystemUIMode(
                                    SystemUiMode.immersiveSticky,
                                  ),
                              icon: const Icon(
                                Icons.fullscreen,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _M3U8VideoPlayerScreenState extends State<M3U8VideoPlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _useNativePlayer = false;
  bool _isBuffering = false;
  bool _isSwitchingQuality = false;
  String? _error;
  String? _currentSource;
  String _selectedQuality = 'Auto';
  Map<String, String> _streamHeaders = const {};
  List<_StreamQuality> _qualities = const [];
  String _statusMessage = 'Initializing...';
  Timer? _progressTimer;
  bool _isLeaving = false;

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
      _statusMessage = 'Fetching servers...';
    });

    try {
      _showStatus('Fetching available servers...');
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
        final source = result['source'] as String? ?? 'Unknown';
        final headers = <String, String>{};
        if (result['referer'] != null) {
          headers['Referer'] = result['referer'].toString();
        }
        if (result['headers'] != null && result['headers'] is Map) {
          (result['headers'] as Map).forEach((k, v) {
            headers[k.toString()] = v.toString();
          });
        }
        final qualities = _parseQualities(result['qualities']);
        var selectedQuality = 'Auto';
        for (final quality in qualities) {
          if (quality.url == url) {
            selectedQuality = quality.label;
            break;
          }
        }
        final resumePosition = await WatchHistoryService.loadWatchPosition(
          widget.tmdbId,
          widget.isMovie,
          widget.season,
          widget.episode,
        );
        if (!mounted) return;

        _showStatus('Stream found from $source! Initializing player...');
        await _initializePlayer(
          url,
          headers: headers,
          source: source,
          qualities: qualities,
          selectedQuality: selectedQuality,
          position: resumePosition,
          isHls:
              result['type'] == 'direct_m3u8' ||
              url.toLowerCase().contains('.m3u8'),
        );
        return;
      }

      _showStatus('No stream found');
      if (mounted) {
        setState(() {
          _error =
              'No working streaming sources found.\n\n'
              '• Check your internet connection\n'
              '• Try again later\n'
              '• Content might be unavailable';
        });
      }
    } catch (e) {
      debugPrint('M3U8VideoPlayer: Error loading stream: $e');
      _showStatus('Error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load stream: $e';
        });
      }
    }
  }

  Future<void> _initializePlayer(
    String m3u8Url, {
    Map<String, String> headers = const {},
    String source = 'Unknown',
    List<_StreamQuality> qualities = const [],
    String selectedQuality = 'Auto',
    Duration position = Duration.zero,
    bool isHls = true,
  }) async {
    try {
      _showStatus('Initializing video player...');
      await _replacePlayer(
        m3u8Url,
        headers: headers,
        source: source,
        qualities: qualities,
        selectedQuality: selectedQuality,
        isHls: isHls,
        position: position,
        shouldPlay: true,
      );
      _showStatus('Playing from $source');
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

  List<_StreamQuality> _parseQualities(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((quality) {
          return _StreamQuality(
            label: quality['label']?.toString() ?? 'Auto',
            url: quality['url']?.toString() ?? '',
            height: int.tryParse(quality['height']?.toString() ?? '') ?? 0,
          );
        })
        .where((quality) => quality.url.isNotEmpty)
        .toList();
  }

  Future<void> _replacePlayer(
    String url, {
    required Map<String, String> headers,
    required String source,
    required List<_StreamQuality> qualities,
    required String selectedQuality,
    required bool isHls,
    required Duration position,
    required bool shouldPlay,
  }) async {
    final previousVideo = _videoPlayerController;
    final previousChewie = _chewieController;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
      formatHint: isHls ? VideoFormat.hls : null,
    );

    try {
      _showStatus(
        position == Duration.zero
            ? 'Loading video...'
            : 'Switching to $selectedQuality...',
      );
      await controller.initialize();
      if (position > Duration.zero) await controller.seekTo(position);
      if (shouldPlay) await controller.play();

      final chewie = ChewieController(
        videoPlayerController: controller,
        autoPlay: false,
        looping: false,
        showControlsOnInitialize: true,
        allowFullScreen: false,
        allowMuting: true,
        fullScreenByDefault: false,
        allowPlaybackSpeedChanging: true,
        allowedScreenSleep: false,
        hideControlsTimer: const Duration(seconds: 4),
        progressIndicatorDelay: const Duration(milliseconds: 150),
        controlsSafeAreaMinimum: const EdgeInsets.fromLTRB(8, 8, 8, 18),
        customControls: _StablePlayerControls(
          controller: controller,
          onBack: _exitPlayer,
          onQuality: _showQualityPicker,
          qualityLabel: selectedQuality,
          showQuality: qualities.length > 1,
        ),
        additionalOptions: qualities.length > 1
            ? (_) => [
                OptionItem(
                  onTap: (menuContext) {
                    Navigator.of(menuContext).pop();
                    Future<void>.delayed(Duration.zero, _showQualityPicker);
                  },
                  iconData: Icons.hd,
                  title: 'Video quality',
                  subtitle: selectedQuality,
                ),
              ]
            : null,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.red,
          handleColor: Colors.red,
          backgroundColor: Colors.grey.shade800,
          bufferedColor: Colors.white70,
        ),
        bufferingBuilder: (_) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 12),
              Text('Buffering...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        placeholder: const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.red)),
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

      if (!mounted) {
        chewie.dispose();
        await controller.dispose();
        return;
      }

      controller.addListener(_handlePlaybackChanged);
      setState(() {
        _videoPlayerController = controller;
        _chewieController = chewie;
        _useNativePlayer = true;
        _currentSource = source;
        _streamHeaders = headers;
        _qualities = qualities;
        _selectedQuality = selectedQuality;
        _isBuffering = controller.value.isBuffering;
        _isSwitchingQuality = false;
      });

      previousVideo?.removeListener(_handlePlaybackChanged);
      previousChewie?.dispose();
      await previousVideo?.dispose();
      _startProgressSaving();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  void _handlePlaybackChanged() {
    final controller = _videoPlayerController;
    if (!mounted || controller == null) return;
    final isBuffering = controller.value.isBuffering;
    if (isBuffering != _isBuffering) {
      setState(() => _isBuffering = isBuffering);
    }
  }

  void _startProgressSaving() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _saveProgress(),
    );
  }

  Future<void> _saveProgress() async {
    final controller = _videoPlayerController;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position;
    final duration = controller.value.duration;
    if (position <= Duration.zero || duration <= Duration.zero) return;
    await WatchHistoryService.saveWatchProgress(
      tmdbId: widget.tmdbId,
      title: widget.title,
      isMovie: widget.isMovie,
      season: widget.season,
      episode: widget.episode,
      position: position,
      duration: duration,
    );
  }

  Future<void> _exitPlayer() async {
    if (_isLeaving) return;
    _isLeaving = true;
    await _saveProgress();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _showQualityPicker() async {
    if (!mounted || _qualities.length < 2) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff202124),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.hd, color: Colors.white),
              title: Text(
                'Video quality',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ..._qualities.map(
              (quality) => RadioListTile<String>(
                value: quality.label,
                groupValue: _selectedQuality,
                activeColor: Colors.red,
                title: Text(
                  quality.label,
                  style: const TextStyle(color: Colors.white),
                ),
                onChanged: (_) {
                  Navigator.of(sheetContext).pop();
                  _switchQuality(quality);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchQuality(_StreamQuality quality) async {
    final current = _videoPlayerController;
    if (current == null ||
        quality.label == _selectedQuality ||
        _isSwitchingQuality) {
      return;
    }

    final position = current.value.position;
    final shouldPlay = current.value.isPlaying || current.value.isBuffering;
    setState(() => _isSwitchingQuality = true);
    try {
      await _replacePlayer(
        quality.url,
        headers: _streamHeaders,
        source: _currentSource ?? 'Unknown',
        qualities: _qualities,
        selectedQuality: quality.label,
        isHls: true,
        position: position,
        shouldPlay: shouldPlay,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSwitchingQuality = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not switch quality: $error')),
      );
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    unawaited(_saveProgress());
    _videoPlayerController?.removeListener(_handlePlaybackChanged);
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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _exitPlayer();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _error != null
            ? _buildError()
            : _useNativePlayer && _chewieController != null
            ? _buildPlayer()
            : _buildLoading(),
      ),
    );
  }

  Widget _buildPlayer() {
    return Stack(
      children: [
        Chewie(controller: _chewieController!),
        if (_isSwitchingQuality)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black38,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.red),
                    SizedBox(height: 12),
                    Text(
                      'Changing video quality...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
                  onPressed: _exitPlayer,
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
