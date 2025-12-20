import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'dart:async';
import 'dart:convert';
import '../services/watch_history_service.dart';
import '../services/settings_service.dart';
import '../services/combined_stream_service.dart';

class InAppVideoPlayerScreen extends StatefulWidget {
  final String? videoUrl;
  final String title;
  final String tmdbId;
  final bool isMovie;
  final int season;
  final int episode;
  final String? posterUrl;
  final double? userRating;

  const InAppVideoPlayerScreen({
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
  State<InAppVideoPlayerScreen> createState() => _InAppVideoPlayerScreenState();
}

class _InAppVideoPlayerScreenState extends State<InAppVideoPlayerScreen>
    with TickerProviderStateMixin {
  late InAppWebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  // Animation controllers
  late AnimationController _controlsAnimationController;
  late Animation<double> _controlsAnimation;

  Timer? _controlsTimer;
  Timer? _progressTimer;
  Duration _lastPosition = Duration.zero;

  // Playback settings
  bool _showControls = true;
  bool _autoPlay = true;
  bool _rememberPosition = true;

  // Skip detection
  bool _showSkipIntro = false;
  bool _showSkipOutro = false;
  int _skipIntroEndTime = 30;

  // Settings from SettingsService
  Map<String, dynamic> _playerSettings = {};

  // Stream source
  String? _streamSource;

  // New player features
  double _volume = 1.0;
  // ignore: unused_field
  double _playbackSpeed = 1.0;
  bool _isTheaterMode = false;
  double _subtitleSync = 0.0; // in seconds
  int _selectedAudioTrack = 0;
  List<String> _availableAudioTracks = ['Default'];
  bool _showAudioTracksMenu = false;
  bool _showSubtitleSyncMenu = false;

  // Gesture controls
  bool _showRewindIndicator = false;
  bool _showForwardIndicator = false;
  Timer? _hideRewindTimer;
  Timer? _hideForwardTimer;

  // Quality and PiP features
  String _currentQuality = 'Auto';
  final List<String> _availableQualities = ['Auto'];
  int _selectedQualityIndex = 0;
  bool _isPictureInPicture = false;
  bool _showQualityMenu = false;

  // Volume gesture control
  bool _showVolumeIndicator = false;
  Timer? _hideVolumeTimer;

  // Ad-blocker enhancement
  int _blockedAdsCount = 0;
  bool _playerFrozen = false;
  Timer? _freezeDetectionTimer;

  // Performance & caching
  static const Duration _cacheExpiration = Duration(hours: 1);
  static final Map<String, dynamic> _streamCache = {};
  static final Map<String, DateTime> _streamCacheTime = {};

  @override
  void initState() {
    super.initState();
    // Force landscape orientation for better video viewing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _setupAnimations();
    _loadSettings();
    _loadWatchHistory();
    _clearExpiredCache(); // Clean up expired cache entries
    _initializePlayer();
  }

  void _setupAnimations() {
    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _controlsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controlsAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadSettings() async {
    try {
      _playerSettings = await SettingsService.getAllPlayerSettings();

      // Apply player settings to state variables
      _autoPlay = _playerSettings['autoPlay'] ?? true;
      _rememberPosition = _playerSettings['rememberPosition'] ?? true;
    } catch (e) {
      debugPrint('Error loading settings: $e');
      _autoPlay = true;
      _rememberPosition = true;
    }
  }

  /// Ad blocking JavaScript injection
  String _getAdBlockingScript() {
    return '''
    (function() {
      // Initialize ad-blocking state
      if (typeof window.adBlockerState === 'undefined') {
        window.adBlockerState = {
          blockedCount: 0
        };
      }
      
      // Block common ad networks
      const adDomains = [
        'google', 'doubleclick', 'googlesyndication', 'googleadservices',
        'pagead', 'adsbygoogle', 'ads-service', 'ads', 'advertising',
        'adv', 'banner', 'amazon-adsystem', 'amazon', 'criteo', 'adzerk',
        'aol', 'yahoo', 'bing', 'facebook', 'fb', 'twitter', 'chartbeat',
        'rubicon', 'openx', 'pubmatic', 'appnexus', 'innity', 'adverticum'
      ];
      
      // Block ad iframes
      const iframes = document.querySelectorAll('iframe');
      iframes.forEach(function(iframe) {
        let shouldBlock = false;
        const src = iframe.src || '';
        const id = iframe.id || '';
        const className = iframe.className || '';
        
        adDomains.forEach(domain => {
          if (src.includes(domain) || id.includes(domain) || className.includes(domain)) {
            shouldBlock = true;
          }
        });
        
        if (shouldBlock || src.includes('ad') || src.includes('advertisement')) {
          window.adBlockerState.blockedCount++;
          iframe.style.display = 'none';
          iframe.remove();
        }
      });
      
      // Block ad divs
      const adClasses = ['ad', 'ads', 'advertisement', 'advert', 'banner', 'sponsor', 'ad-container'];
      const adDivs = document.querySelectorAll('[class*="ad"], [id*="ad"], [class*="sponsor"]');
      adDivs.forEach(function(div) {
        const className = div.className || '';
        const id = div.id || '';
        
        if (adClasses.some(cls => className.toLowerCase().includes(cls) || id.toLowerCase().includes(cls))) {
          window.adBlockerState.blockedCount++;
          div.style.display = 'none';
        }
      });
      
      // Block scripts from ad networks
      const scripts = document.querySelectorAll('script');
      scripts.forEach(function(script) {
        const src = script.src || '';
        let shouldBlock = false;
        
        adDomains.forEach(domain => {
          if (src.includes(domain)) {
            shouldBlock = true;
          }
        });
        
        if (shouldBlock) {
          window.adBlockerState.blockedCount++;
          script.remove();
        }
      });
      
      // Inject global ad blockers
      window.adsbygoogle = [];
      window.googletag = {
        cmd: [],
        defineSlot: function() { return this; },
        addService: function() { return this; },
        enableServices: function() { return this; },
        pubads: function() { return this; },
        display: function() { return this; }
      };
      
      // Report blocked count to Flutter
      if (Flutterplayer && Flutterplayer.postMessage && window.adBlockerState.blockedCount > 0) {
        Flutterplayer.postMessage(JSON.stringify({
          action: 'adsBlocked',
          count: window.adBlockerState.blockedCount
        }));
      }
    })();
    ''';
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Try to get cached stream result first
      final cacheKey = '${widget.tmdbId}_${widget.season}_${widget.episode}';
      final cachedResult = _getFromCache(cacheKey);

      String? bestUrl;
      if (cachedResult != null) {
        bestUrl = cachedResult['streamUrl'];
        _streamSource = cachedResult['source'];
        debugPrint(
          'InAppPlayer: Using cached stream URL: $bestUrl from $_streamSource',
        );
      } else {
        // Extract stream URL using CombinedStreamService
        final streamResult = await CombinedStreamService.extractStream(
          widget.tmdbId,
          widget.isMovie,
          season: widget.season,
          episode: widget.episode,
        );

        if (streamResult != null && streamResult['streamUrl'] != null) {
          bestUrl = streamResult['streamUrl'];
          _streamSource = streamResult['source'];
          // Cache the result
          _saveToCache(cacheKey, streamResult);
          debugPrint(
            'InAppPlayer: Using extracted stream URL: $bestUrl from $_streamSource',
          );
        } else {
          bestUrl = widget.videoUrl;
          _streamSource = null;
          debugPrint('InAppPlayer: Using fallback video URL: $bestUrl');
        }
      }

      if (bestUrl == null) {
        throw Exception('No video URL available');
      }

      // Build HTML5 video player with controls
      final htmlContent = _buildVideoHtml(bestUrl);

      if (!mounted) return;

      // Load HTML content
      await _webViewController.loadData(
        data: htmlContent,
        mimeType: 'text/html',
        encoding: 'utf8',
      );

      // Resume from last position if enabled
      if (_rememberPosition && _lastPosition.inSeconds > 0) {
        // Position will be restored via JavaScript player API when ready
        await _webViewController.evaluateJavascript(
          source:
              '''
            const player = document.getElementById('videoPlayer');
            player.addEventListener('loadedmetadata', function() {
              player.currentTime = ${_lastPosition.inSeconds};
            });
          ''',
        );
      }

      _startProgressTracking();
      _startControlsTimer();
      _startFreezeDetection();

      setState(() {
        _isLoading = false;
      });

      _showControlsWithAnimation();
    } catch (e) {
      debugPrint('InAppPlayer error: $e');
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load video. Please check your internet connection and try again.';
      });
    }
  }

