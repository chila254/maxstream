# Changelog

## 1.6.0+8

> [!NOTE]
> This release modernizes mobile Search with Top Searched / Most Watched and voice search, makes Recommendations live after any watch (including TV), adds official Website/GitHub links, and polishes the native TV player (subtitles, focus, watchlist) while hardening stability on both platforms.

### What's New
- **Mobile Search redesign** — idle state shows **Top Searched** (trending) and **Most Watched** (popular) carousels (`Top Searched`/`Most Watched` fetched in parallel with safe fallbacks); unified results screen for **All / Movies / TV Shows / Actors** with `All` aggregating all media types and separate grids for each tab
- **Voice search** — integrated `speech_to_text 6.6.0` with `RECORD_AUDIO` permission, single-pill search bar (no left icon, mic integrated), 30s listen / 5s pause, `ListenMode.search`, filler stripping (`search for`/`find`/`show me`) and 650 ms partial-result debounce that auto-searches while speaking
- **Mobile Recommendations live** — `Because You Watched` now tracks `history.first` (latest movie/episode/season/series) instead of old `isWatched`, clears 30-min cache and refreshes on `CloudSync.historyRevision` + `WatchHistory.localHistoryRevision` + app resume, pulls TV watches before computing so TV binges appear on mobile
- **Actor filmography correctly grouped** — `movie_credits` / `tv_credits` are authoritative; tv credits now open `MaxStreamSeriesScreen` and enforce `media_type`, fixing movies reading as series and vice versa
- **About screen — Website & GitHub** — new `Website` section (`https://maxstreamweb.vercel.app`) with `Icons.language` and `GitHub Repository` section (`https://github.com/chila254/maxstream`) with `Icons.code` in `maxstream_about_screen.dart`
- **TV subtitles upgraded** — manual overlay for VixSrc (header-signed fetch), English auto-select, selection popups with cue count / `failed to load`, and 200 ms lift above playback controls when visible (`PlayerScreen.kt`)
- **TV Home & Details polish** — series/movie release status badges (`Returning/Ended/Cancelled` / `Released/Post Production/To be released`), watchlist counts, and focused Continue Watching caption `S{season} E{episode} · {name}`

### Features
- **Mobile**
  - Modern pill search bar — `1E1E1E`→`232323` gradient, `0.09` border, dual shadows, integrated mic (red when listening, `Listening…` hint) and clear affordance; tabs hidden until searching and replaced by modern pill `ChoiceChips` (`All/Movies/TV Shows/Actors` with animated red pill)
  - `Top Searched` / `Most Watched` use Coming-Soon style cards (`300×220` backdrop + `56×82` poster, gradient, `TV/MOVIE` badge, pill rating, year + 2-line overview) in `152px` horizontal carousels with `12dp` radius/shadow; grid cards enlarged to `0.62` aspect, `10px` spacing, star pill
  - Reusable `AppShimmer` (`lib/widgets/app_shimmer.dart`) — narrow bright glint band (`0.42/0.5/0.58` stops lerped toward white) sweeping at `800 ms` replaces soft `1500 ms` `Shimmer.fromColors` on all 8 loading screens
  - Recommendation rows and series list now show instant cached content while refreshing in background (no full-screen shimmer on every tab return)
  - `WatchHistoryService.localHistoryRevision` (`ValueNotifier`) bumped on every `save` for immediate offline refresh
- **TV (native Kotlin/Compose)**
  - Player OK flow: first OK reveals controls and focuses Play/Pause (no pause), second OK pauses; single activator via `onPreviewKeyEvent` + `focusable()` eliminates pause/resume flicker (`PlayerScreen.kt:1419,1788`)
  - Content rows use `RowDesc` + `RowNavState` with `focusFirstRow`/`onCardKey`, hero debounced at 400 ms, and 18-attempt focus seeding for sidebar→content
  - Continue Watching card emphasizes `S/E · episodeName` in red/bold when focused, and syncs every 30 s + on `historyRevision`
  - Unreleased episodes show `To be released on {date}` badge, are skipped by D-pad, and block `playNext`/`selectMenuOption`
  - `CloudSyncRepository.getJson` returns `null` on non-2xx to avoid wiping local watchlist/history on error; `TvShell` logout now uses `shellNavController`

