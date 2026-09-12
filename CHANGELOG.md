# Changelog

## 1.7.0+9

> [!NOTE]
> This release adds Viduki as a new streaming server, subtitle customization with cross-device sync, HEVC/H.265 software decode, server auto-switch on failure, and a massive number of stability fixes across mobile and TV. It also introduces the Cloudflare Worker health endpoint and a live server status dashboard on the website.

### What's New

- **Viduki streaming server** — new `VidukiServerProvider` with 4 API servers (`/1/`, `/2/`, `/3/`, `/4/`) for both movies and TV; `VidukiExtractor` uses WebView-based JS injection with fetch/XHR/video interception to resolve streams (`0641735`)
- **Subtitle customization** — cross-device subtitle settings sync via Firebase RTDB; color, size, background opacity, shadow, and font weight now persist and sync between phone and TV (`e5bd18b`, `a81e0ef`, `7579d1f`)
- **HEVC/H.265 software decode** — ExoPlayer decoder fallback enabled on mobile (`beeee27`) and TV (`9e45543`); `video_player_android` fork with `setEnableDecoderFallback(true)` for HEVC playback on devices without hardware support
- **Server auto-switch on Source Error** — TV player automatically tries the next server when a stream fails (`2d3ad97`); mobile skips quality loop and instant-switches to next server (`2888d32`)
- **Mobile quality fallback** — VidLink now falls back from 720p → 480p within the same server before trying the next server (`be0fd7e`, `a7febc3`)
- **Search history** — recent searches saved and displayed on idle search screen (`2366632`)
- **Pull-to-refresh** on home and library screens (`2366632`)
- **Now Playing** indicator in notification with media controls (`2366632`)
- **Genre browsing** screen (`2366632`)
- **Biometric lock** — optional fingerprint/face unlock for the app (`2366632`)
- **Provider health screen** — renamed from Server Health; lists all servers and extractors with live status checks (`1bc5098`, `513e5a4`)
- **VidLink extraction route** — player UI shows whether stream came from Worker, HTTP, or WebView (`3d378fa`)
- **Cloudflare Worker `/health` endpoint** — pings 13 servers + 38 extractors in batches of 15, cached for 5 minutes (`77ce4fc`, `ffa9afb`)
- **Website server status page** — standalone `/status` page with search, filter (All/Online/Offline), auto-refresh, and grouped extractor sections (`maxstream-web`)
- **Website modernized** — animated mesh gradient hero, glassmorphism cards, phone mockup screenshots, scroll-triggered reveals, download dialog with 3 APK variants (`maxstream-web`)
- **VidLink extractor route display** — player shows "Worker" / "HTTP" / "WebView" badge for current stream source (`3d378fa`)
- **VidLove server** registered on TV (`608c55b`)
- **Vidflix extractor** revived via `player.vidflix.club` API (`a4eea58`)
- **Vixcloud extractor** registered (`608c55b`)
- **Continue Watching improvements** — TV watches now appear on mobile recommendations; pull TV history before computing recommendations (`2366632`)

### Bug Fixes

**Video Player & Playback**
- Fix video player crash + continue watching sync (`ad7ac14`)
- Fix `rawUrl` scope error in VidLink HTTP extractor (`a1583f7`)
- Fix HLS streams behind `noon.mooncase.online` proxy (`1490153`)
- Fix VidLink Source error — wrong Referer for hakunaymatata.com streams (`bb9acb9`)
- Fix import logic + Worker hakunaymatata referer (`b2bbc9f`)
- Add `X-Playback-Environment` header to VidLink `/api/b/` requests (`c5684cc`)
- Bypass broken noon proxy for hakunaymatata.com CDN (`c6a966a`)
- Fix mobile next-server `TimeoutException` 15s + dispose race (`9d21c79`)
- Fix mobile server switch stuck + only SW decode Vidlink (`8bd798d`)
- Fix server switch stuck at "Switching to Auto" + fvp Bad state (`5055daf`)
- Fix `VideoFormat.mp4` → other, `String.contains` bool → lowercase (`4a3fb6d`)
- Fix VixSrc/Vixcloud mobile — filter HEVC variants, return best H.264 stream (`a1a635e`, `82492c8`, `1254fe2`)
- Fix TV server discovery timeout too short — Videasy/Vidflix never reached (`1254fe2`)
- Fix TV `onPlayerError` retry with 3x backoff to prevent mid-playback crash (`08c5d4d`)
- Fix TV buffer 300s → 60s (`08c5d4d`)
- Fix VidLink H265 playback on phones: prefer H.264, fix HLS `formatHint` (`6c9ca12`)
- Fix `fvp/nextlib` HEVC SW decode blocking playback start (`cf15075`)
- Fix mobile HLS source errors and expand HEVC URL filtering (`0df160f`)
- Fix `usesCleartextTraffic` + dispose old ExoPlayer before new on server switch (`a7febc3`)
- Fix download: resolve relative HLS variant URIs for Videasy (`057590c`)
- Fix download: whitelist videasy HLS hosts for episode downloads (`0baa57d`)
- Fix VidLink: cap to 720p, fix MIME for proxied mp4 (noon) (`262f8d3`)
- Fix `audio_service` manifest entries and extend `AudioServiceActivity` (`f1d2dc4`)
- Fix `PlaybackState` constructor const removal (`0dcfa6f`)

