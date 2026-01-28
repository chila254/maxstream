// Example usage of TvScraperService for fetching direct m3u8 URLs
//
// This file demonstrates how to use the TvScraperService API.
// To run examples, uncomment functions and call them in test code.

import 'package:maxstream/tv/services/tv_scraper_service.dart';

/// Example 1: Search for a TV channel by name
Future<void> searchTvChannelExample() async {
  final result = await TvScraperService.searchTvChannel('CNN');
  
  if (result != null) {
    print('Found channel: ${result['title']}');
    print('M3U8 URL: ${result['m3u8Url']}');
    print('Source: ${result['source']}');
  }
}

/// Example 2: Get a full M3U8 playlist
Future<void> getPlaylistExample() async {
  final result = await TvScraperService.getM3u8Playlist(
    'https://raw.githubusercontent.com/iptv-org/iptv/master/index.m3u',
  );
  
  if (result != null) {
    print('Playlist fetched successfully');
    print('Type: ${result['type']}');
    print('Content length: ${(result['content'] as String).length} bytes');
  }
}

/// Example 3: Get IPTV Org channels
Future<void> getIPTVOrgExample() async {
  final result = await TvScraperService.getIPTVOrgPlaylists();
  
  if (result != null) {
    print('IPTV Org channels fetched');
    print('Data: ${result['data']}');
  }
}

/// Example 4: Verify an m3u8 URL before playing
Future<void> verifyM3u8Example() async {
  const m3u8Url = 'https://example.com/stream.m3u8';
  
  final isValid = await TvScraperService.verifyM3u8Url(m3u8Url);
  
  if (isValid) {
    print('M3U8 URL is valid and accessible');
  } else {
    print('M3U8 URL is not accessible');
  }
}

/// Example 5: Get available sources
void getSourcesExample() {
  final sources = TvScraperService.getSources();
  
  for (final source in sources) {
    print('Source: ${source['name']}');
    print('Base URL: ${source['baseUrl']}');
    print('Type: ${source['type']}');
  }
}

/// Integration example: Search and verify before playing
Future<void> integratedExample(String channelName) async {
  print('Searching for channel: $channelName');
  
  // Search for the channel
  final result = await TvScraperService.searchTvChannel(channelName);
  
  if (result != null) {
    print('Found: ${result['title']} (Source: ${result['source']})');
    
    // Verify the URL is accessible
    final m3u8Url = result['m3u8Url'] as String;
    final isValid = await TvScraperService.verifyM3u8Url(m3u8Url);
    
    if (isValid) {
      print('URL verified! Ready to play: $m3u8Url');
      // You can now use this URL with a video player
    } else {
      print('URL verification failed');
    }
  } else {
    print('Channel not found');
  }
}
