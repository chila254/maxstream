class ApiConfig {
  // ==================== TMDb Configuration ====================
  // TMDb API Configuration (for movie/series metadata)
  static const String tmdbApiKey = '3b65c5fdee212a85a4e4ef208d31d74e';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // ==================== Native Stream Extraction Configuration ====================
  // Native Method Channel for platform-specific WebView stream extraction
  static const String nativeMethodChannel = 'com.maxstream/stream_extractor';
  
  // Native embed sources (used by WebView extraction on Android/iOS)
  static const Map<String, String> nativeEmbedSources = {
    'vidsrc_pro_primary': 'https://vidsrc.pro/embed',
    'vidsrc_net_fallback': 'https://vidsrc.net/embed',
    'vidsrc_me_backup': 'https://vidsrc.me/embed',
  };

  // Native stream extraction timeouts (in seconds)
  static const int nativeExtractionTimeout = 45;
  static const int nativeAvailabilityCheckTimeout = 5;

  // ==================== Scrapper API Configuration ====================
  // Multiple Scrapper API endpoints for direct m3u8 extraction
  static const Map<String, String> scrapperEndpoints = {
    'vidsrc_direct': 'https://vidsrc.to',
    'v2_vidsrc': 'https://v2.vidsrc.xyz',
    'autoembed': 'https://autoembed.co',
    'upstream': 'https://upstream.to',
  };

  // Scrapper API extraction timeout (in seconds)
  static const int scrapperApiTimeout = 30;

  // ==================== Deprecated/Legacy Configuration ====================
  // VidSrc API Configuration (for streaming) - maintained for backward compatibility
  static const String vidsrcBaseUrl = 'https://vidsrc.to/embed';
  static const String vidsrcMovieUrl = '$vidsrcBaseUrl/movie';
  static const String vidsrcTvUrl = '$vidsrcBaseUrl/tv';

  // ==================== Stream Extraction Strategy ====================
  // Priority order for stream extraction methods
  // 1. Native WebView (highest performance, platform-optimized)
  // 2. Scrapper API (fast, no native overhead)
  // 3. Direct HTTP scraping (fallback)
  static const List<String> extractionMethodPriority = [
    'native_webview',
    'scrapper_api',
  ];

  // ==================== Validation & Configuration Status ====================
  static bool get isTmdbConfigured => tmdbApiKey.isNotEmpty;

  static bool get isNativeAvailable => true; // Checked at runtime via service

  static bool get isScrapperAvailable => scrapperEndpoints.isNotEmpty;

  // Get configured services
  static List<String> get configuredServices {
    final services = <String>[];
    if (isTmdbConfigured) services.add('TMDb');
    services.add('Native WebView'); // Native extraction (primary)
    if (isScrapperAvailable) services.add('Scrapper API'); // Fallback
    return services;
  }

  // ==================== URL Generators ====================
  // VidSrc URL generators
  static String getMovieStreamUrl(String id) {
    return '$vidsrcMovieUrl/$id';
  }

  static String getTvStreamUrl(String id, {int? season, int? episode}) {
    String url = '$vidsrcTvUrl/$id';
    if (season != null) {
      url += '/$season';
      if (episode != null) {
        url += '/$episode';
      }
    }
    return url;
  }

  // Native embed URL generators
  static String getNativeMovieEmbedUrl(String id, {String? sourceKey}) {
    final baseUrl = sourceKey != null && nativeEmbedSources.containsKey(sourceKey)
        ? nativeEmbedSources[sourceKey]!
        : nativeEmbedSources['vidsrc_pro_primary']!;
    return '$baseUrl/movie/$id';
  }

  static String getNativeTvEmbedUrl(
    String id,
    int season,
    int episode, {
    String? sourceKey,
  }) {
    final baseUrl = sourceKey != null && nativeEmbedSources.containsKey(sourceKey)
        ? nativeEmbedSources[sourceKey]!
        : nativeEmbedSources['vidsrc_pro_primary']!;
    return '$baseUrl/tv/$id/$season/$episode';
  }

  // Get all native sources for fallback
  static List<String> getNativeMovieSources(String id) {
    return nativeEmbedSources.values
        .map((baseUrl) => '$baseUrl/movie/$id')
        .toList();
  }

  static List<String> getNativeTvSources(String id, int season, int episode) {
    return nativeEmbedSources.values
        .map((baseUrl) => '$baseUrl/tv/$id/$season/$episode')
        .toList();
  }
}
