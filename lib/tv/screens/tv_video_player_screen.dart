import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/tv_navigation_provider.dart';
import '../../services/direct_m3u8_service.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';

class _QualityOption {
  const _QualityOption({required this.label, required this.url});

  final String label;
  final String url;

  factory _QualityOption.fromMap(Map<String, dynamic> value) {
    return _QualityOption(
      label: value['label']?.toString() ?? 'Auto',
      url: value['url']?.toString() ?? '',
    );
  }
}

class _SubtitleTrack {
  const _SubtitleTrack({
    required this.label,
    required this.url,
    this.source = '',
    this.isDefault = false,
  });

  final String label;
  final String url;
  final String source;
  final bool isDefault;
}

class _SubtitleCue {
  const _SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;

  _SubtitleCue copyWith({String? text, Duration? start, Duration? end}) {
    return _SubtitleCue(
      start: start ?? this.start,
      end: end ?? this.end,
      text: text ?? this.text,
    );
  }
}

class _StreamCandidate {
  const _StreamCandidate({
    required this.url,
    required this.source,
    required this.headers,
    this.route,
    this.qualities = const [],
    this.subtitles = const [],
  });

  final String url;
  final String source;
  final Map<String, String> headers;
  final String? route;
  final List<_QualityOption> qualities;
  final List<_SubtitleTrack> subtitles;

  factory _StreamCandidate.fromMap(Map<String, dynamic> value) {
    final headers = <String, String>{};
    if (value['referer'] != null) {
      headers['Referer'] = value['referer'].toString();
    }
    if (value['headers'] is Map) {
      (value['headers'] as Map).forEach((key, header) {
        headers[key.toString()] = header.toString();
      });
    }
    return _StreamCandidate(
      url: value['url']?.toString() ?? '',
      source: value['source']?.toString() ?? 'Unknown',
      route: value['server']?.toString(),
      headers: headers,
      qualities: _parseQualities(value['qualities']),
      subtitles: _parseSubtitleTracks(value['subtitles']),
    );
  }

  static List<_QualityOption> _parseQualities(dynamic value) {
    if (value is! List) return const [];
    final seen = <String>{};
    return value
        .whereType<Map>()
        .map((q) => _QualityOption.fromMap(q.cast<String, dynamic>()))
        .where((q) => q.url.isNotEmpty && seen.add(q.url))
        .toList();
  }

  static List<_SubtitleTrack> _parseSubtitleTracks(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map(
          (s) => _SubtitleTrack(
            label: s['label']?.toString() ?? 'Subtitle',
            url: s['url']?.toString() ?? '',
            source: s['source']?.toString() ?? '',
            isDefault: s['default'] == true,
          ),
        )
        .where((s) => s.url.isNotEmpty)
        .toList();
  }
}

/// Player control areas laid out on a coarse grid so the D-pad can move
/// predictably between them (mirroring the focus model used on the TV home
/// screen).
enum _Pc {
  back(0, 0),
  playPause(1, 0),
  rewind(2, 0),
  forward(3, 0),
  subtitles(4, 0),
  quality(5, 0),
  server(6, 0),
  volume(4, 1),
  slider(0, 2);

  const _Pc(this.col, this.row);
  final int col;
  final int row;
}

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