  String _buildVideoHtml(String videoUrl) {
    return '''
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <meta http-equiv="Cache-Control" content="max-age=3600">
      <meta http-equiv="Pragma" content="cache">
      <style>
        * {
          margin: 0;
          padding: 0;
          box-sizing: border-box;
        }
        body {
          background: #000;
          width: 100%;
          height: 100%;
          display: flex;
          align-items: center;
          justify-content: center;
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
        }
        video {
          width: 100%;
          height: 100%;
          max-width: 100%;
          max-height: 100%;
          display: block;
        }
        .container {
          width: 100%;
          height: 100vh;
          display: flex;
          align-items: center;
          justify-content: center;
          background: #000;
        }
        .player-ui {
          position: absolute;
          top: 0;
          left: 0;
          width: 100%;
          height: 100%;
          pointer-events: none;
          display: flex;
          flex-direction: column;
        }
        .player-controls {
          pointer-events: auto;
          color: white;
          font-size: 14px;
        }
        .theater-indicator {
          position: absolute;
          top: 10px;
          right: 10px;
          background: rgba(0, 0, 0, 0.6);
          color: white;
          padding: 4px 8px;
          border-radius: 3px;
          font-size: 12px;
          display: none;
        }
        .theater-indicator.active {
          display: block;
        }
        .quality-indicator {
          position: absolute;
          top: 10px;
          left: 10px;
          background: rgba(0, 0, 0, 0.6);
          color: white;
          padding: 4px 8px;
          border-radius: 3px;
          font-size: 12px;
        }
        .pip-indicator {
          position: absolute;
          bottom: 10px;
          left: 10px;
          background: rgba(0, 0, 0, 0.6);
          color: white;
          padding: 4px 8px;
          border-radius: 3px;
          font-size: 12px;
          display: none;
        }
        .pip-indicator.active {
          display: block;
        }
        .play-pause-button {
          position: absolute;
          top: 50%;
          left: 50%;
          transform: translate(-50%, -50%);
          width: 80px;
          height: 80px;
          background: rgba(0, 0, 0, 0.5);
          border: 3px solid white;
          border-radius: 50%;
          display: none;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          z-index: 10;
          transition: background 0.3s ease;
        }
        .play-pause-button:hover {
          background: rgba(255, 255, 255, 0.2);
        }
        .play-pause-button.hidden {
          display: none;
        }
        .play-pause-button.show {
          display: flex;
        }
        .play-pause-icon {
          width: 0;
          height: 0;
          border-left: 25px solid white;
          border-top: 15px solid transparent;
          border-bottom: 15px solid transparent;
          margin-left: 5px;
        }
        .pause-icon {
          width: 6px;
          height: 40px;
          background: white;
          margin: 0 5px;
        }
      </style>
    </head>
    <body>
      <div class="container">
         <video 
           id="videoPlayer" 
           controlsList="nodownload"
           playsinline
           crossorigin="anonymous"
           style="width: 100%; height: 100%; object-fit: contain;">
           Your browser does not support the video tag.
         </video>
        <div id="playPauseButton" class="play-pause-button">
          <div id="playIcon" class="play-pause-icon"></div>
          <div id="pauseIcon" style="display: none;">
            <div class="pause-icon"></div>
            <div class="pause-icon"></div>
          </div>
        </div>
        <div id="theaterIndicator" class="theater-indicator">Theater Mode</div>
        <div id="qualityIndicator" class="quality-indicator">Auto</div>
        <div id="pipIndicator" class="pip-indicator">Picture in Picture</div>
      </div>
      
      <script>
        ${_getAdBlockingScript()}
        
        // Save progress to Flutter
         const player = document.getElementById('videoPlayer');
         const theaterIndicator = document.getElementById('theaterIndicator');
         const playPauseButton = document.getElementById('playPauseButton');
         const playIcon = document.getElementById('playIcon');
         const pauseIcon = document.getElementById('pauseIcon');
         let lastProgressUpdate = 0;
         let introSkipped = false;
         let outroSkipped = false;
         
         // Player state
         let playerVolume = 1.0;
         let playerSpeed = 1.0;
         let isTheaterMode = false;
         let subtitleSync = 0; // seconds offset
         let currentAudioTrack = 0;
         let currentQuality = 'Auto';
         let isPictureInPicture = false;
         
         // Freeze detection
         let lastPlaybackPosition = 0;
         let frozenCheckCount = 0;
         let reportedFrozen = false;
         
         // Skip intro detection (typically 0-30 seconds)
         const INTRO_END = 30;
         // Skip outro detection (typically 3-5 minutes before end or 85%+ of video)
         const OUTRO_START_PERCENT = 0.85;
         
         // Play/Pause button functionality
         function updatePlayPauseIcon() {
           if (player.paused) {
             playIcon.style.display = 'block';
             pauseIcon.style.display = 'none';
           } else {
             playIcon.style.display = 'none';
             pauseIcon.style.display = 'flex';
           }
         }
         
         playPauseButton.addEventListener('click', function() {
           if (player.paused) {
             player.play();
           } else {
             player.pause();
           }
           updatePlayPauseIcon();
         });
         
         player.addEventListener('play', updatePlayPauseIcon);
         player.addEventListener('pause', updatePlayPauseIcon);
         
         // Hide play button when playing, show when paused or ended
         player.addEventListener('play', function() {
           playPauseButton.style.opacity = '0.3';
           playPauseButton.style.pointerEvents = 'auto';
         });
         
         player.addEventListener('pause', function() {
           playPauseButton.style.opacity = '1';
           playPauseButton.style.pointerEvents = 'auto';
         });
         
         // Initialize icon
         updatePlayPauseIcon();
         
         // Load video source dynamically
         const videoUrl = '$videoUrl';
         console.log('📺 Video URL: ' + videoUrl);
         
         // Clear any existing sources
         player.innerHTML = '';
         
         // Create source element dynamically
         const source = document.createElement('source');
         source.src = videoUrl;
         
         // Determine video type based on URL
         if (videoUrl.includes('.m3u8') || videoUrl.includes('master.m3u8')) {
           source.type = 'application/x-mpegURL';
           console.log('🎬 Format: HLS (m3u8)');
         } else if (videoUrl.includes('.mpd')) {
           source.type = 'application/dash+xml';
           console.log('🎬 Format: DASH (mpd)');
         } else {
           source.type = 'video/mp4';
           console.log('🎬 Format: MP4');
         }
         
         source.setAttribute('crossorigin', 'anonymous');
         player.appendChild(source);
         
         console.log('✓ Source element appended');
         
         // Force reload to apply source
         player.load();
         console.log('✓ Player.load() called');
         
         // Error handling and logging
         player.addEventListener('error', function() {
           console.error('Video error:', player.error);
           if (player.error) {
             let errorMessage = 'Unknown error';
             switch(player.error.code) {
               case player.error.MEDIA_ERR_ABORTED:
                 errorMessage = 'Video loading aborted';
                 break;
               case player.error.MEDIA_ERR_NETWORK:
                 errorMessage = 'Network error loading video';
                 break;
               case player.error.MEDIA_ERR_DECODE:
                 errorMessage = 'Error decoding video';
                 break;
               case player.error.MEDIA_ERR_SRC_NOT_SUPPORTED:
                 errorMessage = 'Video source not supported';
                 break;
             }
             console.error('Player error: ' + errorMessage);
             if (Flutterplayer && Flutterplayer.postMessage) {
               Flutterplayer.postMessage(JSON.stringify({
                 action: 'playerError',
                 message: errorMessage,
                 code: player.error.code
               }));
             }
           }
         });
         
         // Log when metadata is loaded
         player.addEventListener('loadedmetadata', function() {
           console.log('✓ Video metadata loaded: ' + player.duration + 's');
           // Show play button when metadata is loaded
           playPauseButton.classList.add('show');
           updatePlayPauseIcon();
           
           // Auto-play if enabled
           if (${_autoPlay ? 'true' : 'false'}) {
             console.log('▶ Auto-playing video...');
             player.play().catch(function(error) {
               console.error('Auto-play failed:', error);
             });
           }
           
           if (Flutterplayer && Flutterplayer.postMessage) {
             Flutterplayer.postMessage(JSON.stringify({
               action: 'videoMetadataLoaded',
               duration: player.duration
             }));
           }
         });
         
         // Log when video can play
         player.addEventListener('canplay', function() {
           console.log('Video can play');
         });
         
         // Log loading states
         player.addEventListener('loadstart', function() {
           console.log('Video loading started');
         });
         
         player.addEventListener('playing', function() {
           console.log('Video started playing');
         });
         
         player.addEventListener('timeupdate', function() {
          const currentTime = player.currentTime;
          const duration = player.duration;
          
          // Auto-skip intro for TV series (only TV, not movies)
          if (currentTime > 5 && currentTime < INTRO_END && !introSkipped && duration > 1200) {
            // Only auto-skip if duration suggests it's a TV episode (>20 min)
            if (Flutterplayer && Flutterplayer.postMessage) {
              Flutterplayer.postMessage(JSON.stringify({
                action: 'skipDetected',
                skipType: 'intro',
                startTime: 0,
                endTime: INTRO_END
              }));
            }
            introSkipped = true;
          }
          
          // Detect outro for TV series
          if (duration > 0 && currentTime > duration * OUTRO_START_PERCENT && !outroSkipped && duration > 1200) {
            const outroStart = Math.floor(duration * OUTRO_START_PERCENT);
            if (Flutterplayer && Flutterplayer.postMessage) {
              Flutterplayer.postMessage(JSON.stringify({
                action: 'skipDetected',
                skipType: 'outro',
                startTime: outroStart,
                endTime: Math.floor(duration)
              }));
            }
            outroSkipped = true;
          }
          
          // Update progress (throttled to 1 per second)
          if (Date.now() - lastProgressUpdate > 1000) {
            if (Flutterplayer && Flutterplayer.postMessage) {
              Flutterplayer.postMessage(JSON.stringify({
                action: 'progressUpdate',
                position: currentTime,
                duration: duration,
                watchPercent: duration > 0 ? (currentTime / duration * 100) : 0
              }));
            }
            lastProgressUpdate = Date.now();
          }
        });
        
        player.addEventListener('loadedmetadata', function() {
          // Detect available audio tracks
          const audioTracks = [];
          if (player.audioTracks && player.audioTracks.length > 0) {
            for (let i = 0; i < player.audioTracks.length; i++) {
              const track = player.audioTracks[i];
              audioTracks.push({
                index: i,
                label: track.label || 'Audio Track ' + (i + 1),
                language: track.language || 'unknown',
                kind: track.kind || 'main'
              });
            }
          }
          
          if (audioTracks.length > 0 && Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'audioTracksDetected',
              tracks: audioTracks
            }));
          }
        });
        
        player.addEventListener('play', function() {
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({action: 'play'}));
          }
        });
        
        player.addEventListener('pause', function() {
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({action: 'pause'}));
          }
        });
        
        player.addEventListener('ended', function() {
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({action: 'ended'}));
          }
        });
        
        // Player control functions
        window.setPlayerVolume = function(volume) {
          playerVolume = Math.max(0, Math.min(1, volume));
          player.volume = playerVolume;
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'volumeChanged',
              volume: playerVolume
            }));
          }
        };
        
        window.setPlaybackSpeed = function(speed) {
          playerSpeed = speed;
          player.playbackRate = playerSpeed;
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'speedChanged',
              speed: playerSpeed
            }));
          }
        };
        
        window.setTheaterMode = function(enabled) {
          isTheaterMode = enabled;
          theaterIndicator.classList.toggle('active', enabled);
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'theaterModeChanged',
              enabled: isTheaterMode
            }));
          }
        };
        
        window.setSubtitleSync = function(offset) {
          subtitleSync = offset;
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'subtitleSyncChanged',
              offset: subtitleSync
            }));
          }
        };
        
        window.setAudioTrack = function(trackIndex) {
          currentAudioTrack = trackIndex;
          
          // Disable all audio tracks and enable the selected one
          if (player.audioTracks && player.audioTracks.length > 0) {
            for (let i = 0; i < player.audioTracks.length; i++) {
              player.audioTracks[i].enabled = (i === (trackIndex - 1));
            }
          }
          
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'audioTrackChanged',
              trackIndex: currentAudioTrack
            }));
          }
        };
        
        window.setQuality = function(quality) {
          currentQuality = quality;
          const qualityIndicator = document.getElementById('qualityIndicator');
          qualityIndicator.textContent = quality;
          
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'qualityChanged',
              quality: currentQuality
            }));
          }
        };
        
        window.togglePictureInPicture = function() {
          const pipIndicator = document.getElementById('pipIndicator');
          
          if (document.pictureInPictureEnabled) {
            if (document.pictureInPictureElement) {
              document.exitPictureInPicture().then(() => {
                isPictureInPicture = false;
                pipIndicator.classList.remove('active');
              }).catch(error => {
                console.log('Error exiting PiP: ' + error);
              });
            } else {
              player.requestPictureInPicture().then(() => {
                isPictureInPicture = true;
                pipIndicator.classList.add('active');
              }).catch(error => {
                console.log('Error entering PiP: ' + error);
              });
            }
          }
          
          if (Flutterplayer && Flutterplayer.postMessage) {
            Flutterplayer.postMessage(JSON.stringify({
              action: 'pipToggled',
              enabled: isPictureInPicture
            }));
          }
        };
        
        window.getBlockedAdsCount = function() {
          return window.adBlockerState ? window.adBlockerState.blockedCount : 0;
        };
        
        window.startFreezeDetection = function() {
          setInterval(function() {
            if (!player.paused && player.duration > 0) {
              const currentPos = player.currentTime;
              
              if (currentPos === lastPlaybackPosition) {
                frozenCheckCount++;
              } else {
                frozenCheckCount = 0;
                reportedFrozen = false;
                lastPlaybackPosition = currentPos;
              }
              
              // If player hasn't moved for 3 consecutive checks (3 seconds), it's frozen
              if (frozenCheckCount >= 3 && !reportedFrozen) {
                reportedFrozen = true;
                if (Flutterplayer && Flutterplayer.postMessage) {
                  Flutterplayer.postMessage(JSON.stringify({
                    action: 'playerFrozen',
                    currentTime: currentPos,
                    duration: player.duration
                  }));
                }
              }
              
              // Reset if video resumes
              if (frozenCheckCount > 0 && currentPos > lastPlaybackPosition) {
                frozenCheckCount = 0;
                reportedFrozen = false;
              }
            }
          }, 1000);
        };
        
        window.getPlayerState = function() {
          return {
            volume: playerVolume,
            speed: playerSpeed,
            theaterMode: isTheaterMode,
            subtitleSync: subtitleSync,
            audioTrack: currentAudioTrack,
            quality: currentQuality,
            pictureInPicture: isPictureInPicture,
            blockedAdsCount: window.adBlockerState ? window.adBlockerState.blockedCount : 0,
            currentTime: player.currentTime,
            duration: player.duration
          };
        };
        
        // Run ad blocking on load
        window.addEventListener('load', function() {
          ${_getAdBlockingScript()}
        });
        
        // Run ad blocking periodically to catch dynamically loaded ads
        setInterval(function() {
          ${_getAdBlockingScript()}
        }, 2000);
      </script>
    </body>
    </html>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView for video playback
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              useShouldOverrideUrlLoading: true,
              mediaPlaybackRequiresUserGesture: false,
              allowsInlineMediaPlayback: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              userAgent:
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              // Performance optimizations
              cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
              disableDefaultErrorPage: true,
              databaseEnabled: false,
              domStorageEnabled: false,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              // Add JavaScript channel for Flutter communication
              controller.addJavaScriptHandler(
                handlerName: 'Flutterplayer',
                callback: (args) {
                  if (args.isNotEmpty) {
                    try {
                      final data = args[0] as String;
                      _handlePlayerMessage(data);
                    } catch (e) {
                      debugPrint('Error handling player message: $e');
                    }
                  }
                },
              );
            },
            onLoadStop: (controller, url) {
              // Re-run ad blocking after page load
              controller.evaluateJavascript(source: _getAdBlockingScript());
            },
            shouldOverrideUrlLoading: (controller, navigationAction) async {
              final uri = navigationAction.request.url;

              // Block ad network URLs
              if (uri != null) {
                final uriString = uri.toString().toLowerCase();
                if (uriString.contains('google') ||
                    uriString.contains('doubleclick') ||
                    uriString.contains('ad') ||
                    uriString.contains('advertisement')) {
                  return NavigationActionPolicy.CANCEL;
                }
              }

              return NavigationActionPolicy.ALLOW;
            },
          ),

          // Left side gesture - double tap to rewind 10 seconds + volume control
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onDoubleTap: () {
                _handleLeftDoubleTap();
              },
              onVerticalDragUpdate: (details) {
                // Scroll up = increase volume
                // Scroll down = decrease volume
                final volumeChange = -details.delta.dy / 500;
                setState(() {
                  _volume = (_volume + volumeChange).clamp(0.0, 1.0);
                  _showVolumeIndicator = true;
                });
                _webViewController.evaluateJavascript(
                  source: 'window.setPlayerVolume($_volume);',
                );
                
                // Restart timer to hide indicator
                _hideVolumeTimer?.cancel();
                _hideVolumeTimer = Timer(const Duration(seconds: 1), () {
                  if (mounted) {
                    setState(() => _showVolumeIndicator = false);
                  }
                });
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // Right side gesture - double tap to forward 10 seconds
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: MediaQuery.of(context).size.width * 0.25,
            child: GestureDetector(
              onDoubleTap: () {
                _handleRightDoubleTap();
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // Volume indicator
          if (_showVolumeIndicator)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2 - 50,
              child: Container(
                width: 60,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _volume == 0
                          ? Icons.volume_off
                          : _volume < 0.5
                              ? Icons.volume_down
                              : Icons.volume_up,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_volume * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Rewind indicator (left side)
          if (_showRewindIndicator)
            Positioned(
              left: 16,
              top: MediaQuery.of(context).size.height / 2 - 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.replay_10,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '10s',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Forward indicator (right side)
          if (_showForwardIndicator)
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height / 2 - 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.forward_10,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '10s',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (_isLoading) _buildLoadingOverlay(),

          // Error overlay
          if (_errorMessage != null) _buildErrorOverlay(),

          // Skip Intro button
          if (_showSkipIntro) _buildSkipIntroButton(),

          // Skip Outro button
          if (_showSkipOutro) _buildSkipOutroButton(),

          // Controls
          _buildCustomControls(),
        ],
      ),
    );
  }

  Widget _buildSkipIntroButton() {
    return Positioned(
      top: 60,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() => _showSkipIntro = false);
            await _webViewController.evaluateJavascript(
              source:
                  'document.getElementById("videoPlayer").currentTime = $_skipIntroEndTime;',
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_next, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text(
                  'Skip Intro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkipOutroButton() {
    return Positioned(
      top: 60,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            setState(() => _showSkipOutro = false);
            await _webViewController.evaluateJavascript(
              source:
                  'document.getElementById("videoPlayer").currentTime = document.getElementById("videoPlayer").duration;',
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.skip_next, color: Colors.white, size: 18),
                SizedBox(width: 4),
                Text(
                  'Skip Outro',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
          child: GestureDetector(
            onTap: _toggleControlsVisibility,
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  // Top controls
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Theater mode indicator
                        if (_isTheaterMode)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Theater Mode',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        // Player frozen indicator
                        if (_playerFrozen)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'Player Frozen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        const Spacer(),
                        // Close button
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Bottom controls
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Audio tracks
                          _buildAudioTracksControl(),
                          // Subtitle sync
                          _buildSubtitleSyncControl(),
                          // Download subtitles
                          _buildDownloadSubtitlesControl(),
                          // Quality control
                          _buildQualityControl(),
                          // Picture in Picture
                          _buildPictureInPictureControl(),
                          // Theater mode toggle
                          _buildTheaterModeControl(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAudioTracksControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<int>(
          onSelected: (trackIndex) {
            setState(() {
              _selectedAudioTrack = trackIndex;
              _showAudioTracksMenu = false;
            });
            _webViewController.evaluateJavascript(
              source: 'window.setAudioTrack($trackIndex);',
            );
            _showControlsWithAnimation();
          },
          itemBuilder: (context) {
            return List.generate(
              _availableAudioTracks.length,
              (index) => PopupMenuItem(
                value: index,
                child: Row(
                  children: [
                    if (_selectedAudioTrack == index)
                      const Icon(Icons.check, color: Colors.red, size: 18),
                    if (_selectedAudioTrack == index) const SizedBox(width: 8),
                    Text(_availableAudioTracks[index]),
                  ],
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.audiotrack,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  setState(() => _showAudioTracksMenu = !_showAudioTracksMenu);
                  _showControlsWithAnimation();
                },
              ),
              Text(
                'Audio',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitleSyncControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.subtitles, color: Colors.white, size: 20),
          onPressed: () {
            setState(() {
              _showSubtitleSyncMenu = !_showSubtitleSyncMenu;
            });
            _showControlsWithAnimation();
          },
        ),
        if (_showSubtitleSyncMenu)
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _subtitleSync -= 0.5;
                        });
                        _webViewController.evaluateJavascript(
                          source: 'window.setSubtitleSync($_subtitleSync);',
                        );
                      },
                    ),
                    Text(
                      '${_subtitleSync.toStringAsFixed(1)}s',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _subtitleSync += 0.5;
                        });
                        _webViewController.evaluateJavascript(
                          source: 'window.setSubtitleSync($_subtitleSync);',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Text(
          'Subtitle',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildDownloadSubtitlesControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.download, color: Colors.white, size: 20),
          onPressed: () {
            _downloadSubtitles();
            _showControlsWithAnimation();
          },
        ),
        const Text('Subs', style: TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  Widget _buildQualityControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<int>(
          onSelected: (qualityIndex) {
            setState(() {
              _selectedQualityIndex = qualityIndex;
              _currentQuality = _availableQualities[qualityIndex];
              _showQualityMenu = false;
            });
            _webViewController.evaluateJavascript(
              source:
                  'window.setQuality("${_availableQualities[qualityIndex]}");',
            );
            _showControlsWithAnimation();
          },
          itemBuilder: (context) {
            return List.generate(
              _availableQualities.length,
              (index) => PopupMenuItem(
                value: index,
                child: Row(
                  children: [
                    if (_selectedQualityIndex == index)
                      const Icon(Icons.check, color: Colors.red, size: 18),
                    if (_selectedQualityIndex == index)
                      const SizedBox(width: 8),
                    Text(_availableQualities[index]),
                  ],
                ),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.hd, color: Colors.white, size: 20),
                onPressed: () {
                  setState(() => _showQualityMenu = !_showQualityMenu);
                  _showControlsWithAnimation();
                },
              ),
              Text(
                _currentQuality,
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPictureInPictureControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPictureInPicture
                ? Icons.picture_in_picture_alt
                : Icons.picture_in_picture,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _isPictureInPicture = !_isPictureInPicture;
            });
            _webViewController.evaluateJavascript(
              source: 'window.togglePictureInPicture();',
            );
            _showControlsWithAnimation();
          },
        ),
        const Text('PiP', style: TextStyle(color: Colors.white, fontSize: 10)),
      ],
    );
  }

  Widget _buildTheaterModeControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isTheaterMode ? Icons.fullscreen_exit : Icons.fullscreen,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () {
            setState(() {
              _isTheaterMode = !_isTheaterMode;
            });
            _webViewController.evaluateJavascript(
              source: 'window.setTheaterMode($_isTheaterMode);',
            );
            _showControlsWithAnimation();
          },
        ),
        const Text(
          'Theater',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Stack(
      children: [
        // Background with lazy-loaded poster image
        if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty)
          Container(
            color: Colors.black,
            child: Image.network(
              widget.posterUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: Colors.black);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Container(color: Colors.black);
              },
            ),
          )
        else
          Container(color: Colors.black),
        // Semi-transparent overlay with loading indicator
        Container(
          color: Colors.black87,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading ${widget.title}...',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Connecting to stream...',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorOverlay() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                });
                _initializePlayer();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _handlePlayerMessage(String message) {
    try {
      final data = jsonDecode(message) as Map<String, dynamic>;
      final action = data['action'] as String?;

      switch (action) {
        case 'progressUpdate':
          _lastPosition = Duration(
            seconds: (data['position'] as num?)?.toInt() ?? 0,
          );
          break;

        case 'skipDetected':
          final skipType = data['skipType'] as String?;
          final endTime = (data['endTime'] as num?)?.toInt() ?? 0;

          if (skipType == 'intro') {
            setState(() {
              _showSkipIntro = true;
              _skipIntroEndTime = endTime;
            });
            // Auto-hide after 8 seconds if not clicked
            Future.delayed(const Duration(seconds: 8), () {
              if (mounted && _showSkipIntro) {
                setState(() => _showSkipIntro = false);
              }
            });
          } else if (skipType == 'outro') {
            setState(() {
              _showSkipOutro = true;
            });
            // Auto-hide after 8 seconds if not clicked
            Future.delayed(const Duration(seconds: 8), () {
              if (mounted && _showSkipOutro) {
                setState(() => _showSkipOutro = false);
              }
            });
          }
          break;

        case 'volumeChanged':
          setState(() {
            _volume = (data['volume'] as num?)?.toDouble() ?? 1.0;
          });
          break;

        case 'speedChanged':
          setState(() {
            _playbackSpeed = (data['speed'] as num?)?.toDouble() ?? 1.0;
          });
          break;

        case 'theaterModeChanged':
          setState(() {
            _isTheaterMode = data['enabled'] as bool? ?? false;
          });
          // Auto-rotate to landscape when theatre mode is enabled
          if (_isTheaterMode) {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          } else {
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
          }
          break;

        case 'subtitleSyncChanged':
          setState(() {
            _subtitleSync = (data['offset'] as num?)?.toDouble() ?? 0.0;
          });
          break;

        case 'audioTrackChanged':
          setState(() {
            _selectedAudioTrack = (data['trackIndex'] as num?)?.toInt() ?? 0;
          });
          break;

        case 'audioTracksDetected':
          final tracks = data['tracks'] as List?;
          if (tracks != null && tracks.isNotEmpty) {
            setState(() {
              _availableAudioTracks = [
                'Default',
                ...tracks.map((track) {
                  final label = track['label'] as String? ?? 'Audio Track';
                  final language = track['language'] as String? ?? '';
                  return language.isNotEmpty && language != 'unknown'
                      ? '$label ($language)'
                      : label;
                }),
              ];
            });
          }
          break;

        case 'qualityChanged':
          setState(() {
            _currentQuality = (data['quality'] as String?) ?? 'Auto';
          });
          break;

        case 'pipToggled':
          setState(() {
            _isPictureInPicture = data['enabled'] as bool? ?? false;
          });
          break;

        case 'adsBlocked':
          setState(() {
            _blockedAdsCount += (data['count'] as num?)?.toInt() ?? 0;
          });
          break;

        case 'playerFrozen':
          setState(() {
            _playerFrozen = true;
          });
          _handlePlayerFreeze(
            (data['currentTime'] as num?)?.toDouble() ?? 0.0,
            (data['duration'] as num?)?.toDouble() ?? 0.0,
          );
          break;

        case 'ended':
          _handleVideoEnded();
          break;

        case 'playerError':
          final errorMessage = data['message'] as String?;
          final errorCode = data['code'] as int?;
          debugPrint('InAppPlayer error from JS: $errorMessage (code: $errorCode)');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Video playback error: $errorMessage'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
          break;

        case 'videoMetadataLoaded':
          final duration = data['duration'] as num?;
          debugPrint('Video metadata loaded: ${duration}s');
          break;

        default:
          debugPrint('Unknown player action: $action');
      }
    } catch (e) {
      debugPrint('Error parsing player message: $e');
    }
  }

  void _handleVideoEnded() {
    // Mark as watched and auto-advance to next episode
    WatchHistoryService.markAsWatched(
      widget.tmdbId,
      widget.isMovie,
      widget.season,
      widget.episode,
    );

    if (!widget.isMovie) {
      // For TV series, show "Next Episode" dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Episode Finished',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Mark as watched?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _downloadSubtitles() async {
    try {
      // Extract subtitles from HTML5 video element
      final subtitleData = await _webViewController.evaluateJavascript(
        source: '''
          (function() {
            const textTracks = document.getElementById('videoPlayer').textTracks;
            const subtitles = [];
            
            if (textTracks && textTracks.length > 0) {
              for (let i = 0; i < textTracks.length; i++) {
                const track = textTracks[i];
                if (track.kind === 'subtitles' || track.kind === 'captions') {
                  subtitles.push({
                    label: track.label || 'Subtitle ' + (i + 1),
                    lang: track.srclang || 'unknown',
                    kind: track.kind,
                    src: track.src || ''
                  });
                }
              }
            }
            return subtitles;
          })();
        ''',
      );

      if (subtitleData != null &&
          subtitleData is List &&
          subtitleData.isNotEmpty) {
        // Show subtitle options
        if (!mounted) return;

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.grey[900],
          builder: (context) => Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Available Subtitles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(subtitleData.length, (index) {
                  final subtitle = subtitleData[index] as Map<String, dynamic>;
                  final label =
                      subtitle['label'] as String? ?? 'Subtitle $index';
                  final lang = subtitle['lang'] as String? ?? 'Unknown';
                  final src = subtitle['src'] as String? ?? '';

                  return ListTile(
                    title: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      lang,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(
                      Icons.file_download,
                      color: Colors.red,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showSubtitleInfo(label, lang, src);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No subtitles available'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error extracting subtitles: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading subtitles: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSubtitleInfo(String label, String language, String source) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(label, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Language:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(language, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            const Text(
              'Source:',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              source.isNotEmpty ? source : 'Embedded in video',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: Subtitle files are typically embedded in the video stream or linked from the source. To download, use a video downloader tool that supports subtitle extraction.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _handlePlayerFreeze(double currentTime, double duration) {
    if (!mounted) return;

    debugPrint(
      'Player freeze detected at ${currentTime.toStringAsFixed(2)}s of ${duration.toStringAsFixed(2)}s',
    );
    debugPrint('Blocked ads during session: $_blockedAdsCount');

    // Show notification
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Video Playback Frozen',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The video player appears to be frozen. Try refreshing or switching sources.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Position: ${currentTime.toStringAsFixed(0)}s',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _playerFrozen = false);
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _startFreezeDetection() {
    _freezeDetectionTimer?.cancel();
    _webViewController.evaluateJavascript(
      source: 'window.startFreezeDetection();',
    );
  }

  void _handleLeftDoubleTap() {
    // Rewind 10 seconds
    _webViewController.evaluateJavascript(
      source: '''
        const player = document.getElementById('videoPlayer');
        player.currentTime = Math.max(0, player.currentTime - 10);
      ''',
    );

    setState(() {
      _showRewindIndicator = true;
    });

    _hideRewindTimer?.cancel();
    _hideRewindTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showRewindIndicator = false);
      }
    });
  }

  void _handleRightDoubleTap() {
    // Forward 10 seconds
    _webViewController.evaluateJavascript(
      source: '''
        const player = document.getElementById('videoPlayer');
        player.currentTime = Math.min(player.duration, player.currentTime + 10);
      ''',
    );

    setState(() {
      _showForwardIndicator = true;
    });

    _hideForwardTimer?.cancel();
    _hideForwardTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _showForwardIndicator = false);
      }
    });
  }

  /// Cache management methods
  void _saveToCache(String key, dynamic value) {
    _streamCache[key] = value;
    _streamCacheTime[key] = DateTime.now();
  }

  dynamic _getFromCache(String key) {
    final cachedTime = _streamCacheTime[key];
    if (cachedTime == null) return null;

    // Check if cache has expired
    if (DateTime.now().difference(cachedTime) > _cacheExpiration) {
      _streamCache.remove(key);
      _streamCacheTime.remove(key);
      return null;
    }

    return _streamCache[key];
  }

  void _clearExpiredCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    _streamCacheTime.forEach((key, cacheTime) {
      if (now.difference(cacheTime) > _cacheExpiration) {
        keysToRemove.add(key);
      }
    });

    for (final key in keysToRemove) {
      _streamCache.remove(key);
      _streamCacheTime.remove(key);
    }

    debugPrint('Cache cleanup: Removed ${keysToRemove.length} expired entries');
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
      if (mounted) {
        setState(() {
          _showControls = false;
        });
        _controlsAnimationController.reverse();
      }
    });
  }

  void _startProgressTracking() {
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _saveWatchHistory();
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
    // Save position (InAppWebView doesn't provide direct position access)
    // This would be handled through JavaScript communication
    await WatchHistoryService.saveWatchProgress(
      tmdbId: widget.tmdbId,
      title: widget.title,
      isMovie: widget.isMovie,
      season: widget.season,
      episode: widget.episode,
      position: _lastPosition,
      duration: Duration.zero,
    );
  }

  @override
  void dispose() {
    _saveWatchHistory();
    _controlsTimer?.cancel();
    _progressTimer?.cancel();
    _freezeDetectionTimer?.cancel();
    _hideVolumeTimer?.cancel();
    _hideRewindTimer?.cancel();
    _hideForwardTimer?.cancel();

    _controlsAnimationController.dispose();
    CombinedStreamService.dispose();

    // Reset orientation to allow both portrait and landscape
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
}
