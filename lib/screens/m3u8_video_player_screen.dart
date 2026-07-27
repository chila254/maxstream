import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import '../services/direct_m3u8_service.dart';
import '../services/media_download_manager.dart';
import '../services/native_stream_extractor.dart';
import '../services/tmdb_api_service.dart';
import '../services/watch_history_service.dart';

class M3U8VideoPlayerScreen extends StatefulWidget {
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;
  final String? offlinePath;
  final List<Map<String, dynamic>> offlineSubtitles;
  final List<Map<String, dynamic>> offlineEpisodes;

  const M3U8VideoPlayerScreen({
    super.key,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
    this.offlinePath,
    this.offlineSubtitles = const [],
    this.offlineEpisodes = const [],
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

class Subtitle {
  const Subtitle({
    required this.index,
    required this.start,
    required this.end,
    required this.text,
  });

  final int index;
  final Duration start;
  final Duration end;
  final String text;
}

class _StablePlayerControls extends StatefulWidget {
  const _StablePlayerControls({
    required this.controller,
    required this.onBack,
    required this.mediaTitle,
    required this.onQuality,
    required this.qualityLabel,
    required this.showQuality,
    required this.onServer,
    required this.serverLabel,
    required this.showServer,
    required this.serversLoading,
    required this.onSubtitles,
    required this.subtitleLabel,
    required this.showSubtitles,
    required this.onAspectRatio,
    required this.aspectRatioLabel,
    required this.onDownload,
    required this.showDownload,
    required this.downloadProgress,
  });

  final VideoPlayerController controller;
  final VoidCallback onBack;
  final String mediaTitle;
  final VoidCallback onQuality;
  final String qualityLabel;
  final bool showQuality;
  final VoidCallback onServer;
  final String serverLabel;
  final bool showServer;
  final bool serversLoading;
  final VoidCallback onSubtitles;
  final ValueNotifier<String> subtitleLabel;
  final bool showSubtitles;
  final VoidCallback onAspectRatio;
  final String aspectRatioLabel;
  final VoidCallback onDownload;
  final bool showDownload;
  final double? downloadProgress;

  @override
  State<_StablePlayerControls> createState() => _StablePlayerControlsState();
}

class _StablePlayerControlsState extends State<_StablePlayerControls> {
  bool _visible = true;
  Timer? _hideTimer;
  bool _adjustingBrightness = false;
  double _gestureValue = 0.5;
  bool _showGestureValue = false;
  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;

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
      final value = widget.controller.value;
      if (mounted && value.isPlaying && !value.isBuffering && !value.hasError) {
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
        if (value.duration > Duration.zero) _lastDuration = value.duration;
        if (value.position > Duration.zero) _lastPosition = value.position;
        final displayedDuration = value.duration > Duration.zero
            ? value.duration
            : _lastDuration;
        final displayedPosition = value.position > Duration.zero
            ? value.position
            : _lastPosition;
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
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: widget.onBack,
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.mediaTitle.isNotEmpty)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  widget.mediaTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        ],
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
                        if (value.isInitialized &&
                            value.duration > Duration.zero)
                          VideoProgressIndicator(
                            widget.controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            colors: const VideoProgressColors(
                              playedColor: Colors.red,
                              bufferedColor: Colors.white54,
                              backgroundColor: Colors.white24,
                            ),
                          )
                        else if (value.isInitialized &&
                            displayedDuration > Duration.zero)
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              activeTrackColor: Colors.red,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: Colors.red,
                              overlayColor: Colors.red.withOpacity(0.2),
                            ),
                            child: Slider(
                              value: displayedPosition.inMilliseconds
                                  .clamp(0, displayedDuration.inMilliseconds)
                                  .toDouble(),
                              max: displayedDuration.inMilliseconds.toDouble(),
                              onChanged: (milliseconds) {
                                widget.controller.seekTo(
                                  Duration(milliseconds: milliseconds.round()),
                                );
                                _restartHideTimer();
                              },
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: SizedBox(
                              height: 4,
                              child: ColoredBox(color: Colors.white24),
                            ),
                          ),
                        Row(
                          children: [
                            Text(
                              '${_format(displayedPosition)} / ${_format(displayedDuration)}',
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
                            if (widget.showDownload)
                              IconButton(
                                tooltip: widget.downloadProgress == null
                                    ? 'Download for offline viewing'
                                    : 'Downloading',
                                onPressed: widget.downloadProgress == null
                                    ? widget.onDownload
                                    : null,
                                icon: widget.downloadProgress == null
                                    ? const Icon(
                                        Icons.download_for_offline_outlined,
                                        color: Colors.white,
                                      )
                                    : SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          value: widget.downloadProgress,
                                          strokeWidth: 2.5,
                                          color: Colors.red,
                                          backgroundColor: Colors.white24,
                                        ),
                                      ),
                              ),
                            if (widget.showServer)
                              TextButton.icon(
                                onPressed: widget.onServer,
                                icon: widget.serversLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.dns_outlined,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  widget.serverLabel,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
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
  bool _useNativePlayer = false;
  bool _isBuffering = false;
  bool _isSwitchingQuality = false;
  bool _isSwitchingServer = false;
  String? _error;
  String? _currentSource;
  String _selectedQuality = 'Auto';
  Map<String, String> _streamHeaders = const {};
  List<_StreamQuality> _qualities = const [];
  List<_SubtitleTrack> _subtitleTracks = const [];
  final ValueNotifier<List<Subtitle>> _activeSubtitles =
      ValueNotifier<List<Subtitle>>(const []);
  final ValueNotifier<String> _selectedSubtitle = ValueNotifier<String>('Off');
  double _subtitleOffsetMs = 0; // Subtitle timing offset in milliseconds
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
  String? _currentStreamUrl;
  bool _currentStreamIsHls = true;
  Duration _lastStablePosition = Duration.zero;
  bool _recoveringPlayback = false;
  int _playbackRetryCount = 0;
  double? _downloadProgress;
  String? _offlinePath;
  List<Map<String, dynamic>> _offlineSubtitles = const [];
  List<Map<String, dynamic>> _availableServers = const [];
  bool _serversLoading = false;
  String? _selectedServerUrl;
  int _serverDiscoveryGeneration = 0;

  @override
  void initState() {
    super.initState();
    _currentSeason = widget.season;
    _currentEpisode = widget.episode;
    _currentTitle = widget.title;
    _resolverTitle = widget.title;
    _offlinePath = widget.offlinePath;
    _offlineSubtitles = widget.offlineSubtitles;
    MediaDownloadManager.instance.addListener(_handleDownloadChanged);
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
    final offlinePath = _offlinePath;
    if (offlinePath != null && offlinePath.isNotEmpty) {
      await _loadOfflineStream(offlinePath, resume: resume);
      return;
    }
    final discoveryGeneration = ++_serverDiscoveryGeneration;

    setState(() {
      _error = null;
      _statusMessage = 'Fetching servers...';
      _availableServers = const [];
      _serversLoading = false;
      _selectedServerUrl = null;
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
        _playbackRetryCount = 0;
        _availableServers = [result];
        _serversLoading = true;
        _selectedServerUrl = url;
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
        var discoveredServers = false;
        var initialized = await _initializePlayer(
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
        if (!initialized) {
          discoveredServers = true;
          await _discoverAvailableServers(discoveryGeneration);
          for (final server in _availableServers) {
            final fallbackUrl = server['url']?.toString() ?? '';
            if (fallbackUrl.isEmpty || fallbackUrl == url) continue;
            final fallbackSource = server['source']?.toString() ?? 'Server';
            final fallbackQualities = _parseQualities(server['qualities']);
            _subtitleTracks = _parseSubtitleTracks(server['subtitles']);
            _selectedSubtitle.value = 'Off';
            _activeSubtitles.value = const [];
            initialized = await _initializePlayer(
              fallbackUrl,
              headers: _parseStreamHeaders(server),
              source: fallbackSource,
              qualities: fallbackQualities,
              selectedQuality: 'Auto',
              position: resumePosition,
              isHls:
                  server['type'] == 'direct_m3u8' ||
                  fallbackUrl.toLowerCase().contains('.m3u8'),
            );
            if (initialized) {
              _selectedServerUrl = fallbackUrl;
              break;
            }
          }
        }
        if (!initialized) {
          if (mounted) {
            setState(() {
              _error =
                  'None of the available servers could start playback. '
                  'Please try again later.';
            });
          }
          return;
        }
        // Now that the new player is ready, allow the next-episode countdown
        // to function again. The cancel flag was held true during the episode
        // transition to prevent the old controller's listener from showing
        // the overlay with stale data.
        if (mounted) {
          setState(() {
            _nextEpisodeCancelled = false;
          });
        }
        if (!discoveredServers) {
          unawaited(_discoverAvailableServers(discoveryGeneration));
        }
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

  Future<void> _loadOfflineStream(String path, {required bool resume}) async {
    final previousVideo = _videoPlayerController;
    setState(() {
      _error = null;
      _statusMessage = 'Opening download...';
      _availableServers = const [];
      _serversLoading = false;
    });
    final file = File(path);
    final exists = await file.exists();
    if (!mounted) return;
    if (!exists) {
      setState(() => _error = 'This downloaded video file no longer exists.');
      return;
    }
    final controller = VideoPlayerController.file(
      file,
      videoPlayerOptions: VideoPlayerOptions(
        backBufferDurationMs: 60000,
        allowBackgroundPlayback: false,
      ),
    );
    try {
      final subtitleTracks = _parseSubtitleTracks(_offlineSubtitles);
      await controller.initialize();
      final position = resume
          ? await WatchHistoryService.loadWatchPosition(
              widget.tmdbId,
              widget.isMovie,
              _currentSeason,
              _currentEpisode,
            )
          : Duration.zero;
      if (position > Duration.zero && position < controller.value.duration) {
        await controller.seekTo(position);
      }
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(_handlePlaybackChanged);
      _prepareNextOfflineEpisode();
      setState(() {
        _videoPlayerController = controller;
        _useNativePlayer = true;
        _videoInitialized = true;
        _currentSource = 'Downloaded';
        _currentStreamUrl = null;
        _currentStreamIsHls = path.toLowerCase().endsWith('.m3u8');
        _streamHeaders = const {};
        _qualities = const [];
        _subtitleTracks = subtitleTracks;
        _selectedSubtitle.value = 'Off';
        _activeSubtitles.value = const [];
        _nextEpisodeCancelled = false;
      });
      previousVideo?.removeListener(_handlePlaybackChanged);
      await previousVideo?.dispose();
      _startProgressSaving();
    } catch (error) {
      await controller.dispose();
      debugPrint('M3U8Player: Download playback failed: $error');
      if (mounted) {
        setState(() {
          _error =
              'This downloaded video is incomplete or damaged and cannot play. '
              'Delete it and download it again.';
        });
      }
    }
  }

  void _prepareNextOfflineEpisode() {
    if (widget.isMovie || widget.offlineEpisodes.isEmpty) {
      _nextEpisode = null;
      return;
    }
    final episodes = List<Map<String, dynamic>>.from(widget.offlineEpisodes)
      ..sort((a, b) {
        final season = ((a['seasonNumber'] as num?)?.toInt() ?? 0).compareTo(
          (b['seasonNumber'] as num?)?.toInt() ?? 0,
        );
        return season != 0
            ? season
            : ((a['episodeNumber'] as num?)?.toInt() ?? 0).compareTo(
                (b['episodeNumber'] as num?)?.toInt() ?? 0,
              );
      });
    Map<String, dynamic>? next;
    for (final episode in episodes) {
      final season = (episode['seasonNumber'] as num?)?.toInt() ?? 0;
      final number = (episode['episodeNumber'] as num?)?.toInt() ?? 0;
      if (season > _currentSeason ||
          (season == _currentSeason && number > _currentEpisode)) {
        next = episode;
        break;
      }
    }
    if (next == null) {
      _nextEpisode = null;
      return;
    }
    final title = next['title']?.toString() ?? 'Next episode';
    _nextEpisode = {
      'season': next['seasonNumber'],
      'episode': next['episodeNumber'],
      'name': title.contains(': ')
          ? title.split(': ').skip(1).join(': ')
          : title,
      'seriesTitle': title.contains(' - S')
          ? title.split(' - S').first
          : _resolverTitle,
      'stillUrl': next['thumbnail']?.toString() ?? '',
      'offlinePath': next['localPath']?.toString() ?? '',
      'subtitles': next['subtitles'] ?? const <Map<String, dynamic>>[],
    };
  }

  Future<void> _downloadCurrentStream() async {
    final url = _currentStreamUrl;
    if (url == null || _downloadProgress != null) return;
    try {
      await MediaDownloadManager.instance.start(
        downloadKey: _currentDownloadKey,
        url: url,
        headers: _streamHeaders,
        mediaId: widget.tmdbId,
        isMovie: widget.isMovie,
        isHls: _currentStreamIsHls,
        seriesId: widget.isMovie ? null : widget.tmdbId,
        seasonNumber: widget.isMovie ? null : _currentSeason,
        episodeNumber: widget.isMovie ? null : _currentEpisode,
        title: _currentTitle,
        resolverTitle: _resolverTitle,
        thumbnail: _posterUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Download completed')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Download failed: $error')));
      }
    }
  }

  String get _currentDownloadKey => widget.isMovie
      ? 'movie_${widget.tmdbId}'
      : 'series_${widget.tmdbId}_s${_currentSeason}_e$_currentEpisode';

  void _handleDownloadChanged() {
    if (!mounted) return;
    final progress = MediaDownloadManager.instance
        .taskFor(_currentDownloadKey)
        ?.progress;
    if (progress != _downloadProgress) {
      setState(() => _downloadProgress = progress);
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
    final episodes = await TmdbApiService.getSeasonEpisodes(id, _currentSeason);
    final currentEpisodeData = episodes
        .where(
          (e) =>
              ((e['episode_number'] as num?)?.toInt() ?? 0) == _currentEpisode,
        )
        .firstOrNull;
    final episodeName = currentEpisodeData?['name']?.toString() ?? '';
    _currentTitle = episodeName.isNotEmpty
        ? '$seriesTitle - S${_currentSeason}E$_currentEpisode: $episodeName'
        : '$seriesTitle - S${_currentSeason}E$_currentEpisode';
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
    _showNextEpisode = false;
    _nextEpisodeCountdown = 30;
    // _nextEpisodeCancelled stays true during loading to prevent the old
    // controller's listener from showing the popup with stale data.
    // It gets reset in _loadStream after the new player is initialized.
  }

  Future<bool> _initializePlayer(
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
      return true;
    } catch (e) {
      debugPrint('M3U8VideoPlayer: Error initializing player: $e');
      _showStatus('Player error: $e');
      return false;
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

  Map<String, String> _parseStreamHeaders(Map<String, dynamic> stream) {
    final headers = <String, String>{};
    if (stream['referer'] != null) {
      headers['Referer'] = stream['referer'].toString();
    }
    final rawHeaders = stream['headers'];
    if (rawHeaders is Map) {
      rawHeaders.forEach((key, value) {
        headers[key.toString()] = value.toString();
      });
    }
    return headers;
  }

  Future<void> _discoverAvailableServers(int generation) async {
    final streams = await DirectM3u8Service.fetchAvailableStreams(
      title: _resolverTitle,
      tmdbId: widget.tmdbId,
      isMovie: widget.isMovie,
      season: _currentSeason,
      episode: _currentEpisode,
    );
    if (!mounted || generation != _serverDiscoveryGeneration) return;
    final merged = <Map<String, dynamic>>[..._availableServers, ...streams];
    final seen = <String>{};
    setState(() {
      _availableServers = merged.where((stream) {
        final url = stream['url']?.toString() ?? '';
        return url.isNotEmpty && seen.add(url);
      }).toList();
      _serversLoading = false;
    });
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

      if (!mounted) {
        await controller.dispose();
        return;
      }

      controller.addListener(_handlePlaybackChanged);
      setState(() {
        _videoPlayerController = controller;
        _useNativePlayer = true;
        _currentSource = source;
        _streamHeaders = headers;
        _qualities = qualities;
        _selectedQuality = selectedQuality;
        _isBuffering = controller.value.isBuffering;
        _isSwitchingQuality = false;
        _videoInitialized = true;
        _currentStreamUrl = url;
        _currentStreamIsHls = isHls;
      });

      previousVideo?.removeListener(_handlePlaybackChanged);
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
    if (value.position > Duration.zero) _lastStablePosition = value.position;
    if (value.hasError && _offlinePath != null && _error == null) {
      controller.pause();
      setState(() {
        _error =
            'This downloaded video is incomplete or damaged and cannot continue. '
            'Delete it and download it again.';
      });
      return;
    }
    if (value.hasError && !_recoveringPlayback && _playbackRetryCount < 2) {
      unawaited(_recoverPlayback());
    }
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

  Future<void> _recoverPlayback() async {
    final url = _currentStreamUrl;
    if (url == null || _recoveringPlayback || _playbackRetryCount >= 2) return;
    _recoveringPlayback = true;
    _playbackRetryCount++;
    if (mounted) {
      setState(() {
        _isBuffering = true;
        _statusMessage = 'Recovering playback...';
      });
    }
    await Future<void>.delayed(Duration(seconds: _playbackRetryCount * 2));
    try {
      await _replacePlayer(
        url,
        headers: _streamHeaders,
        source: _currentSource ?? 'Unknown',
        qualities: _qualities,
        selectedQuality: _selectedQuality,
        isHls: _currentStreamIsHls,
        position: _lastStablePosition,
        shouldPlay: true,
      );
    } catch (error) {
      debugPrint('M3U8Player: Playback recovery failed: $error');
      if (mounted && _playbackRetryCount >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The current server stopped responding. Please try again.',
            ),
          ),
        );
      }
    } finally {
      _recoveringPlayback = false;
    }
  }

  Future<void> _playNextEpisode() async {
    final next = _nextEpisode;
    if (next == null || _loadingNextEpisode) return;
    _loadingNextEpisode = true;
    // Clear next-episode state immediately so the old controller's
    // _handlePlaybackChanged doesn't re-show the popup for the next-next episode.
    if (mounted) {
      setState(() {
        _nextEpisode = null;
        _nextEpisodeCancelled = true;
        _showNextEpisode = false;
        _isSwitchingQuality = true;
        _statusMessage = 'Loading next episode...';
      });
    }
    await _saveProgress();
    _currentSeason = (next['season'] as num).toInt();
    _currentEpisode = (next['episode'] as num).toInt();
    _currentTitle =
        '${next['seriesTitle']} - S${_currentSeason}E$_currentEpisode: ${next['name']}';
    if (_offlinePath != null) {
      _offlinePath = next['offlinePath']?.toString();
      _offlineSubtitles = (next['subtitles'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (track) =>
                track.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList();
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
      seriesTitle: widget.isMovie ? null : _resolverTitle,
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

  Future<void> _showServerPicker() async {
    if (!mounted || _availableServers.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff202124),
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.dns_outlined, color: Colors.white),
              title: const Text(
                'Select server',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                _serversLoading
                    ? 'Checking other servers...'
                    : '${_availableServers.length} working server${_availableServers.length == 1 ? '' : 's'}',
                style: const TextStyle(color: Colors.white60),
              ),
              trailing: _serversLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red,
                      ),
                    )
                  : null,
            ),
            ..._availableServers.asMap().entries.map((entry) {
              final stream = entry.value;
              final url = stream['url']?.toString() ?? '';
              final source = stream['source']?.toString() ?? 'Server';
              final server = stream['server']?.toString() ?? source;
              final selected = url == _selectedServerUrl;
              return ListTile(
                leading: Icon(
                  selected ? Icons.check_circle : Icons.play_circle_outline,
                  color: selected ? Colors.red : Colors.white70,
                ),
                title: Text(
                  source,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  server == source
                      ? 'Server ${entry.key + 1}'
                      : 'Via $server · Server ${entry.key + 1}',
                  style: const TextStyle(color: Colors.white54),
                ),
                enabled: !selected && !_isSwitchingServer,
                onTap: selected
                    ? null
                    : () {
                        Navigator.of(sheetContext).pop();
                        _switchServer(stream);
                      },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _switchServer(Map<String, dynamic> stream) async {
    if (_isSwitchingServer) return;
    final url = stream['url']?.toString() ?? '';
    if (url.isEmpty || url == _selectedServerUrl) return;
    final current = _videoPlayerController;
    if (current == null) return;

    final oldTracks = _subtitleTracks;
    final oldSelectedSubtitle = _selectedSubtitle.value;
    final oldSubtitles = _activeSubtitles.value;
    final headers = _parseStreamHeaders(stream);
    final qualities = _parseQualities(stream['qualities']);
    var selectedQuality = 'Auto';
    for (final quality in qualities) {
      if (quality.url == url) selectedQuality = quality.label;
    }
    final position = current.value.position > Duration.zero
        ? current.value.position
        : _lastStablePosition;
    final shouldPlay = current.value.isPlaying || current.value.isBuffering;
    setState(() {
      _isSwitchingServer = true;
      _subtitleTracks = _parseSubtitleTracks(stream['subtitles']);
      _selectedSubtitle.value = 'Off';
      _activeSubtitles.value = const [];
    });
    try {
      await _replacePlayer(
        url,
        headers: headers,
        source: stream['source']?.toString() ?? 'Server',
        qualities: qualities,
        selectedQuality: selectedQuality,
        isHls:
            stream['type'] == 'direct_m3u8' ||
            url.toLowerCase().contains('.m3u8'),
        position: position,
        shouldPlay: shouldPlay,
      );
      if (mounted) setState(() => _selectedServerUrl = url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _subtitleTracks = oldTracks;
        _selectedSubtitle.value = oldSelectedSubtitle;
        _activeSubtitles.value = oldSubtitles;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not switch server: $error')),
      );
    } finally {
      _isSwitchingServer = false;
      if (mounted) setState(() {});
    }
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

  Future<void> _showSubtitlePicker() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xff202124),
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) => ListView(
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
              // Subtitle offset adjustment
              if (_selectedSubtitle.value != 'Off') ...[
                const Divider(color: Colors.white24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Subtitle Offset',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_subtitleOffsetMs.round()}ms',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Adjust if subtitles are out of sync with video',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          activeTrackColor: Colors.red,
                          inactiveTrackColor: Colors.white24,
                          thumbColor: Colors.red,
                          overlayColor: Colors.red.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: _subtitleOffsetMs.clamp(-5000, 5000),
                          min: -5000,
                          max: 5000,
                          divisions: 100,
                          onChanged: (value) {
                            setSheetState(() {
                              _subtitleOffsetMs = value;
                            });
                            setState(() {});
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                _subtitleOffsetMs = 0;
                              });
                              setState(() {});
                            },
                            child: const Text(
                              'Reset',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          Text(
                            _subtitleOffsetMs > 0
                                ? 'Subtitles later'
                                : _subtitleOffsetMs < 0
                                ? 'Subtitles earlier'
                                : 'Synced',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(color: Colors.white24),
              ..._buildGroupedSubtitleTiles(),
            ],
          ),
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
    final localFile = File(track.url);
    if (await localFile.exists()) {
      final input = await localFile.readAsString();
      final subtitles = _parseSubtitleFile(input);
      if (subtitles.isEmpty) {
        throw const FormatException(
          'The downloaded subtitle contained no valid timed cues',
        );
      }
      return subtitles;
    }
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
        final inheritedHeaders = track.source == 'Vidflix'
            ? const <String, String>{}
            : headers;
        final response = await http
            .get(
              parsedUri,
              headers: {
                ...inheritedHeaders,
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
                'Accept': 'text/vtt, application/x-subrip, text/plain, */*',
              },
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = utf8.decode(response.bodyBytes, allowMalformed: true);
          if (body.trim().isNotEmpty) {
            final subtitles = _parseSubtitleFile(body);
            if (subtitles.isNotEmpty) return subtitles;
            lastError = const FormatException(
              'The subtitle file contained no valid timed cues',
            );
            continue;
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
    final normalized = input
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');

    final upper = normalized.trimLeft().toUpperCase();

    // Detect format
    if (upper.startsWith('WEBVTT')) {
      return _parseVtt(normalized);
    } else if (upper.startsWith('{') || upper.startsWith('[')) {
      final jsonSubtitles = _parseJsonSubtitles(normalized);
      if (jsonSubtitles.isNotEmpty) return jsonSubtitles;
    } else if (upper.contains('[SCRIPT INFO]') || upper.contains('[V4')) {
      return _parseAss(normalized);
    } else if (upper.contains('<TT') ||
        upper.contains('<P ') ||
        upper.contains('<P>')) {
      return _parseTtml(normalized);
    } else {
      final srt = _parseSrt(normalized);
      if (srt.isNotEmpty) return srt;
      // Last resort: try TTML for any XML-like content
      if (normalized.contains('<') && normalized.contains('begin=')) {
        return _parseTtml(normalized);
      }
      return srt;
    }
    return const [];
  }

  List<Subtitle> _parseJsonSubtitles(String input) {
    try {
      final decoded = jsonDecode(input);
      final dynamic rawCues = decoded is List
          ? decoded
          : decoded is Map
          ? decoded['cues'] ?? decoded['subtitles'] ?? decoded['data']
          : null;
      if (rawCues is! List) return const [];

      final subtitles = <Subtitle>[];
      for (final rawCue in rawCues.whereType<Map>()) {
        final start = _parseJsonCueTime(
          rawCue['startTime'] ?? rawCue['start'] ?? rawCue['from'],
        );
        final end = _parseJsonCueTime(
          rawCue['endTime'] ?? rawCue['end'] ?? rawCue['to'],
        );
        final rawText =
            rawCue['text'] ?? rawCue['payload'] ?? rawCue['caption'];
        final text = rawText is List
            ? rawText.join('\n')
            : rawText?.toString() ?? '';
        final cleanedText = text
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .trim();
        if (start == null || end == null || cleanedText.isEmpty) continue;
        subtitles.add(
          Subtitle(
            index: subtitles.length,
            start: start,
            end: end,
            text: cleanedText,
          ),
        );
      }
      return subtitles;
    } catch (_) {
      return const [];
    }
  }

  Duration? _parseJsonCueTime(dynamic value) {
    if (value is num) {
      return Duration(milliseconds: (value.toDouble() * 1000).round());
    }
    if (value is! String) return null;
    final timestamp = _parseSubtitleTime(value);
    if (timestamp != null) return timestamp;
    final seconds = double.tryParse(value);
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
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
      final endValue = timing[1].trim().split(RegExp(r'\s+')).first;
      final end = _parseSubtitleTime(endValue);
      if (start == null || end == null) {
        i++;
        continue;
      }

      // Collect text lines until next empty line or next cue timing
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        // Stop if we hit another timing line (handles VTT without blank lines between cues)
        if (lines[i].trim().contains('-->')) break;
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
      final endValue = timing[1].trim().split(RegExp(r'\s+')).first;
      final end = _parseSrtTime(endValue);
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

  List<Subtitle> _parseAss(String input) {
    final subtitles = <Subtitle>[];
    final lines = input.split('\n');
    bool inEvents = false;
    bool foundFormat = false;
    int textIndex = -1;
    int startIdx = -1;
    int endIdx = -1;

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.toUpperCase() == '[EVENTS]') {
        inEvents = true;
        continue;
      }
      if (line.startsWith('[') && inEvents) break;

      if (inEvents) {
        if (line.toUpperCase().startsWith('FORMAT:')) {
          foundFormat = true;
          final fields = line
              .substring(7)
              .split(',')
              .map((f) => f.trim().toLowerCase())
              .toList();
          startIdx = fields.indexOf('start');
          endIdx = fields.indexOf('end');
          textIndex = fields.indexOf('text');
          continue;
        }

        if (!foundFormat || textIndex < 0) continue;
        if (!line.toUpperCase().startsWith('DIALOGUE:') &&
            !line.toUpperCase().startsWith('COMMENT:')) {
          continue;
        }
        if (line.toUpperCase().startsWith('COMMENT:')) continue;

        final afterColon = line.substring(line.indexOf(':') + 1);
        final parts = afterColon.split(',');
        if (parts.length <= textIndex) continue;

        final start = _parseAssTime(
          startIdx >= 0 && startIdx < parts.length ? parts[startIdx] : '',
        );
        final end = _parseAssTime(
          endIdx >= 0 && endIdx < parts.length ? parts[endIdx] : '',
        );
        if (start == null || end == null) continue;

        final text = parts
            .sublist(textIndex)
            .join(',')
            .replaceAll(RegExp(r'\{[^}]*\}'), '')
            .replaceAll('\\N', '\n')
            .replaceAll('\\n', '\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (text.isEmpty) continue;

        subtitles.add(
          Subtitle(index: subtitles.length, start: start, end: end, text: text),
        );
      }
    }
    return subtitles;
  }

  Duration? _parseAssTime(String value) {
    final cleaned = value.trim();
    final match = RegExp(r'(\d+):(\d+):(\d+)\.(\d+)').firstMatch(cleaned);
    if (match == null) return null;
    final hours = int.tryParse(match.group(1) ?? '') ?? 0;
    final minutes = int.tryParse(match.group(2) ?? '') ?? 0;
    final seconds = int.tryParse(match.group(3) ?? '') ?? 0;
    final cs = int.tryParse(match.group(4) ?? '') ?? 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: cs * 10,
    );
  }

  List<Subtitle> _parseTtml(String input) {
    final subtitles = <Subtitle>[];
    // Match <p> or <div><p> elements with begin/end attributes
    final cuePattern = RegExp(
      r'<(?:p|P)\s[^>]*?begin="([^"]+)"[^>]*?end="([^"]+)"[^>]*?>([\s\S]*?)</(?:p|P)>',
      caseSensitive: false,
    );
    for (final match in cuePattern.allMatches(input)) {
      final start = _parseTtmlTime(match.group(1) ?? '');
      final end = _parseTtmlTime(match.group(2) ?? '');
      if (start == null || end == null) continue;
      final text = match
          .group(3)!
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&#xA;', '\n')
          .replaceAll('\n', ' ')
          .trim();
      if (text.isEmpty) continue;
      subtitles.add(
        Subtitle(index: subtitles.length, start: start, end: end, text: text),
      );
    }
    return subtitles;
  }

  Duration? _parseTtmlTime(String value) {
    final cleaned = value.trim();
    // TTML formats: HH:MM:SS.mmm, HH:MM:SS:mm (frames), HH:MM:SS, or decimal seconds
    final hmsMatch = RegExp(
      r'(\d+):(\d+):(\d+)(?:\.(\d+))?',
    ).firstMatch(cleaned);
    if (hmsMatch != null) {
      final hours = int.tryParse(hmsMatch.group(1) ?? '') ?? 0;
      final minutes = int.tryParse(hmsMatch.group(2) ?? '') ?? 0;
      final seconds = int.tryParse(hmsMatch.group(3) ?? '') ?? 0;
      final frac = hmsMatch.group(4) ?? '0';
      // Normalize fractional part to milliseconds
      int ms = 0;
      if (frac.isNotEmpty) {
        final padded = frac.padRight(3, '0').substring(0, 3);
        ms = int.tryParse(padded) ?? 0;
      }
      return Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: ms,
      );
    }
    // Plain seconds: "123.456"
    final secMatch = RegExp(r'^(\d+(?:\.\d+)?)s?$').firstMatch(cleaned);
    if (secMatch != null) {
      final seconds = double.tryParse(secMatch.group(1) ?? '') ?? 0;
      return Duration(milliseconds: (seconds * 1000).round());
    }
    return null;
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
    MediaDownloadManager.instance.removeListener(_handleDownloadChanged);
    _selectedSubtitle.dispose();
    _activeSubtitles.dispose();
    _progressTimer?.cancel();
    unawaited(_saveProgress());
    _videoPlayerController?.removeListener(_handlePlaybackChanged);
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
            : _useNativePlayer && _videoPlayerController != null
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
        if (_videoInitialized &&
            _isBuffering &&
            !_isSwitchingQuality &&
            !_isSwitchingServer)
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
        Positioned.fill(
          child: _StablePlayerControls(
            controller: controller,
            onBack: _exitPlayer,
            mediaTitle: _currentTitle,
            onQuality: _showQualityPicker,
            qualityLabel: _selectedQuality,
            showQuality: _qualities.length > 1,
            onServer: _showServerPicker,
            serverLabel: _currentSource ?? 'Server',
            showServer: _availableServers.isNotEmpty,
            serversLoading: _serversLoading,
            onSubtitles: _showSubtitlePicker,
            subtitleLabel: _selectedSubtitle,
            showSubtitles: _subtitleTracks.isNotEmpty,
            onAspectRatio: _cycleAspectRatio,
            aspectRatioLabel: _aspectRatioLabel,
            onDownload: _downloadCurrentStream,
            showDownload: widget.offlinePath == null,
            downloadProgress: _downloadProgress,
          ),
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
                      // Apply subtitle offset for sync adjustment
                      final adjustedPosition = Duration(
                        milliseconds:
                            value.position.inMilliseconds +
                            _subtitleOffsetMs.round(),
                      );
                      final cues = subtitles.where(
                        (cue) =>
                            adjustedPosition >= cue.start &&
                            adjustedPosition <= cue.end,
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
