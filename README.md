# MaxStream

A feature-rich streaming application built with Flutter that provides users with an extensive catalog of movies and series with a modern, intuitive interface.

<div align="center">
  <img src="assets/images/maxstream_logo.png" alt="MaxStream Logo" width="128" height="128" />
</div>

## Overview

MaxStream is a comprehensive entertainment streaming platform that offers seamless browsing, searching, and watching of movies and TV series. With Firebase authentication, real-time notifications, and advanced video playback capabilities, MaxStream delivers a premium streaming experience across multiple platforms.

## Features

### Core Features
- **User Authentication**: Secure Firebase authentication with Google Sign-In support
- **Advanced Video Player**: Modern video player with media_kit for superior playback quality
- **Movie & Series Catalog**: Browse thousands of movies and TV series with detailed information
- **Search Functionality**: Fast and efficient search across the entire content library
- **Watch History**: Automatic tracking of watched content with resume playback capability
- **Watchlist Management**: Curate a personal watchlist of favorite content
- **Actor Information**: Detailed actor profiles integrated with TMDB API

### User Experience
- **Dark/Light Theme Support**: Fully themed UI with persistent theme preferences
- **Responsive Design**: Optimized layouts for phones, tablets, and desktop devices
- **Splash Screen**: Branded native splash screen with animated transitions
- **Glassmorphism UI**: Modern glassmorphism effects for enhanced aesthetics
- **Loading States**: Smooth shimmer loading animations for content
- **Push Notifications**: Real-time updates and notifications using Firebase

### Content & Streaming
- **TMDB Integration**: Access to extensive movie and series metadata
- **Stream Extraction**: Multiple streaming source support
- **Adaptive Streaming**: Quality adjustment based on network conditions
- **Continue Watching**: Pick up where you left off with smart resume functionality
- **Video Caching**: Efficient caching of frequently accessed content

### Additional Features
- **Settings & Preferences**: Granular control over app behavior and playback options
- **In-App WebView**: Browse content within the app using flutter_inappwebview
- **App Update Checking**: Automatic update notifications via package_info_plus
- **Local Database**: SQLite-based local storage for watch history and preferences
- **Permission Management**: Proper runtime permission handling for Android/iOS
- **Native Integration**: Android intent support for system integration

## Tech Stack

### Flutter & Dart
- **Flutter SDK**: >=3.8.0 <4.0.0
- **Dart**: Latest stable version

### State Management & Architecture
- **Provider**: ^6.0.5 - Efficient state management and dependency injection

### UI & Themes
- **Material Design 3**: Modern material design components
- **Glassmorphism**: ^3.0.0 - Modern frosted glass UI effects
- **Shimmer**: ^3.0.0 - Smooth loading skeleton screens
- **Lottie**: ^3.1.0 - Beautiful vector animations

### Video & Media
- **Media Kit**: ^1.0.0 - Professional video player library
- **Media Kit Video**: ^1.0.0 - Video player UI components
- **Media Kit Libs Android**: ^1.0.0 - Android video codec libraries
- **YouTube Player**: ^9.1.1 - YouTube video integration
- **WebView Flutter**: ^4.4.4 - Web content integration
- **Flutter InAppWebView**: ^6.1.5 - Advanced web view functionality

### Backend & APIs
- **Firebase Core**: ^4.2.0 - Firebase platform initialization
- **Firebase Auth**: ^6.1.2 - User authentication
- **Google Sign-In**: ^6.3.0 - Google account integration
- **Dio**: ^5.4.0 - HTTP client for API requests
- **HTTP**: ^1.4.0 - Standard HTTP library

### Local Storage & Databases
- **SQLite (sqflite)**: ^2.3.2 - Local database for watch history
- **Shared Preferences**: ^2.2.2 - Key-value storage for user preferences
- **Path Provider**: ^2.1.1 - File system paths

### Notifications & Platform Integration
- **Firebase Cloud Messaging**: Push notification support via Firebase
- **Flutter Local Notifications**: ^19.4.2 - Local notification handling
- **Android Intent Plus**: ^6.0.0 - Android native intent support
- **Permission Handler**: ^12.0.1 - Runtime permissions management

### Utilities
- **Cached Network Image**: ^3.2.3 - Optimized image caching and loading
- **URL Launcher**: ^6.2.6 - External URL handling
- **Package Info Plus**: ^9.0.0 - App version and build information
- **Open File**: ^3.3.2 - File opening functionality
- **HTML Parser**: ^0.15.4 - HTML content parsing
- **Logger**: ^2.0.2 - Comprehensive logging framework

### Build & Deployment
- **Flutter Launcher Icons**: ^0.14.4 - App icon generation
- **Flutter Native Splash**: ^2.4.6 - Native splash screen
- **Installed Apps**: ^2.0.0 - System app detection

## Project Structure