### Bug Fixes
- **Mobile**
  - Fix `RenderFlex overflowed by 2.0px` fatal on Honor/MagicOS & Android 16 edge-to-edge by clamping `MediaQuery.textScaler` to `0.8–1.3x` in `MaxStreamApp.builder` and demoting `RenderFlex overflowed` to benign in `isBenignError` (`lib/main.dart:140`, `lib/widgets/crash_screen.dart:228`)
  - Fix black homescreen / recommendations / series list caused by sequential `Future.wait` where one TMDB failure blanked all rows — now parallel per-row `runCatching`/`_safe` fallbacks with `WatchProgressRepository`/`RecommendationService` guards (`HomeViewModel.kt:54`, `maxstream_home_screen.dart:52`, `maxstream_recommendations_screen.dart:77`, `maxstream_series_list_screen.dart:34`)
  - Fix `NullSafeMutableLiveData` lint on `HomeViewModel` parallel assignments (`@SuppressLint`)
  - Fix `speech_to_text` `js` version conflict by pinning `6.5.1` (resolves to `6.6.0`) and committing `pubspec.lock`
  - Fix mic dismissing in 2 s — extended to `30s/5s`, `cancelOnError:false`, `ListenMode.search`, filler stripping and partial debounce
  - Fix actor grouping mix-up via enforced `media_type` (`actor_details_screen.dart:337`)
- **TV**
  - Fix subtitle `MM:SS.mmm` 2-part timestamps dropped by old `HH:MM:SS` regex — new `parseSubtitleCues` mirrors Dart `_parseVtt` and decodes entities (`PlayerScreen.kt:148`)
  - Fix VixSrc HLS subtitle fetch requiring stream headers — fallback to stream headers and retry without custom headers, validate `looksLikeSubtitle` (`PlayerScreen.kt:544`)
  - Fix watchlist not syncing old phone items — phone now backfills full local watchlist on `startListening` (`cloud_sync_service.dart:53`)
  - Fix subtitles not appearing at bottom — now auto-select default and surface `failed to load` diagnostics
  - Fix TV app icon/banner, sidebar lag, VidLink header fallback, Firebase idToken expiry, setState-after-dispose, subtitle/menu dedupe, episode focus, shell focus on player return, batch season downloads, HLS audio/subtitles, server picker, `CancellationException`/`HLS OOM` crashes (commits `cb736c1`..`a0e16be`)

## 1.5.0+7

> [!NOTE]
> This release rebuilds the Android TV app as a native Kotlin/Compose experience with a real D-pad remote player, device-code login, cloud sync with your phone, and more stream servers.

### What's New
- Native Kotlin TV app with Jetpack Compose UI, D-pad navigation, and a dedicated ExoPlayer-based player
- Device-code authentication with on-screen keyboard and 3-tab login screen
- Cloud sync: watch history and watchlist sync with your phone in real time over Firestore
- Continue watching with per-episode cover art and automatic next-episode playback
- Season/episode picker with thumbnails, Dart-style episode panel, and autoplay
- Self-update via GitHub releases with in-app download and install

### Features
- Focusable playback controls with auto-scrolling submenus and keyboard shortcuts
- Server and quality switching without restarting playback
- Parallel stream server racing for faster load times
- Pre-flight stream validation with friendly loading messages
- Crash reporting with in-app restart screen
- LMK detection and memory-pressure handling to prevent player crashes
- VidLink and additional stream server support
- Firebase idToken refresh to keep cloud sync alive

### Bug Fixes
- Fix TV app icon and banner not rendering on the Android TV home screen
- Fix continue-watching showing wrong episode and finished items lingering in details
- Fix player focus theft, card bounce, and D-pad navigation across all screens
- Fix device-code login failing with invalid code
- Fix sidebar lag, logo branding, and home focus seeding
- Fix VidLink media header fallback and Mov2Day webview frame promotion
- Fix Firebase idToken expiry silently killing cloud sync
- Fix mobile setState-after-dispose crash in async loads
- Fix player subtitle detection, search keyboard layout, and genre screen loading

## 1.4.0+6

