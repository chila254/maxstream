import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:dio/dio.dart';
import '../services/watch_history_service.dart';
import '../services/settings_service.dart';
import '../services/combined_stream_service.dart';
import 'dart:async';

void initMediaKit() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
}

class ModernVideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;
  final String? posterUrl;
  final double? userRating;

  const ModernVideoPlayerScreen({
    super.key,
    this.videoUrl,
    required this.title,
    required this.tmdbId,
    required this.isMovie,
    this.season = 1,
    this.episode = 1,
    this.posterUrl,
    this.userRating,
  });

  @override
  State<ModernVideoPlayerScreen> createState() =>
      _ModernVideoPlayerScreenState();
}

class _ModernVideoPlayerScreenState extends State<ModernVideoPlayerScreen>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlayerReady = false;
  bool _showControls = true;
  bool _isLoading = true;
  bool _isBuffering = false;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late AnimationController _loadingAnimationController;
  late Animation<double> _controlsAnimation;
  late Animation<double> _loadingAnimation;

  Timer? _controlsTimer;
  Timer? _progressTimer;
  Duration _lastPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Playback settings
  double _playbackSpeed = 1.0;
  bool _isMuted = false;
  String _resizeMode = 'Fit'; // Default resize mode
  bool _autoPlay = true;
  bool _rememberPosition = true;
  double _seekSensitivity = 1.0;

  // Settings from SettingsService
  Map<String, dynamic> _playerSettings = {};
  Map<String, dynamic> _subtitleSettings = {};

  // Subtitle state
  List<Map<String, dynamic>> _currentSubtitles = [];
  String? _currentSubtitleText;
  Timer? _subtitleTimer;
  bool _subtitlesEnabled = true;
  String _subtitleFont = 'Default';
  double _subtitleTextSize = 16.0;
  String _subtitlePosition = 'Bottom';
  Color _subtitleTextColor = Colors.white;
  Color _subtitleBackgroundColor = const Color.fromARGB(179, 0, 0, 0);

  // Netflix-like features
  bool _showMoreInfo = false;
  bool _showPlaybackSettings = false;
  bool _showSubtitlesPanel = false;
  bool _showSkipIntroButton = false;
  bool _showSkipRecapButton = false;
  bool _showAudioTracksPanel = false;
  bool _showPlayButton = false;
  List<Map<String, dynamic>> _availableSubtitles = [];
  List<Map<String, dynamic>> _availableAudioTracks = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Initialize player
    _player = Player();
    _videoController = VideoController(_player);

    _setupAnimations();
    _loadSettings();
    _loadWatchHistory();
    _initializePlayer();
    _setupPictureInPicture();
  }

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _loadingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      _playerSettings = await SettingsService.getAllPlayerSettings();
      _subtitleSettings = await SettingsService.getAllSubtitleSettings();

      // Apply player settings to state variables
      _resizeMode = _playerSettings['defaultResizeMode'] ?? 'Fit';
      _autoPlay = _playerSettings['autoPlay'] ?? true;
      _rememberPosition = _playerSettings['rememberPosition'] ?? true;
      _seekSensitivity = _playerSettings['seekSensitivity'] ?? 1.0;

      // Apply subtitle settings to state variables
      _subtitlesEnabled = _subtitleSettings['enabled'] ?? true;
      _subtitleFont = _subtitleSettings['font'] ?? 'Default';
      _subtitleTextSize = _subtitleSettings['textSize'] ?? 16.0;
      _subtitlePosition = _subtitleSettings['position'] ?? 'Bottom';
      _subtitleTextColor = _subtitleSettings['textColor'] ?? Colors.white;
      _subtitleBackgroundColor =
          _subtitleSettings['backgroundColor'] ??
          const Color.fromARGB(179, 0, 0, 0);

      // Load available subtitles and audio tracks
      await _loadAvailableSubtitles();
      await _loadAvailableAudioTracks();

      setState(() {});
    } catch (e) {
      // Silently ignore settings loading errors
    }
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      String? bestUrl = widget.videoUrl;

      // If no video URL provided, try to extract stream using scrapper services
      if (bestUrl == null) {
        debugPrint(
          'VideoPlayer: No videoUrl provided, attempting to extract stream',
        );
        final streamResult = await CombinedStreamService.extractStream(
          widget.tmdbId,
          widget.isMovie,
          season: widget.season,
          episode: widget.episode,
        );

        if (streamResult != null && streamResult['streamUrl'] != null) {
          bestUrl = streamResult['streamUrl'];
          debugPrint('VideoPlayer: Stream extracted successfully: $bestUrl');
        } else {
          debugPrint('VideoPlayer: Failed to extract stream');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Unable to find streaming source for this content.';
          });
          return;
        }
      }

      try {
        debugPrint('VideoPlayer: Attempting to load URL: $bestUrl');

        // Create Media with optimized headers
        final media = Media(
          bestUrl!,
          httpHeaders: _getOptimizedHeaders(bestUrl),
        );

        debugPrint('VideoPlayer: Created media with headers');

        // Open the media with explicit play: false
        await _player.open(media, play: false);

        debugPrint('VideoPlayer: Media opened successfully');

        // Wait for the player to be ready before proceeding
        await Future.delayed(const Duration(milliseconds: 200));

        // Get duration
        _totalDuration = _player.state.duration;

        // Resume from last position if rememberPosition is enabled
        if (_rememberPosition && _lastPosition.inSeconds > 0) {
          await _player.seek(_lastPosition);
        }

        // Set initial volume and mute state
        await _player.setVolume(100);

        // Apply autoplay setting from preferences
        if (_autoPlay) {
          // Add a small delay to ensure the player is fully ready
          await Future.delayed(const Duration(milliseconds: 500));
          try {
            await _player.play();
          } catch (e) {
            debugPrint('Initial autoplay failed, will retry: $e');
          }
        }

        _startProgressTracking();
        _startControlsTimer();

        // Listen to player state changes
        _player.streams.buffering.listen((buffering) {
          if (buffering != _isBuffering) {
            setState(() {
              _isBuffering = buffering;
            });
          }
        });

        // Listen for player errors
        _player.streams.error.listen((error) {
          debugPrint('Player error: $error');
          setState(() {
            _isLoading = false;
            _errorMessage = 'Video playback failed. Please try again.';
          });
        });

        _player.streams.position.listen((position) {
          final currentPosition = position.inSeconds;

          // Auto-hide controls when playing
          if (_player.state.playing && _showControls) {
            _startControlsTimer();
          }

          // Show skip intro button
          if (widget.isMovie == false &&
              currentPosition >= 0 &&
              currentPosition <= 30) {
            if (!_showSkipIntroButton) {
              setState(() => _showSkipIntroButton = true);
            }
          } else {
            if (_showSkipIntroButton) {
              setState(() => _showSkipIntroButton = false);
            }
          }

          // Show skip recap button
          if (widget.isMovie == false &&
              currentPosition >= 60 &&
              currentPosition <= 120) {
            if (!_showSkipRecapButton) {
              setState(() => _showSkipRecapButton = true);
            }
          } else {
            if (_showSkipRecapButton) {
              setState(() => _showSkipRecapButton = false);
            }
          }
        });

        setState(() {
          _isPlayerReady = true;
          _isLoading = false;
        });

        // Show controls initially
        _showControlsWithAnimation();
      } catch (videoPlayerError) {
        debugPrint('Video player error: $videoPlayerError');
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to load video. Please check your internet connection and try again.';
        });
      }

      // Add a retry mechanism for failed autoplay
      if (_autoPlay && !_player.state.playing) {
        Future.delayed(const Duration(seconds: 2), () async {
          if (mounted && !_player.state.playing && _isPlayerReady) {
            try {
              await _player.play();
              debugPrint('Retry autoplay succeeded');
            } catch (e) {
              debugPrint('Retry autoplay failed: $e');
              // Show a play button overlay if autoplay fails
              setState(() {
                _showPlayButton = true;
              });
            }
          }
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load video. Please check your internet connection and try again.';
      });
    }
  }

  /// Get video alignment based on resize mode setting
  Alignment _getVideoAlignment() {
    return Alignment.center;
  }

  /// Get optimized HTTP headers for streaming URLs
  Map<String, String> _getOptimizedHeaders(String? url) {
    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Referer': 'https://vidsrc.to/',
      'Accept': '*/*',
      'Accept-Encoding': 'gzip, deflate, br',
      'Accept-Language': 'en-US,en;q=0.9',
    };

    // For HLS streams, add additional headers
    if (url != null && url.contains('.m3u8')) {
      headers.addAll({
        'Origin': 'https://vidsrc.to',
        'Sec-Fetch-Dest': 'video',
        'Sec-Fetch-Mode': 'cors',
        'Sec-Fetch-Site': 'cross-site',
      });
    }

    return headers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main video player
          Center(child: _buildVideoPlayer()),

          // Buffering indicator
          if (_isBuffering) _buildBufferingIndicator(),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // Error overlay
          if (_errorMessage != null) _buildErrorOverlay(),

          // Custom controls
          _buildCustomControls(),

          // Subtitle overlay
          if (_currentSubtitleText != null && _currentSubtitleText!.isNotEmpty)
            _buildSubtitleOverlay(),

          // More info panel
          if (_showMoreInfo) _buildMoreInfoPanel(),

          // Playback settings panel
          if (_showPlaybackSettings) _buildPlaybackSettingsPanel(),

          // Subtitles panel
          if (_showSubtitlesPanel) _buildSubtitlesPanel(),

          // Skip buttons
          if (_showSkipIntroButton) _buildSkipIntroButton(),
          if (_showSkipRecapButton) _buildSkipRecapButton(),

          // Audio tracks panel
          if (_showAudioTracksPanel) _buildAudioTracksPanel(),

          // Play button overlay for failed autoplay
          if (_showPlayButton) _buildPlayButtonOverlay(),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (!_isPlayerReady) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: widget.posterUrl != null
            ? Image.network(
                widget.posterUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.movie, size: 100, color: Colors.white24),
              )
            : const Icon(Icons.movie, size: 100, color: Colors.white24),
      );
    }

    return GestureDetector(
      onTap: _toggleControlsVisibility,
      onDoubleTap: _togglePlayPause,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Container(
          color: Colors.black,
          alignment: _getVideoAlignment(),
          child: SizedBox(
            width: _resizeMode == 'Stretch' || _resizeMode == 'Fill'
                ? double.infinity
                : null,
            height: _resizeMode == 'Stretch' || _resizeMode == 'Fill'
                ? double.infinity
                : null,
            child: Video(
              controller: _videoController,
              // Add fit parameter to ensure video fills the container
              fit: _resizeMode == 'Stretch'
                  ? BoxFit.fill
                  : _resizeMode == 'Fill'
                  ? BoxFit.cover
                  : BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomControls() {
    return AnimatedBuilder(
      animation: _controlsAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _showControls ? _controlsAnimation.value : 0.0,
          child: Stack(
            children: [
              // Netflix-style bottom overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withAlpha((255 * 0.8).round()),
                        Colors.black.withAlpha((255 * 0.4).round()),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress bar
                          _buildProgressBar(),

                          const SizedBox(height: 16),

                          // Controls row
                          Row(
                            children: [
                              // Play/Pause button
                              _buildControlButton(
                                icon: _player.state.playing
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                onPressed: _togglePlayPause,
                                size: 32,
                              ),

                              const SizedBox(width: 16),

                              // Current time
                              Text(
                                _formatDuration(_player.state.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),

                              const Spacer(),

                              // Mute/Unmute button
                              _buildControlButton(
                                icon: _isMuted
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                onPressed: _toggleMute,
                                size: 24,
                              ),

                              const SizedBox(width: 16),

                              // Settings button
                              _buildControlButton(
                                icon: Icons.settings,
                                onPressed: () => setState(
                                  () => _showPlaybackSettings =
                                      !_showPlaybackSettings,
                                ),
                                size: 24,
                              ),

                              const SizedBox(width: 16),

                              // Total duration
                              Text(
                                _formatDuration(_totalDuration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _buildProgressBar() {
    return StreamBuilder<Duration>(
      stream: _player.streams.position,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.state.duration;

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            if (duration.inSeconds > 0) {
              final seekAmount = (details.delta.dx * _seekSensitivity / 2)
                  .toInt();
              final newPosition = position.inSeconds + seekAmount;
              final clampedPosition = newPosition
                  .clamp(0, duration.inSeconds)
                  .toDouble();
              _player.seek(Duration(seconds: clampedPosition.toInt()));
            }
          },
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: duration.inSeconds > 0
                      ? position.inSeconds / duration.inSeconds
                      : 0,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required double size,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }

  Widget _buildBufferingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.red),
            SizedBox(height: 16),
            Text('Buffering...', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: AnimatedBuilder(
          animation: _loadingAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _loadingAnimation.value * 3.14159 * 2,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.withAlpha(
                      (_loadingAnimation.value * 255).toInt(),
                    ),
                    width: 3,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleOverlay() {
    if (!_subtitlesEnabled) {
      return const SizedBox.shrink();
    }

    // Determine vertical position based on setting
    final verticalPosition = _subtitlePosition == 'Top'
        ? 80.0
        : _subtitlePosition == 'Center'
        ? null
        : 100.0;

    return Positioned(
      bottom: _subtitlePosition == 'Center' ? null : verticalPosition,
      top: _subtitlePosition == 'Center'
          ? MediaQuery.of(context).size.height / 2 - 20
          : null,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _subtitleBackgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _currentSubtitleText ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _subtitleTextColor,
              fontSize: _subtitleTextSize,
              fontWeight: FontWeight.w500,
              fontFamily: _subtitleFont == 'Default' ? null : _subtitleFont,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreInfoPanel() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.userRating != null)
                  Text(
                    'Rating: ${widget.userRating!.toStringAsFixed(1)}/10',
                    style: const TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => setState(() => _showMoreInfo = false),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackSettingsPanel() {
    return Positioned(
      top: 60,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSettingsTile('Speed', _playbackSpeed.toString(), () {
              _showSpeedOptions();
            }),
            _buildSettingsTile('Quality', 'Auto', () {
              _showQualityOptions();
            }),
            _buildSettingsTile('Subtitles', 'English', () {
              setState(() {
                _showSubtitlesPanel = true;
                _showPlaybackSettings = false;
              });
            }),
            _buildSettingsTile('Audio', 'Default', () {
              setState(() {
                _showAudioTracksPanel = true;
                _showPlaybackSettings = false;
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$label: $value', style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtitlesPanel() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Subtitles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._availableSubtitles.map((subtitle) {
                  return ListTile(
                    title: Text(
                      subtitle['language'] ?? 'Unknown',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _selectSubtitle(subtitle),
                  );
                }),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => setState(() => _showSubtitlesPanel = false),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioTracksPanel() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Audio Tracks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ..._availableAudioTracks.map((track) {
                  return ListTile(
                    title: Text(
                      '${track['language']} (${track['channels']})',
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () => _selectAudioTrack(track),
                  );
                }),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () =>
                      setState(() => _showAudioTracksPanel = false),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipIntroButton() {
    return Positioned(
      top: 60,
      right: 16,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: _skipIntro,
        child: const Text('Skip Intro'),
      ),
    );
  }

  Widget _buildSkipRecapButton() {
    return Positioned(
      top: 60,
      right: 16,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: _skipRecap,
        child: const Text('Skip Recap'),
      ),
    );
  }

  Widget _buildPlayButtonOverlay() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          iconSize: 80,
          icon: const Icon(Icons.play_circle_fill, color: Colors.white),
          onPressed: () async {
            setState(() {
              _showPlayButton = false;
            });
            try {
              await _player.play();
            } catch (e) {
              debugPrint('Manual play failed: $e');
            }
          },
        ),
      ),
    );
  }

  void _toggleControlsVisibility() {
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _showControlsWithAnimation();
    } else {
      _controlsAnimationController.reverse();
    }
  }

  void _showControlsWithAnimation() {
    _controlsAnimationController.forward();
    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _player.state.playing) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _togglePlayPause() async {
    if (_player.state.playing) {
      _player.pause();
    } else {
      try {
        await _player.play();
        // Hide play button overlay if it was showing
        if (_showPlayButton) {
          setState(() {
            _showPlayButton = false;
          });
        }
      } catch (e) {
        debugPrint('Play failed: $e');
      }
    }
    setState(() {});
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      _player.setVolume(0);
    } else {
      _player.setVolume(100);
    }
  }

  void _selectSubtitle(Map<String, dynamic> subtitle) {
    setState(() {
      _showSubtitlesPanel = false;
    });

    if (subtitle['url'] != null) {
      _loadSubtitleContent(subtitle['url']);
    } else {
      _currentSubtitles = [];
      _currentSubtitleText = null;
      _subtitleTimer?.cancel();
    }

    debugPrint('Selected subtitle: ${subtitle['language']}');
  }

  Future<void> _loadSubtitleContent(String url) async {
    try {
      final dio = Dio();
      final response = await dio.get(url);
      final content = response.data as String;

      if (url.contains('.vtt')) {
        _currentSubtitles = _parseVTT(content);
      } else if (url.contains('.srt')) {
        _currentSubtitles = _parseSRT(content);
      }

      _startSubtitleTimer();
    } catch (e) {
      debugPrint('Failed to load subtitle content: $e');
    }
  }

  List<Map<String, dynamic>> _parseVTT(String content) {
    final subtitles = <Map<String, dynamic>>[];
    final lines = content.split('\n');
    int i = 0;

    while (i < lines.length && lines[i].trim().isNotEmpty) {
      i++;
    }

    while (i < lines.length) {
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i >= lines.length) break;

      if (lines[i].trim().contains('-->')) {
        // This line contains timing
      } else {
        i++;
        if (i >= lines.length) break;
      }

      final timingLine = lines[i].trim();
      final timingMatch = RegExp(
        r'(\d{2}:\d{2}:\d{2}\.\d{3}) --> (\d{2}:\d{2}:\d{2}\.\d{3})',
      ).firstMatch(timingLine);
      if (timingMatch != null) {
        final startTime = _parseTime(timingMatch.group(1)!);
        final endTime = _parseTime(timingMatch.group(2)!);

        i++;

        final textLines = <String>[];
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          textLines.add(lines[i].trim());
          i++;
        }

        subtitles.add({
          'start': startTime,
          'end': endTime,
          'text': textLines.join('\n'),
        });
      } else {
        i++;
      }
    }

    return subtitles;
  }

  List<Map<String, dynamic>> _parseSRT(String content) {
    final subtitles = <Map<String, dynamic>>[];
    final blocks = content.split('\n\n');

    for (final block in blocks) {
      final lines = block.split('\n');
      if (lines.length < 3) continue;

      int lineIndex = 1;

      final timingLine = lines[lineIndex].trim();
      final timingMatch = RegExp(
        r'(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})',
      ).firstMatch(timingLine);
      if (timingMatch != null) {
        final startTime = _parseTime(
          timingMatch.group(1)!.replaceAll(',', '.'),
        );
        final endTime = _parseTime(timingMatch.group(2)!.replaceAll(',', '.'));

        lineIndex++;

        final textLines = <String>[];
        while (lineIndex < lines.length) {
          textLines.add(lines[lineIndex].trim());
          lineIndex++;
        }

        subtitles.add({
          'start': startTime,
          'end': endTime,
          'text': textLines.join('\n'),
        });
      }
    }

    return subtitles;
  }

  Duration _parseTime(String timeString) {
    final parts = timeString.split(':');
    final secondsParts = parts[2].split('.');

    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(secondsParts[0]);
    final milliseconds = int.parse(secondsParts[1]);

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }

  void _startSubtitleTimer() {
    _subtitleTimer?.cancel();
    _subtitleTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_currentSubtitles.isNotEmpty) {
        final currentPosition = _player.state.position;

        final currentSubtitle = _currentSubtitles.firstWhere(
          (sub) =>
              currentPosition >= sub['start'] && currentPosition <= sub['end'],
          orElse: () => <String, dynamic>{},
        );

        final newText = currentSubtitle['text'] as String?;
        if (newText != _currentSubtitleText) {
          setState(() {
            _currentSubtitleText = newText;
          });
        }
      }
    });
  }

  Future<void> _loadAvailableSubtitles() async {
    try {
      _availableSubtitles = [
        {'language': 'English', 'code': 'en'},
        {'language': 'Spanish', 'code': 'es'},
        {'language': 'French', 'code': 'fr'},
      ];
    } catch (e) {
      debugPrint('Failed to load subtitles: $e');
    }
  }

  Future<void> _loadAvailableAudioTracks() async {
    try {
      _availableAudioTracks = [
        {'language': 'English', 'code': 'en', 'channels': '2.0'},
        {'language': 'Spanish', 'code': 'es', 'channels': '2.0'},
        {'language': 'French', 'code': 'fr', 'channels': '5.1'},
      ];
    } catch (e) {
      debugPrint('Failed to load audio tracks: $e');
    }
  }

  void _selectAudioTrack(Map<String, dynamic> audioTrack) {
    setState(() {
      _showAudioTracksPanel = false;
    });
    debugPrint(
      'Selected audio track: ${audioTrack['language']} (${audioTrack['channels']})',
    );
  }

  void _setupPictureInPicture() {}

  void _skipIntro() {
    _player.seek(const Duration(seconds: 30));
    setState(() => _showSkipIntroButton = false);
  }

  void _skipRecap() {
    _player.seek(const Duration(seconds: 120));
    setState(() => _showSkipRecapButton = false);
  }

  void _showSpeedOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...['0.5x', '0.75x', '1.0x', '1.25x', '1.5x', '2.0x'].map(
              (speed) => ListTile(
                title: Text(speed, style: const TextStyle(color: Colors.white)),
                trailing:
                    _playbackSpeed == double.parse(speed.replaceAll('x', ''))
                    ? const Icon(Icons.check, color: Colors.red)
                    : null,
                onTap: () {
                  final newSpeed = double.parse(speed.replaceAll('x', ''));
                  setState(() => _playbackSpeed = newSpeed);
                  _player.setRate(newSpeed);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQualityOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Video Quality',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...['Auto', '1080p', '720p', '480p', '360p'].map(
              (quality) => ListTile(
                title: Text(
                  quality,
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: quality == 'Auto'
                    ? const Icon(Icons.check, color: Colors.red)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _startProgressTracking() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_player.state.playing) {
        _saveWatchHistory();
      }
    });
  }

  Future<void> _loadWatchHistory() async {
    _lastPosition = await WatchHistoryService.loadWatchPosition(
      widget.tmdbId,
      widget.isMovie,
      widget.season,
      widget.episode,
    );
  }

  Future<void> _saveWatchHistory() async {
    final position = _player.state.position;
    final duration = _player.state.duration;

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

  @override
  void dispose() {
    _saveWatchHistory();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    _subtitleTimer?.cancel();
    _player.dispose();
    _controlsAnimationController.dispose();
    _loadingAnimationController.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }
}