**TV App**
- Fix TV subtitle settings crash: use `BackHandler` + `Surface` rows pattern (`ea28681`)
- Fix TV subtitle settings D-pad: replace `verticalScroll` Column with `LazyColumn` (`603a6e7`)
- Fix D-pad up/down navigation in TV subtitle settings screen (`50837db`)
- Fix missing imports: `toArgb` and `focusRequester` (`4870b96`)
- Fix 3 TV bugs: back nav, D-pad focus, subtitle color sync (`e5f2fdf`)
- Fix TV subtitle settings sync — UI now reacts to cloud changes (`cbe89e3`)
- Fix TV focus restore + subtitle settings up/down navigation (`08b0b3f`)
- Fix TV subtitle settings — back key nav, cloud sync on startup, player re-reads (`d7c265e`)
- Fix `ServerValue.TIMESTAMP` uppercase, add import + `Map`-based `setValue` (`40e2ae7`, `0590843`)
- Fix `Shadow` `spreadRadius`, `mutableIntStateOf`, TV Firebase deps (`88e678f`)
- Fix Compose `Color.White` for `graphicsLayer` shadow colors (`2725c52`)
- Fix TV exit dialog white focus + mobile notification icons/thumbnails (`1cc199f`)
- Fix TV Details Watchlist → dual push Firebase + Supabase (`ff368ca`)
- Fix TV episode menu: auto-scroll seasons like episodes (`3de7685`)
- Fix TV compile: inline Source Error switch (`c011eae`)
- Fix TV compile: move `switchMedia` before `buildPlayer` (`e4dd4bd`)
- Fix TV compile: `WatchProgress` `appContext`, `runCatching` suspend (`2589cda`)
- Fix TV compile: `WatchProgressRepository.pushWatchProgress` not suspend (`d5779d0`)
- Fix TV StreamExtractor domains to match mobile fixes (`5d8e0b1`)
- Fix TV `About` dialog loads version dynamically via `PackageManager` (`94dd7c6`)
- Fix `_FullListScreen` null check on `setState` after dispose (`1da9fca`)

**Cloud Sync**
- Fix continue watching not updating — timestamp guard on cloud import + refresh after player return (`af4b657`)
- Fix watchlist deletions reconciliation across phone and TV (`9be8eca`)
- Fix Continue Watching sync + Coming Soon duplicates (`d0851d5`)
- Fix Continue Watching racing between Firebase and Supabase (`d6283e8`)
- Fix `CloudSyncRepository.getJson` returns `null` on non-2xx to avoid wiping local data
- Remove Supabase entirely, use RTDB-only sync with auto-delete watched entries (`d497216`)
- Fix `pullFromCloud` `Unit?` return type mismatch (`a521704`)
- Fix unbalanced braces in `CloudSyncRepository` + suspend type inference (`ab025ea`)

**Mobile**
- Fix subtitle sync, mobile auto-install, TV update dialog (`59848ca`)
- Fix mobile subtitle settings to reload when TV pushes changes (`7579d1f`)
- Fix search history, improve notification thumbnails (`03eea58`)
- Fix recommendations after watch + dynamic version in About (`d55a692`)
- Fix `1da9fca` `_FullListScreen` null check on `setState` after dispose