```
lib/
├── assets/                      # Static assets and configurations
├── config/                      # Application configuration files
├── database/                    # Database models and helpers
├── models/                      # Data models (Movie, Series, User, etc.)
├── screens/                     # UI screens
│   ├── splash_screen.dart      # Initial splash and auth gate
│   ├── onstream_main_screen.dart # Main app navigation
│   ├── onstream_home_screen.dart # Home with featured content
│   ├── onstream_search_screen.dart # Search functionality
│   ├── onstream_details_screen.dart # Movie/Series details
│   ├── modern_video_player_screen.dart # Advanced video player
│   ├── onstream_watchlist_screen.dart # Watchlist management
│   ├── watch_history_screen.dart # Watch history
│   ├── onstream_series_screen.dart # Series browser
│   ├── onstream_series_list_screen.dart # Series listings
│   ├── actor_details_screen.dart # Actor information
│   ├── sign_in_screen.dart     # Login screen
│   ├── sign_up_screen.dart     # Registration screen
│   ├── profile_settings_screen.dart # Profile management
│   ├── general_settings_screen.dart # App settings
│   └── forgot_password_screen.dart # Password recovery
├── services/                    # Business logic services
│   ├── auth_service.dart       # Firebase authentication
│   ├── tmdb_api_service.dart   # TMDB API integration
│   ├── combined_stream_service.dart # Unified stream extraction (native + scrapper)
│   ├── native_stream_extractor_service.dart # Native WebView stream extraction
│   ├── scrapper_api_service.dart # Direct m3u8 HTTP scraping
│   ├── theme_service.dart      # Dark/Light theme management
│   ├── notification_service.dart # Push notifications
│   ├── watch_history_service.dart # Watch history tracking
│   ├── user_service.dart       # User profile management
│   ├── settings_service.dart   # User settings storage
│   ├── update_service.dart     # App update checking
│   └── api_service.dart        # Generic API client
├── widgets/                     # Reusable UI components
│   ├── hero_banner.dart        # Featured content banner
│   ├── series_hero_banner.dart # Series featured banner
│   ├── movie_slider.dart       # Horizontal movie carousel
│   ├── custom_nav_bar.dart     # Bottom navigation
│   ├── continue_watching_section.dart # Resume playback widget
│   ├── custom_loading_widget.dart # Shimmer loader
│   └── ...                     # Other custom widgets
├── utils/                       # Utility functions
│   ├── responsive_utils.dart   # Responsive design helpers
│   ├── player_settings_utils.dart # Video player configuration
│   └── logger.dart             # Logging utilities
├── main.dart                    # App entry point
└── firebase_options.dart        # Firebase configuration

assets/
├── images/
│   ├── maxstream_logo.png      # App logo (launcher icon)
│   └── background.jpg          # Background image
└── movies.json                 # Sample movie data
```

## Getting Started

### Prerequisites
- Flutter SDK (>=3.8.0)
- Dart SDK (latest)
- Firebase project configuration
- TMDB API key
- Android Studio / Xcode for native development

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/chila254/maxstream.git
   cd maxstream
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate launcher icons**
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

4. **Generate native splash screen**
   ```bash
   flutter pub run flutter_native_splash:create
   ```

5. **Configure Firebase**
   - Download `google-services.json` and place in `android/app/`
   - Download `GoogleService-Info.plist` and place in `ios/Runner/`

6. **Run the app**
   ```bash
   flutter run
   ```

## Configuration

### Environment Variables
Create a `.env` file in the project root with:
```
TMDB_API_KEY=your_tmdb_api_key
FIREBASE_PROJECT_ID=your_firebase_project_id
```

### Firebase Setup
1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Enable Authentication (Email/Password and Google Sign-In)
3. Create a Realtime Database or Firestore
4. Download configuration files for Android and iOS

### App Icons & Branding
- **Launcher Icon**: `assets/images/maxstream_logo.png` (512x512 minimum)
- **Splash Screen**: Configured in `pubspec.yaml` under `flutter_native_splash`
- **Theme Colors**: Customize in `services/theme_service.dart`

## Build & Deployment

### Android
```bash
flutter build apk --release
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

### Web
```bash
flutter build web --release
```

## Project Version
- **Current Version**: 1.0.1 (Build 2)
- **Minimum SDK**: 3.8.0
- **Target SDK**: Flutter 4.0.0 (when released)

## Key Services

### Authentication Service
Handles Firebase authentication with support for:
- Email/password authentication
- Google Sign-In
- Password reset functionality
- User profile management

### TMDB API Service
Integrates with The Movie Database API for:
- Movie and series metadata
- Actor information and filmography
- Search functionality
- Trending content discovery

### Stream Extraction Service
Manages video streaming by:
- Extracting playable streams from multiple sources
- Handling DRM and adaptive bitrate streaming
- Managing playback quality
- Caching streaming data

### Theme Service
Provides theming capabilities:
- Dark and Light mode support
- Persistent theme preferences
- Real-time theme switching
- Material Design 3 compliance

### Notification Service
Handles in-app and push notifications:
- Firebase Cloud Messaging integration
- Local notification scheduling
- Notification management
- Real-time updates

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support & Resources

- **Flutter Documentation**: [flutter.dev](https://flutter.dev)
- **Firebase Documentation**: [firebase.google.com](https://firebase.google.com)
- **TMDB API**: [themoviedb.org/settings/api](https://www.themoviedb.org/settings/api)
- **Media Kit Documentation**: [media-kit.io](https://media-kit.io)

## Authors

- **Developer**: Chila254
- **Repository**: [github.com/chila254/maxstream](https://github.com/chila254/maxstream)

## Acknowledgments

- Flutter and Dart teams for the amazing framework
- Firebase for backend services
- The Movie Database (TMDB) for content metadata
- Media Kit for professional video playback
- All package maintainers and open-source contributors

---

**Note**: This is a production-ready streaming application. Ensure all API keys and credentials are properly configured before deployment.