class _TvVideoPlayerScreenState extends State<TvVideoPlayerScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  String? _error;
  String _statusMessage = '';

  List<_StreamCandidate> _availableServers = [];
  bool _serversLoading = false;
  String? _selectedSource;
  String? _selectedServerUrl;
  String? _currentTitle;
  _StreamCandidate? _currentCandidate;

  VideoPlayerController? _controller;
  String? _currentStreamUrl;
  bool _showControls = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _positionTimer;
  Timer? _initTimeout;
  int _operationGeneration = 0;
  bool _switchingServer = false;
  bool _disposed = false;
  bool _recoveringPlayback = false;
  int _playbackRetryCount = 0;
  bool _completionHandled = false;
  Duration _lastReportedPosition = Duration.zero;
  Duration _lastStablePosition = Duration.zero;
  int _rebufferCount = 0;
  DateTime? _lastRebufferTime;
  bool _wasBufferingAtLastCheck = false;

  List<_QualityOption> _qualities = const [];
  List<_SubtitleTrack> _subtitleTracks = const [];
  List<_SubtitleCue> _activeSubtitles = const [];
  final ValueNotifier<String> _subtitleText = ValueNotifier<String>('');
  String _selectedSubtitleLabel = 'Off';

  _Pc _currentControl = _Pc.playPause;

  bool _subtitleMenuOpen = false;
  bool _qualityMenuOpen = false;
  bool _serverMenuOpen = false;

  final FocusNode _surfaceNode = FocusNode(debugLabel: 'Player surface');
  final FocusNode _retryNode = FocusNode(debugLabel: 'Player retry');
  final FocusNode _errorBackNode = FocusNode(debugLabel: 'Player error back');
  final Map<_Pc, FocusNode> _controlFocusNodes = {};

  bool get _hasDuration => _duration > Duration.zero;

  String get _selectedQualityLabel {
    final currentUrl = _currentStreamUrl;
    if (currentUrl == null || _qualities.isEmpty) return 'Auto';
    return _qualities
            .where((q) => q.url == currentUrl)
            .map((q) => q.label)
            .firstOrNull ??
        'Auto';
  }

  List<Map<String, dynamic>> _seasonEpisodes = const [];
  int _nextSeason = 1;
  int _nextEpisode = 1;
  bool _hasNextEpisode = false;
  bool _loadingNext = false;

  int _activeSeason = 1;
  int _activeEpisode = 1;

  String _seriesTitle = '';
  String _seriesPosterUrl = '';
  String _episodeStillUrl = '';
  String _movieBackdropUrl = '';
  String _currentEpisodeName = '';

  void _populateControlFocusNodes() {
    for (final pc in _Pc.values) {
      _controlFocusNodes[pc] = FocusNode(debugLabel: 'Player control $pc');
    }
  }

  bool get _hasFocusableMenu =>
      _subtitleMenuOpen || _qualityMenuOpen || _serverMenuOpen;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _populateControlFocusNodes();
    _activeSeason = widget.season;
    _activeEpisode = widget.episode;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();

    context.read<TvNavigationProvider>().setDeepNavigating(true);

    _progressTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _saveProgress();
    });

    _positionTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      _onPositionTick();
    });

    _loadStream();
  }

  @override
  void dispose() {
    _disposed = true;
    _operationGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _positionTimer?.cancel();
    _initTimeout?.cancel();
    _saveProgress();
    _controller?.removeListener(_handlePlaybackChanged);
    _controller?.dispose();
    _controller = null;
    _subtitleText.dispose();
    WakelockPlus.disable();
    if (mounted) {
      context.read<TvNavigationProvider>().setDeepNavigating(false);
    }
    for (final node in [
      _surfaceNode,
      _retryNode,
      _errorBackNode,
      ..._controlFocusNodes.values,
    ]) {
      node.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveProgress();
      _controller?.pause();
    }
  }

  void _saveProgress() {
    final position = _position;
    final duration = _duration;
    if (mounted && position > Duration.zero && duration > Duration.zero) {
      WatchHistoryService.saveWatchProgress(
        tmdbId: widget.tmdbId,
        title: _currentTitle ?? widget.title,
        isMovie: widget.isMovie,
        season: widget.isMovie ? widget.season : _activeSeason,
        episode: widget.isMovie ? widget.episode : _activeEpisode,
        position: position,
        duration: duration,
        posterUrl: widget.isMovie
            ? _movieBackdropUrl
            : (_episodeStillUrl.isNotEmpty
                  ? _episodeStillUrl
                  : _seriesPosterUrl),
        seriesTitle: widget.isMovie ? null : _seriesTitle,
        episodeName: widget.isMovie ? null : _currentEpisodeName,
      );
    }
  }

  void _showStatus(String message) {
    debugPrint('TvVideoPlayer: $message');
    if (mounted) {
      setState(() => _statusMessage = message);
    }
  }

  bool _isCurrent(int generation) =>
      !_disposed && mounted && generation == _operationGeneration;
  Future<void> _loadStream() async {
    if (!mounted || _disposed) return;
    final generation = ++_operationGeneration;

    setState(() {
      _isLoading = true;
      _error = null;
      _statusMessage = 'Fetching servers...';
    });

    try {
      await _loadMediaMetadata();

      Map<String, dynamic>? result;

      if (widget.isMovie) {
        result = await DirectM3u8Service.fetchMovieStreamUrl(
          _currentTitle ?? widget.title,
          null,
          widget.tmdbId,
        );
      } else {
        result = await DirectM3u8Service.fetchSeriesStreamUrl(
          _currentTitle ?? widget.title,
          widget.season,
          widget.episode,
          widget.tmdbId,
        );
      }

      if (!mounted) return;

      if (result != null && result['url'] != null) {
        if (!_isCurrent(generation)) return;
        final candidate = _StreamCandidate.fromMap(result);
        _availableServers = [candidate];
        _qualities = candidate.qualities;
        _subtitleTracks = candidate.subtitles;
        _showStatus(
          'Stream found from ${candidate.source}. Initializing player...',
        );
        final initialized = await _initializePlayer(
          candidate,
          generation: generation,
resumePosition: null,
        );
        if (!initialized || !_isCurrent(generation)) return;
        _loadDefaultSubtitle(candidate);
        _discoverAvailableServers(generation);
        return;
      }

      _showStatus('No stream found');
      if (mounted) {
        setState(() {
          _error =
              'No working streaming sources found.\n\n'
              'Check your internet connection\n'
              'Try again later\n'
              'Content might be unavailable';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!_isCurrent(generation)) return;
      debugPrint('TvVideoPlayer: Error loading stream: $e');
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
      _movieBackdropUrl = TmdbApiService.getBackdropUrl(
        details['backdrop_path']?.toString() ?? '',
      );
    } else {
      final seriesTitle = details['name']?.toString() ?? widget.title;
      _seriesTitle = seriesTitle;
      _seriesPosterUrl = TmdbApiService.getPosterUrl(
        details['poster_path']?.toString() ?? '',
      );
      final episodes = await TmdbApiService.getSeasonEpisodes(
        id,
        widget.season,
      );
      _seasonEpisodes = episodes;
      final currentEpisodeData = episodes
          .where(
            (e) =>
                ((e['episode_number'] as num?)?.toInt() ?? 0) == widget.episode,
          )
          .firstOrNull;
      final episodeName = currentEpisodeData?['name']?.toString() ?? '';
      _currentEpisodeName = episodeName;
      _episodeStillUrl = TmdbApiService.getImageUrl(
        currentEpisodeData?['still_path']?.toString() ?? '',
      );
      _currentTitle = episodeName.isNotEmpty
          ? '$seriesTitle - S${widget.season}E${widget.episode}: $episodeName'
          : '$seriesTitle - S${widget.season}E${widget.episode}';
      _resolveNextEpisode(id, seriesTitle);
    }
  }

  void _resolveNextEpisode(int seriesId, String seriesTitle) {
    final episodes = _seasonEpisodes;
    final episodeNumbers = episodes
        .map((e) => (e['episode_number'] as num?)?.toInt() ?? 0)
        .where((n) => n > 0)
        .toList();
    final currentNumber = _activeEpisode;
    final isLastOfSeason =
        episodeNumbers.isNotEmpty &&
        currentNumber >= episodeNumbers.reduce((a, b) => a > b ? a : b);
    final isLastKnownEpisode =
        currentNumber >= 2000 ||
        (episodeNumbers.isEmpty && currentNumber >= 24);

    if (!isLastOfSeason && !isLastKnownEpisode) {
      _nextSeason = _activeSeason;
      _nextEpisode = currentNumber + 1;
      _hasNextEpisode = true;
      return;
    }

    // Season finished: advance to the next season episode 1 (series may continue).
    if (isLastOfSeason && !isLastKnownEpisode) {
      _nextSeason = _activeSeason + 1;
      _nextEpisode = 1;
      _hasNextEpisode = true;
    } else {
      _hasNextEpisode = false;
    }
  }

  Future<void> _playNextEpisode() async {
    if (!widget.isMovie &&
        _hasNextEpisode &&
        !_loadingNext &&
        !_disposed &&
        mounted) {
      _loadingNext = true;
      final targetSeason = _nextSeason;
      final targetEpisode = _nextEpisode;
      _showStatus('Auto-playing S${targetSeason}E$targetEpisode...');
      _controller?.removeListener(_handlePlaybackChanged);
      await _controller?.dispose();
      _controller = null;
      final generation = ++_operationGeneration;

      final id = int.tryParse(widget.tmdbId);
      Map<String, dynamic>? result;
      if (id != null) {
        final seasonEpisodes = await TmdbApiService.getSeasonEpisodes(
          id,
          targetSeason,
        );
        final episodeData = seasonEpisodes
            .where(
              (e) =>
                  ((e['episode_number'] as num?)?.toInt() ?? 0) ==
                  targetEpisode,
            )
            .firstOrNull;
        final episodeName = episodeData?['name']?.toString();
        _currentEpisodeName = episodeName ?? '';
        _episodeStillUrl = TmdbApiService.getImageUrl(
          episodeData?['still_path']?.toString() ?? '',
        );
        final seriesTitle = _currentTitle?.split(' - ').first ?? widget.title;
        _currentTitle = episodeName != null && episodeName.isNotEmpty
            ? '$seriesTitle - S$targetSeason'
                  'E$targetEpisode: $episodeName'
            : '$seriesTitle - S$targetSeason'
                  'E$targetEpisode';
      }
      result = await DirectM3u8Service.fetchSeriesStreamUrl(
        _currentTitle ?? widget.title,
        targetSeason,
        targetEpisode,
        widget.tmdbId,
      );
      if (result == null || result['url'] == null || !_isCurrent(generation)) {
        _loadingNext = false;
        if (mounted && _isCurrent(generation)) {
          setState(() {
            _error = 'Could not load the next episode. Please try again.';
            _isLoading = false;
          });
        }
        return;
      }
      final candidate = _StreamCandidate.fromMap(result);
      final initialized = await _initializePlayer(
        candidate,
        generation: generation,
resumePosition: Duration.zero,
      );
      if (!initialized || !_isCurrent(generation)) {
        _loadingNext = false;
        return;
      }
      setState(() {
        _nextSeason = targetSeason;
        _nextEpisode = targetEpisode;
        _activeSeason = targetSeason;
        _activeEpisode = targetEpisode;
        _completionHandled = false;
        _loadingNext = false;
      });
      if (id != null) {
        _seasonEpisodes = await TmdbApiService.getSeasonEpisodes(
          id,
          _nextSeason,
        );
        _resolveNextEpisode(id, _currentTitle ?? widget.title);
      }
      _loadDefaultSubtitle(candidate);
      _discoverAvailableServers(generation);
      _saveProgress();
    }
  }

  Future<bool> _initializePlayer(
    _StreamCandidate candidate, {
    required int generation,
    required Duration? resumePosition,
  }) async {
    if (!_isCurrent(generation)) return false;
    final url = candidate.url;
    final isHls = url.toLowerCase().contains('.m3u8');
    final previous = _controller;

    try {
      _showStatus('Loading video...');
      _initTimeout?.cancel();
      _initTimeout = Timer(const Duration(seconds: 20), () {
        if (_isLoading && mounted && _isCurrent(generation)) {
          _showStatus('Player is taking longer than expected. Please wait...');
        }
      });

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: candidate.headers,
        formatHint: isHls ? VideoFormat.hls : null,
        viewType: VideoViewType.platformView,
        videoPlayerOptions: VideoPlayerOptions(
          backBufferDurationMs: 15000,
          allowBackgroundPlayback: false,
        ),
      );

      await controller.initialize();
      if (!_isCurrent(generation)) {
        await controller.dispose();
        return false;
      }

      final target =
          resumePosition ??
          await WatchHistoryService.loadWatchPosition(
            widget.tmdbId,
            widget.isMovie,
            widget.season,
            widget.episode,
          );
      if (!_isCurrent(generation)) {
        await controller.dispose();
        return false;
      }
      if (target > Duration.zero) {
        await controller.seekTo(target);
        if (!_isCurrent(generation)) {
          await controller.dispose();
          return false;
        }
      }

      controller.addListener(_handlePlaybackChanged);
      await controller.play();
      if (!_isCurrent(generation)) {
        controller.removeListener(_handlePlaybackChanged);
        await controller.dispose();
        return false;
      }

      _initTimeout?.cancel();
      setState(() {
        _controller = controller;
        _currentStreamUrl = url;
        _currentCandidate = candidate;
        _selectedSource = candidate.source;
        _selectedServerUrl = url;
        _error = null;
        _statusMessage = '';
        _isBuffering = controller.value.isBuffering;
        _isLoading = false;
        _playbackRetryCount = 0;
        _rebufferCount = 0;
        _lastRebufferTime = null;
        _lastReportedPosition = Duration.zero;
        _isPlaying = controller.value.isPlaying;
        _wasBufferingAtLastCheck = controller.value.isBuffering;
      });

      previous?.removeListener(_handlePlaybackChanged);
      await previous?.dispose();
      _startProgressSaving();
      _showControlsAndFocus();
      return true;
    } catch (e) {
      debugPrint('TvVideoPlayer: Error initializing player: $e');
      if (_isCurrent(generation)) {
        setState(() {
          _error = 'Failed to play video: $e';
          _isLoading = false;
        });
        _focusAfterFrames(_retryNode);
      }
      return false;
    }
  }

  void _handlePlaybackChanged() {
    final controller = _controller;
    if (!mounted || _disposed || controller == null) return;
    final value = controller.value;
    if (value.position > Duration.zero) _lastStablePosition = value.position;
    if (value.duration > Duration.zero) _duration = value.duration;
    final wasBuffering = _isBuffering;
    final wasPlaying = _isPlaying;
    _isBuffering = value.isBuffering;
    _isPlaying = value.isPlaying;
    if (value.isPlaying) {
      _isLoading = false;
    }
    if (value.hasError && !_recoveringPlayback && _playbackRetryCount < 2) {
      unawaited(_recoverPlayback());
      _isBuffering = true;
    }
    final shouldRebuild = _isBuffering != wasBuffering || _isPlaying != wasPlaying || value.isInitialized;
    if (shouldRebuild && mounted) setState(() {});
  }

  void _onPositionTick() {
    final controller = _controller;
    if (_disposed || !mounted || controller == null) return;
    final value = controller.value;
    if (value.position > Duration.zero) {
      _position = value.position;
      _lastStablePosition = value.position;
    }
    if (value.duration > Duration.zero) _duration = value.duration;

    final newText = _findSubtitleText(value.position);
    if (_subtitleText.value != newText) {
      _subtitleText.value = newText;
    }

    final isBuffering = value.isBuffering;
    if (isBuffering && !_wasBufferingAtLastCheck) {
      _rebufferCount++;
      _lastRebufferTime = DateTime.now();
    }
    _wasBufferingAtLastCheck = isBuffering;

    final positionChanged = (_position - _lastReportedPosition).inSeconds >= 1;
    if (_showControls && positionChanged) {
      _lastReportedPosition = _position;
      if (mounted) setState(() {});
    }

    if (_isNearEnd(value) &&
        !_loadingNext &&
        !_isBuffering &&
        !_completionHandled) {
      unawaited(_completeCurrentItem());
    }
  }

  bool _isNearEnd(VideoPlayerValue value) {
    if (_duration <= Duration.zero) return false;
    final remainingMs = (_duration - value.position).inMilliseconds.clamp(
      0,
      3000,
    );
    if (remainingMs > 1500) return false;
    if (_rebufferCount > 0) {
      final lastRebuffer = _lastRebufferTime;
      if (lastRebuffer != null) {
        final elapsed = DateTime.now().difference(lastRebuffer).inSeconds;
        if (elapsed < 5) return false;
      }
    }
    return true;
  }

  Future<void> _completeCurrentItem() async {
    if (_completionHandled || _disposed) return;
    _completionHandled = true;
    await WatchHistoryService.markAsWatched(
      widget.tmdbId,
      widget.isMovie,
      _activeSeason,
      _activeEpisode,
    );
    if (!_disposed && mounted && !widget.isMovie) {
      await _playNextEpisode();
    }
  }

  Future<void> _recoverPlayback() async {
    if (_recoveringPlayback || _playbackRetryCount >= 2) return;
    final generation = _operationGeneration;
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
      if (!_isCurrent(generation)) return;
      final next = _nextServer();
      if (next != null) {
        _showStatus('Trying ${next.source}...');
        await _initializePlayer(
          next,
          generation: generation,
          resumePosition: _lastStablePosition,
        );
      } else if (_currentCandidate != null) {
        await _initializePlayer(
          _currentCandidate!,
          generation: generation,
          resumePosition: _lastStablePosition,
        );
      }
    } catch (error) {
      debugPrint('TvVideoPlayer: Playback recovery failed: $error');
      if (mounted && _playbackRetryCount >= 2) {
        setState(() {
          _error = 'The current server stopped responding. Please try again.';
        });
      }
    } finally {
      _recoveringPlayback = false;
    }
  }

  _StreamCandidate? _nextServer() {
    final currentUrl = _currentStreamUrl;
    if (_availableServers.length <= 1 || currentUrl == null) return null;
    final currentIndex = _availableServers.indexWhere(
      (s) => s.url == currentUrl,
    );
    final start =
        (currentIndex < 0 ? 0 : currentIndex + 1) % _availableServers.length;
    for (var i = 0; i < _availableServers.length; i++) {
      final candidate =
          _availableServers[(start + i) % _availableServers.length];
      if (candidate.url.isNotEmpty && candidate.url != currentUrl) {
        return candidate;
      }
    }
    return null;
  }

  Future<void> _discoverAvailableServers(int generation) async {
    if (!_isCurrent(generation)) return;
    setState(() => _serversLoading = true);

    try {
      final servers = await DirectM3u8Service.fetchAvailableStreams(
        title: _currentTitle ?? widget.title,
        tmdbId: widget.tmdbId,
        isMovie: widget.isMovie,
        season: widget.season,
        episode: widget.episode,
      );

      if (_isCurrent(generation)) {
        final merged = <_StreamCandidate>[
          ..._availableServers,
          ...servers.map(_StreamCandidate.fromMap),
        ];
        final seen = <String>{};
        setState(() {
          _availableServers = merged.where((server) {
            return server.url.isNotEmpty && seen.add(server.url);
          }).toList();
          _serversLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TvVideoPlayer: Server discovery error: $e');
      if (_isCurrent(generation)) setState(() => _serversLoading = false);
    }
  }

  Future<void> _switchServer(_StreamCandidate server) async {
    if (!mounted || _disposed || _switchingServer) return;
    final generation = ++_operationGeneration;
    final livePosition = _position;
    _saveProgress();
    setState(() {
      _switchingServer = true;
      _isLoading = true;
    });

    _showStatus('Switching to ${server.source}...');
    final initialized = await _initializePlayer(
      server,
      generation: generation,
      resumePosition: livePosition,
    );
    if (!_isCurrent(generation)) return;
    setState(() {
      _switchingServer = false;
      if (initialized) {
        _selectedSource = server.source;
        _selectedServerUrl = server.url;
        _qualities = server.qualities;
        _subtitleTracks = server.subtitles;
        _clearSubtitles();
      }
    });
  }

  Future<void> _switchQuality(_QualityOption quality) async {
    final candidate = _currentCandidate;
    if (candidate == null || _switchingServer) return;
    if (quality.url == _currentStreamUrl) return;
    final livePosition = _position;
    setState(() {
      _switchingServer = true;
      _isLoading = true;
    });
    _showStatus('Switching to ${quality.label}...');
    final generation = ++_operationGeneration;
    await _initializePlayer(
      _StreamCandidate(
        url: quality.url,
        source: candidate.source,
        headers: candidate.headers,
        route: candidate.route,
        qualities: candidate.qualities,
        subtitles: candidate.subtitles,
      ),
      generation: generation,
      resumePosition: livePosition,
    );
    if (!_isCurrent(generation)) return;
    setState(() {
      _switchingServer = false;
      _currentStreamUrl = quality.url;
      _selectedServerUrl = quality.url;
    });
    _showControlsAndFocus();
  }

  void _clearSubtitles() {
    _activeSubtitles = const [];
    _subtitleText.value = '';
    _selectedSubtitleLabel = 'Off';
  }

  Future<void> _loadDefaultSubtitle(_StreamCandidate candidate) async {
    _SubtitleTrack? def;
    for (final track in candidate.subtitles) {
      if (track.isDefault) {
        def = track;
        break;
      }
    }
    if (def == null && candidate.subtitles.isNotEmpty) {
      def = candidate.subtitles.first;
    }
    if (def == null) return;
    await _selectSubtitle(def);
  }

  Future<void> _selectSubtitle(_SubtitleTrack track) async {
    if (track.url.isEmpty) {
      _clearSubtitles();
      return;
    }
    try {
      final uri = Uri.parse(track.url);
      final headers = _currentCandidate?.headers ?? const <String, String>{};
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final cues = _parseSubtitleFile(response.body);
        if (cues.isEmpty) {
          _showStatus('Subtitle file was empty or could not be parsed');
          return;
        }
        final parsed = cues
            .map((c) => c.copyWith(text: _stripTags(c.text)))
            .toList();
        if (!mounted) return;
        setState(() {
          _activeSubtitles = parsed;
          _selectedSubtitleLabel = track.source.isNotEmpty
              ? '${track.source}/${track.label}'
              : track.label;
        });
      }
    } catch (e) {
      debugPrint('TvVideoPlayer: Subtitle fetch failed: $e');
      _showStatus('Failed to load subtitle');
    }
  }

  String _findSubtitleText(Duration position) {
    if (_activeSubtitles.isEmpty) return '';
    final base = position.inMilliseconds;
    for (final cue in _activeSubtitles) {
      if (base >= cue.start.inMilliseconds && base < cue.end.inMilliseconds) {
        return cue.text;
      }
    }
    return '';
  }

  String _stripTags(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(r'{\w[^}]*}', '')
        .trim();
  }

  List<_SubtitleCue> _parseSubtitleFile(String input) {
    var normalized = input.trim();
    if (normalized.isEmpty) return const [];
    if (normalized.startsWith('{')) {
      final parsed = _tryParseJson(
        jsonDecode(normalized) as Map<dynamic, dynamic>,
      );
      if (parsed != null && parsed.isNotEmpty) return parsed;
    }
    if (normalized.contains('WEBVTT')) return _parseVtt(normalized);
    if (normalized.contains('[Script Info]') ||
        normalized.contains('[Events]')) {
      return _parseAss(normalized);
    }
    return _parseSrt(normalized);
  }

  List<_SubtitleCue>? _tryParseJson(Map<dynamic, dynamic> json) {
    try {
      final cues = <_SubtitleCue>[];
      final body = json['body'] ?? json['cues'] ?? json['payload'] ?? json;
      final rawCues = (body is Map && body['cues'] is List)
          ? body['cues']
          : body;
      if (rawCues is List) {
        for (final item in rawCues) {
          if (item is! Map) continue;
          final start = _parseSubTime(item['from'] ?? item['start']);
          final end = _parseSubTime(item['to'] ?? item['end']);
          final text =
              (item['text'] ??
                      item['payload'] ??
                      item['content'] ??
                      item['value'])
                  ?.toString()
                  .trim();
          if (start != null && end != null && text != null && text.isNotEmpty) {
            cues.add(_SubtitleCue(start: start, end: end, text: text));
          }
        }
      }
      return cues;
    } catch (_) {
      return null;
    }
  }

  List<_SubtitleCue> _parseVtt(String input) {
    final cues = <_SubtitleCue>[];
    final blocks = input.split(RegExp(r'\n{2,}'));
    for (final block in blocks) {
      final lines = block.split('\n');
      String? timing;
      final textLines = <String>[];
      for (final line in lines) {
        if (line.contains('-->')) {
          timing = line;
        } else if (line.trim().isNotEmpty &&
            !line.trim().startsWith('WEBVTT') &&
            !line.trim().startsWith('NOTE') &&
            !line.trim().startsWith('STYLE')) {
          textLines.add(line);
        }
      }
      if (timing == null || textLines.isEmpty) continue;
      final times = timing.split('-->');
      final start = _parseSubTime(times[0]);
      final end = _parseSubTime(times[1].split(RegExp(r'\s')).first);
      if (start != null && end != null && end > start) {
        cues.add(
          _SubtitleCue(
            start: start,
            end: end,
            text: textLines.join('\n').trim(),
          ),
        );
      }
    }
    return cues;
  }

  List<_SubtitleCue> _parseSrt(String input) {
    final cues = <_SubtitleCue>[];
    final blocks = input.split(RegExp(r'\n{2,}'));
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      if (int.tryParse(lines[0].trim()) == null) continue;
      String? timing;
      var idx = 1;
      for (; idx < lines.length; idx++) {
        if (lines[idx].contains('-->')) {
          timing = lines[idx];
          break;
        }
      }
      if (timing == null) continue;
      final times = timing.split('-->');
      final start = _parseSubTime(times[0]);
      final end = _parseSubTime(times[1]);
      final text = lines.skip(idx + 1).join('\n').trim();
      if (start != null && end != null && end > start && text.isNotEmpty) {
        cues.add(_SubtitleCue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  List<_SubtitleCue> _parseAss(String input) {
    final cues = <_SubtitleCue>[];
    for (final line in input.split('\n')) {
      if (!line.startsWith('Dialogue:')) continue;
      final parts = _splitDialogue(line);
      if (parts.length < 3) continue;
      final start = _parseAssTime(parts[1]);
      final end = _parseAssTime(parts[2]);
      final text = parts.sublist(9).join(',').replaceAll(r'\N', '\n').trim();
      if (start != null && end != null && end > start && text.isNotEmpty) {
        cues.add(_SubtitleCue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  List<String> _splitDialogue(String line) {
    // Dialect is: Dialogue: Marked=0,0:00:00.00,0:00:05.00,Style,Name,...
    // Split only: keep commas after 9 fields.
    final body = line.substring('Dialogue:'.length).trim();
    final fields = body.split(',');
    // Rejoin any extra commas into the text field.
    if (fields.length > 9) {
      return fields.take(9).toList()..add(fields.skip(9).join(','));
    }
    return fields;
  }

  Duration? _parseAssTime(String raw) {
    final m = RegExp(r'(\d+):(\d+):(\d+)[.:](\d+)').firstMatch(raw.trim());
    if (m == null) return null;
    final h = int.tryParse(m.group(1)!);
    final min = int.tryParse(m.group(2)!);
    final sec = int.tryParse(m.group(3)!);
    final msRaw = m.group(4)!;
    final ms = msRaw.length == 2
        ? int.tryParse(msRaw) ?? 0
        : int.tryParse(msRaw);
    if (h == null || min == null || sec == null) return null;
    final centis = ms ?? 0;
    final val =
        Duration(hours: h, minutes: min, seconds: sec) +
        Duration(
          milliseconds: centis == 0
              ? 0
              : (msRaw.length == 2 ? centis * 10 : centis),
        );
    return val;
  }

  Duration? _parseSubTime(String raw) {
    final t = raw.trim();
    final m = RegExp(
      r'(?:(\d+):)?(\d{1,2}):(\d{2})[.,](\d{1,3})',
    ).firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1) ?? '0') ?? 0;
      final min = int.tryParse(m.group(2)!) ?? 0;
      final sec = int.tryParse(m.group(3)!) ?? 0;
      var ms = int.tryParse(m.group(4)!) ?? 0;
      if (m.group(4)!.length == 2) ms *= 10;
      return Duration(hours: h, minutes: min, seconds: sec, milliseconds: ms);
    }
    return null;
  }

  String get _formatTime {
    if (_controller == null) return '00:00';
    final d = (_position <= Duration.zero || !_hasDuration)
        ? Duration.zero
        : _position;
    final total = _duration;
    return '${_two(d.inHours)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}'
        ' / '
        '${_two(total.inHours)}:${_two(total.inMinutes % 60)}:${_two(total.inSeconds % 60)}';
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  void _showControlsAndFocus({_Pc target = _Pc.playPause}) {
    if (!mounted || _disposed) return;
    setState(() {
      _showControls = true;
      _isBuffering = false;
      _isLoading = false;
      _currentControl = target;
    });
    _resetHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed && _showControls) {
        _requestFocusFor(target);
      }
    });
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && !_disposed) {
        if (_hasFocusableMenu) {
          _resetHideTimer();
          return;
        }
        setState(() => _showControls = false);
        _clearFocusedBack();
      }
    });
  }

  void _clearFocusedBack() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _surfaceNode.requestFocus();
  }

  void _toggleControls() {
    if (_showControls) {
      setState(() => _showControls = false);
      _clearFocusedBack();
    } else {
      _showControlsAndFocus();
    }
  }

  KeyEventResult _onControlKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonA) {
        _activateControl(_currentControl);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowDown) {
        _moveFocus(key);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.gameButtonB) {
        if (_hasFocusableMenu) {
          _closeMenus();
        } else {
          _toggleControls();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onBaselineAmbitKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.gameButtonB ||
          key == LogicalKeyboardKey.goBack) {
        if (_hasFocusableMenu) {
          _closeMenus();
        } else if (_showControls) {
          setState(() => _showControls = false);
          _resetHideTimer();
        } else {
          _handleBackNavigation();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonA) {
        _toggleControls();
        return KeyEventResult.handled;
      }
      if (!_showControls &&
          (key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.arrowUp ||
              key == LogicalKeyboardKey.arrowDown)) {
        final target = switch (key) {
          LogicalKeyboardKey.arrowLeft => _Pc.rewind,
          LogicalKeyboardKey.arrowRight => _Pc.forward,
          LogicalKeyboardKey.arrowDown => _Pc.slider,
          _ => _Pc.playPause,
        };
        _showControlsAndFocus(target: target);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _moveFocus(LogicalKeyboardKey key) {
    var next = _currentControl;
    switch (_currentControl) {
      case _Pc.back:
        if (key == LogicalKeyboardKey.arrowDown) {
          next = _Pc.playPause;
        }
        break;
      case _Pc.playPause:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.rewind;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.forward;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.back;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          next = _Pc.slider;
        }
        break;
      case _Pc.rewind:
        if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.playPause;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.back;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          next = _Pc.slider;
        }
        break;
      case _Pc.forward:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.playPause;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.back;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          next = _Pc.slider;
        }
        break;
      case _Pc.subtitles:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.quality;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.quality:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.volume;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.subtitles;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.server:
        if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.volume;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.volume:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.server;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.quality;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.slider:
        if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.playPause;
        } else if (key == LogicalKeyboardKey.arrowDown) {
          next = _Pc.volume;
        }
        break;
    }

