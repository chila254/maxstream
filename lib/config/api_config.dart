class ApiConfig {
  // ==================== TMDb Configuration ====================
  // TMDb API Configuration (for movie/series metadata)
  static const String tmdbApiKey = '3b65c5fdee212a85a4e4ef208d31d74e';
  static const String tmdbBaseUrl = 'https://api.themoviedb.org/3';

  // ==================== WebRTC P2P Torrent Configuration ====================
  // WebRTC P2P streaming configuration
  static const int webrtcP2pTimeout = 30;
  static const String webrtcProtocol = 'webrtc-stream://';

  // DHT nodes for peer discovery
  static const List<String> dhtNodes = [
    'dht.transmissionbt.com:6881',
    'router.bittorrent.gdn:6881',
    'router.utorrent.com:6881',
  ];

  // ==================== Stream Extraction Strategy ====================
  // WebRTC P2P Torrent is the primary method for stream extraction
  static const List<String> extractionMethodPriority = ['webrtc_p2p'];

  // ==================== Validation & Configuration Status ====================
  static bool get isTmdbConfigured => tmdbApiKey.isNotEmpty;

  static bool get isWebRTCAvailable => dhtNodes.isNotEmpty;

  // Get configured services
  static List<String> get configuredServices {
    final services = <String>[];
    if (isTmdbConfigured) services.add('TMDb');
    if (isWebRTCAvailable) services.add('WebRTC P2P Torrent'); // Primary extraction method
    return services;
  }

  // ==================== URL Generators ====================
  // WebRTC stream URL generator
  static String getWebRTCStreamUrl(String infoHash) {
    return '$webrtcProtocol$infoHash';
  }

  // Legacy VidSrc URL generators (for backward compatibility)
  static String getMovieStreamUrl(String id) {
    // Now redirects to torrent stream
    return getWebRTCStreamUrl(id);
  }

  static String getTvStreamUrl(String id, {int? season, int? episode}) {
    // Now redirects to torrent stream
    return getWebRTCStreamUrl(id);
  }
}
