import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../providers/tv_navigation_provider.dart';
import '../../services/direct_m3u8_service.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';

class _StreamCandidate {
  const _StreamCandidate({
    required this.url,
    required this.source,
    required this.headers,
    this.route,
  });

  final String url;
  final String source;
  final Map<String, String> headers;
  final String? route;

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
    );
  }
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
  String? _currentStreamUrl;

  VideoPlayerController? _controller;
  bool _showControls = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;
  Timer? _hideTimer;
  Timer? _progressTimer;
  int _operationGeneration = 0;
  bool _switchingServer = false;
  bool _disposed = false;
  bool _recoveringPlayback = false;
  int _playbackRetryCount = 0;
  Duration _lastStablePosition = Duration.zero;

  final FocusNode _surfaceNode = FocusNode(debugLabel: 'Player surface');
  final FocusNode _backNode = FocusNode(debugLabel: 'Player back');
  final FocusNode _serverNode = FocusNode(debugLabel: 'Player server');
  final FocusNode _rewindNode = FocusNode(debugLabel: 'Player rewind');
  final FocusNode _playNode = FocusNode(debugLabel: 'Player play pause');
  final FocusNode _forwardNode = FocusNode(debugLabel: 'Player forward');
  final FocusNode _seekNode = FocusNode(debugLabel: 'Player seek');
  final FocusNode _retryNode = FocusNode(debugLabel: 'Player retry');
  final FocusNode _errorBackNode = FocusNode(debugLabel: 'Player error back');
  final List<FocusNode> _overlayNodes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _progressTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      _saveProgress();
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
    _saveProgress();
    _controller?.removeListener(_handlePlaybackChanged);
    _controller?.dispose();
    for (final node in [
      _surfaceNode,
      _backNode,
      _serverNode,
      _rewindNode,
      _playNode,
      _forwardNode,
      _seekNode,
      _retryNode,
      _errorBackNode,
      ..._overlayNodes,
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
        season: widget.season,
        episode: widget.episode,
        position: position,
        duration: duration,
      );
    }
  }

  void _showStatus(String message) {
    debugPrint('TvVideoPlayer: $message');
    if (mounted) setState(() => _statusMessage = message);
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
        _showStatus(
          'Stream found from ${candidate.source}. Initializing player...',
        );
        final initialized = await _initializePlayer(
          candidate,
          generation: generation,
          resumePosition: null,
        );
        if (!initialized || !_isCurrent(generation)) return;
        setState(() {
          _selectedSource = candidate.source;
          _selectedServerUrl = candidate.url;
        });
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
    } else {
      final seriesTitle = details['name']?.toString() ?? widget.title;
      final episodes = await TmdbApiService.getSeasonEpisodes(
        id,
        widget.season,
      );
      final currentEpisodeData = episodes
          .where(
            (e) =>
                ((e['episode_number'] as num?)?.toInt() ?? 0) == widget.episode,
          )
          .firstOrNull;
      final episodeName = currentEpisodeData?['name']?.toString() ?? '';
      _currentTitle = episodeName.isNotEmpty
          ? '$seriesTitle - S${widget.season}E${widget.episode}: $episodeName'
          : '$seriesTitle - S${widget.season}E${widget.episode}';
    }
  }

  Future<bool> _initializePlayer(
    _StreamCandidate candidate, {
    required int generation,
    required Duration? resumePosition,
  }) async {
    final previousController = _controller;
    final url = candidate.url;
    final isHls = url.toLowerCase().contains('.m3u8');
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: candidate.headers,
      formatHint: isHls ? VideoFormat.hls : null,
      videoPlayerOptions: VideoPlayerOptions(
        backBufferDurationMs: 60000,
        allowBackgroundPlayback: false,
      ),
    );

    try {
      _showStatus('Loading video...');
      await controller.initialize();
      if (!_isCurrent(generation)) {
        await controller.dispose();
        return false;
      }

      final target = resumePosition ??
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

      await controller.play();
      if (!_isCurrent(generation)) {
        await controller.dispose();
        return false;
      }

      controller.addListener(_handlePlaybackChanged);
      setState(() {
        _controller = controller;
        _currentStreamUrl = url;
        _isLoading = false;
        _error = null;
        _statusMessage = '';
        _isBuffering = controller.value.isBuffering;
        _playbackRetryCount = 0;
      });

      previousController?.removeListener(_handlePlaybackChanged);
      await previousController?.dispose();
      _startProgressSaving();
      _showControlsAndFocus(_playNode);
      return true;
    } on PlatformException catch (e) {
      await controller.dispose();
      debugPrint('TvVideoPlayer: PlatformException: ${e.message}');
      if (_isCurrent(generation)) {
        final codecError = e.message?.contains('MediaCodec') == true ||
            e.message?.contains('VideoRenderer') == true;
        if (codecError && _playbackRetryCount < 1) {
          _playbackRetryCount++;
          _showStatus('Decoder error, trying fallback...');
          await _switchToNextServer(generation);
          return false;
        }
        setState(() {
          _error = 'Playback failed on this device.\n'
              'The stream format may not be supported.\n\n'
              'Try switching to another server from the server picker.';
          _isLoading = false;
        });
        _focusAfterFrames(_retryNode);
      }
      return false;
    } catch (e) {
      await controller.dispose();
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

  Future<void> _switchToNextServer(int generation) async {
    if (_availableServers.length <= 1) return;
    final currentIndex = _availableServers
        .indexWhere((s) => s.url == _currentStreamUrl);
    final nextIndex = currentIndex < 0 ? 0 : currentIndex + 1;
    final next = _availableServers[nextIndex % _availableServers.length];
    if (next.url.isEmpty || next.url == _currentStreamUrl) return;
    _showStatus('Trying ${next.source}...');
    await _initializePlayer(
      next,
      generation: generation,
      resumePosition: _lastStablePosition,
    );
  }

  void _handlePlaybackChanged() {
    final controller = _controller;
    if (!mounted || controller == null || _disposed) return;
    final value = controller.value;
    if (value.position > Duration.zero) _lastStablePosition = value.position;
    if (value.hasError && !_recoveringPlayback && _playbackRetryCount < 2) {
      unawaited(_recoverPlayback());
    }
    final isBuffering = value.isBuffering;
    var shouldRebuild = isBuffering != _isBuffering;
    _isBuffering = isBuffering;

    if (value.isInitialized) {
      shouldRebuild = true;
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
      final candidate = _StreamCandidate(
        url: url,
        source: _selectedSource ?? 'Unknown',
        headers: const {},
      );
      await _initializePlayer(
        candidate,
        generation: _operationGeneration,
        resumePosition: _lastStablePosition,
      );
    } catch (error) {
      debugPrint('TvVideoPlayer: Playback recovery failed: $error');
      if (mounted && _playbackRetryCount >= 2) {
        setState(() {
          _error =
              'The current server stopped responding. Please try again.';
        });
      }
    } finally {
      _recoveringPlayback = false;
    }
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
      }
    });
  }

  void _togglePlayPause() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() => _showControls = true);
    _resetHideTimer();
  }

  void _seekBy(Duration offset) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    var target = _position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    controller.seekTo(target);
    setState(() => _showControls = true);
    _resetHideTimer();
  }

  void _seekTo(Duration position) {
    _controller?.seekTo(position);
    _resetHideTimer();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showControlsAndFocus(FocusNode node) {
    setState(() => _showControls = true);
    _resetHideTimer();
    _focusAfterFrames(node);
  }

  void _focusAfterFrames(FocusNode node) {
    if (_disposed || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && mounted) {
        node.requestFocus();
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _resetHideTimer();
  }

  void _showServerPicker() {
    _resetHideTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Server',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_serversLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.red),
                ),
              )
            else
              ..._availableServers.map((server) {
                final source = server.source;
                final route = server.route ?? source;
                final url = server.url;
                final isSelected = url.isNotEmpty && url == _selectedServerUrl;
                return ListTile(
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: isSelected ? Colors.red : Colors.grey,
                  ),
                  title: Text(
                    source,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[300],
                    ),
                  ),
                  subtitle: route == source
                      ? null
                      : Text(
                          'Via $route',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                  onTap: () {
                    Navigator.pop(context);
                    if (!isSelected) _switchServer(server);
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  void _handleBackNavigation() {
    _saveProgress();
    context.read<TvNavigationProvider>().setDeepNavigating(false);
    Navigator.pop(context);
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
        if (didPop) {
          _controller?.pause();
          context.read<TvNavigationProvider>().setDeepNavigating(false);
        }
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: (event) {
          if (event is KeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.escape ||
                event.logicalKey == LogicalKeyboardKey.goBack) {
              _handleBackNavigation();
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.space) {
              _togglePlayPause();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _seekBy(const Duration(seconds: -10));
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _seekBy(const Duration(seconds: 10));
            }
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: _error != null
              ? _buildErrorWidget()
              : _isLoading
                  ? _buildLoadingWidget()
                  : _buildPlayerWidget(),
        ),
      ),
    );
  }

  Widget _buildPlayerWidget() {
    final controller = _controller;
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          if (controller != null && controller.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: VideoPlayer(controller),
              ),
            )
          else
            Container(color: Colors.black),
          if (_isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          if (_showControls) _buildControlsOverlay(),
        ],
      ),
    );
  }

  Widget _buildControlsOverlay() {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: [0.0, 0.2, 0.8, 1.0],
        ),
      ),
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _ControlButton(
                    icon: Icons.arrow_back,
                    size: 24,
                    onTap: _handleBackNavigation,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentTitle ?? widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedSource != null)
                    GestureDetector(
                      onTap: _showServerPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.dns,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _selectedSource!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.replay_10,
                size: 40,
                onTap: () => _seekBy(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 24),
              _ControlButton(
                icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 40,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: 24),
              _ControlButton(
                icon: Icons.forward_10,
                size: 40,
                onTap: () => _seekBy(const Duration(seconds: 10)),
              ),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: Colors.red,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.red,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    trackHeight: 3,
                    overlayColor: Colors.red.withOpacity(0.2),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (value) {
                      final pos = Duration(
                        milliseconds: (value * _duration.inMilliseconds)
                            .toInt(),
                      );
                      _seekTo(pos);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Stack(
      children: [
        Container(color: Colors.black),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Loading stream for ${widget.title}...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _statusMessage,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Stack(
      children: [
        Container(color: Colors.black),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Unable to Load Stream',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.grey[300], fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      _playbackRetryCount = 0;
                      _loadStream();
                    },
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
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text(
                      'Go Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: _ControlButton(
            icon: Icons.arrow_back,
            size: 24,
            onTap: () => Navigator.pop(context),
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: FocusNode(debugLabel: 'Control $icon'),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.all(size * 0.2),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}
