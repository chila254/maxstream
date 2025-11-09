class ApiConfig {
  // TMDb API Configuration (for movie/series metadata)
  static const String tmdbApiKey = '3b65c5fdee212a85a4e4ef208d31d74e';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // VidSrc API Configuration (for streaming)
  static const String vidsrcBaseUrl = 'https://vidsrc.to/embed';
  static const String vidsrcMovieUrl = '$vidsrcBaseUrl/movie';
  static const String vidsrcTvUrl = '$vidsrcBaseUrl/tv';

  // Alternative VidSrc API for direct stream URLs (backup)
  static const String vidsrcApiBaseUrl =
      'https://streaming-proxy-apcwzno2f-franklin-finyanges-projects.vercel.app';
  static const String vidsrcApiStreamUrl = '$vidsrcApiBaseUrl/vidsrc';

  // Validate API keys
  static bool get isTmdbConfigured => tmdbApiKey.isNotEmpty;

  // Get configured services
  static List<String> get configuredServices {
    final services = <String>[];
    if (isTmdbConfigured) services.add('TMDb');
    services.add('VidSrc'); // Always available
    return services;
  }

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

  // API endpoints for direct stream data
  static String getMovieApiUrl(String id) {
    return '$vidsrcApiStreamUrl/$id';
  }

  static String getTvApiUrl(String id, int season, int episode) {
    return '$vidsrcApiStreamUrl/$id?s=$season&e=$episode';
  }
}
