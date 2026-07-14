import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../services/direct_m3u8_service.dart';
import '../services/native_stream_extractor.dart';
import '../services/tmdb_api_service.dart';
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

class _SubtitleTrack {
  const _SubtitleTrack({
    required this.label,
    required this.url,
    required this.isDefault,
    this.source = '',
  });

  final String label;
  final String url;
  final bool isDefault;
  final String source;
}

class _StablePlayerControls extends StatefulWidget {
  const _StablePlayerControls({
    required this.controller,
    required this.onBack,
    required this.onQuality,
    required this.qualityLabel,
    required this.showQuality,
    required this.onSubtitles,
    required this.subtitleLabel,
    required this.showSubtitles,
    required this.onAspectRatio,
    required this.aspectRatioLabel,
  });

  final VideoPlayerController controller;
  final VoidCallback onBack;
  final VoidCallback onQuality;
  final String qualityLabel;
  final bool showQuality;
  final VoidCallback onSubtitles;
  final ValueNotifier<String> subtitleLabel;
  final bool showSubtitles;
  final VoidCallback onAspectRatio;
  final String aspectRatioLabel;

  @override
  State<_StablePlayerControls> createState() => _StablePlayerControlsState();
}

class _StablePlayerControlsState extends State<_StablePlayerControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _adjustingBrightness = false;
  double _gestureValue = 0.5;
  bool _showGestureValue = false;

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

  void _seekBy(Duration offset) {
    final value = widget.controller.value;
    var target = value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (value.duration > Duration.zero && target > value.duration) {
      target = value.duration;
    }
    widget.controller.seekTo(target);
    _restartHideTimer();
  }

  void _startVerticalDrag(DragStartDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    _adjustingBrightness = details.localPosition.dx < width / 2;
    _gestureValue = _adjustingBrightness ? 0.5 : widget.controller.value.volume;
    if (_adjustingBrightness) {
      NativeStreamExtractor.getBrightness().then((value) {
        if (mounted && _adjustingBrightness) _gestureValue = value;
      });
    }
    setState(() => _showGestureValue = true);
    _hideTimer?.cancel();
  }

  void _updateVerticalDrag(DragUpdateDetails details) {
    final delta = -(details.primaryDelta ?? 0) / 220;
    _gestureValue = (_gestureValue + delta).clamp(0.01, 1.0);
    if (_adjustingBrightness) {
      NativeStreamExtractor.setBrightness(_gestureValue);
    } else {
      widget.controller.setVolume(_gestureValue);
    }
    setState(() => _showGestureValue = true);
  }

  void _endVerticalDrag(DragEndDetails details) {
    setState(() => _showGestureValue = false);
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
          onVerticalDragStart: _startVerticalDrag,
          onVerticalDragUpdate: _updateVerticalDrag,
          onVerticalDragEnd: _endVerticalDrag,
          child: Stack(
            children: [
              if (_visible)
                const Positioned.fill(child: ColoredBox(color: Colors.black26)),
              if (_visible)
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Back 10 seconds',
                        iconSize: 42,
                        onPressed: () => _seekBy(const Duration(seconds: -10)),
                        icon: const Icon(Icons.replay_10, color: Colors.white),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        iconSize: 58,
                        onPressed: _togglePlayback,
                        icon: Icon(
                          value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 24),
                      IconButton(
                        tooltip: 'Forward 10 seconds',
                        iconSize: 42,
                        onPressed: () => _seekBy(const Duration(seconds: 10)),
                        icon: const Icon(Icons.forward_10, color: Colors.white),
                      ),
                    ],
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
                            if (widget.showSubtitles)
                              ValueListenableBuilder<String>(
                                valueListenable: widget.subtitleLabel,
                                builder: (context, label, _) => TextButton.icon(
                                  onPressed: widget.onSubtitles,
                                  icon: const Icon(
                                    Icons.subtitles,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    label,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            if (widget.showQuality)
                              TextButton.icon(
                                onPressed: widget.onQuality,
                                icon: const Icon(Icons.hd, color: Colors.white),
                                label: Text(
                                  widget.qualityLabel,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            TextButton.icon(
                              onPressed: widget.onAspectRatio,
                              icon: const Icon(
                                Icons.aspect_ratio,
                                color: Colors.white,
                              ),
                              label: Text(
                                widget.aspectRatioLabel,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showGestureValue)
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: _adjustingBrightness ? 36 : null,
                  right: _adjustingBrightness ? null : 36,
                  child: Center(
                    child: Container(
                      width: 64,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _adjustingBrightness
                                ? Icons.brightness_6
                                : Icons.volume_up,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_gestureValue * 100).round()}%',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
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

enum _AspectRatioMode { fit, stretch, zoom }

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
  List<_SubtitleTrack> _subtitleTracks = const [];
  final ValueNotifier<List<Subtitle>> _activeSubtitles =
      ValueNotifier<List<Subtitle>>(const []);
  final ValueNotifier<String> _selectedSubtitle = ValueNotifier<String>('Off');
  String _statusMessage = 'Initializing...';
  Timer? _progressTimer;
  bool _isLeaving = false;
  late int _currentSeason;
  late int _currentEpisode;
  late String _currentTitle;
  late String _resolverTitle;
  String _posterUrl = '';
  Map<String, dynamic>? _nextEpisode;
  bool _nextEpisodeCancelled = false;
  bool _loadingNextEpisode = false;
  bool _showNextEpisode = false;
  int _nextEpisodeCountdown = 30;
  _AspectRatioMode _aspectRatioMode = _AspectRatioMode.fit;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;
    _resolverTitle = widget.title;
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

  Future<void> _loadStream({bool resume = true}) async {
    if (!mounted) return;

    setState(() {
      _error = null;
      _statusMessage = 'Fetching servers...';
    });

    try {
      _showStatus('Fetching available servers...');
      await _loadMediaMetadata();
      Map<String, dynamic>? result;

      if (widget.isMovie) {
        result = await DirectM3u8Service.fetchMovieStreamUrl(
          _resolverTitle,
          null,
          widget.tmdbId,
        );
      } else {
        result = await DirectM3u8Service.fetchSeriesStreamUrl(
          _resolverTitle,
          _currentSeason,
          _currentEpisode,
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
        final subtitleTracks = _parseSubtitleTracks(result['subtitles']);
        _SubtitleTrack? initialSubtitle;
        for (final track in subtitleTracks) {
          if (track.isDefault) {
            initialSubtitle = track;
            break;
          }
        }
        var initialSubtitles = const <Subtitle>[];
        if (initialSubtitle != null) {
          try {
            initialSubtitles = await _fetchSubtitles(initialSubtitle, headers);
          } catch (error) {
            debugPrint('M3U8Player: Default subtitle failed: $error');
            initialSubtitle = null;
          }
        }
        var selectedQuality = 'Auto';
        for (final quality in qualities) {
          if (quality.url == url) {
            selectedQuality = quality.label;
            break;
          }
        }
        final resumePosition = resume
            ? await WatchHistoryService.loadWatchPosition(
                widget.tmdbId,
                widget.isMovie,
                _currentSeason,
                _currentEpisode,
              )
            : Duration.zero;
        if (!mounted) return;
        _subtitleTracks = subtitleTracks;
        _activeSubtitles.value = initialSubtitles;
        _selectedSubtitle.value = initialSubtitle != null
            ? '${initialSubtitle.source}/${initialSubtitle.label}'
            : 'Off';

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

  Future<void> _loadMediaMetadata() async {
    final id = int.tryParse(widget.tmdbId);
    if (id == null) return;
    final details = widget.isMovie
        ? await TmdbApiService.getMovieDetails(id)
        : await TmdbApiService.getSeriesDetails(id);
    if (details == null) return;

    _posterUrl = TmdbApiService.getPosterUrl(
      details['poster_path']?.toString(),
    );
    if (widget.isMovie) {
      _currentTitle = details['title']?.toString() ?? widget.title;
      _resolverTitle = _currentTitle;
      _nextEpisode = null;
      return;
    }

    final seriesTitle = details['name']?.toString() ?? widget.title;
    _resolverTitle = seriesTitle;
    _currentTitle = '$seriesTitle - S${_currentSeason}E$_currentEpisode';
    final episodes = await TmdbApiService.getSeasonEpisodes(id, _currentSeason);
    final laterEpisodes =
        episodes
            .where(
              (episode) =>
                  ((episode['episode_number'] as num?)?.toInt() ?? 0) >
                  _currentEpisode,
            )
            .toList()
          ..sort(
            (a, b) => ((a['episode_number'] as num?)?.toInt() ?? 0).compareTo(
              (b['episode_number'] as num?)?.toInt() ?? 0,
            ),
          );

    Map<String, dynamic>? next;
    var nextSeason = _currentSeason;
    if (laterEpisodes.isNotEmpty) {
      next = laterEpisodes.first;
    } else {
      final seasons =
          (details['seasons'] as List? ?? const [])
              .whereType<Map>()
              .where(
                (season) =>
                    ((season['season_number'] as num?)?.toInt() ?? 0) >
                        _currentSeason &&
                    ((season['episode_count'] as num?)?.toInt() ?? 0) > 0,
              )
              .toList()
            ..sort(
              (a, b) => ((a['season_number'] as num?)?.toInt() ?? 0).compareTo(
                (b['season_number'] as num?)?.toInt() ?? 0,
              ),
            );
      if (seasons.isNotEmpty) {
        nextSeason = (seasons.first['season_number'] as num).toInt();
        final nextSeasonEpisodes = await TmdbApiService.getSeasonEpisodes(
          id,
          nextSeason,
        );
        if (nextSeasonEpisodes.isNotEmpty) next = nextSeasonEpisodes.first;
      }
    }

    _nextEpisode = next == null
        ? null
        : {
            'season': nextSeason,
            'episode': (next['episode_number'] as num).toInt(),
            'name': next['name']?.toString() ?? 'Next episode',
            'stillUrl': TmdbApiService.getBackdropUrl(
              next['still_path']?.toString(),
            ),
            'seriesTitle': seriesTitle,
          };
    _nextEpisodeCancelled = false;
    _showNextEpisode = false;
    _nextEpisodeCountdown = 30;
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

  List<_SubtitleTrack> _parseSubtitleTracks(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (subtitle) => _SubtitleTrack(
            label: subtitle['label']?.toString() ?? 'Subtitle',
            url: subtitle['url']?.toString() ?? '',
            isDefault: subtitle['default'] == true,
            source: subtitle['source']?.toString() ?? '',
          ),
        )
        .where((subtitle) => subtitle.url.isNotEmpty)
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
      videoPlayerOptions: VideoPlayerOptions(
        backBufferDurationMs: 60000,
        allowBackgroundPlayback: false,
      ),
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
        progressIndicatorDelay: const Duration(milliseconds: 100),
        controlsSafeAreaMinimum: const EdgeInsets.fromLTRB(8, 8, 8, 18),
        customControls: _StablePlayerControls(
          controller: controller,
          onBack: _exitPlayer,
          onQuality: _showQualityPicker,
          qualityLabel: selectedQuality,
          showQuality: qualities.length > 1,
          onSubtitles: _showSubtitlePicker,
          subtitleLabel: _selectedSubtitle,
          showSubtitles: _subtitleTracks.isNotEmpty,
          onAspectRatio: _cycleAspectRatio,
          aspectRatioLabel: _aspectRatioLabel,
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
              CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
              SizedBox(height: 12),
              Text('Buffering...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.red, strokeWidth: 3),
                SizedBox(height: 16),
                Text(
                  'Loading video...',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
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
        _videoInitialized = true;
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
    final value = controller.value;
    final isBuffering = value.isBuffering;
    var shouldRebuild = isBuffering != _isBuffering;
    _isBuffering = isBuffering;

    if (!widget.isMovie &&
        _nextEpisode != null &&
        !_nextEpisodeCancelled &&
        value.duration > Duration.zero) {
      final remaining = value.duration - value.position;
      final countdown = remaining.inSeconds.clamp(0, 30);
      final showNext = remaining <= const Duration(seconds: 30);
      if (showNext != _showNextEpisode || countdown != _nextEpisodeCountdown) {
        _showNextEpisode = showNext;
        _nextEpisodeCountdown = countdown;
        shouldRebuild = true;
      }
      if (remaining <= const Duration(milliseconds: 500) &&
          !_loadingNextEpisode) {
        unawaited(_playNextEpisode());
      }
    }
    if (shouldRebuild) setState(() {});
  }

  Future<void> _playNextEpisode() async {
    final next = _nextEpisode;
    if (next == null || _loadingNextEpisode) return;
    _loadingNextEpisode = true;
    await _saveProgress();
    _currentSeason = (next['season'] as num).toInt();
    _currentEpisode = (next['episode'] as num).toInt();
    _currentTitle =
        '${next['seriesTitle']} - S${_currentSeason}E$_currentEpisode: ${next['name']}';
    if (mounted) {
      setState(() {
        _showNextEpisode = false;
        _isSwitchingQuality = true;
        _statusMessage = 'Loading next episode...';
      });
    }
    try {
      await _loadStream(resume: false);
    } finally {
      _loadingNextEpisode = false;
      if (mounted) setState(() => _isSwitchingQuality = false);
    }
  }

  void _cancelNextEpisode() {
    setState(() {
      _nextEpisodeCancelled = true;
      _showNextEpisode = false;
    });
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
      title: _currentTitle,
      isMovie: widget.isMovie,
      season: _currentSeason,
      episode: _currentEpisode,
      posterUrl: _posterUrl,
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

  void _cycleAspectRatio() {
    setState(() {
      _aspectRatioMode = switch (_aspectRatioMode) {
        _AspectRatioMode.fit => _AspectRatioMode.stretch,
        _AspectRatioMode.stretch => _AspectRatioMode.zoom,
        _AspectRatioMode.zoom => _AspectRatioMode.fit,
      };
    });
  }

  String get _aspectRatioLabel => switch (_aspectRatioMode) {
    _AspectRatioMode.fit => 'Fit',
    _AspectRatioMode.stretch => 'Stretch',
    _AspectRatioMode.zoom => 'Zoom',
  };

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

  Future<void> _showSubtitlePicker() async {
    if (!mounted || _subtitleTracks.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff202124),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              leading: Icon(Icons.subtitles, color: Colors.white),
              title: Text(
                'Subtitles',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            RadioListTile<String>(
              value: 'Off',
              groupValue: _selectedSubtitle.value,
              activeColor: Colors.red,
              title: const Text('Off', style: TextStyle(color: Colors.white)),
              onChanged: (_) {
                Navigator.of(sheetContext).pop();
                setState(() {
                  _selectedSubtitle.value = 'Off';
                  _activeSubtitles.value = const [];
                });
              },
            ),
            ..._buildGroupedSubtitleTiles(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedSubtitleTiles() {
    final grouped = <String, List<_SubtitleTrack>>{};
    for (final track in _subtitleTracks) {
      final source = track.source.isEmpty ? 'Other' : track.source;
      grouped.putIfAbsent(source, () => []).add(track);
    }
    final widgets = <Widget>[];
    for (final entry in grouped.entries) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            entry.key,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      );
      for (final track in entry.value) {
        widgets.add(
          RadioListTile<String>(
            value: '${track.source}/${track.label}',
            groupValue: _selectedSubtitle.value,
            activeColor: Colors.red,
            title: Text(
              track.label,
              style: const TextStyle(color: Colors.white),
            ),
            onChanged: (_) {
              Navigator.of(context).pop();
              _selectSubtitle(track);
            },
          ),
        );
      }
    }
    return widgets;
  }

  Future<void> _selectSubtitle(_SubtitleTrack track) async {
    try {
      final subtitles = await _fetchSubtitles(track, _streamHeaders);
      if (!mounted) return;
      if (subtitles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subtitle file was empty or could not be parsed'),
          ),
        );
        return;
      }
      setState(() {
        _selectedSubtitle.value = '${track.source}/${track.label}';
        _activeSubtitles.value = subtitles;
      });
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString().contains('404')
          ? 'Subtitle not found on server (404). Try another subtitle track.'
          : error.toString().contains('401')
          ? 'Subtitle requires authentication. Try another track.'
          : 'Could not load subtitles: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    }
  }

  Future<List<Subtitle>> _fetchSubtitles(
    _SubtitleTrack track,
    Map<String, String> headers,
  ) async {
    final uri = Uri.parse(track.url);
    if (uri.host.isEmpty) {
      throw Exception('Invalid subtitle URL: ${track.url}');
    }

    // Try the direct URL first
    final urlsToTry = <String>[track.url];

    // For RPM-style subtitles, try alternative URL patterns
    if (track.url.contains('.vtt') && !track.url.startsWith('http')) {
      // Already handled by URL construction
    } else if (track.url.contains('.vtt') || track.url.contains('.srt')) {
      // Try without fragment
      final urlNoFragment = track.url.split('#')[0];
      if (urlNoFragment != track.url) urlsToTry.add(urlNoFragment);
    }

    // For opensubtitles URLs, try with different headers
    if (track.url.contains('opensubtitles')) {
      urlsToTry.add(track.url);
    }

    Exception? lastError;
    for (final url in urlsToTry) {
      try {
        final parsedUri = Uri.parse(url);
        final response = await http
            .get(
              parsedUri,
              headers: {
                ...headers,
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = response.body;
          if (body.trim().isNotEmpty) {
            return _parseSubtitleFile(body);
          }
        }
        lastError = Exception('HTTP ${response.statusCode}');
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
      }
    }
    throw lastError ?? Exception('Failed to load subtitles');
  }

  List<Subtitle> _parseSubtitleFile(String input) {
    final normalized = input.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Detect format: WEBVTT or SRT
    final isVtt = normalized.trimLeft().toUpperCase().startsWith('WEBVTT');

    if (isVtt) {
      return _parseVtt(normalized);
    } else {
      return _parseSrt(normalized);
    }
  }

  List<Subtitle> _parseVtt(String input) {
    final lines = input.split('\n');
    final subtitles = <Subtitle>[];
    int i = 0;

    // Skip WEBVTT header
    if (lines.isNotEmpty &&
        lines[0].trim().toUpperCase().startsWith('WEBVTT')) {
      i = 1;
    }

    while (i < lines.length) {
      final line = lines[i].trim();

      // Skip empty lines and NOTE blocks
      if (line.isEmpty || line.toUpperCase().startsWith('NOTE')) {
        if (line.toUpperCase().startsWith('NOTE')) {
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            i++;
          }
        }
        i++;
        continue;
      }

      // Skip cue identifiers (lines that don't contain -->)
      if (!line.contains('-->')) {
        i++;
        continue;
      }

      // Parse timing line
      final timing = line.split('-->');
      if (timing.length != 2) {
        i++;
        continue;
      }
      final start = _parseSubtitleTime(timing[0]);
      final end = _parseSubtitleTime(timing[1].split(' ').first);
      if (start == null || end == null) {
        i++;
        continue;
      }

      // Collect text lines until next empty line
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        textLines.add(lines[i].trim());
        i++;
      }

      final text = textLines
          .join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll(RegExp(r'\{[^}]+\}'), '');
      if (text.isEmpty) continue;

      subtitles.add(
        Subtitle(index: subtitles.length, start: start, end: end, text: text),
      );
    }
    return subtitles;
  }

  List<Subtitle> _parseSrt(String input) {
    final blocks = input.split(RegExp(r'\n\s*\n'));
    final subtitles = <Subtitle>[];

    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;

      // Find the timing line
      int timingIndex = -1;
      for (int j = 0; j < lines.length; j++) {
        if (lines[j].contains('-->')) {
          timingIndex = j;
          break;
        }
      }
      if (timingIndex < 0) continue;

      final timing = lines[timingIndex].split('-->');
      if (timing.length != 2) continue;

      final start = _parseSrtTime(timing[0]);
      final end = _parseSrtTime(timing[1].split(' ').first);
      if (start == null || end == null) continue;

      // Text is everything after the timing line
      final textLines = lines.sublist(timingIndex + 1);
      final text = textLines
          .join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .trim();
      if (text.isEmpty) continue;

      subtitles.add(
        Subtitle(index: subtitles.length, start: start, end: end, text: text),
      );
    }
    return subtitles;
  }

  Duration? _parseSrtTime(String value) {
    final cleaned = value.trim().replaceAll(',', '.');
    final parts = cleaned.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final seconds = double.tryParse(parts.last);
    final minutes = int.tryParse(parts[parts.length - 2]);
    final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
    if (seconds == null || minutes == null || hours == null) return null;
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
    );
  }

  Duration? _parseSubtitleTime(String value) {
    final parts = value.trim().replaceAll(',', '.').split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final seconds = double.tryParse(parts.last);
    final minutes = int.tryParse(parts[parts.length - 2]);
    final hours = parts.length == 3 ? int.tryParse(parts.first) : 0;
    if (seconds == null || minutes == null || hours == null) return null;
    return Duration(
      hours: hours,
      minutes: minutes,
      milliseconds: (seconds * 1000).round(),
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
    setState(() {
      _isSwitchingQuality = true;
      _videoInitialized = false;
    });
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
    _selectedSubtitle.dispose();
    _activeSubtitles.dispose();
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
    final controller = _videoPlayerController!;
    final size = controller.value.size;
    final videoWidth = size.width > 0 ? size.width : 1920.0;
    final videoHeight = size.height > 0 ? size.height : 1080.0;
    final videoWidget = switch (_aspectRatioMode) {
      _AspectRatioMode.fit => Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio > 0
              ? controller.value.aspectRatio
              : 16 / 9,
          child: VideoPlayer(controller),
        ),
      ),
      _AspectRatioMode.stretch => SizedBox.expand(
        child: VideoPlayer(controller),
      ),
      _AspectRatioMode.zoom => ClipRect(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: videoWidth,
              height: videoHeight,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: videoWidget),
        if (!_videoInitialized)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.red,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Preparing video...',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (_videoInitialized && _isBuffering && !_isSwitchingQuality)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Loading video...',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        _StablePlayerControls(
          controller: controller,
          onBack: _exitPlayer,
          onQuality: _showQualityPicker,
          qualityLabel: _selectedQuality,
          showQuality: _qualities.length > 1,
          onSubtitles: _showSubtitlePicker,
          subtitleLabel: _selectedSubtitle,
          showSubtitles: _subtitleTracks.isNotEmpty,
          onAspectRatio: _cycleAspectRatio,
          aspectRatioLabel: _aspectRatioLabel,
        ),
        if (_videoPlayerController != null)
          Positioned(
            left: 24,
            right: 24,
            bottom: 92,
            child: IgnorePointer(
              child: ValueListenableBuilder<List<Subtitle>>(
                valueListenable: _activeSubtitles,
                builder: (context, subtitles, _) {
                  if (subtitles.isEmpty) return const SizedBox.shrink();
                  return ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: _videoPlayerController!,
                    builder: (context, value, _) {
                      final cues = subtitles.where(
                        (cue) =>
                            value.position >= cue.start &&
                            value.position <= cue.end,
                      );
                      if (cues.isEmpty) return const SizedBox.shrink();
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            cues.map((cue) => cue.text.toString()).join('\n'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
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
        if (_showNextEpisode && _nextEpisode != null)
          Positioned(
            right: 20,
            bottom: 100,
            child: Container(
              width: 340,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xff202124),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black54, blurRadius: 12),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      _nextEpisode!['stillUrl']?.toString() ?? '',
                      width: 110,
                      height: 66,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Colors.black45,
                        child: SizedBox(
                          width: 110,
                          height: 66,
                          child: Icon(Icons.tv, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Next episode in $_nextEpisodeCountdown seconds',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'S${_nextEpisode!['season']}E${_nextEpisode!['episode']} · ${_nextEpisode!['name']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton(
                              onPressed: _playNextEpisode,
                              child: const Text('Play now'),
                            ),
                            TextButton(
                              onPressed: _cancelNextEpisode,
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
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
                  onPressed: () => _loadStream(),
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