**Build & Infrastructure**
- Fix FOSS TV build — conditional Firebase + Kotlin stubs (`ee8325a`)
- Fix remove `google-services.json` decode from FOSS TV build (`51df5ca`)
- Fix `Gradle` property instead of `file-exists` check for Firebase (`8fc0943`)
- Fix enable core library desugaring for `play-services-tasks` (`90e4c29`)
- Fix `org.json` dep conflicts with Firebase under R8 + ProGuard keep rule (`940e9ff`)
- Fix missing import, `audio_service` API, handler type (`bad3cfc`)
- Fix `lastError` `Throwable` to match Throwable catch for WebView OOM (`790731b`)

### Infrastructure

- **Removed VLC entirely** — `flutter_vlc_player` + `libvlc-all` removed; ExoPlayer is now the sole player (`331cfa3`)
- **Removed Supabase** — RTDB-only sync with auto-delete watched entries; simpler, no external dependency (`d497216`)
- **Split-per-abi APK builds** — `maxstream-arm64-v8a.apk`, `maxstream-armeabi-v7a.apk`, `maxstream-x86_64.apk` (`009ba91`)
- **TV build isolated** from mobile + `nextlib` made optional (`f2812c1`)
- **TV `compileSdk` 35 → 36**, `minSdk` 21 → 23 for Media3 1.10.1 (`540d5fc`, `d5c029b`)
- **R8 minify + shrink** enabled for mobile release builds (`fef77e7`)
- **`video_player_android`** fork updated to 2.12.2 (`1872b70`)
- **Cloudflare Worker** health endpoint with batched subrequests (groups of 15) (`77ce4fc`, `ffa9afb`)
- **CI** builds FOSS Universal TV APK (no `google-services.json` needed) (`51df5ca`)
- **ProGuard** keep rule for `R$drawable` resources (`b016773`)
- **Firebase** already-initialized race condition guard (`fc4884d`, `0086432`)
- **Constants** `PREFS`/`KEY_JSON`/`TAG` moved into `SubtitleSettingsRepository` object (`53c909e`)

---

## 1.6.0+8

> [!NOTE]
> This release modernizes mobile Search with Top Searched / Most Watched and voice search, makes Recommendations live after any watch (including TV), adds official Website/GitHub links, and polishes the native TV player (subtitles, focus, watchlist) while hardening stability on both platforms.

### What's New

- **Mobile Search redesign** — idle state shows **Top Searched** (trending) and **Most Watched** (popular) carousels; unified results screen for **All / Movies / TV Shows / Actors**
- **Voice search** — integrated `speech_to_text 6.6.0` with `RECORD_AUDIO` permission, single-pill search bar, 30s listen / 5s pause, filler stripping and 650 ms partial-result debounce
- **Mobile Recommendations live** — `Because You Watched` tracks `history.first`; pulls TV watches before computing so TV binges appear on mobile
- **Actor filmography correctly grouped** — `movie_credits` / `tv_credits` are authoritative; tv credits now open `MaxStreamSeriesScreen`
- **About screen — Website & GitHub** — new Website section and GitHub Repository section
- **TV subtitles upgraded** — manual overlay for VixSrc, English auto-select, selection popups with cue count
- **TV Home & Details polish** — series/movie release status badges, watchlist counts, focused Continue Watching caption

### Features

- **Mobile**
  - Modern pill search bar with integrated mic (red when listening)
  - `Top Searched` / `Most Watched` use Coming-Soon style cards in horizontal carousels
  - Reusable `AppShimmer` with narrow bright glint band sweeping at 800 ms
  - Recommendation rows show instant cached content while refreshing in background
  - `WatchHistoryService.localHistoryRevision` bumped on every save

- **TV (native Kotlin/Compose)**
  - Player OK flow: first OK reveals controls, second OK pauses
  - Content rows use `RowDesc` + `RowNavState` with focus debouncing
  - Continue Watching card emphasizes `S/E · episodeName` in red/bold
  - Unreleased episodes show badge, are skipped by D-pad, block playNext
  - `CloudSyncRepository.getJson` returns `null` on non-2xx

### Bug Fixes

- Fix mobile `setState`-after-dispose crash in async loads
- Fix player subtitle detection, search keyboard layout, genre screen loading
- Fix TV app icon and banner not rendering on Android TV home screen
- Fix continue-watching showing wrong episode and finished items lingering
- Fix player focus theft, card bounce, D-pad navigation across all screens
- Fix device-code login failing with invalid code
- Fix sidebar lag, logo branding, home focus seeding
- Fix VidLink media header fallback and Mov2Day webview frame promotion
- Fix Firebase idToken expiry silently killing cloud sync
