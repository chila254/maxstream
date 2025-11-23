class ApiConfig {
  // ==================== TMDb Configuration ====================
  // TMDb API Configuration (for movie/series metadata)
  static const String tmdbApiKey = '3b65c5fdee212a85a4e4ef208d31d74e';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // ==================== Scrapper API Configuration ====================
  // Multiple Scrapper API endpoints for direct m3u8 extraction
  static const Map<String, String> scrapperEndpoints = {
    'flixhq': 'https://flixhq.to',
    'hdtoday': 'https://hdtoday.tv',
    'sflix': 'https://sflix.to',
    'lookmovie': 'https://lookmovie.io',
  };

  // Scrapper API extraction timeout (in seconds)
  static const int scrapperApiTimeout = 30;

  // ==================== Deprecated/Legacy Configuration ====================
  // VidSrc API Configuration (for streaming) - maintained for backward compatibility
  static const String vidsrcBaseUrl = 'https://vidsrc.to/embed';
  static const String vidsrcMovieUrl = '$vidsrcBaseUrl/movie';
  static const String vidsrcTvUrl = '$vidsrcBaseUrl/tv';

  // ==================== Stream Extraction Strategy ====================
  // Scrapper API is the primary and only method for stream extraction
  static const List<String> extractionMethodPriority = ['scrapper_api'];

  // ==================== Validation & Configuration Status ====================
  static bool get isTmdbConfigured => tmdbApiKey.isNotEmpty;

  static bool get isScrapperAvailable => scrapperEndpoints.isNotEmpty;

  // Get configured services
  static List<String> get configuredServices {
    final services = <String>[];
    if (isTmdbConfigured) services.add('TMDb');
    if (isScrapperAvailable)
      services.add('Scrapper API'); // Primary extraction method
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
}
