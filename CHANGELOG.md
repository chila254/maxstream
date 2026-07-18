# Changelog

> [!NOTE]
> This release was built faster for a streamlined UX for the user and the download functionality. Download support is now available for movies and series. We are still working to improve streaming functionality.

## 1.3.0+5

### What's New
- Download movies directly from the movie details screen
- Download individual episodes from series screen
- Download entire seasons with queued episode processing
- Background download support with foreground service and wakelock
- Download retry logic for failed downloads

### Features
- Movie download button on details screen
- Episode download button on each episode row
- Download Season action for currently selected season
- Foreground service for background downloads
- Wakelock to keep device awake during downloads
- Download retry mechanism for failed downloads

### Bug Fixes
- Fix media download build error by moving local path persistence into download manager

## 1.2.0+4

### What's New
- Server switching capability in the video player
- Grouped series display in Watch History
- Enhanced subtitle support with TTML, ASS/SSA parsers
- Aspect ratio toggle for video playback (fit/stretch/zoom)
- Improved progress bar with better visibility and seek handle
- Community stream extraction support

### Features
- Add server switching in player
- Show media title at top left (movie name for movies, series+episode name for series)
- Implemented grouped series in Watch History
- Harden playback recovery, extend time-based buffering and validate Community streams
- Improve playback resilience with extended Media3 buffering
- Integrate Community stream extraction and stabilize adaptive playback
- Add WebView-based MaxstreamVideo extractor for Cloudflare-protected maxstream.video
- Add changelog display from GitHub release body in update dialog
- Add PrimeSrc WebView link resolution + Voe/Streamtape HTTP extraction
- Add pure HTTP extractors: PrimeSrc → Voe/Streamtape extraction
- Add detailed progress messages to video player for debugging
- Add flutter_inappwebview dependency
- Add GitHub Actions workflow for automated APK builds
- Add Flutter platform files (ios, linux, macos, windows)
- Replicated TV app code to import from 'utils/index.dart' instead of individual utility files
- Removed Netflix-specific features and implemented MaxStream-specific features
- Refactored TV screens to use TvContentCard widget
- Refactor TV widgets for improved responsiveness and animations
- Removed TV-specific code and dependencies
- Removed all files and directories related to a Flutter project on iOS and Windows
- Removed Flutter project files and configurations for a macOS app
- Update minSdk in android/app/build.gradle.kts to use flutter.minSdkVersion
- Refactored TV screens to improve focus and selection functionality
- Added keyboard navigation support to various TV screens
- Added TV D-Pad Navigation mixin and various TV-specific widgets and screens
- Refactor TV app to support multiple device types (phone, TV) and add TV-specific features
- Added TV pairing feature and dependencies
- Updated ad blocking and network security configurations
- Updated code with changes to video player functionality
- Updated code to reflect changes in ad domains, added Peacock and Paramount+ providers, and added haptic feedback to provider selection
- Updated embedded video servers and providers
- Updated code to reflect changes in streaming providers and network security
- Removed unused code and updated imports
- Renamed OnStream to MaxStream in various files
- Updated codebase with various changes, including database schema updates, new features, and refactored code
- Removed FijkPlayer and FilmBoomService, replaced with WebViewFlutter
- Updated video player plugin from video_player to fijkplayer
- Refactor: Get video URL directly from FilmBoom service
- Removed EmbedDiscoveryService and StreamExtractionService, replaced with FilmBoomService for video URL extraction and Chewie for video playback
- Removed Chewie and VideoPlayer dependencies, replaced direct URL extraction with embed URL return
- Added JavaScript extraction for dynamically loaded content and fallback extraction from HTML
- Updated InAppVideoPlayerScreen to use Chewie instead of BetterPlayer
- Refactor InAppVideoPlayerScreen to use BetterPlayer for direct video URLs and maintain existing embed functionality
- Refactor inapp_video_player_screen.dart to update onShouldOverrideUrlLoading and onLoadStop handlers
- Added support for overriding URL loading and creating windows in InAppVideoPlayerScreen
- Added embed future and updated FutureBuilder to use it
- Removed unused code and services: StreamExtractionService, SettingsService, PlayerSettingsUtils, and StreamProvider
- Refactor StreamExtractionService to use direct embed URLs instead of resolving playable URLs
- Removed FIX_SUMMARY.md, STREAM_SERVICE_QUICK_REFERENCE.md, and STREAM_SERVICE_UNIFICATION.md files
- Removed combined stream service and related files, replaced with stream extraction service
- Refactor image cropping and resizing logic
- Refactored code in multiple files, removed unused code, and added new functionality
- Added permissions for USE_CREDENTIALS and GET_ACCOUNTS, updated player settings, and added image picker functionality
- Refactor ad blocking script to only target iframe-based ads and preserve playback scripts
- Delete .github/workflows directory
- Refactor in-app video player to support HLS and embed URLs
- Updated code with various changes across multiple files
- Refactor StreamResolverService to improve extraction strategies and add connection reset functionality
- Update VidSrc.to to VidSrc.me in multiple files
- Update Android app build.gradle.kts and remove google.services.json file
- Add GitHub Actions workflow for Dart CI
- Update keystore properties loading in Android build.gradle.kts
- Added Firebase/Google Services configuration and signing credentials to .gitignore and updated Android build.gradle.kts to load signing credentials from keystore.properties

