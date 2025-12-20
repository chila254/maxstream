# MaxStream

A Flutter streaming app with movies, TV series, advanced video playback, and ad-blocking.

<div align="center">
  <img src="assets/images/maxstream_logo.png" alt="MaxStream Logo" width="128" height="128" />
</div>

## Features

- **Firebase Auth**: Email/password and Google Sign-In
- **Video Player**: InAppWebView player with comprehensive ad-blocking
- **Content Catalog**: Browse movies and TV series with TMDB integration
- **Search**: Fast full-library search
- **Watch History**: Resume playback from last position
- **Watchlist**: Save favorite content
- **Dark/Light Theme**: Persistent theme preferences
- **Multi-Provider Streaming**: VidSrc, FlixHQ, HDToday with automatic fallback
- **Push Notifications**: Firebase Cloud Messaging
- **Settings**: Granular playback and app preferences

## Tech Stack

- **Frontend**: Flutter 3.8.0+
- **State Management**: Provider
- **Video**: InAppWebView with HTML5 player + ad-blocking
- **Backend**: Firebase (Auth, Cloud Messaging)
- **API**: TMDB API
- **Database**: SQLite (local), Shared Preferences
- **UI**: Material Design 3, Glassmorphism, Lottie animations

## Project Structure

```
lib/
├── screens/              # UI screens (player, home, search, etc.)
├── services/             # Business logic (auth, stream extraction, TMDB)
├── models/              # Data models
├── widgets/             # Reusable UI components
├── database/            # SQLite helpers
├── utils/               # Helper functions
└── config/              # App configuration
```

## Getting Started

### Prerequisites
- Flutter SDK >=3.8.0
- Dart SDK (latest)
- Firebase project
- TMDB API key

### Installation

```bash
git clone https://github.com/chila254/maxstream.git
cd maxstream
flutter pub get
flutter pub run flutter_launcher_icons:main
flutter pub run flutter_native_splash:create
flutter run
```

### Configuration

1. **Firebase Setup**
   - Create project at [Firebase Console](https://console.firebase.google.com)
   - Enable Auth (Email/Password, Google Sign-In)
   - Download `google-services.json` → `android/app/`
   - Download `GoogleService-Info.plist` → `ios/Runner/`

2. **TMDB API**
   - Get API key from [TMDB](https://www.themoviedb.org/settings/api)
   - Add to app configuration

## Video Player

### Ad-Blocking
The embedded InAppWebView player blocks 40+ ad networks:
- Google AdSense, DoubleClick
- Facebook/Meta, Amazon, Twitter/X
- Criteo, AppNexus, OpenX, and more

Blocking mechanisms:
- Script injection to remove ad domains
- Iframe filtering
- DOM cleanup for ad containers
- Continuous monitoring for dynamic ads

## Build

```bash
# Android
flutter build apk --release
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## Version
- **Current**: 1.0.1 (Build 2)
- **Min SDK**: 3.8.0

## Stream Extraction Pipeline

```
User selects content
    ↓
CombinedStreamService.extractStream()
    ↓
Provider Discovery (VidSrc, FlixHQ, etc.)
    ↓
WebView Stream Resolution
    ↓
InAppWebView with HTML5 Player + Ad-Blocking
    ↓
Video plays ad-free
```

## Dependencies

**Key Packages**:
- `flutter_inappwebview`: Video player with ad-blocking
- `provider`: State management
- `firebase_core`, `firebase_auth`: Authentication
- `dio`: HTTP requests
- `sqflite`: Local database
- `lottie`, `shimmer`, `glassmorphism`: UI effects

See `pubspec.yaml` for full list.

## Contributing

Pull requests welcome.

## License

MIT License - see LICENSE file for details.

## Links

- [Flutter](https://flutter.dev)
- [Firebase](https://firebase.google.com)
- [TMDB API](https://www.themoviedb.org/settings/api)

## Author

**Chila254** - [github.com/chila254/maxstream](https://github.com/chila254/maxstream)