if (next != _currentControl) {
      _currentControl = next;
      _resetHideTimer();
      _requestFocusFor(next);
    }
  }

  void _requestFocusFor(_Pc pc) {
    if (!mounted) return;
    final node = _controlFocusNodes[pc];
    if (node != null) {
      node.requestFocus();
    }
  }

  void _activateControl(_Pc pc) {
    switch (pc) {
      case _Pc.back:
        _handleBackNavigation();
        break;
      case _Pc.playPause:
        _executePlayPause();
        break;
      case _Pc.rewind:
        _seekBy(-10);
        break;
      case _Pc.forward:
        _seekBy(10);
        break;
      case _Pc.subtitles:
        _openSubtitleMenu();
        break;
      case _Pc.quality:
        _openQualityMenu();
        break;
      case _Pc.server:
        _openServerMenu();
        break;
      case _Pc.volume:
        _stepVolume();
        break;
      case _Pc.slider:
        break;
    }
  }

  void _stepVolume() {
    final player = _controller;
    if (player == null) return;
    final current = player.value.volume;
    final next = current >= 1.0 ? 0.0 : 1.0;
    player.setVolume(next);
    _showStatus(next >= 1.0 ? 'Unmuted' : 'Muted');
    _resetHideTimer();
  }

  void _seekBy(int seconds) {
    final controller = _controller;
    if (controller == null || !_hasDuration) return;
    var target = _position.inMilliseconds + seconds * 1000;
    final total = _duration.inMilliseconds;
    if (target < 0) target = 0;
    if (target > total) target = total;
    controller.seekTo(Duration(milliseconds: target));
    _showStatus(_formatClock(Duration(milliseconds: target)));
    _resetHideTimer();
  }

  String _formatClock(Duration d) {
    final h = d.inHours;
    if (h > 0) {
      return '${_two(h)}:${_two(d.inMinutes % 60)}:${_two(d.inSeconds % 60)}';
    }
    return '${_two(d.inMinutes)}:${_two(d.inSeconds % 60)}';
  }

  void _executePlayPause() {
    final controller = _controller;
    if (controller == null || _disposed || !mounted) return;
    final isCurrentlyPlaying = controller.value.isPlaying;
    if (isCurrentlyPlaying) {
      controller.pause();
      _showStatus('Paused');
    } else if (!isCurrentlyPlaying && !controller.value.isBuffering) {
      _unpauseWithWake();
      _showStatus('Playing');
    }
    _resetHideTimer();
  }

  void _openSubtitleMenu() {
    if (!mounted) return;
    setState(() {
      _subtitleMenuOpen = true;
      _currentControl = _Pc.subtitles;
    });
  }

  void _openQualityMenu() {
    if (!mounted) return;
    setState(() {
      _qualityMenuOpen = true;
      _currentControl = _Pc.quality;
    });
  }

  void _openServerMenu() {
    if (!mounted) return;
    setState(() {
      _serverMenuOpen = true;
      _currentControl = _Pc.server;
    });
  }

  void _closeMenus() {
    if (!mounted) return;
    setState(() {
      _subtitleMenuOpen = false;
      _qualityMenuOpen = false;
      _serverMenuOpen = false;
    });
  }

  void _selectMenuOption(String menu, Object? option) {
    switch (menu) {
      case 'subtitle':
        if (option is _SubtitleTrack) {
          _selectSubtitle(option);
        } else {
          _clearSubtitles();
        }
        break;
      case 'quality':
        if (option is _QualityOption) _switchQuality(option);
        break;
      case 'server':
        if (option is _StreamCandidate) _switchServer(option);
        break;
    }
    _closeMenus();
  }

  Widget _buildSubtitleWidget() {
    final alert = _subtitleText.value;
    if (_currentControl != _Pc.back && alert.isNotEmpty) {
      return SafeArea(
        child: IgnorePointer(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 90),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                alert,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.3,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusWidget() {
    if (_statusMessage.isEmpty) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: 90,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _statusMessage,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final message = _error ?? 'Something went wrong';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.redAccent[200]),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
              ),
              onPressed: () {
                if (Navigator.of(context).canPop()) Navigator.of(context).pop();
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text('Back', style: TextStyle(fontSize: 20)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          SizedBox(height: 24),
          Text('Loading stream...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    if (!_showControls) return const SizedBox.shrink();
    final isPlaying = _isPlaying || (_controller?.value.isPlaying ?? false);

    final backButton = _controlButton(
      _Pc.back,
      Icons.arrow_back,
      'Back',
      onPress: _handleBackNavigation,
    );

    final playPauseButton = _controlButton(
      _Pc.playPause,
      isPlaying ? Icons.pause : Icons.play_arrow,
      isPlaying ? 'Pause' : 'Play',
      onPress: _executePlayPause,
    );

    final rewindButton = _controlButton(
      _Pc.rewind,
      Icons.replay_10,
      'Back 10s',
      onPress: () => _seekBy(-10),
    );

    final forwardButton = _controlButton(
      _Pc.forward,
      Icons.forward_10,
      'Forward 10s',
      onPress: () => _seekBy(10),
    );

    final subtitlesButton = _controlButton(
      _Pc.subtitles,
      Icons.subtitles,
      'Subtitles',
      label: _selectedSubtitleLabel == 'Default'
          ? 'Off'
          : _selectedSubtitleLabel,
      onPress: _openSubtitleMenu,
    );

    final qualityButton = _controlButton(
      _Pc.quality,
      Icons.high_quality,
      'Quality',
      label: _selectedQualityLabel,
      onPress: _openQualityMenu,
    );

    final serverButton = _controlButton(
      _Pc.server,
      Icons.dns,
      'Server',
      label: _selectedSource,
      onPress: _openServerMenu,
    );

    final volumeButton = _controlButton(
      _Pc.volume,
      (_controller?.value.volume ?? 1) == 0
          ? Icons.volume_off
          : Icons.volume_up,
      'Volume',
      onPress: _stepVolume,
    );

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xB8000000),
                Colors.transparent,
                Color(0xE6000000),
              ],
              stops: [0, .42, 1],
            ),
          ),
          child: Focus(
            onKeyEvent: _onBaselineAmbitKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: 22,
                  left: 28,
                  right: 28,
                  child: Row(
                    children: [
                      backButton,
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          _currentTitle ?? widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 174,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      rewindButton,
                      const SizedBox(width: 14),
                      playPauseButton,
                      const SizedBox(width: 14),
                      forwardButton,
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      _buildProgressBar(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          serverButton,
                          const SizedBox(width: 18),
                          volumeButton,
                          const SizedBox(width: 18),
                          qualityButton,
                          const SizedBox(width: 18),
                          subtitlesButton,
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    final value = !_hasDuration || _duration == Duration.zero
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    return Focus(
      focusNode: _controlFocusNodes[_Pc.slider],
      onFocusChange: (focused) {
        if (!focused || !mounted) return;
        setState(() => _currentControl = _Pc.slider);
        _resetHideTimer();
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.arrowLeft) {
            _seekBy(-10);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowRight) {
            _seekBy(10);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowUp) {
            _currentControl = _Pc.playPause;
            _resetHideTimer();
            _requestFocusFor(_Pc.playPause);
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.gameButtonB) {
            _toggleControls();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 44),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE50914),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: Text(
                _formatTime,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(
    _Pc pc,
    IconData icon,
    String title, {
    VoidCallback? onPress,
    String? label,
  }) {
    final node = _controlFocusNodes[pc];
    final isFocused = node?.hasFocus ?? false;
    return GestureDetector(
      onTap: onPress ?? () {},
      child: Focus(
        focusNode: node,
        onKeyEvent: _onControlKey,
        onFocusChange: (focused) {
          if (!focused || !mounted) return;
          setState(() => _currentControl = pc);
          _resetHideTimer();
        },
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isFocused
                ? const Color(0xFFE50914)
                : const Color.fromARGB(150, 30, 30, 30),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isFocused ? Colors.redAccent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isFocused ? Colors.white : Colors.white70,
              ),
              const SizedBox(height: 3),
              Text(
                title,
                style: TextStyle(
                  color: isFocused ? Colors.white : Colors.white70,
                  fontSize: 10,
                ),
              ),
              if (label != null && label.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSheet(String title, List<Widget> items) {
    return Positioned(
      top: 110,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 560,
          constraints: const BoxConstraints(maxHeight: 640),
          decoration: BoxDecoration(
            color: const Color(0xF2181818),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [for (final item in items) item],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuRow(
    String label,
    VoidCallback onSelect, {
    bool selected = false,
  }) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event.runtimeType == KeyDownEvent && keyIsEnter(event)) {
          _closeMenus();
          _currentControl = (label == 'Subtitles')
              ? _Pc.subtitles
              : (label == 'Quality' ? _Pc.quality : _Pc.server);
          onSelect();
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        key: Key('menu-option-$label'),
        onTap: onSelect,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          color: selected ? const Color(0xFFE50914) : Colors.transparent,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  bool keyIsEnter(KeyEvent event) {
    final key = event.logicalKey;
    return key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA;
  }

  void _unpauseWithWake() {
    if (_disposed || !mounted) return;
    final controller = _controller;
    if (controller == null) return;
    if (!controller.value.isPlaying && !controller.value.isBuffering) {
      controller.play();
      _isPlaying = true;
      _isLoading = false;
    }
  }

  void _handleBackNavigation() {
    _saveProgress();
    if (mounted && !_disposed) {
      context.read<TvNavigationProvider>().setDeepNavigating(false);
    }
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _focusAfterFrames(FocusNode node) {
    if (_disposed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted) node.requestFocus();
    });
  }

  void _startProgressSaving() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _saveProgress(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop && !_disposed) {
          context.read<TvNavigationProvider>().setDeepNavigating(false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Focus(
          focusNode: _surfaceNode,
          canRequestFocus: true,
          onKeyEvent: _onBaselineAmbitKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null)
                Positioned.fill(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio == 0
                          ? 16 / 9
                          : _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              if (_isLoading && _error == null) _buildLoadingWidget(),
              if (_isBuffering && _error == null && !_showControls)
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              if (_error != null) _buildErrorWidget(),
              if (_showControls) _buildControlsOverlay(),
              if (_showControls) _buildMenuSheets(),
              _buildSubtitleWidget(),
              if (_statusMessage.isNotEmpty && _showControls)
                _buildStatusWidget(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSheets() {
    final sheets = <Widget>[];
    if (_subtitleMenuOpen) {
      sheets.add(_buildMenuSheet('Subtitles', _buildSubtitleMenuItems()));
    }
    if (_qualityMenuOpen) {
      sheets.add(_buildMenuSheet('Quality', _buildQualityMenuItems()));
    }
    if (_serverMenuOpen) {
      sheets.add(_buildMenuSheet('Server', _buildServerMenuItems()));
    }
    if (sheets.isEmpty) return const SizedBox.shrink();
    return Stack(children: sheets);
  }

  List<Widget> _buildSubtitleMenuItems() {
    final items = <Widget>[
      _menuRow(
        'Off',
        () => _selectMenuOption('subtitle', null),
        selected: _activeSubtitles.isEmpty,
      ),
      for (final track in _subtitleTracks)
        _menuRow(
          track.source.isNotEmpty
              ? '${track.source}/${track.label}'
              : track.label,
          () => _selectMenuOption('subtitle', track),
          selected:
              _activeSubtitles.isNotEmpty &&
                  track.label == _selectedSubtitleLabel ||
              (track.label == _selectedSubtitleLabel &&
                  _activeSubtitles.isNotEmpty),
        ),
    ];
    return items;
  }

  List<Widget> _buildQualityMenuItems() {
    final allQuality = <_QualityOption>[
      const _QualityOption(label: 'Auto', url: ''),
      ..._qualities,
    ];
    final seen = <String>{};
    return [
      for (final q in allQuality)
        if (seen.add(q.label))
          _menuRow(
            q.label,
            () => q.url.isEmpty ? (null) : _selectMenuOption('quality', q),
            selected: _selectedQualityLabel == q.label,
          ),
    ];
  }

  List<Widget> _buildServerMenuItems() {
    return [
      if (_serversLoading)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: Colors.redAccent),
            ),
          ),
        ),
      for (final server in _availableServers)
        _menuRow(
          server.source,
          () => _selectMenuOption('server', server),
          selected: server.url == _selectedServerUrl || streamEquals(server),
        ),
    ];
  }

  bool streamEquals(_StreamCandidate server) {
    final selected = _availableServers
        .where((s) => s.url == _selectedServerUrl)
        .firstOrNull;
    return selected?.source == server.source &&
        server.url == _selectedServerUrl;
  }
}
