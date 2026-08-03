import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
import '../../services/direct_m3u8_service.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/watch_history_service.dart';

enum _PlayerOverlay { none, servers, audio, subtitles, video }

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

  // Server discovery
  List<_StreamCandidate> _availableServers = [];
  bool _serversLoading = false;
  String? _selectedSource;
  String? _selectedServerUrl;
  String? _currentTitle;

  // media_kit player
  late final Player _player;
  late final VideoController _videoController;
  bool _showControls = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isBuffering = false;
  Tracks _tracks = const Tracks();
  Track _selectedTrack = const Track();
  _PlayerOverlay _overlay = _PlayerOverlay.none;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _seekFeedbackTimer;
  String? _seekFeedback;
  int _operationGeneration = 0;
  bool _switchingServer = false;
  bool _disposed = false;
  bool _exiting = false;

  final FocusNode _surfaceNode = FocusNode(debugLabel: 'Player surface');
  final FocusNode _backNode = FocusNode(debugLabel: 'Player back');
  final FocusNode _serverNode = FocusNode(debugLabel: 'Player server');
  final FocusNode _rewindNode = FocusNode(debugLabel: 'Player rewind');
  final FocusNode _playNode = FocusNode(debugLabel: 'Player play pause');
  final FocusNode _forwardNode = FocusNode(debugLabel: 'Player forward');
  final FocusNode _seekNode = FocusNode(debugLabel: 'Player seek');
  final FocusNode _audioNode = FocusNode(debugLabel: 'Player audio');
  final FocusNode _subtitleNode = FocusNode(debugLabel: 'Player subtitles');
  final FocusNode _videoNode = FocusNode(debugLabel: 'Player quality');
  final FocusNode _retryNode = FocusNode(debugLabel: 'Player retry');
  final FocusNode _errorBackNode = FocusNode(debugLabel: 'Player error back');
  final List<FocusNode> _overlayNodes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _videoController = VideoController(_player);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _bindPlayerStreams();
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
    _seekFeedbackTimer?.cancel();
    _saveProgress();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    for (final node in [
      _surfaceNode,
      _backNode,
      _serverNode,
      _rewindNode,
      _playNode,
      _forwardNode,
      _seekNode,
      _audioNode,
      _subtitleNode,
      _videoNode,
      _retryNode,
      _errorBackNode,
      ..._overlayNodes,
    ]) {
      node.dispose();
    }
    _player.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    super.dispose();
  }

  void _bindPlayerStreams() {
    _subscriptions.addAll([
      _player.stream.playing.listen((playing) {
        if (!_disposed && mounted) setState(() => _isPlaying = playing);
        if (!playing) _saveProgress();
      }),
      _player.stream.position.listen((position) {
        if (!_disposed && mounted) setState(() => _position = position);
      }),
      _player.stream.duration.listen((duration) {
        if (!_disposed && mounted) setState(() => _duration = duration);
      }),
      _player.stream.buffering.listen((buffering) {
        if (!_disposed && mounted) setState(() => _isBuffering = buffering);
      }),
      _player.stream.completed.listen((completed) {
        if (completed) _saveProgress();
      }),
      _player.stream.error.listen((message) {
        if (_disposed || !mounted || message.trim().isEmpty) return;
        setState(() {
          _error = 'Playback error: $message';
          _isLoading = false;
          _showControls = true;
        });
        _focusAfterFrames(_retryNode);
      }),
      _player.stream.tracks.listen((tracks) {
        if (!_disposed && mounted) setState(() => _tracks = tracks);
      }),
      _player.stream.track.listen((track) {
        if (!_disposed && mounted) setState(() => _selectedTrack = track);
      }),
    ]);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _saveProgress();
      _player.pause();
    }
  }

  void _saveProgress() {
    if (mounted && _position > Duration.zero && _duration > Duration.zero) {
      WatchHistoryService.saveWatchProgress(
        tmdbId: widget.tmdbId,
        title: widget.title,
        isMovie: widget.isMovie,
        season: widget.season,
        episode: widget.episode,
        position: _position,
        duration: _duration,
      );
    }
  }

  void _showStatus(String message) {
    debugPrint('TvVideoPlayer: $message');
    if (mounted) setState(() => _statusMessage = message);
  }

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
        final opened = await _playCandidate(
          candidate,
          generation: generation,
          resumePosition: null,
        );
        if (!opened || !_isCurrent(generation)) return;
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

  bool _isCurrent(int generation) =>
      !_disposed && mounted && generation == _operationGeneration;

  Future<bool> _playCandidate(
    _StreamCandidate candidate, {
    required int generation,
    required Duration? resumePosition,
  }) async {
    try {
      final media = Media(candidate.url, httpHeaders: candidate.headers);
      await _player.open(media);
      if (!_isCurrent(generation)) return false;

      final target = resumePosition ??
          await WatchHistoryService.loadWatchPosition(
            widget.tmdbId,
            widget.isMovie,
            widget.season,
            widget.episode,
          );
      if (!_isCurrent(generation)) return false;
      if (target > Duration.zero) {
        await _player.seek(target);
        if (!_isCurrent(generation)) return false;
      }

      if (_isCurrent(generation)) {
        setState(() {
          _isLoading = false;
          _error = null;
          _statusMessage = '';
          _tracks = _player.state.tracks;
          _selectedTrack = _player.state.track;
        });
        _showControlsAndFocus(_playNode);
      }
      return true;
    } catch (e) {
      if (!_isCurrent(generation)) return false;
      debugPrint('TvVideoPlayer: Error playing: $e');
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
    final opened = await _playCandidate(
      server,
      generation: generation,
      resumePosition: livePosition,
    );
    if (!_isCurrent(generation)) return;
    setState(() {
      _switchingServer = false;
      if (opened) {
        _selectedSource = server.source;
        _selectedServerUrl = server.url;
      }
    });
  }

  void _togglePlayPause() {
    _player.playOrPause();
    setState(() => _showControls = true);
    _resetHideTimer();
  }

  void _seekBy(Duration offset) {
    var target = _position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (_duration > Duration.zero && target > _duration) target = _duration;
    _player.seek(target);
    setState(() => _showControls = true);
    _resetHideTimer();
  }

  void _seekTo(Duration position) {
    _player.seek(position);
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _player.pause();
          context.read<TvNavigationProvider>().setDeepNavigating(false);
        }
      },
      child: KeyboardListener(
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
        focusNode: FocusNode(),
        autofocus: true,
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
    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Video
          Center(
            child: Video(
              controller: _videoController,
              controls: NoVideoControls,
            ),
          ),
          // Buffering indicator
          if (_isBuffering)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          // Controls overlay
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
          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _handleBackNavigation,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
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
          // Center play controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.replay_10,
                size: 40,
                onTap: () => _seekBy(const Duration(seconds: -10)),
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
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
          // Bottom progress bar
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
                style: TvTypography.bodyLarge,
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
    return GestureDetector(
      onTap: onTap,
      child: Icon(icon, color: Colors.white, size: size),
    );
  }
}
