import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:video_player_android/video_player_android.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../providers/tv_navigation_provider.dart';
import '../../services/direct_m3u8_service.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';
import '../../widgets/crash_screen.dart';

class _QualityOption {
  const _QualityOption({
    required this.label,
    required this.url,
    this.height = 0,
    this.codec = '',
  });

  final String label;
  final String url;

  /// Variant height in pixels (0 for the synthetic "Auto" entry).
  final int height;

  /// Video codec family from the HLS master `CODECS` attribute: "h264",
  /// "hevc", "av1", "vp9" or "" when unknown (direct MP4, VidLink, etc.).
  final String codec;

  bool get isAvc => codec == 'h264';

  factory _QualityOption.fromMap(Map<String, dynamic> value) {
    return _QualityOption(
      label: value['label']?.toString() ?? 'Auto',
      url: value['url']?.toString() ?? '',
      height: (value['height'] as num?)?.toInt() ?? 0,
      codec: value['codec']?.toString() ?? '',
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

  /// Returns a copy of this candidate that pins ExoPlayer to a single,
  /// fixed-quality rendition instead of the multi-variant master playlist.
  ///
  /// The resolvers hand us the HLS master URL as the primary stream, which
  /// makes ExoPlayer run adaptive bitrate selection: it switches variants
  /// mid-playback, and each switch forces a decoder reconfiguration that
  /// crashes the fragile TV compositor/decoder path (same failure the
  /// software-decoder fallback in the vendored plugin targets). Pinning a
  /// single variant keeps one codec active for the whole play.
  ///
  /// When codec info is available (from the extractor's master CODECS parse),
  /// the highest *H.264/AVC* rendition is preferred over a taller HEVC/AV1
  /// stream, whose firmware hardware decoders are the box's main native-crash
  /// source. Streams without codec info fall back to the plain highest variant.
  _StreamCandidate pinnedToHighestQuality() {
    final available = <_QualityOption>[
      for (final q in qualities)
        if (q.url.isNotEmpty && q.height > 0) q,
    ];
    if (available.isEmpty) return this;
    final avc = [
      for (final q in available)
        if (q.isAvc) q,
    ];
    final pool = avc.isNotEmpty ? avc : available;
    var best = pool.first;
    for (final q in pool) {
      if (q.height > best.height) best = q;
    }
    if (best.url == url) return this;
    return _StreamCandidate(
      url: best.url,
      source: source,
      headers: headers,
      route: route,
      qualities: qualities,
      subtitles: subtitles,
    );
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

/// A single episode shown in the "Episodes" menu (series only).
class _EpisodeInfo {
  const _EpisodeInfo({
    required this.number,
    required this.name,
    this.stillUrl = '',
  });

  final int number;
  final String name;

  /// Episode still-frame thumbnail URL (may be empty when the source has none).
  final String stillUrl;
}

/// A season tab shown in the "Episodes" menu.
class _SeasonInfo {
  const _SeasonInfo({
    required this.number,
    required this.name,
    required this.episodeCount,
  });

  final int number;
  final String name;
  final int episodeCount;
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
  episodes(7, 0),
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
  DateTime? _lastHeartbeat;

  VideoPlayerController? _controller;
  String? _currentStreamUrl;
  bool _showControls = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffered = Duration.zero;
  bool _isBuffering = false;
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _positionTimer;
  Timer? _initTimeout;
  Timer? _statusTimer;
  int _operationGeneration = 0;
  bool _switchingServer = false;
  bool _findingFallback = false;
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

  // Episodes menu (series only): a seasons rail + episode list with
  // thumbnails. Driven by _activeMenu == _Pc.episodes so the hide timer and
  // back-navigation already treat it like the other menus.
  List<_SeasonInfo> _menuSeasons = const [];
  final Map<int, List<_EpisodeInfo>> _menuEpisodeCache = {};
  int _menuSeason = 1;
  bool _episodeMenuLoading = false;
  final ScrollController _episodeScroll = ScrollController();
  final List<FocusNode> _seasonTabNodes = [];
  final List<FocusNode> _episodeItemNodes = [];
  final List<GlobalKey> _episodeItemKeys = [];
  FocusNode _seasonTabNode(int index) => _seasonTabNodes[index];
  FocusNode _episodeItemNode(int index) => _episodeItemNodes[index];
  void _rebuildSeasonTabNodes(int count) {
    if (count < _seasonTabNodes.length) {
      for (var i = count; i < _seasonTabNodes.length; i++) {
        _seasonTabNodes[i].dispose();
      }
      _seasonTabNodes.removeRange(count, _seasonTabNodes.length);
    } else if (count > _seasonTabNodes.length) {
      for (var i = _seasonTabNodes.length; i < count; i++) {
        _seasonTabNodes.add(FocusNode(debugLabel: 'episode menu season $i'));
      }
    }
  }

  void _rebuildEpisodeItemNodes(int count) {
    if (count < _episodeItemNodes.length) {
      for (var i = count; i < _episodeItemNodes.length; i++) {
        _episodeItemNodes[i].dispose();
      }
      _episodeItemNodes.removeRange(count, _episodeItemNodes.length);
      _episodeItemKeys.removeRange(count, _episodeItemKeys.length);
    } else if (count > _episodeItemNodes.length) {
      for (var i = _episodeItemNodes.length; i < count; i++) {
        _episodeItemNodes.add(FocusNode(debugLabel: 'episode menu item $i'));
        _episodeItemKeys.add(GlobalKey());
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

  // Resolved in initState so dispose() never does a context lookup: by the
  // time dispose runs the inherited element is already torn down and
  // Provider.of returns null, crashing the "Null check operator" (the old
  // `context.read` in dispose crashed when exiting the player).
  TvNavigationProvider? _navProvider;

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

    final navProvider = context.read<TvNavigationProvider>();
    _navProvider = navProvider;
    navProvider.setDeepNavigating(true);

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
    unawaited(heartbeatClear());
    _operationGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _positionTimer?.cancel();
    _initTimeout?.cancel();
    _statusTimer?.cancel();
    _popGuardTimer?.cancel();
    _saveProgress();
    _controller?.removeListener(_handlePlaybackChanged);
    _controller?.dispose();
    _controller = null;
    _subtitleText.dispose();
    WakelockPlus.disable();
    _navProvider?.setDeepNavigating(false);
    _episodeScroll.dispose();
    for (final node in [
      _surfaceNode,
      _retryNode,
      _errorBackNode,
      _menuHeaderNode,
      ..._controlFocusNodes.values,
      ..._menuOptionNodes,
      ..._seasonTabNodes,
      ..._episodeItemNodes,
    ]) {
      node.dispose();
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveProgress();
      // The app is leaving the foreground by our hand (Home/standby), not by
      // a kill - so a background-process death is not reported as a crash.
      unawaited(heartbeatClear());
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
    if (!mounted) return;
    setState(() => _statusMessage = message);
    // Auto-dismiss transient feedback (Paused/Playing/volume/seek) so it never
    // lingers at the center of the screen. Persistent states (loading a
    // stream, recovering) write _statusMessage directly instead of relying on
    // this timer.
    _statusTimer?.cancel();
    _statusTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMessage = '');
    });
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
    _findingFallback = false;

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
          _seriesTitle.isNotEmpty
              ? _seriesTitle
              : (_currentTitle ?? widget.title),
          widget.season < 1 ? 1 : widget.season,
          widget.episode < 1 ? 1 : widget.episode,
          widget.tmdbId,
        );
      }

      if (!mounted) return;

      if (result != null && result['url'] != null) {
        if (!_isCurrent(generation)) return;
        final candidate = _StreamCandidate.fromMap(
          result,
        ).pinnedToHighestQuality();
        _availableServers = [candidate];
        _qualities = candidate.qualities;
        _subtitleTracks = candidate.subtitles;
        _showStatus(
          'Stream found from ${candidate.source}. Initializing player...',
        );
        // Pre-flight the stream before ExoPlayer ever sees it so a dead or
        // expired-token URL falls through to a working server instead of
        // surfacing a source error. The whole resolution-to-play path below is
        // one continuous "find a working stream" attempt, so even a failure of
        // the primary candidate must keep the friendly waiting state rather
        // than flashing a terminal error.
        _findingFallback = true;
        var initialized = false;
        if (await _isStreamPlayable(candidate)) {
          initialized = await _initializePlayer(
            candidate,
            generation: generation,
            resumePosition: null,
          );
        }
        if (!_isCurrent(generation)) return;
        if (!initialized) {
          // The primary stream was resolved but is dead (e.g. an expired HLS
          // token). Fall back to the remaining servers so a single bad server
          // never blocks playback with a source error.
          setState(() {
            _statusMessage =
                'That stream is unavailable. Finding a working one...';
          });
          await _discoverAvailableServers(generation);
          if (!_isCurrent(generation)) return;
          // Prefer servers that pass the pre-flight check, but never block the
          // player from trying the rest: validation can miss streams a CDN
          // will happily serve to ExoPlayer, which is the final arbiter.
          final validated = <_StreamCandidate>[];
          final unvalidated = <_StreamCandidate>[];
          for (final alt in _availableServers) {
            if (alt.url == candidate.url) continue;
            (await _isStreamPlayable(alt) ? validated : unvalidated).add(alt);
          }
          for (final alt in [...validated, ...unvalidated]) {
            if (!_isCurrent(generation) || initialized) break;
            // Let a failed platform view fully release before the next
            // SurfaceView is created; overlapping them crashes the compositor
            // on some TV boxes.
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (!_isCurrent(generation) || initialized) break;
            initialized = await _initializePlayer(
              alt,
              generation: generation,
              resumePosition: null,
            );
          }
        }
        _findingFallback = false;
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
        _seriesTitle.isNotEmpty
            ? _seriesTitle
            : (_currentTitle ?? widget.title),
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
      final candidate = _StreamCandidate.fromMap(
        result,
      ).pinnedToHighestQuality();
      _findingFallback = true;
      final initialized = await _initializePlayer(
        candidate,
        generation: generation,
        resumePosition: Duration.zero,
      );
      _findingFallback = false;
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

    // Fully tear down the previous platform view (SurfaceView) BEFORE creating
    // a replacement. Overlapping two live platform views crashes the fragile
    // compositor on some TV boxes, so the old player must be fully gone before
    // the next line creates a new view. This applies to every path that swaps
    // players (server switch, quality change, next episode, recovery).
    if (previous != null) {
      previous.removeListener(_handlePlaybackChanged);
      // Null the controller FIRST so the old VideoPlayer widget unmounts from
      // the tree (releasing its platform view) before the native player is
      // released. Disposing the player while its widget could still rebuild
      // makes AndroidVideoPlayer build viewWithOptions against a disposed
      // player id and throws "Bad state: No active player with ID N".
      if (_isCurrent(generation) && mounted) {
        setState(() {
          _controller = null;
          _isBuffering = true;
        });
      }
      try {
        await previous.dispose();
      } catch (e, st) {
        debugPrint('TvVideoPlayer: disposing previous player failed: $e\n$st');
      }
      if (!_isCurrent(generation)) return false;
      // Give the torn-down platform view a moment to fully release before a
      // new SurfaceView is created; overlapping them crashes the compositor
      // on some TV boxes.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!_isCurrent(generation)) return false;
    }

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
          // Buffer up to ~5 minutes ahead so slow CDN bursts don't stall
          // playback on TV boxes. The vendored ExoPlayer plugin configures
          // DefaultLoadControl with this as the max buffer duration.
          maxBufferDurationMs: 300000,
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

      _startProgressSaving();
      _showControlsAndFocus();
      return true;
    } catch (e) {
      debugPrint('TvVideoPlayer: Error initializing player: $e');
      if (_isCurrent(generation)) {
        if (_recoveringPlayback || _switchingServer || _findingFallback) {
          // Automatic retry is in progress: keep the friendly "waiting for a
          // working stream" state instead of flashing a terminal error between
          // server attempts.
          setState(() {
            _error = null;
            _isLoading = true;
            _statusMessage =
                'That stream is unavailable. Finding a working one...';
          });
        } else {
          setState(() {
            _error = 'Failed to play video: $e';
            _isLoading = false;
          });
          _focusAfterFrames(_retryNode);
        }
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
    if (value.buffered.isNotEmpty) {
      _buffered = value.buffered.last.end;
    }
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
      // streams fresh and is the one that decides when every server has truly
      // failed, so never suppress it here: leaving the dead player on screen is
      // exactly the "error in the middle" bug.
      unawaited(_recoverPlayback());
      _isBuffering = true;
    }
    final shouldRebuild =
        _isBuffering != wasBuffering ||
        _isPlaying != wasPlaying ||
        value.isInitialized;
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
    if (value.buffered.isNotEmpty) {
      _buffered = value.buffered.last.end;
    }
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

    // Refresh the playback heartbeat (throttled) so a Low-Memory-Killer death
    // while watching leaves a marker that the next cold start can report.
    final now = DateTime.now();
    if (_lastHeartbeat == null ||
        now.difference(_lastHeartbeat!) >= const Duration(seconds: 10)) {
      _lastHeartbeat = now;
      unawaited(heartbeatTouch());
    }

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

  /// Re-queues [candidate] on the *existing* controller/player instead of
  /// tearing it down and creating a new one. Native side keeps the same
  /// ExoPlayer (and its SurfaceView), so there's no platform-view gap where
  /// overlapping views crash the TV compositor, and recovery is near-atomic.
  ///
  /// Returns false (and never throws) when the current controller can't be
  /// reused, so [ _recoverPlayback] can fall back to the full teardown path.
  Future<bool> _reloadPlayback(
    _StreamCandidate candidate, {
    required int generation,
    required Duration? resumePosition,
  }) async {
    final controller = _controller;
    if (_disposed || !mounted || controller == null) return false;
    if (!controller.value.isInitialized) return false;
    final platform = VideoPlayerPlatform.instance;
    if (platform is! AndroidVideoPlayer) return false;

    try {
      final isHls = candidate.url.toLowerCase().contains('.m3u8');
      await platform.reloadMedia(
        controller.playerId,
        url: Uri.parse(candidate.url),
        httpHeaders: candidate.headers,
        formatHint: isHls ? VideoFormat.hls : null,
      );
      if (!_isCurrent(generation)) return false;

      final target = resumePosition ?? Duration.zero;
      if (target > Duration.zero) {
        await controller.seekTo(target);
        if (!_isCurrent(generation)) return false;
      }
      await controller.play();
      if (!_isCurrent(generation)) return false;

      setState(() {
        _currentStreamUrl = candidate.url;
        _currentCandidate = candidate;
        _selectedSource = candidate.source;
        _selectedServerUrl = candidate.url;
        _error = null;
        _statusMessage = '';
        _isBuffering = true;
        _isLoading = false;
        _playbackRetryCount = 0;
        _failedServerUrls.clear();
        _rebufferCount = 0;
        _lastRebufferTime = null;
        _lastReportedPosition = Duration.zero;
      });
      return true;
    } catch (e) {
      debugPrint('TvVideoPlayer: reload onto existing player failed: $e');
      return false;
    }
  }

  Future<void> _recoverPlayback() async {
    if (_recoveringPlayback) return;
    final generation = _operationGeneration;
    _recoveringPlayback = true;
    _playbackRetryCount++;
    if (mounted) {
      setState(() {
        _error = null;
        _isBuffering = true;
        _statusMessage = 'The stream stopped. Finding a working one...';
      });
    }
    await Future<void>.delayed(Duration(seconds: _playbackRetryCount * 2));
    try {
      if (!_isCurrent(generation)) return;

      // Do NOT tear down the failed player up front: when the error was
      // transient we want to re-queue the next candidate onto the SAME
      // ExoPlayer + SurfaceView (see _reloadPlayback). Tearing down a view
      // and creating a new one overlaps two live platform views, which crashes
      // the fragile compositor on some TV boxes, so the full teardown path is
      // only used as a fallback when reuse is impossible.

      // Re-resolve streams fresh: discovered URLs (esp. VixSrc tokens) expire
      // quickly, so fall back to freshly extracted servers instead of stale
      // entries that ExoPlayer rejects with a source error.
      await _discoverAvailableServers(generation);
      if (!_isCurrent(generation)) return;
      final failedUrl = _currentStreamUrl;
      if (failedUrl != null) _failedServerUrls.add(failedUrl);
      // Prefer servers that pass the pre-flight check, but never block the
      // player from trying the rest: validation can miss streams a CDN will
      // happily serve to ExoPlayer, which is the final arbiter.
      final validated = <_StreamCandidate>[];
      final unvalidated = <_StreamCandidate>[];
      for (final server in _availableServers) {
        if (server.url == failedUrl) continue;
        (await _isStreamPlayable(server) ? validated : unvalidated).add(server);
      }
      var initialized = false;
      final tried = <String>{};
      for (final next in [...validated, ...unvalidated]) {
        if (!_isCurrent(generation) || initialized) break;
        if (!tried.add(next.url)) continue;
        _showStatus('Loading a working stream from ${next.source}...');
        // Preferred path: re-queue onto the existing player, keeping its
        // SurfaceView alive. Only when that's not possible do we fall back to
        // a full teardown + fresh create (serialized so the old platform view
        // is fully gone before a new one is created).
        initialized = await _reloadPlayback(
          next,
          generation: generation,
          resumePosition: _lastStablePosition,
        );
        if (!initialized && _isCurrent(generation)) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
          if (_isCurrent(generation)) {
            initialized = await _initializePlayer(
              next,
              generation: generation,
              resumePosition: _lastStablePosition,
            );
          }
        }
        if (!initialized && _isCurrent(generation)) {
          _failedServerUrls.add(next.url);
        }
      }
      if (!initialized && mounted && _isCurrent(generation)) {
        setState(() {
          _isLoading = false;
          _error =
              'All streams are unavailable right now. Please try again later.';
        });
        _focusAfterFrames(_retryNode);
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

  /// Pre-flight check that a server is actually playable before ExoPlayer is
  /// handed its URL, so a dead or expired-token stream is skipped and the next
  /// working server is tried instead of surfacing a source error.
  Future<bool> _isStreamPlayable(_StreamCandidate candidate) {
    return DirectM3u8Service.validateStream(
      candidate.url,
      headers: candidate.headers,
    );
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
            .map(
              (server) =>
                  _StreamCandidate.fromMap(server).pinnedToHighestQuality(),
            )
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
    final current = freshTarget ?? server;
    // Prefer servers that pass the pre-flight check, but never block the player
    // from trying the rest: validation can miss streams a CDN will happily
    // serve to ExoPlayer, which is the final arbiter.
    final validated = <_StreamCandidate>[];
    final unvalidated = <_StreamCandidate>[];
    for (final s in _availableServers) {
      if (s.url == current.url) continue;
      (await _isStreamPlayable(s) ? validated : unvalidated).add(s);
    }
    var initialized = false;
    final tried = <String>{};
    for (final candidate in [current, ...validated, ...unvalidated]) {
      if (!_isCurrent(generation) || initialized) break;
      if (!tried.add(candidate.url)) continue;
      if (candidate.url == current.url && !await _isStreamPlayable(candidate)) {
        _failedServerUrls.add(candidate.url);
        continue;
      }
      // Let a torn-down platform view fully release before the next
      // SurfaceView is created; overlapping them crashes the compositor on
      // some TV boxes.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!_isCurrent(generation) || initialized) break;
      _showStatus('Loading a working stream from ${candidate.source}...');
      initialized = await _initializePlayer(
        candidate,
        generation: generation,
        resumePosition: livePosition,
      );
      if (initialized || !_isCurrent(generation)) break;
      _failedServerUrls.add(candidate.url);
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
    final inheritedHeaders =
        _currentCandidate?.headers ?? const <String, String>{};
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
            // Subtitle parsing is pure CPU work (regex loops over every cue) and
            // runs fit-for-purpose on a background isolate so a large subtitle
            // file can never jank the playback UI thread.
            final cues = await compute(_parseSubtitleFile, body);
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

  static String _stripTags(String input) {
    return input
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll(r'{\w[^}]*}', '')
        .trim();
  }

  static String _decodeHtmlEntities(String input) => input
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');

  static List<_SubtitleCue> _parseSubtitleFile(String input) {
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
    if (normalized.contains('[Script Info]') ||
        normalized.contains('[Events]')) {
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

  static List<_SubtitleCue>? _tryParseJson(String input) {
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

  static Duration? _parseJsonCueTime(dynamic value) {
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

  static List<_SubtitleCue> _parseVtt(String input) {
    final lines = input.split('\n');
    final cues = <_SubtitleCue>[];
    var i = 0;
    if (lines.isNotEmpty &&
        lines[0].trim().toUpperCase().startsWith('WEBVTT')) {
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

  static List<_SubtitleCue> _parseSrt(String input) {
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

  static List<_SubtitleCue> _parseTtml(String input) {
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

  static Duration? _parseTtmlTime(String raw) {
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

  static List<_SubtitleCue> _parseAss(String input) {
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

  static List<String> _splitDialogue(String line) {
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

  static Duration? _parseAssTime(String raw) {
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

  static Duration? _parseSubTime(String raw) {
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
        } else if (key == LogicalKeyboardKey.arrowRight) {
          if (!widget.isMovie) next = _Pc.episodes;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.episodes:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.subtitles;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.quality:
        if (key == LogicalKeyboardKey.arrowLeft) {
          next = _Pc.server;
        } else if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.subtitles;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.server:
        if (key == LogicalKeyboardKey.arrowRight) {
          next = _Pc.quality;
        } else if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.slider;
        }
        break;
      case _Pc.slider:
        if (key == LogicalKeyboardKey.arrowUp) {
          next = _Pc.playPause;
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
      case _Pc.episodes:
        _openEpisodeMenu();
        break;
      case _Pc.slider:
        break;
    }
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
      if (_activeMenu == _Pc.episodes) {
        if (_seasonTabNodes.isNotEmpty) {
          _seasonTabNode(0).requestFocus();
        } else if (_episodeItemNodes.isNotEmpty) {
          _setFocusedEpisode(0);
          _episodeItemNode(0).requestFocus();
        }
      } else if (_menuOptionNodes.isNotEmpty) {
        _focusMenuOption(_focusedMenuIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_activeMenu == _Pc.episodes) {
        if (_seasonTabNodes.isNotEmpty) {
          _seasonTabNode(_seasonTabNodes.length - 1).requestFocus();
        }
      } else if (_menuOptionNodes.isNotEmpty) {
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

  /// Opens the season/episode picker. Keeps playback running underneath;
  /// selecting an episode re-queues the SAME native player (see
  /// [_playSpecificEpisode]), so the picker is crash-safe on TV boxes.
  Future<void> _openEpisodeMenu() async {
    if (!mounted || _disposed || widget.isMovie) return;
    if (_episodeMenuLoading) return;
    final id = int.tryParse(widget.tmdbId);
    if (id == null) return;
    _episodeMenuLoading = true;
    setState(() {
      _activeMenu = _Pc.episodes;
      _currentControl = _Pc.episodes;
      _focusedMenuIndex = 0;
    });
    _resetHideTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_disposed && _activeMenu == _Pc.episodes) {
        _menuHeaderNode.requestFocus();
      }
    });
    try {
      final details = await TmdbApiService.getSeriesDetails(id);
      if (_disposed || !mounted || _activeMenu != _Pc.episodes) return;
      final raw = details?['seasons'] as List<dynamic>? ?? const [];
      final seasons = <_SeasonInfo>[];
      for (final s in raw) {
        if (s is! Map<dynamic, dynamic>) continue;
        final number = (s['season_number'] as num?)?.toInt() ?? 0;
        if (number <= 0) continue;
        seasons.add(
          _SeasonInfo(
            number: number,
            name: s['name']?.toString() ?? 'Season $number',
            episodeCount: (s['episode_count'] as num?)?.toInt() ?? 0,
          ),
        );
      }
      if (_disposed || !mounted || _activeMenu != _Pc.episodes) return;
      setState(() {
        _menuSeasons = seasons.isNotEmpty
            ? seasons
            : [
                _SeasonInfo(
                  number: _activeSeason,
                  name: 'Season $_activeSeason',
                  episodeCount: 0,
                ),
              ];
        _menuSeason = _activeSeason;
      });
      await _loadMenuEpisodes(_menuSeason, focusCurrent: true);
    } catch (e, st) {
      debugPrint('TvVideoPlayer: opening episode menu failed: $e\n$st');
    } finally {
      _episodeMenuLoading = false;
      if (mounted) setState(() {});
    }
  }

  /// Loads (and caches) the episodes for [season] for the picker.
  Future<void> _loadMenuEpisodes(
    int season, {
    bool focusCurrent = false,
  }) async {
    final id = int.tryParse(widget.tmdbId);
    if (id == null || _disposed || !mounted) return;
    if (!_menuEpisodeCache.containsKey(season)) {
      List<Map<String, dynamic>> episodes;
      try {
        episodes = await TmdbApiService.getSeasonEpisodes(id, season);
      } catch (e, st) {
        debugPrint(
          'TvVideoPlayer: loading season $season episodes failed: $e\n$st',
        );
        episodes = const [];
      }
      if (_disposed || !mounted) return;
      _menuEpisodeCache[season] = [
        for (final e in episodes)
          if (((e['episode_number'] as num?)?.toInt() ?? 0) > 0)
            _EpisodeInfo(
              number: (e['episode_number'] as num?)?.toInt() ?? 0,
              name: e['name']?.toString() ?? 'Season $season',
              stillUrl: TmdbApiService.getImageUrl(e['still_path']?.toString()),
            ),
      ];
    }
    if (_disposed || !mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed || !mounted || _activeMenu != _Pc.episodes) return;
      final episodes = _menuEpisodeCache[season] ?? const <_EpisodeInfo>[];
      var index = 0;
      if (focusCurrent) {
        final playing = episodes.indexWhere((e) => e.number == _activeEpisode);
        if (playing >= 0) index = playing;
      }
      _setFocusedEpisode(index);
      if (_episodeItemNodes.isNotEmpty) {
        _episodeItemNode(index).requestFocus();
        _ensureEpisodeVisible(index);
      }
    });
  }

  void _selectMenuSeason(_SeasonInfo season) {
    if (!mounted || _disposed || _episodeMenuLoading) return;
    if (season.number == _menuSeason) {
      _setFocusedEpisode(0);
      if (_episodeItemNodes.isNotEmpty) {
        _ensureEpisodeVisible(0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _activeMenu == _Pc.episodes) {
            _episodeItemNode(0).requestFocus();
          }
        });
      }
      return;
    }
    setState(() => _menuSeason = season.number);
    _loadMenuEpisodes(season.number);
  }

  KeyEventResult _onSeasonTabKey(
    int index,
    KeyEvent event,
    _SeasonInfo season,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight &&
        index + 1 < _seasonTabNodes.length) {
      _seasonTabNode(index + 1).requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && index > 0) {
      _seasonTabNode(index - 1).requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_episodeItemNodes.isNotEmpty) {
        _setFocusedEpisode(0);
        _episodeItemNode(0).requestFocus();
        _ensureEpisodeVisible(0);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _menuHeaderNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (keyIsEnter(event)) {
      _selectMenuSeason(season);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      _closeMenus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onEpisodeItemKey(
    int index,
    KeyEvent event,
    _EpisodeInfo episode,
    int season,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final episodes = _menuEpisodeCache[season] ?? const <_EpisodeInfo>[];
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + 1 < episodes.length ? index + 1 : index;
      _setFocusedEpisode(next);
      if (next != index) {
        _episodeItemNode(next).requestFocus();
        _ensureEpisodeVisible(next);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (index > 0) {
        _setFocusedEpisode(index - 1);
        _episodeItemNode(index - 1).requestFocus();
        _ensureEpisodeVisible(index - 1);
      } else if (_seasonTabNodes.isNotEmpty) {
        _seasonTabNode(0).requestFocus();
      } else {
        _menuHeaderNode.requestFocus();
      }
      return KeyEventResult.handled;
    }
    if (keyIsEnter(event)) {
      _playEpisodeFromMenu(season, episode);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      _closeMenus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setFocusedEpisode(int index) {
    if (!mounted) return;
    setState(() => _focusedMenuIndex = index);
  }

  Future<void> _ensureEpisodeVisible(int index) async {
    final keys = _episodeItemKeys;
    if (index < 0 || index >= keys.length) return;
    final ctx = keys[index].currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  void _playEpisodeFromMenu(int season, _EpisodeInfo episode) {
    _closeMenus();
    if (_disposed || !mounted) return;
    unawaited(_playSpecificEpisode(season, episode.number, episode.name));
  }

  /// Plays a chosen episode, mirroring [_playNextEpisode]'s metadata/fetch
  /// steps but preferring [_reloadPlayback] (same ExoPlayer + surface) and
  /// only falling back to a full teardown + re-init when reuse is impossible.
  Future<void> _playSpecificEpisode(
    int season,
    int episode,
    String episodeName,
  ) async {
    if (_disposed || !mounted) return;
    if (_loadingNext || _switchingServer) return;
    _loadingNext = true;
    final generation = ++_operationGeneration;
    final id = int.tryParse(widget.tmdbId);
    final seriesTitle = _seriesTitle.isNotEmpty
        ? _seriesTitle
        : (_currentTitle?.split(' - ').first ?? widget.title);
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _statusMessage = 'Loading S$season E$episode...';
      });
    }
    var resolvedName = episodeName;
    var resolvedStill = '';
    try {
      if (id != null) {
        final seasonEpisodes = await TmdbApiService.getSeasonEpisodes(
          id,
          season,
        );
        if (_isCurrent(generation)) {
          _seasonEpisodes = seasonEpisodes;
          final epsData = seasonEpisodes
              .where(
                (e) => ((e['episode_number'] as num?)?.toInt() ?? 0) == episode,
              )
              .firstOrNull;
          resolvedName = epsData?['name']?.toString() ?? episodeName;
          resolvedStill = TmdbApiService.getImageUrl(
            epsData?['still_path']?.toString(),
          );
        }
      }
      if (!_isCurrent(generation)) return;

      final result = await DirectM3u8Service.fetchSeriesStreamUrl(
        seriesTitle,
        season,
        episode,
        widget.tmdbId,
      );
      if (!_isCurrent(generation)) return;
      if (result == null || result['url'] == null) {
        _loadingNext = false;
        if (mounted && _isCurrent(generation)) {
          setState(() {
            _error = 'Could not load S$season E$episode. Please try again.';
            _isLoading = false;
            _statusMessage = '';
          });
        }
        return;
      }
      final candidate = _StreamCandidate.fromMap(
        result,
      ).pinnedToHighestQuality();
      var initialized = await _reloadPlayback(
        candidate,
        generation: generation,
        resumePosition: Duration.zero,
      );
      if (!initialized && _isCurrent(generation)) {
        initialized = await _initializePlayer(
          candidate,
          generation: generation,
          resumePosition: Duration.zero,
        );
      }
      _loadingNext = false;
      if (!initialized || !_isCurrent(generation)) return;
      setState(() {
        _activeSeason = season;
        _activeEpisode = episode;
        _currentEpisodeName = resolvedName;
        _episodeStillUrl = resolvedStill;
        _currentTitle = resolvedName.isNotEmpty
            ? '$seriesTitle - S$season'
                  'E$episode: $resolvedName'
            : '$seriesTitle - S$season'
                  'E$episode';
        _nextSeason = season;
        _nextEpisode = episode;
        _completionHandled = false;
        _isLoading = false;
        _statusMessage = '';
      });
      if (id != null) {
        _resolveNextEpisode(id, seriesTitle);
      }
      _loadDefaultSubtitle(candidate);
      _discoverAvailableServers(generation);
      _saveProgress();
    } catch (e, st) {
      debugPrint('TvVideoPlayer: switching episode failed: $e\n$st');
      _loadingNext = false;
      if (mounted && _isCurrent(generation)) {
        setState(() {
          _error = 'Could not load S$season E$episode. Please try again.';
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
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
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xCC000000),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _statusMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 18),
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
    final message = _statusMessage.isEmpty
        ? 'Loading stream...'
        : _statusMessage;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
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

    final episodesButton = _controlButton(
      _Pc.episodes,
      Icons.video_library,
      'Episodes',
      width: 112,
      height: 64,
      label: 'S$_activeSeason  E$_activeEpisode',
      onPress: () => _openEpisodeMenu(),
    );

    return Positioned.fill(
      // RepaintBoundary is INSIDE the Positioned: a Positioned must stay a
      // direct child of the outer Stack (it sets the Stack's parent data), so
      // the isolation boundary wraps the painted controls, not the positioner.
      child: RepaintBoundary(
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
                        final hasEpisodesButton = !widget.isMovie;
                        final rowWidth =
                            buttonWidth * (hasEpisodesButton ? 4 : 3) +
                            gap * (hasEpisodesButton ? 3 : 2);
                        final startX = (constraints.maxWidth - rowWidth) / 2;
                        final menuIndex = <_Pc, int>{
                          _Pc.server: 0,
                          _Pc.quality: 1,
                          _Pc.subtitles: 2,
                          if (hasEpisodesButton) _Pc.episodes: 3,
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
                                    qualityButton,
                                    const SizedBox(width: gap),
                                    subtitlesButton,
                                    if (hasEpisodesButton) ...[
                                      const SizedBox(width: gap),
                                      episodesButton,
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                            if (openMenu == _Pc.episodes)
                              Positioned(
                                left: 48,
                                right: 48,
                                bottom: 96,
                                child: _buildEpisodeMenuPanel(),
                              )
                            else if (openMenu != null)
                              Positioned(
                                bottom: 88,
                                left:
                                    (startX +
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
      ),
    );
  }

  Widget _buildProgressBar() {
    final totalMs = _duration.inMilliseconds;
    final hasTotal = _hasDuration && totalMs > 0;
    final played = hasTotal
        ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final buffered = hasTotal
        ? (_buffered.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
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
              // Animation disabled: every animated transition over the video
              // texture stalls the weak TV GPU (the "scratch"), so highlights
              // jump instantly instead of tweening.
              duration: Duration.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              decoration: BoxDecoration(
                color: focused ? Colors.white10 : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: focused ? Colors.white70 : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: focused ? 8 : 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Buffered (loaded) portion — same safety indicator the
                      // mobile player shows via VideoProgressIndicator.
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (buffered < played ? played : buffered),
                        child: ColoredBox(color: Colors.white38),
                      ),
                      // Played portion.
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: played,
                        child: const ColoredBox(color: Color(0xFFE50914)),
                      ),
                    ],
                  ),
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
                // Animation disabled: every animated transition over the video
                // texture stalls the weak TV GPU (the "scratch"), so highlights
                // jump instantly instead of tweening.
                duration: Duration.zero,
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

  Widget _buildEpisodeMenuPanel() {
    final episodes = _menuEpisodeCache[_menuSeason] ?? const <_EpisodeInfo>[];
    _rebuildSeasonTabNodes(_menuSeasons.length);
    _rebuildEpisodeItemNodes(episodes.length);
    return Container(
      height: 380,
      decoration: BoxDecoration(
        color: const Color(0xF2181818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Focus(
            focusNode: _menuHeaderNode,
            onKeyEvent: _onMenuHeaderKey,
            child: InkWell(
              onTap: _closeMenus,
              child: AnimatedContainer(
                // Animation disabled: every animated transition over the video
                // texture stalls the weak TV GPU (the "scratch"), so highlights
                // jump instantly instead of tweening.
                duration: Duration.zero,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                decoration: BoxDecoration(
                  color: _menuHeaderNode.hasFocus
                      ? Colors.white12
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.video_library,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _seriesTitle.isNotEmpty ? _seriesTitle : widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Text(
                      'Episodes',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.white24),
          if (_menuSeasons.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < _menuSeasons.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      _seasonTab(i, _menuSeasons[i]),
                    ],
                  ],
                ),
              ),
            ),
          const Divider(height: 1, color: Colors.white24),
          Expanded(
            child: _episodeMenuLoading && episodes.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.redAccent),
                  )
                : episodes.isEmpty
                ? const Center(
                    child: Text(
                      'No episodes found',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  )
                : SingleChildScrollView(
                    controller: _episodeScroll,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (var i = 0; i < episodes.length; i++)
                          _episodeTile(i, episodes[i], _menuSeason),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seasonTab(int index, _SeasonInfo season) {
    final node = _seasonTabNode(index);
    final isActive = season.number == _menuSeason;
    final isFocused = node.hasFocus;
    final label = season.name.isNotEmpty && season.name.length <= 14
        ? season.name
        : 'Season ${season.number}';
    return Focus(
      focusNode: node,
      onKeyEvent: (_, event) => _onSeasonTabKey(index, event, season),
      child: InkWell(
        onTap: () => _selectMenuSeason(season),
        child: AnimatedContainer(
          // Animation disabled: every animated transition over the video
          // texture stalls the weak TV GPU (the "scratch"), so highlights
          // jump instantly instead of tweening.
          duration: Duration.zero,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFE50914)
                : (isFocused ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFocused ? Colors.redAccent : Colors.white24,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isActive || isFocused ? Colors.white : Colors.white70,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (season.episodeCount > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '(${season.episodeCount})',
                  style: TextStyle(
                    color: isActive || isFocused
                        ? Colors.white70
                        : Colors.white38,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _episodeTile(int index, _EpisodeInfo episode, int season) {
    final node = _episodeItemNode(index);
    final isPlaying =
        season == _activeSeason && episode.number == _activeEpisode;
    final isFocused = node.hasFocus || index == _focusedMenuIndex;
    return Focus(
      key: _episodeItemKeys[index],
      focusNode: node,
      onKeyEvent: (_, event) =>
          _onEpisodeItemKey(index, event, episode, season),
      child: InkWell(
        onTap: () => _playEpisodeFromMenu(season, episode),
        child: Container(
          height: 96,
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPlaying
                ? const Color(0x33E50914)
                : (isFocused ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: isFocused
                ? Border.all(color: Colors.redAccent, width: 2)
                : null,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 148,
                  height: 80,
                  child: episode.stillUrl.isNotEmpty
                      ? Image.network(
                          episode.stillUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              _episodeThumbPlaceholder(),
                        )
                      : _episodeThumbPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'S$season  E${episode.number}',
                      style: TextStyle(
                        color: isPlaying ? Colors.redAccent : Colors.white70,
                        fontSize: 15,
                        fontWeight: isPlaying
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      episode.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
              if (isPlaying)
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 30,
                )
              else if (isFocused)
                const Icon(
                  Icons.play_circle_outline,
                  color: Colors.white70,
                  size: 30,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _episodeThumbPlaceholder() {
    return Container(
      color: const Color(0xFF2A2A2A),
      child: const Icon(Icons.movie, color: Colors.white38, size: 32),
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
              selected:
                  _activeSubtitles.isNotEmpty &&
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
              selected:
                  server.url == _selectedServerUrl || streamEquals(server),
            ),
        ];
      case _Pc.playPause:
      case _Pc.back:
      case _Pc.rewind:
      case _Pc.forward:
      case _Pc.episodes:
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
              // RepaintBoundary isolates the video texture from Flutter UI
              // repaints: on the low-end TV GPU, every overlay/slider repaint
              // over the texture stalls a frame ("scratch"). Isolating the
              // layers means UI redraws no longer invalidate the video.
              if (_controller != null)
                Positioned.fill(
                  child: RepaintBoundary(
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
                ),
              if (_isLoading && _error == null)
                RepaintBoundary(child: _buildLoadingWidget()),
              if (_isBuffering &&
                  _error == null &&
                  !_showControls &&
                  !_isLoading)
                RepaintBoundary(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        if (_statusMessage.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (_error != null) RepaintBoundary(child: _buildErrorWidget()),
              if (_showControls) _buildControlsOverlay(),
              RepaintBoundary(child: _buildSubtitleWidget()),
              // Status messages (e.g. "Finding a working stream...") belong in
              // the middle of the screen on TV, visible regardless of whether
              // the controls overlay is up. Skip the duplicate when the loading
              // or buffering spinner is already showing the same message.
              if (_statusMessage.isNotEmpty &&
                  _error == null &&
                  !_isLoading &&
                  !(_isBuffering && !_showControls))
                RepaintBoundary(child: _buildStatusWidget()),
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
