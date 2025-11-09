import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:dio/dio.dart';
import '../services/watch_history_service.dart';
import '../services/settings_service.dart';
import '../services/stream_extraction_service.dart';
import 'dart:async';

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
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
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
  double _volume = 1.0;
  bool _isMuted = false;

  // Settings from SettingsService
  Map<String, dynamic> _subtitleSettings = {};
  Map<String, dynamic> _playerSettings = {};

  // Subtitle state
  List<Map<String, dynamic>> _currentSubtitles = [];
  String? _currentSubtitleText;
  Timer? _subtitleTimer;

  // Netflix-like features
  bool _showMoreInfo = false;
  bool _showPlaybackSettings = false;
  bool _showSubtitlesPanel = false;
  bool _isInPictureInPicture = false;
  bool _isCasting = false;
  bool _showSkipIntroButton = false;
  bool _showSkipRecapButton = false;
  bool _showAudioTracksPanel = false;
  List<Map<String, dynamic>> _availableSubtitles = [];
  List<Map<String, dynamic>> _availableAudioTracks = [];
  Map<String, dynamic>? _selectedSubtitle;
  Map<String, dynamic>? _selectedAudioTrack;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
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
      _subtitleSettings = await SettingsService.getAllSubtitleSettings();
      _playerSettings = await SettingsService.getAllPlayerSettings();

      // Apply subtitle settings
      // _showSubtitles = _subtitleSettings['enabled'] ?? true;

      // Load available subtitles and audio tracks
      await _loadAvailableSubtitles();
      await _loadAvailableAudioTracks();

      // Apply player settings
      // Auto play setting will be used in _initializePlayer

      setState(() {});
    } catch (e) {}
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      String? bestUrl = widget.videoUrl;

      // If videoUrl is not provided, extract the stream
      if (bestUrl == null) {
        final streamData = await StreamExtractionService.extractStream(
          widget.tmdbId,
          widget.isMovie,
          season: widget.season,
          episode: widget.episode,
        );
        if (streamData != null && streamData['streamUrl'] != null) {
          bestUrl = streamData['streamUrl'];
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Failed to load video stream. Please try again.';
          });
          return;
        }
      }

      // Use native video player only

      // Try to initialize native video player for direct streams
      try {
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(bestUrl!),
          httpHeaders: _getOptimizedHeaders(bestUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );

        await _videoPlayerController!.initialize();

        // Set up video controller listeners
        _videoPlayerController!.addListener(_videoListener);

        // Resume from last position if available
        if (_lastPosition.inSeconds > 0) {
          await _videoPlayerController!.seekTo(_lastPosition);
        }

        // Apply player settings
        final autoPlay = _playerSettings['autoPlay'] ?? true;

        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: autoPlay,
          looping: false,
          allowFullScreen: false, // We handle fullscreen ourselves
          allowMuting: true,
          showControls: false, // Use custom controls
          aspectRatio: 16 / 9,
          placeholder: _buildLoadingWidget(),
          errorBuilder: (context, errorMessage) =>
              _buildErrorWidget(errorMessage),
          progressIndicatorDelay: const Duration(seconds: 3),
          hideControlsTimer: const Duration(seconds: 5),
        );

        _totalDuration = _videoPlayerController!.value.duration;
        _startProgressTracking();
        _startControlsTimer();

        // Set initial volume to ensure videos start unmuted
        await _videoPlayerController!.setVolume(1.0);

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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load video. Please check your internet connection and try again.';
      });
    }
  }

  /// Get optimized HTTP headers for streaming URLs
  /// Supports HLS (M3U8) and direct streams with proper Referer and User-Agent
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

  void _videoListener() {
    if (_videoPlayerController == null) return;

    final value = _videoPlayerController!.value;
    final currentPosition = value.position.inSeconds;

    // Handle buffering state
    if (value.isBuffering != _isBuffering) {
      setState(() {
        _isBuffering = value.isBuffering;
      });
    }

    // Auto-hide controls when playing
    if (value.isPlaying && _showControls) {
      _startControlsTimer();
    }

    // Show skip intro button (0-30 seconds for TV shows)
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

    // Show skip recap button (for TV shows, typically after intro)
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

    if (_chewieController != null) {
      return GestureDetector(
        onTap: _toggleControlsVisibility,
        onDoubleTap: _togglePlayPause,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Chewie(controller: _chewieController!),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: const Center(child: CircularProgressIndicator(color: Colors.red)),
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
                      stops: [0.0, 0.7, 1.0],
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
                                icon:
                                    _videoPlayerController?.value.isPlaying ==
                                        true
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                onPressed: _togglePlayPause,
                                size: 32,
                              ),

                              const SizedBox(width: 16),

                              // Current time
                              Text(
                                _formatDuration(
                                  _videoPlayerController?.value.position ??
                                      Duration.zero,
                                ),
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

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    double size = 32,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha((255 * 0.5).round()),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: size),
        padding: EdgeInsets.all(size * 0.25),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_videoPlayerController == null) return const SizedBox();

    return ValueListenableBuilder(
      valueListenable: _videoPlayerController!,
      builder: (context, VideoPlayerValue value, child) {
        final progress =
            value.position.inMilliseconds / value.duration.inMilliseconds;

        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.red,
            inactiveTrackColor: Colors.white.withAlpha((255 * 0.3).round()),
            thumbColor: Colors.red,
            overlayColor: Colors.red.withAlpha((255 * 0.2).round()),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 4,
          ),
          child: Slider(
            value: progress.isNaN ? 0.0 : progress.clamp(0.0, 1.0),
            onChanged: (newValue) {
              final newPosition = Duration(
                milliseconds: (newValue * value.duration.inMilliseconds)
                    .round(),
              );
              _videoPlayerController!.seekTo(newPosition);
            },
            onChangeStart: (_) => _pauseControlsTimer(),
            onChangeEnd: (_) => _startControlsTimer(),
          ),
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _loadingAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _loadingAnimation.value * 2 * 3.14159,
                  child: const CircularProgressIndicator(
                    color: Colors.red,
                    strokeWidth: 3,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Loading video...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Please wait while we prepare your content',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withAlpha((255 * 0.8).round()),
      child: _buildLoadingWidget(),
    );
  }

  Widget _buildBufferingIndicator() {
    return Positioned.fill(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha((255 * 0.7).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.red, strokeWidth: 2),
              SizedBox(height: 8),
              Text(
                'Buffering...',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Playback Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initializePlayer,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudioTracksPanel() {
    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        width: 250,
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha((255 * 0.9).round()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Audio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showAudioTracksPanel = false),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Audio track options
              ..._availableAudioTracks.map(
                (audioTrack) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${audioTrack['language']} (${audioTrack['channels']})',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: _selectedAudioTrack?['code'] == audioTrack['code']
                      ? const Icon(Icons.check, color: Colors.red)
                      : null,
                  onTap: () => _selectAudioTrack(audioTrack),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withAlpha((255 * 0.9).round()),
      child: _buildErrorWidget(_errorMessage!),
    );
  }

  Widget _buildMoreInfoPanel() {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      child: Container(
        width: 300,
        color: Colors.black.withAlpha((255 * 0.9).round()),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'More Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => setState(() => _showMoreInfo = false),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (widget.userRating != null)
                  _buildInfoRow('Rating', '${widget.userRating}/10'),

                _buildInfoRow('Type', widget.isMovie ? 'Movie' : 'TV Series'),

                if (!widget.isMovie)
                  _buildInfoRow(
                    'Episode',
                    'S${widget.season} E${widget.episode}',
                  ),

                const SizedBox(height: 24),

                // Episode navigation for TV series
                if (!widget.isMovie) ...[
                  const Text(
                    'Episode Navigation',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: widget.episode > 1
                              ? _previousEpisode
                              : null,
                          icon: const Icon(Icons.skip_previous),
                          label: const Text('Previous'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.episode > 1
                                ? Colors.red
                                : Colors.grey,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _nextEpisode,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('Next'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                ListTile(
                  leading: const Icon(Icons.download, color: Colors.white),
                  title: const Text(
                    'Download',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    _downloadVideo();
                    Navigator.pop(context);
                  },
                ),

                ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text(
                    'Share',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    // TODO: Implement share functionality
                    Navigator.pop(context);
                  },
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
      bottom: 120,
      right: 16,
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Playback Settings',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showPlaybackSettings = false),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Playback speed
              _buildSettingsRow(
                'Speed',
                '${_playbackSpeed}x',
                () => _showSpeedOptions(),
              ),

              // Volume
              _buildVolumeSlider(),

              const SizedBox(height: 16),

              // Quality (placeholder)
              _buildSettingsRow('Quality', 'Auto', () => _showQualityOptions()),

              // Subtitles
              _buildSettingsRow(
                'Subtitles',
                _selectedSubtitle?['language'] ?? 'Off',
                _openSubtitlesPanel,
              ),

              // Picture-in-Picture
              _buildSettingsRow(
                'Picture-in-Picture',
                _isInPictureInPicture ? 'On' : 'Off',
                _togglePictureInPicture,
              ),

              // Cast
              _buildSettingsRow(
                'Cast',
                _isCasting ? 'Connected' : 'Available',
                _toggleCast,
              ),

              // Audio
              _buildSettingsRow(
                'Audio',
                _selectedAudioTrack?['language'] ?? 'Default',
                _openAudioTracksPanel,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitlesPanel() {
    return Positioned(
      bottom: 120,
      right: 16,
      child: Container(
        width: 250,
        constraints: const BoxConstraints(maxHeight: 300),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Subtitles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () =>
                        setState(() => _showSubtitlesPanel = false),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Subtitle options
              ..._availableSubtitles.map(
                (subtitle) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    subtitle['language'],
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: _selectedSubtitle?['code'] == subtitle['code']
                      ? const Icon(Icons.check, color: Colors.red)
                      : null,
                  onTap: () => _selectSubtitle(subtitle),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkipIntroButton() {
    return Positioned(
      bottom: 200,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextButton.icon(
          onPressed: _skipIntro,
          icon: const Icon(Icons.fast_forward, color: Colors.white),
          label: const Text(
            'Skip Intro',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipRecapButton() {
    return Positioned(
      bottom: 250,
      right: 16,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextButton.icon(
          onPressed: _skipRecap,
          icon: const Icon(Icons.fast_forward, color: Colors.white),
          label: const Text(
            'Skip Recap',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitleOverlay() {
    return Positioned(
      bottom: _subtitleSettings['position'] ?? 160.0, // Above the controls
      left: 16,
      right: 16,
      child: Container(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _currentSubtitleText!,
            style: TextStyle(
              color: Colors.white,
              fontSize: _subtitleSettings['fontSize'] ?? 16.0,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsRow(String label, String value, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: Text(value, style: const TextStyle(color: Colors.white70)),
      onTap: onTap,
    );
  }

  Widget _buildVolumeSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Volume',
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.red,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.red,
            overlayColor: Colors.red.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            trackHeight: 3,
          ),
          child: Slider(
            value: _volume,
            onChanged: (value) {
              setState(() {
                _volume = value;
                _isMuted = false; // Unmute when volume slider is adjusted
              });
              _videoPlayerController?.setVolume(value);
            },
          ),
        ),
      ],
    );
  }

  // Control methods
  void _toggleControlsVisibility() {
    // For Netflix-style, tapping anywhere shows/hides the bottom overlay
    setState(() {
      _showControls = !_showControls;
    });

    if (_showControls) {
      _showControlsWithAnimation();
    } else {
      _hideControlsWithAnimation();
    }
  }

  void _showControlsWithAnimation() {
    _controlsAnimationController.forward();
    _startControlsTimer();
  }

  void _hideControlsWithAnimation() {
    _controlsAnimationController.reverse();
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _videoPlayerController?.value.isPlaying == true) {
        setState(() => _showControls = false);
        _hideControlsWithAnimation();
      }
    });
  }

  void _pauseControlsTimer() {
    _controlsTimer?.cancel();
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;

    if (_videoPlayerController!.value.isPlaying) {
      _videoPlayerController!.pause();
    } else {
      _videoPlayerController!.play();
    }

    _startControlsTimer();
  }

  void _toggleMute() {
    if (_videoPlayerController == null) return;

    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) {
        _videoPlayerController!.setVolume(0.0);
      } else {
        _videoPlayerController!.setVolume(_volume);
      }
    });
  }

  Future<void> _loadAvailableSubtitles() async {
    try {
      // Fetch available subtitles from TMDb API or other sources
      // For now, we'll create mock subtitle options with URLs
      final baseUrl = 'https://your-vercel-app.vercel.app/api/sub-proxy?url=';
      final token =
          'xK9mP2qR7sT4vW8yZ3aB6cE9fH1jL5nQ'; // Same token as in sub-proxy.js

      _availableSubtitles = [
        {
          'language': 'English',
          'code': 'en',
          'url': '${baseUrl}https://example.com/subtitles/en.vtt&token=$token',
        },
        {
          'language': 'Spanish',
          'code': 'es',
          'url': '${baseUrl}https://example.com/subtitles/es.vtt&token=$token',
        },
        {
          'language': 'French',
          'code': 'fr',
          'url': '${baseUrl}https://example.com/subtitles/fr.vtt&token=$token',
        },
        {
          'language': 'German',
          'code': 'de',
          'url': '${baseUrl}https://example.com/subtitles/de.vtt&token=$token',
        },
        {'language': 'Off', 'code': 'off', 'url': null},
      ];

      // Set default subtitle based on settings
      final defaultLanguage = _subtitleSettings['language'] ?? 'en';
      _selectedSubtitle = _availableSubtitles.firstWhere(
        (sub) => sub['code'] == defaultLanguage,
        orElse: () => _availableSubtitles.first,
      );
    } catch (e) {
      print('Failed to load subtitles: $e');
    }
  }

  void _openSubtitlesPanel() {
    setState(() {
      _showSubtitlesPanel = !_showSubtitlesPanel;
      _showPlaybackSettings = false; // Close other panels
    });
  }

  void _selectSubtitle(Map<String, dynamic> subtitle) {
    setState(() {
      _selectedSubtitle = subtitle;
      _showSubtitlesPanel = false;
    });

    // Load subtitle content if URL is provided
    if (subtitle['url'] != null) {
      _loadSubtitleContent(subtitle['url']);
    } else {
      // Turn off subtitles
      _currentSubtitles = [];
      _currentSubtitleText = null;
      _subtitleTimer?.cancel();
    }

    // Save subtitle preference (mock implementation)
    print('Selected subtitle: ${subtitle['language']}');
  }

  Future<void> _loadSubtitleContent(String url) async {
    try {
      final dio = Dio();
      final response = await dio.get(url);
      final content = response.data as String;

      // Parse VTT or SRT content
      if (url.contains('.vtt')) {
        _currentSubtitles = _parseVTT(content);
      } else if (url.contains('.srt')) {
        _currentSubtitles = _parseSRT(content);
      }

      // Start subtitle timer
      _startSubtitleTimer();
    } catch (e) {
      print('Failed to load subtitle content: $e');
    }
  }

  List<Map<String, dynamic>> _parseVTT(String content) {
    final subtitles = <Map<String, dynamic>>[];
    final lines = content.split('\n');
    int i = 0;

    // Skip WEBVTT header
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      i++;
    }

    while (i < lines.length) {
      // Skip empty lines
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i >= lines.length) break;

      // Parse sequence number (optional)
      if (lines[i].trim().contains('-->')) {
        // This line contains timing
      } else {
        i++; // Skip sequence number
        if (i >= lines.length) break;
      }

      // Parse timing
      final timingLine = lines[i].trim();
      final timingMatch = RegExp(
        r'(\d{2}:\d{2}:\d{2}\.\d{3}) --> (\d{2}:\d{2}:\d{2}\.\d{3})',
      ).firstMatch(timingLine);
      if (timingMatch != null) {
        final startTime = _parseTime(timingMatch.group(1)!);
        final endTime = _parseTime(timingMatch.group(2)!);

        i++; // Move to text

        // Collect text lines
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

      // Skip sequence number
      int lineIndex = 1;

      // Parse timing
      final timingLine = lines[lineIndex].trim();
      final timingMatch = RegExp(
        r'(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})',
      ).firstMatch(timingLine);
      if (timingMatch != null) {
        final startTime = _parseTime(
          timingMatch.group(1)!.replaceAll(',', '.'),
        );
        final endTime = _parseTime(timingMatch.group(2)!.replaceAll(',', '.'));

        lineIndex++; // Move to text

        // Collect text lines
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
      if (_videoPlayerController != null && _currentSubtitles.isNotEmpty) {
        final currentPosition = _videoPlayerController!.value.position;

        // Find current subtitle
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

  Future<void> _loadAvailableAudioTracks() async {
    try {
      // For now, we'll create mock audio track options
      // In a real implementation, you would detect available audio tracks from the video
      _availableAudioTracks = [
        {'language': 'English', 'code': 'en', 'channels': '2.0'},
        {'language': 'Spanish', 'code': 'es', 'channels': '2.0'},
        {'language': 'French', 'code': 'fr', 'channels': '5.1'},
        {'language': 'German', 'code': 'de', 'channels': '2.0'},
      ];

      // Set default audio track
      _selectedAudioTrack = _availableAudioTracks.first;
    } catch (e) {
      print('Failed to load audio tracks: $e');
    }
  }

  void _openAudioTracksPanel() {
    setState(() {
      _showAudioTracksPanel = !_showAudioTracksPanel;
      _showPlaybackSettings = false; // Close other panels
    });
  }

  void _selectAudioTrack(Map<String, dynamic> audioTrack) {
    setState(() {
      _selectedAudioTrack = audioTrack;
      _showAudioTracksPanel = false;
    });

    // Apply audio track selection (mock implementation)
    print(
      'Selected audio track: ${audioTrack['language']} (${audioTrack['channels']})',
    );
  }

  void _setupPictureInPicture() {
    // Picture-in-Picture setup would go here
    // For now, we'll add a button to toggle PiP mode
  }

  void _togglePictureInPicture() {
    setState(() {
      _isInPictureInPicture = !_isInPictureInPicture;
    });

    if (_isInPictureInPicture) {
      // Enter Picture-in-Picture mode
      // In a real implementation, this would use platform-specific APIs
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture-in-Picture mode enabled')),
      );
    } else {
      // Exit Picture-in-Picture mode
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Picture-in-Picture mode disabled')),
      );
    }
  }

  void _toggleCast() {
    setState(() {
      _isCasting = !_isCasting;
    });

    if (_isCasting) {
      // Start casting
      // In a real implementation, this would use platform-specific casting APIs
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Casting to device...')));
    } else {
      // Stop casting
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stopped casting')));
    }
  }

  void _skipIntro() {
    if (_videoPlayerController != null) {
      // Skip to 30 seconds (typical intro length)
      _videoPlayerController!.seekTo(const Duration(seconds: 30));
      setState(() => _showSkipIntroButton = false);
    }
  }

  void _skipRecap() {
    if (_videoPlayerController != null) {
      // Skip to 2 minutes (typical recap + intro length)
      _videoPlayerController!.seekTo(const Duration(seconds: 120));
      setState(() => _showSkipRecapButton = false);
    }
  }

  Future<void> _downloadVideo() async {
    try {
      // Show a loading indicator
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Starting download...')));

      // Get the URL to download
      String downloadUrl = widget.videoUrl ?? '';
      if (downloadUrl.isEmpty) {
      final streamData = await StreamExtractionService.extractStream(
      widget.tmdbId,
      widget.isMovie,
      season: widget.season,
      episode: widget.episode,
      );
        if (streamData != null && streamData['streamUrl'] != null) {
          downloadUrl = streamData['streamUrl'];
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download failed: No stream URL found'),
            ),
          );
          return;
        }
      }

      // Download functionality not yet implemented
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download functionality coming soon')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Download error: $e')));
    }
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
                  _videoPlayerController?.setPlaybackSpeed(newSpeed);
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
                  // TODO: Implement quality selection
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
      if (_videoPlayerController != null &&
          _videoPlayerController!.value.isPlaying) {
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
    if (_videoPlayerController == null) return;

    final position = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;

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

  // Episode navigation methods
  void _previousEpisode() {
    if (widget.isMovie || widget.episode <= 1) return;

    _navigateToEpisode(widget.season, widget.episode - 1);
  }

  void _nextEpisode() {
    if (widget.isMovie) return;

    _navigateToEpisode(widget.season, widget.episode + 1);
  }

  void _navigateToEpisode(int season, int episode) {
    // For now, we'll use a placeholder URL that will be processed by the PHP proxy
    // In a real implementation, you would construct the appropriate URL for your content
    final contentUrl =
        'https://example.com/tv/${widget.tmdbId}/$season/$episode';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ModernVideoPlayerScreen(
          videoUrl: contentUrl,
          title: widget.title,
          tmdbId: widget.tmdbId,
          isMovie: false,
          season: season,
          episode: episode,
          posterUrl: widget.posterUrl,
          userRating: widget.userRating,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _saveWatchHistory();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    _subtitleTimer?.cancel();
    _videoPlayerController?.removeListener(_videoListener);
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _controlsAnimationController.dispose();
    _loadingAnimationController.dispose();

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    super.dispose();
  }
}
