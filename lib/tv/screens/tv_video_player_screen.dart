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
import '../../services/volume_boost_service.dart';
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

class _MenuOption {
  const _MenuOption({
    required this.label,
    required this.onSelect,
    this.selected = false,
  });

  final String label;
  final VoidCallback onSelect;
  final bool selected;
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
  boost(4, 1),
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
  double _boostDb = 0;

  String get _boostLabel =>
      _boostDb == 0 ? 'Off' : '+${_boostDb.round()} dB';

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
  final Set<String> _failedServerUrls = {};
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

  bool _menuJustClosed = false;
  Timer? _popGuardTimer;

  _Pc? _activeMenu;
  int _focusedMenuIndex = 0;
  final FocusNode _menuHeaderNode = FocusNode(debugLabel: 'player menu header');
  final List<FocusNode> _menuOptionNodes = [];
  FocusNode _menuOptionNode(int index) => _menuOptionNodes[index];
  void _rebuildMenuOptionNodes(int count) {
    if (count < _menuOptionNodes.length) {
      for (var i = count; i < _menuOptionNodes.length; i++) {
        _menuOptionNodes[i].dispose();
      }
      _menuOptionNodes.removeRange(count, _menuOptionNodes.length);
    } else if (count > _menuOptionNodes.length) {
      for (var i = _menuOptionNodes.length; i < count; i++) {
        _menuOptionNodes.add(FocusNode(debugLabel: 'player menu option $i'));
      }
    }
  }

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

  bool get _hasFocusableMenu => _activeMenu != null;

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

    _initVolumeBoost();
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
    _popGuardTimer?.cancel();
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
      _menuHeaderNode,
      ..._controlFocusNodes.values,
      ..._menuOptionNodes,
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
      try {
        _controller?.pause();
      } catch (e, st) {
        debugPrint('TvVideoPlayer: lifecycle pause failed: $e\n$st');
      }
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