### Bug Fixes
- Fix VixSrc source errors with HLS segment validation and support VidLink JSON subtitles
- Fix VixSrc ExoPlayer playback by forwarding OkHttp cookies
- Add TTML subtitle parser, fix autoplay overlay race condition, fix VTT parser cue merging
- Fix VixSrc ExoPlayer error with Origin header, add ASS/SSA subtitle parser for VidLink captions
- Fix next episode popup showing immediately when switching episodes, fix VixSrc ExoPlayer source error by using main domain as Referer
- Restore VideoProgressIndicator progress bar from commit 6e2840b
- Fix progress bar: wrap controls in Positioned.fill, improve bar visibility with thicker track, gradient buffer, and seek handle
- Fix subtitle HTTP 404, add aspect ratio toggle (fit/stretch/zoom), improve buffering and loading indicators, remove dead Moviesapi server
- Fix profile delete not-found error, add pre-buffering for smoother HLS playback
- Fix profile upload await, search results scrolling, and back button navigation to home
- Fix missing semicolon in subtitle ValueListenableBuilder return
- Fix subtitle display: ValueNotifier for reactive controls, VTT parser, nested rebuild
- Fix VidsrcRuExtractor: add WebResourceRequest/WebResourceResponse imports, fix return label
- Group subtitles by source server, fix subtitle display, and add source labels to all extractors
- Harden stream extraction: resilient extractServer, multi-route Vidrock/Videasy, VixSrc 410 retry, VidsrcNet subtitles, add Frembed provider
- Fix subtitle 404 by resolving relative URLs to absolute in VidLink and Vidflix extractors
- Stabilize playback, add quality controls and restore watch progress
- Validate extracted streams before initializing playback
- Refactor native stream resolution with provider and extractor registries
- Fix Kotlin: add explicit extension function imports for OkHttp 4.x
- Fix Kotlin build: add okhttp-dnsoverhttps, fix extension function imports
- Complete stream extraction: VixSrc, Vidrock, Vidzee, Videasy, Voe, Streamtape, PrimeSrc + DNS-over-HTTPS
- Fix stream extraction: use direct provider APIs instead of PrimeSrc Cloudflare
- Fix Kotlin build: add OkHttp + org.json deps, fix Pattern.DOTALL
- Replace WebView extractors with native Kotlin OkHttp extractor
- Fix VidLinkExtractor not rendering during loading phase
- Fix provider_preferences table missing for existing users
- Update .gitignore
- Pin flutter_inappwebview to 6.2.0-beta.3 to fix AGP 9 proguard error
- Change Flutter channel from beta to stable
- Switch CI to Flutter beta to fix AGP compatibility with flutter_inappwebview
- Restore working stream extraction: hidden VidLink WebView + native Chewie player
- Fix formatting for flutter_inappwebview dependency
- Replace broken API sources with working VixSrc and Vidrock extractors
- Fix regex syntax errors and unawaited futures in direct_m3u8_service
- Remove WebView fallback, use native player with multiple API sources
- Remove unsupported playedColorAtDragStart from ChewieProgressColors
- Improve video player: fix progress bar visibility, control positioning, and buffering
- Fix provider preference errors: align mismatched provider IDs (Apple TV 192→350, AMC+ 591→526) and add upsert fallback in setProviderPreference
- Stabilize playback and prevent automatic server switching
- Fix playback stability: extract VidLink playlist natively, use desktop UA
- Fix signing: write storePassword/keyAlias/keyPassword to keystore.properties (was key.properties)
- Fix signing: write android/keystore.properties to match build.gradle.kts
- Fix workflow: map secrets to env so conditionals work (google-services + keystore)
- Fix workflow: reference GOOGLE_SERVICES_JSON secret directly so google-services.json is written
- Fix AGP 9 build: upgrade flutter_inappwebview to 6.2.0-beta.3 (proguard-android fix)
- Temporarily disable minification and add proguard rules for flutter_inappwebview compatibility
- Update NDK version to 28.2.13676358 (required by Flutter 3.24)
- Update to JVM 21 and NDK 29.0.13124710
- Update Android configuration: fix Gradle/NDK compatibility and update dependencies
- Fix streaming functionality: update embed sources and improve video extraction

## 1.1.0+3

### Initial Release
- Base functionality with streaming support