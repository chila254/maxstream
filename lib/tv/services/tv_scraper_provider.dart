import 'package:flutter/foundation.dart';
import '../models/tv_channel.dart';
import 'tv_scraper_service.dart';

/// Provider for managing TV scraper state and caching
class TvScraperProvider extends ChangeNotifier {
  static const String _tag = 'TvScraperProvider';

  /// Cache of fetched TV channels
  final Map<String, TvChannel> _channelCache = {};

  /// List of recently searched channels
  final List<TvChannel> _recentChannels = [];

  /// Current loading state
  bool _isLoading = false;

  /// Current search query
  String _lastSearchQuery = '';

  /// Error message if any
  String? _errorMessage;

  // Getters
  List<TvChannel> get recentChannels => List.unmodifiable(_recentChannels);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get lastSearchQuery => _lastSearchQuery;
  Map<String, TvChannel> get channelCache => Map.unmodifiable(_channelCache);

  /// Search for a TV channel and cache result
  Future<TvChannel?> searchChannel(String channelName) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _lastSearchQuery = channelName;
      notifyListeners();

      // Check cache first
      if (_channelCache.containsKey(channelName.toLowerCase())) {
        debugPrint('$_tag: Found channel in cache: $channelName');
        final channel = _channelCache[channelName.toLowerCase()]!;
        _isLoading = false;
        notifyListeners();
        return channel;
      }

      // Search using scraper service
      final result = await TvScraperService.searchTvChannel(channelName);

      if (result != null) {
        final channel = TvChannel.fromJson(result);

        // Cache the result
        _channelCache[channelName.toLowerCase()] = channel;

        // Add to recent if not already there
        _addToRecent(channel);

        _isLoading = false;
        notifyListeners();

        return channel;
      }

      _errorMessage = 'Channel not found: $channelName';
      _isLoading = false;
      notifyListeners();

      return null;
    } catch (e) {
      _errorMessage = 'Error searching channel: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('$_tag: Search error: $e');
      return null;
    }
  }

  /// Get M3U8 playlist
  Future<Map<String, dynamic>?> getM3u8Playlist(String playlistUrl) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await TvScraperService.getM3u8Playlist(playlistUrl);

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _errorMessage = 'Error fetching playlist: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('$_tag: Playlist error: $e');
      return null;
    }
  }

  /// Get IPTV Org playlists
  Future<Map<String, dynamic>?> getIPTVOrgPlaylists() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await TvScraperService.getIPTVOrgPlaylists();

      _isLoading = false;
      notifyListeners();

      return result;
    } catch (e) {
      _errorMessage = 'Error fetching IPTV Org: $e';
      _isLoading = false;
      notifyListeners();
      debugPrint('$_tag: IPTV Org error: $e');
      return null;
    }
  }

  /// Verify m3u8 URL
  Future<bool> verifyChannel(String m3u8Url) async {
    try {
      return await TvScraperService.verifyM3u8Url(m3u8Url);
    } catch (e) {
      debugPrint('$_tag: Verification error: $e');
      return false;
    }
  }

  /// Get available sources
  List<Map<String, String>> getSources() {
    return TvScraperService.getSources();
  }

  /// Add channel to recent channels (max 20)
  void _addToRecent(TvChannel channel) {
    // Remove if already exists
    _recentChannels.removeWhere((c) => c.id == channel.id);

    // Add to beginning
    _recentChannels.insert(0, channel);

    // Keep only last 20
    if (_recentChannels.length > 20) {
      _recentChannels.removeRange(20, _recentChannels.length);
    }
  }

  /// Clear search history
  void clearHistory() {
    _recentChannels.clear();
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear cache
  void clearCache() {
    _channelCache.clear();
    notifyListeners();
  }

  /// Refresh all caches
  void refreshAll() {
    clearCache();
    clearHistory();
  }

  /// Remove specific channel from cache
  void removeFromCache(String channelName) {
    _channelCache.remove(channelName.toLowerCase());
    notifyListeners();
  }
}