  /// Restores the persisted volume boost and applies it to the native player.
  /// The gain processor reads the level per audio buffer, so playback that is
  /// already starting picks it up immediately.
  Future<void> _initVolumeBoost() async {
    final saved = await VolumeBoostService.loadPersistedGainDb();
    if (!mounted) return;
    setState(() => _boostDb = saved);
    await VolumeBoostService.setGainDb(saved);
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
          _seriesTitle.isNotEmpty ? _seriesTitle : (_currentTitle ?? widget.title),
          widget.season < 1 ? 1 : widget.season,
          widget.episode < 1 ? 1 : widget.episode,
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
        var initialized = await _initializePlayer(
          candidate,
          generation: generation,
resumePosition: null,
        );
        if (!_isCurrent(generation)) return;
        if (!initialized) {
          // The primary stream was resolved but ExoPlayer rejected it
          // (e.g. a dead HLS playlist). Fall back to the remaining servers so
          // a single bad server never blocks playback with a source error.
          await _discoverAvailableServers(generation);
          if (!_isCurrent(generation)) return;
          for (final alt in _availableServers) {
            if (alt.url == candidate.url) continue;
            initialized = await _initializePlayer(
              alt,
              generation: generation,
resumePosition: null,
            );
            if (initialized || !_isCurrent(generation)) break;
          }
        }
        if (!initialized) return;
        _loadDefaultSubtitle(_currentCandidate ?? candidate);
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
        _seriesTitle.isNotEmpty ? _seriesTitle : (_currentTitle ?? widget.title),
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
          backBufferDurationMs: 3000,
          allowBackgroundPlayback: false,
        ),
      );

      try {
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
      } catch (e) {
        // Never leak the native player: a failed start (e.g. a dead HLS
        // playlist) would otherwise leave an ExoPlayer + MediaCodec + audio
        // sink behind, and the server-switch/recovery loops repeat this many
        // times, exhausting memory and MediaCodec slots on TV boxes.
        try {
          await controller.dispose();
        } catch (_) {}
        rethrow;
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
        _failedServerUrls.clear();
        _rebufferCount = 0;
        _lastRebufferTime = null;
        _lastReportedPosition = Duration.zero;
        _isPlaying = controller.value.isPlaying;
        _wasBufferingAtLastCheck = controller.value.isBuffering;
      });

      previous?.removeListener(_handlePlaybackChanged);
      try {
        await previous?.dispose();
      } catch (e, st) {
        debugPrint('TvVideoPlayer: disposing previous player failed: $e\n$st');
      }
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
    if (value.hasError && !_recoveringPlayback) {
      // Keep switching to other servers so a single dead source (e.g. an
      // expired RPM HLS URL) never blocks playback. Recovery re-resolves
      // streams fresh, so allow a few rounds even without a known next server.
      final hasNext = _nextServer() != null;
      if (_playbackRetryCount < 3 || hasNext) {
        unawaited(_recoverPlayback());
        _isBuffering = true;
      }
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
    if (_recoveringPlayback) return;
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

      // Tear down the failed player's platform view BEFORE creating the next
      // one. Overlapping a fresh SurfaceView with the old one's teardown (and
      // the old ExoPlayer's release) crashes the fragile compositor on some TV
      // boxes; mobile uses the texture path so it never hits this. Serialize
      // the lifecycle so a new view is only ever created once the old one is
      // fully gone.
      if (_controller != null) {
        final stale = _controller;
        _controller?.removeListener(_handlePlaybackChanged);
        setState(() {
          _controller = null;
          _isBuffering = true;
          _statusMessage = 'Recovering playback...';
        });
        try {
          await stale?.dispose();
        } catch (e, st) {
          debugPrint('TvVideoPlayer: dispose during recovery failed: $e\n$st');
        }
      }

      // Re-resolve streams fresh: discovered URLs (esp. VixSrc tokens) expire
      // quickly, so fall back to freshly extracted servers instead of stale
      // entries that ExoPlayer rejects with a source error.
      await _discoverAvailableServers(generation);
      if (!_isCurrent(generation)) return;
      final failedUrl = _currentStreamUrl;
      if (failedUrl != null) _failedServerUrls.add(failedUrl);
      var next = _nextServer();
      var initialized = false;
      final tried = <String>{};
      while (next != null && _isCurrent(generation) && !initialized) {
        if (!tried.add(next.url)) break;
        _showStatus('Trying ${next.source}...');
        initialized = await _initializePlayer(
          next,
          generation: generation,
          resumePosition: _lastStablePosition,
        );
        if (initialized || !_isCurrent(generation)) break;
        _failedServerUrls.add(next.url);
        next = _nextServer();
        if (next != null) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      if (!initialized && _currentCandidate != null) {
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
      if (candidate.url.isNotEmpty &&
          candidate.url != currentUrl &&
          !_failedServerUrls.contains(candidate.url)) {
        return candidate;
      }
    }
    return null;
  }

  _StreamCandidate? _nextServerAfter(String url) {
    if (_availableServers.length <= 1) return null;
    final index = _availableServers.indexWhere((s) => s.url == url);
    final start = (index < 0 ? 0 : index + 1) % _availableServers.length;
    for (var i = 0; i < _availableServers.length; i++) {
      final candidate =
          _availableServers[(start + i) % _availableServers.length];
      if (candidate.url.isNotEmpty &&
          candidate.url != url &&
          !_failedServerUrls.contains(candidate.url)) {
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
        title: _seriesTitle.isNotEmpty
            ? _seriesTitle
            : (_currentTitle ?? widget.title),
        tmdbId: widget.tmdbId,
        isMovie: widget.isMovie,
        season: widget.isMovie ? widget.season : _activeSeason,
        episode: widget.isMovie ? widget.episode : _activeEpisode,
      );

      if (_isCurrent(generation)) {
        // Replace stale entries with freshly extracted URLs: stream URLs
        // (esp. VixSrc tokens) expire quickly, so reusing them when switching
        // servers or recovering causes a "Source error". Keep the currently
        // playing server around so the menu stays consistent.
        final playingUrl = _currentStreamUrl;
        final playing = _currentCandidate;
        final seen = <String>{};
        final fresh = servers
            .map(_StreamCandidate.fromMap)
            .where((server) => server.url.isNotEmpty && seen.add(server.url))
            .toList();
        setState(() {
          _availableServers = [
            if (playing != null &&
                !fresh.any((server) => server.url == playingUrl))
              playing,
            ...fresh.where(
              (server) => playing == null || server.url != playing.url,
            ),
          ];
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
    final previousSource = _selectedSource;
    final previousUrl = _selectedServerUrl;
    final previousQualities = _qualities;
    final previousSubtitles = _subtitleTracks;
    _saveProgress();
    setState(() {
      _switchingServer = true;
      _isLoading = true;
    });

    // Re-resolve streams fresh before switching: the server list may hold
    // expired URLs (e.g. short-lived VixSrc tokens) that ExoPlayer rejects.
    await _discoverAvailableServers(generation);
    if (!_isCurrent(generation)) return;

    final freshTarget = _availableServers
        .where((s) => s.source == server.source)
        .firstOrNull;
    var current = freshTarget ?? server;
    var initialized = false;
    final tried = <String>{};
    while (_isCurrent(generation) && !initialized) {
      if (!tried.add(current.url)) break;
      _showStatus('Switching to ${current.source}...');
      initialized = await _initializePlayer(
        current,
        generation: generation,
        resumePosition: livePosition,
      );
      if (initialized || !_isCurrent(generation)) break;
      _failedServerUrls.add(current.url);
      final next = _nextServerAfter(current.url);
      if (next == null) break;
      current = next;
    }

    if (!_isCurrent(generation)) return;
    setState(() {
      _switchingServer = false;
      if (initialized) {
        _selectedSource = current.source;
        _selectedServerUrl = current.url;
        _qualities = current.qualities;
        _subtitleTracks = current.subtitles;
        _clearSubtitles();
      } else {
        // No server could start: keep the previously working stream instead of
        // leaving the player stuck on a source error.
        _selectedSource = previousSource;
        _selectedServerUrl = previousUrl;
        _qualities = previousQualities;
        _subtitleTracks = previousSubtitles;
        _error = null;
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
      final cues = await _fetchSubtitles(track);
      if (!mounted) return;
      if (cues.isEmpty) {
        _showStatus('Subtitle file was empty or could not be parsed');
        return;
      }
      final parsed = cues
          .map((c) => c.copyWith(text: _stripTags(c.text)))
          .toList();
      setState(() {
        _activeSubtitles = parsed;
        _selectedSubtitleLabel = track.source.isNotEmpty
            ? '${track.source}/${track.label}'
            : track.label;
      });
    } catch (e) {
      debugPrint('TvVideoPlayer: Subtitle fetch failed: $e');
      if (!mounted) return;
      final msg = e.toString().contains('404')
          ? 'Subtitle not found on server (404). Try another track.'
          : e.toString().contains('401')
          ? 'Subtitle requires authentication. Try another track.'
          : 'Failed to load subtitles: $e';
      _showStatus(msg);
    }
  }

  Future<List<_SubtitleCue>> _fetchSubtitles(_SubtitleTrack track) async {
    final uri = Uri.parse(track.url);
    if (uri.host.isEmpty) {
      final streamUrl = _currentStreamUrl;
      final base = (streamUrl == null || streamUrl.isEmpty)
          ? null
          : Uri.tryParse(streamUrl);
      if (base != null && base.host.isNotEmpty) {
        final resolved = base.resolveUri(uri);
        if (resolved.host.isNotEmpty) {
          return _fetchSubtitles(
            _SubtitleTrack(
              label: track.label,
              url: resolved.toString(),
              source: track.source,
              isDefault: track.isDefault,
            ),
          );
        }
      }
      throw Exception('Invalid subtitle URL: ${track.url}');
    }
    final inheritedHeaders = _currentCandidate?.headers ?? const <String, String>{};
    final headers = <String, String>{
      if (track.source != 'Vidflix') ...inheritedHeaders,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      'Accept': 'text/vtt, application/x-subrip, text/plain, */*',
    };
    final urlsToTry = <String>[track.url];
    final noFragment = track.url.split('#')[0];
    if (noFragment != track.url) urlsToTry.add(noFragment);
    Exception? lastError;
    for (final url in urlsToTry) {
      try {
        final response = await http
            .get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final body = utf8.decode(response.bodyBytes, allowMalformed: true);
          if (body.trim().isNotEmpty) {
            final cues = _parseSubtitleFile(body);
            if (cues.isNotEmpty) return cues;
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

  String _decodeHtmlEntities(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  List<_SubtitleCue> _parseSubtitleFile(String input) {
    final normalized = input
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final upper = normalized.trimLeft().toUpperCase();

    if (upper.startsWith('WEBVTT')) return _parseVtt(normalized);
    if (upper.startsWith('{') || upper.startsWith('[')) {
      final json = _tryParseJson(normalized);
      if (json != null && json.isNotEmpty) return json;
    }
    if (normalized.contains('[Script Info]') || normalized.contains('[Events]')) {
      return _parseAss(normalized);
    }
    if (normalized.contains('<tt') ||
        normalized.contains('<p ') ||
        normalized.contains('<p>')) {
      final ttml = _parseTtml(normalized);
      if (ttml.isNotEmpty) return ttml;
    }
    final srt = _parseSrt(normalized);
    if (srt.isNotEmpty) return srt;
    if (normalized.contains('<') && normalized.contains('begin=')) {
      return _parseTtml(normalized);
    }
    return srt;
  }

  List<_SubtitleCue>? _tryParseJson(String input) {
    try {
      final decoded = jsonDecode(input);
      final dynamic rawCues = decoded is List
          ? decoded
          : decoded is Map
          ? decoded['cues'] ??
                decoded['subtitles'] ??
                decoded['data'] ??
                decoded['body'] ??
                decoded['payload'] ??
                decoded
          : null;
      if (rawCues is! List) return const [];
      final cues = <_SubtitleCue>[];
      for (final item in rawCues.whereType<Map>()) {
        final start = _parseJsonCueTime(
          item['startTime'] ?? item['start'] ?? item['from'],
        );
        final end = _parseJsonCueTime(
          item['endTime'] ?? item['end'] ?? item['to'],
        );
        final rawText =
            item['text'] ?? item['payload'] ?? item['content'] ?? item['value'];
        final text = rawText is List
            ? rawText.join('\n')
            : rawText?.toString() ?? '';
        final cleaned = _decodeHtmlEntities(text).trim();
        if (start != null && end != null && end > start && cleaned.isNotEmpty) {
          cues.add(_SubtitleCue(start: start, end: end, text: cleaned));
        }
      }
      return cues;
    } catch (_) {
      return null;
    }
  }

  Duration? _parseJsonCueTime(dynamic value) {
    if (value is num) {
      return Duration(milliseconds: (value.toDouble() * 1000).round());
    }
    if (value is! String) return null;
    final timestamp = _parseSubTime(value);
    if (timestamp != null) return timestamp;
    final seconds = double.tryParse(value);
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
  }

  List<_SubtitleCue> _parseVtt(String input) {
    final lines = input.split('\n');
    final cues = <_SubtitleCue>[];
    var i = 0;
    if (lines.isNotEmpty && lines[0].trim().toUpperCase().startsWith('WEBVTT')) {
      i = 1;
    }
    while (i < lines.length) {
      final line = lines[i].trim();
      if (line.isEmpty || line.toUpperCase().startsWith('NOTE')) {
        if (line.toUpperCase().startsWith('NOTE')) {
          while (i < lines.length && lines[i].trim().isNotEmpty) {
            i++;
          }
        }
        i++;
        continue;
      }
      if (!line.contains('-->')) {
        i++;
        continue;
      }
      final timing = line.split('-->');
      if (timing.length != 2) {
        i++;
        continue;
      }
      final start = _parseSubTime(timing[0]);
      final end = _parseSubTime(timing[1].trim().split(RegExp(r'\s+')).first);
      if (start == null || end == null) {
        i++;
        continue;
      }
      i++;
      final textLines = <String>[];
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (lines[i].trim().contains('-->')) break;
        textLines.add(lines[i].trim());
        i++;
      }
      final text = _decodeHtmlEntities(textLines.join('\n')).trim();
      if (text.isNotEmpty && end > start) {
        cues.add(_SubtitleCue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  List<_SubtitleCue> _parseSrt(String input) {
    final blocks = input.split(RegExp(r'\n\s*\n'));
    final cues = <_SubtitleCue>[];
    for (final block in blocks) {
      final lines = block.trim().split('\n');
      if (lines.length < 2) continue;
      var idx = 0;
      if (int.tryParse(lines[0].trim()) != null) idx = 1;
      String? timing;
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
      final text = _decodeHtmlEntities(lines.skip(idx + 1).join('\n')).trim();
      if (start != null && end != null && end > start && text.isNotEmpty) {
        cues.add(_SubtitleCue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  List<_SubtitleCue> _parseTtml(String input) {
    final cues = <_SubtitleCue>[];
    final pTag = RegExp(
      r'<p\b[^>]*begin="([^"]+)"[^>]*end="([^"]+)"[^>]*>(.*?)</p>',
      dotAll: true,
    );
    for (final match in pTag.allMatches(input)) {
      final start = _parseTtmlTime(match.group(1)!);
      final end = _parseTtmlTime(match.group(2)!);
      final text = _decodeHtmlEntities(_stripTags(match.group(3)!)).trim();
      if (start != null && end != null && end > start && text.isNotEmpty) {
        cues.add(_SubtitleCue(start: start, end: end, text: text));
      }
    }
    return cues;
  }

  Duration? _parseTtmlTime(String raw) {
    final t = raw.trim();
    final m = RegExp(r'(?:(\d+):)?(\d+):(\d+)[.,](\d+)').firstMatch(t);
    if (m != null) {
      final h = int.tryParse(m.group(1) ?? '0') ?? 0;
      final min = int.tryParse(m.group(2)!) ?? 0;
      final sec = int.tryParse(m.group(3)!) ?? 0;
      final frac = m.group(4)!;
      var ms = int.tryParse(frac) ?? 0;
      if (frac.length == 2) {
        ms *= 10;
      } else if (frac.length == 1) {
        ms *= 100;
      }
      return Duration(hours: h, minutes: min, seconds: sec, milliseconds: ms);
    }
    final seconds = double.tryParse(t);
    return seconds == null
        ? null
        : Duration(milliseconds: (seconds * 1000).round());
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
          key == LogicalKeyboardKey.goBack ||
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
          next = _Pc.boost;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.subtitles;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.server:
        if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.boost;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.boost:
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
          next = _Pc.boost;
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
        _openMenu(_Pc.subtitles);
        break;
      case _Pc.quality:
        _openMenu(_Pc.quality);
        break;
      case _Pc.server:
        _openMenu(_Pc.server);
        break;
      case _Pc.boost:
        unawaited(_cycleBoost());
        break;
      case _Pc.slider:
        break;
    }
  }

  Future<void> _cycleBoost() async {
    final levels = VolumeBoostService.levels;
    final currentIndex = levels.indexOf(_boostDb);
    final nextIndex = (currentIndex < 0 ? -1 : currentIndex) + 1;
    final next = levels[nextIndex % levels.length];
    setState(() => _boostDb = next);
    await VolumeBoostService.setGainDb(next);
    await VolumeBoostService.persistGainDb(next);
    _showStatus(next == 0 ? 'Volume boost off' : 'Volume boost +${next.round()} dB');
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
    try {
      if (isCurrentlyPlaying) {
        controller.pause();
        _showStatus('Paused');
      } else if (!isCurrentlyPlaying && !controller.value.isBuffering) {
        _unpauseWithWake();
        _showStatus('Playing');
      }
    } catch (e, st) {
      debugPrint('TvVideoPlayer: play/pause failed: $e\n$st');
    }
    _resetHideTimer();
  }

  void _openMenu(_Pc pc) {
    if (!mounted) return;
    final options = _buildMenuOptions(pc);
    _rebuildMenuOptionNodes(options.length);
    final selectedIndex = options.indexWhere((option) => option.selected);
    final focusIndex = selectedIndex < 0 ? 0 : selectedIndex;
    setState(() {
      _activeMenu = pc;
      _currentControl = pc;
      _focusedMenuIndex = focusIndex;
    });
    _resetHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeMenu != pc) return;
      _menuHeaderNode.requestFocus();
    });
  }

  KeyEventResult _onMenuHeaderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_menuOptionNodes.isNotEmpty) _focusMenuOption(_focusedMenuIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_menuOptionNodes.isNotEmpty) {
        _focusMenuOption(_menuOptionNodes.length - 1);
      }
      return KeyEventResult.handled;
    }
    if (keyIsEnter(event) ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      _closeMenus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _closeMenus({bool refocus = true}) {
    if (!mounted) return;
    final opener = _activeMenu;
    setState(() {
      _activeMenu = null;
      _focusedMenuIndex = 0;
    });
    _menuJustClosed = true;
    _popGuardTimer?.cancel();
    _popGuardTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && !_disposed) setState(() => _menuJustClosed = false);
    });
    _resetHideTimer();
    if (refocus && opener != null) {
      _requestFocusFor(opener);
    }
  }

  void _focusMenuOption(int index) {
    if (index < 0 || index >= _menuOptionNodes.length) return;
    setState(() => _focusedMenuIndex = index);
    _menuOptionNode(index).requestFocus();
    _resetHideTimer();
  }

  KeyEventResult _onMenuOptionKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        _focusMenuOption(index - 1);
      } else {
        _menuHeaderNode.requestFocus();
        _resetHideTimer();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (index + 1 < _menuOptionNodes.length) {
        _focusMenuOption(index + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      _closeMenus();
      return KeyEventResult.handled;
    }
    if (keyIsEnter(event)) {
      final options = _buildMenuOptions(_activeMenu ?? _Pc.server);
      if (index >= 0 && index < options.length) {
        _selectMenuOption(options[index]);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
      width: 112,
      height: 64,
      label: _selectedSubtitleLabel == 'Default'
          ? 'Off'
          : _selectedSubtitleLabel,
      onPress: () => _openMenu(_Pc.subtitles),
    );

    final qualityButton = _controlButton(
      _Pc.quality,
      Icons.high_quality,
      'Quality',
      width: 112,
      height: 64,
      label: _selectedQualityLabel,
      onPress: () => _openMenu(_Pc.quality),
    );

    final serverButton = _controlButton(
      _Pc.server,
      Icons.dns,
      'Server',
      width: 112,
      height: 64,
      label: _selectedSource,
      onPress: () => _openMenu(_Pc.server),
    );

    final boostButton = _controlButton(
      _Pc.boost,
      _boostDb == 0 ? Icons.volume_up : Icons.graphic_eq,
      'Boost',
      width: 112,
      height: 64,
      label: _boostLabel,
      onPress: _cycleBoost,
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const buttonWidth = 112.0;
                      const gap = 18.0;
                      const rowWidth = buttonWidth * 4 + gap * 3;
                      final startX = (constraints.maxWidth - rowWidth) / 2;
                      const menuIndex = <_Pc, int>{
                        _Pc.server: 0,
                        _Pc.boost: 1,
                        _Pc.quality: 2,
                        _Pc.subtitles: 3,
                      };
                      final openMenu = _activeMenu;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            children: [
                              _buildProgressBar(),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  serverButton,
                                  const SizedBox(width: gap),
                                  boostButton,
                                  const SizedBox(width: gap),
                                  qualityButton,
                                  const SizedBox(width: gap),
                                  subtitlesButton,
                                ],
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                          if (openMenu != null)
                            Positioned(
                              bottom: 88,
                              left: (startX +
                                          menuIndex[openMenu]! *
                                              (buttonWidth + gap) +
                                          buttonWidth / 2 -
                                          170)
                                  .clamp(
                                    8,
                                    constraints.maxWidth >= 356
                                        ? constraints.maxWidth - 348
                                        : 8,
                                  ),
                              child: _buildMenuPanel(openMenu),
                            ),
                        ],
                      );
                    },
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
    final focused = _controlFocusNodes[_Pc.slider]?.hasFocus ?? false;
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
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: focused ? Colors.white10 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? Colors.white70 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: LinearProgressIndicator(
                value: value,
                minHeight: focused ? 8 : 6,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFE50914),
                ),
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
    double width = 64,
    double height = 60,
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
          width: width,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            mainAxisAlignment: MainAxisAlignment.center,
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

  Widget _buildMenuPanel(_Pc pc) {
    final options = _buildMenuOptions(pc);
    if (_menuOptionNodes.length != options.length) {
      _rebuildMenuOptionNodes(options.length);
    }
    if (_focusedMenuIndex >= _menuOptionNodes.length) {
      _focusedMenuIndex = _menuOptionNodes.isEmpty
          ? 0
          : _menuOptionNodes.length - 1;
    }
    final title = switch (pc) {
      _Pc.server => 'Server',
      _Pc.quality => 'Quality',
      _Pc.subtitles => 'Subtitles',
      _ => '',
    };
    return Container(
      width: 340,
      constraints: const BoxConstraints(maxHeight: 440),
      decoration: BoxDecoration(
        color: const Color(0xF2181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            focusNode: _menuHeaderNode,
            onKeyEvent: _onMenuHeaderKey,
            child: InkWell(
              onTap: _closeMenus,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                decoration: BoxDecoration(
                  color: _menuHeaderNode.hasFocus
                      ? Colors.white12
                      : Colors.transparent,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _menuHeaderNode.hasFocus
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_up,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_menuHeaderNode.hasFocus)
                      const Icon(Icons.check, color: Colors.white70, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var i = 0; i < options.length; i++) _menuOption(i, pc),
              ],
            ),
          ),
          if (options.isEmpty || (pc == _Pc.server && _serversLoading))
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
        ],
      ),
    );
  }

  Widget _menuOption(int index, _Pc pc) {
    final options = _buildMenuOptions(pc);
    if (index >= options.length) return const SizedBox.shrink();
    final option = options[index];
    final node = _menuOptionNode(index);
    final isFocused = node.hasFocus || index == _focusedMenuIndex;
    return Focus(
      focusNode: node,
      onKeyEvent: (_, event) => _onMenuOptionKey(index, event),
      child: InkWell(
        key: Key('menu-option-$index'),
        onTap: option.onSelect,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: option.selected
              ? const Color(0xFFE50914)
              : (isFocused ? Colors.white12 : Colors.transparent),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: option.selected ? Colors.white : Colors.white70,
                    fontSize: 16,
                    fontWeight: option.selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              if (option.selected)
                const Icon(Icons.check, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  List<_MenuOption> _buildMenuOptions(_Pc pc) {
    switch (pc) {
      case _Pc.subtitles:
        return [
          _MenuOption(
            label: 'Off',
            onSelect: _clearSubtitles,
            selected: _activeSubtitles.isEmpty,
          ),
          for (final track in _subtitleTracks)
            _MenuOption(
              label: track.source.isNotEmpty
                  ? '${track.source}/${track.label}'
                  : track.label,
              onSelect: () => _selectSubtitle(track),
              selected: _activeSubtitles.isNotEmpty &&
                  track.label == _selectedSubtitleLabel,
            ),
        ];
      case _Pc.quality:
        final allQuality = <_QualityOption>[
          const _QualityOption(label: 'Auto', url: ''),
          ..._qualities,
        ];
        final seen = <String>{};
        return [
          for (final q in allQuality)
            if (seen.add(q.label))
              _MenuOption(
                label: q.label,
                onSelect: () {
                  if (q.url.isEmpty) return;
                  _switchQuality(q);
                },
                selected: _selectedQualityLabel == q.label,
              ),
        ];
      case _Pc.server:
        return [
          for (final server in _availableServers)
            _MenuOption(
              label: server.source,
              onSelect: () => _switchServer(server),
              selected: server.url == _selectedServerUrl ||
                  streamEquals(server),
            ),
        ];
      case _Pc.playPause:
      case _Pc.back:
      case _Pc.rewind:
      case _Pc.forward:
      case _Pc.boost:
      case _Pc.slider:
        return const [];
    }
  }

  void _selectMenuOption(_MenuOption option) {
    option.onSelect();
    _closeMenus();
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
      try {
        controller.play();
        _isPlaying = true;
        _isLoading = false;
      } catch (e, st) {
        debugPrint('TvVideoPlayer: resume failed: $e\n$st');
      }
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
      canPop: !_hasFocusableMenu && !_menuJustClosed,
      onPopInvoked: (didPop) {
        if (_hasFocusableMenu || _menuJustClosed) {
          _closeMenus();
        } else if (didPop && !_disposed) {
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
                      child: VideoPlayer(
                        _controller!,
                        key: ObjectKey(_controller),
                      ),
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
              _buildSubtitleWidget(),
              if (_statusMessage.isNotEmpty && _showControls)
                _buildStatusWidget(),
            ],
          ),
        ),
      ),
    );
  }

  bool streamEquals(_StreamCandidate server) {
    final selected = _availableServers
        .where((s) => s.url == _selectedServerUrl)
        .firstOrNull;
    return selected?.source == server.source &&
        server.url == _selectedServerUrl;
  }
}