> [!NOTE]
> This release makes downloads significantly more reliable with persistent pause and resume support, expired-link recovery, file integrity checks, cancellation controls, offline subtitles, and clearer player status indicators.

### What's New
- Stream movies and series in the browser with platform-aware web player routing and refreshed MaxStream web branding
- Play web streams without provider ads through a Cloudflare Worker that extracts and proxies signed HLS media
- Use the redesigned TV experience with a modern sidebar, content-focused screens, improved remote focus navigation, and a `media_kit` player
- Download movies, individual episodes, or complete seasons with background processing and MB/GB progress tracking
- Watch downloaded series continuously with offline subtitles and automatic next-episode playback

### Features
- Select VixSrc, VidLink, 2Embed, or Goodstream from the web player's server menu
- Switch web servers without stale iframe or platform-view state carrying over between streams
- Proxy HLS master playlists, variants, segments, encryption keys, and provider headers through signed, CORS-safe Worker URLs
- Fall back to browser-compatible VidLink embeds when direct Worker extraction is unavailable
- Block popup ads at the parent page and suppress embed overlays without sandbox restrictions that break playback
- Select download quality from movie and episode screens
- View download percentage and transferred size in MB or GB
- Pause, resume, persist, and recover partial movie and episode downloads across connection loss and app restarts
- Cancel individual movie or episode downloads and remove their partial files
- Refresh expired signed stream URLs and request headers before resuming paused downloads
- Download subtitles for offline viewing and preserve subtitle metadata in the downloads database
- Adjust subtitle timing offsets when captions are out of sync between providers
- Show download status on movie and episode screens and a green completed checkmark in player controls
- Check GitHub hourly for new releases while preventing duplicate requests, dialogs, and notifications
- Enable Android release minification and resource shrinking with updated ProGuard rules
- Align Flutter and Android release metadata for version-code 5 builds
- Add web deployment configuration and platform-specific native/web video player exports

### Bug Fixes
- Fix TV build errors, default focus, D-pad navigation, and focus traversal across details, genre, search, series, and watchlist screens
- Fix Continue Watching so browser sessions open the web streaming player
- Fix web builds with conditional player imports and browser-safe DOM APIs
- Fix CORS-blocked browser stream checks and add clearer extraction diagnostics
- Fix embedded HLS playback blocked by iframe sandbox and referrer restrictions
- Fix stale web stream URLs, popup handling, reused view types, and unreliable iframe replacement during server changes
- Fix indefinite web loading by using a browser-compatible HTTP client and embed fallback
- Fix the Cloudflare Worker deployment URL and route requests through `maxstream-extractor.maxstream123.workers.dev`
- Fix VixSrc web extraction by resolving API, embed, JavaScript, and playlist stages correctly
- Fix browser playback with signed media URLs and recursive rewriting of HLS playlists and media resources
- Fix web source API build errors after replacing `getEmbedSources()` with the server catalog
- Fix embed-type web results and add CSS ad suppression for fallback embeds
- Fix Goodstream extraction support and correct the Android extractor syntax error
- Fix downloads disappearing after connection errors by retaining them as paused tasks
- Fix downloads disappearing during refresh or completion by retaining active items and rejecting stale asynchronous reloads
- Fix interrupted downloads disappearing after app restarts by persisting pending task metadata
- Fix paused downloads unnecessarily keeping foreground services and wakelocks active
- Fix expired CDN links returning HTTP 403 or 410 by resolving a fresh server URL before resume
- Fix truncated direct files, invalid byte ranges, incomplete HLS playlists, empty or partial segments, and damaged media being marked complete
- Fix corrupted offline playback freezing silently by showing a clear damaged-download error
- Fix fallback server labels so the player shows the actual extractor and originating route
- Fix dead HLS variants reaching the player by validating media segments before playback
- Fix player initialization failures by automatically trying another validated server
- Fix subtitle synchronization controls and keep adjusted captions reactive during playback
- Fix online playback controls so played, buffered, and unbuffered progress are visible while scrubbing remains available
- Fix completed downloads still showing an actionable download button in player controls

## 1.3.0+5

> [!NOTE]
> This release was built faster for a streamlined UX for the user and the download functionality. Download support is now available for movies and series. We are still working to improve streaming functionality.

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
