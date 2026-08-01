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
  String _statusMessage = '';

  // Server discovery
  List<Map<String, dynamic>> _availableServers = [];
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

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _player.stream.position.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _player.stream.duration.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isBuffering = buffering);
    });

    _loadStream();
  }

  @override
  void dispose() {
    _saveProgress();
    _player.dispose();
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
    if (!mounted) return;

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

        _availableServers = [result];
        _selectedSource = source;
        _selectedServerUrl = url;

        _showStatus('Stream found from $source! Initializing player...');
        await _playUrl(url, headers: headers);
        _discoverAvailableServers();
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

  Future<void> _playUrl(
    String url, {
    Map<String, String> headers = const {},
  }) async {
    try {
      final media = Media(url, httpHeaders: headers);
      await _player.open(media);

      // Resume from saved position
      final savedPosition = await WatchHistoryService.loadWatchPosition(
        widget.tmdbId,
        widget.isMovie,
        widget.season,
        widget.episode,
      );
      if (savedPosition > Duration.zero) {
        await _player.seek(savedPosition);
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    } catch (e) {
      debugPrint('TvVideoPlayer: Error playing: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to play video: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _discoverAvailableServers() async {
    if (!mounted) return;
    setState(() => _serversLoading = true);

    try {
      final servers = await DirectM3u8Service.fetchAvailableStreams(
        title: _currentTitle ?? widget.title,
        tmdbId: widget.tmdbId,
        isMovie: widget.isMovie,
        season: widget.season,
        episode: widget.episode,
      );

      if (mounted) {
        final merged = <Map<String, dynamic>>[..._availableServers, ...servers];
        final seen = <String>{};
        setState(() {
          _availableServers = merged.where((server) {
            final url = server['url']?.toString() ?? '';
            return url.isNotEmpty && seen.add(url);
          }).toList();
          _serversLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TvVideoPlayer: Server discovery error: $e');
      if (mounted) setState(() => _serversLoading = false);
    }
  }

  Future<void> _switchServer(Map<String, dynamic> server) async {
    if (!mounted) return;
    final url = server['url'] as String?;
    if (url == null) return;

    final source = server['source'] as String? ?? 'Unknown';
    final headers = <String, String>{};
    if (server['referer'] != null) {
      headers['Referer'] = server['referer'].toString();
    }
    if (server['headers'] != null && server['headers'] is Map) {
      (server['headers'] as Map).forEach((k, v) {
        headers[k.toString()] = v.toString();
      });
    }

    _saveProgress();
    setState(() {
      _selectedSource = source;
      _selectedServerUrl = url;
      _isLoading = true;
    });

    _showStatus('Switching to $source...');
    await _playUrl(url, headers: headers);
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

  Timer? _hideTimer;
  void _resetHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
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
                final source = server['source'] as String? ?? 'Unknown';
                final route = server['server']?.toString() ?? source;
                final url = server['url']?.toString() ?? '';
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
