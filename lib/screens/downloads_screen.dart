import 'dart:io';

import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../services/media_download_manager.dart';
import 'm3u8_video_player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<Map<String, dynamic>> _downloads = const [];
  bool _loading = true;
  final MediaDownloadManager _downloadManager = MediaDownloadManager.instance;
  late int _completionVersion;

  @override
  void initState() {
    super.initState();
    _completionVersion = _downloadManager.completionVersion;
    _downloadManager.addListener(_handleDownloadManagerChanged);
    _loadDownloads();
  }

  @override
  void dispose() {
    _downloadManager.removeListener(_handleDownloadManagerChanged);
    super.dispose();
  }

  void _handleDownloadManagerChanged() {
    if (_completionVersion != _downloadManager.completionVersion) {
      _completionVersion = _downloadManager.completionVersion;
      _loadDownloads();
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadDownloads() async {
    if (mounted) setState(() => _loading = true);
    final downloads = await DBHelper.getMediaDownloads();
    final existing = <Map<String, dynamic>>[];
    for (final download in downloads) {
      if (await File(download['localPath']?.toString() ?? '').exists()) {
        existing.add(download);
      }
    }
    if (mounted) {
      setState(() {
        _downloads = existing;
        _loading = false;
      });
    }
  }

  Future<void> _play(Map<String, dynamic> download) async {
    final isMovie = download['mediaType'] == 'movie';
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => M3U8VideoPlayerScreen(
          title: download['title']?.toString() ?? 'Downloaded video',
          tmdbId: download['mediaId']?.toString() ?? '',
          isMovie: isMovie,
          season: (download['seasonNumber'] as num?)?.toInt() ?? 1,
          episode: (download['episodeNumber'] as num?)?.toInt() ?? 1,
          offlinePath: download['localPath']?.toString(),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> download) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete download?'),
        content: Text(
          '${download['title'] ?? 'This video'} will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final file = File(download['localPath']?.toString() ?? '');
    try {
      if (await file.exists()) await file.parent.delete(recursive: true);
    } on FileSystemException {
      // Remove stale database entries even if their files are already gone.
    }
    await DBHelper.deleteMediaDownload(download['downloadKey'].toString());
    await _loadDownloads();
  }

  @override
  Widget build(BuildContext context) {
    final movies = _downloads
        .where((download) => download['mediaType'] == 'movie')
        .toList();
    final episodes = _downloads
        .where((download) => download['mediaType'] == 'episode')
        .toList();
    final series = <String, List<Map<String, dynamic>>>{};
    for (final episode in episodes) {
      final key =
          episode['seriesId']?.toString() ?? episode['mediaId'].toString();
      series.putIfAbsent(key, () => []).add(episode);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadDownloads,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading && _downloadManager.activeDownloads.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _downloads.isEmpty && _downloadManager.activeDownloads.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.download_done, size: 64, color: Colors.white38),
                  SizedBox(height: 16),
                  Text(
                    'No downloads yet',
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Use the download button inside the video player.',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDownloads,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_downloadManager.activeDownloads.isNotEmpty) ...[
                    _sectionTitle(
                      'Downloading',
                      _downloadManager.activeDownloads.length,
                    ),
                    ..._downloadManager.activeDownloads.map(
                      _activeDownloadTile,
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (_downloads.isNotEmpty)
                    _sectionTitle('Downloaded', _downloads.length),
                  if (movies.isNotEmpty) ...[
                    _subsectionTitle('Movies'),
                    ...movies.map(_downloadTile),
                    const SizedBox(height: 20),
                  ],
                  if (series.isNotEmpty) ...[
                    _subsectionTitle('Series'),
                    ...series.values.map(_seriesGroup),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        '$title ($count)',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _subsectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _activeDownloadTile(ActiveMediaDownload download) {
    final percent = (download.progress * 100).round().clamp(0, 100);
    return Card(
      color: const Color(0xFF1E1E1E),
      child: ListTile(
        leading: _thumbnail(download.thumbnail),
        title: Text(
          download.label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: download.progress,
                  minHeight: 5,
                  color: Colors.red,
                  backgroundColor: Colors.white24,
                ),
              ),
              const SizedBox(width: 10),
              Text('$percent%', style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seriesGroup(List<Map<String, dynamic>> episodes) {
    episodes.sort((a, b) {
      final season = ((a['seasonNumber'] as num?)?.toInt() ?? 0).compareTo(
        (b['seasonNumber'] as num?)?.toInt() ?? 0,
      );
      return season != 0
          ? season
          : ((a['episodeNumber'] as num?)?.toInt() ?? 0).compareTo(
              (b['episodeNumber'] as num?)?.toInt() ?? 0,
            );
    });
    final first = episodes.first;
    final title = first['title']?.toString().split(' - S').first ?? 'Series';
    final seasons = <int, List<Map<String, dynamic>>>{};
    for (final episode in episodes) {
      final season = (episode['seasonNumber'] as num?)?.toInt() ?? 1;
      seasons.putIfAbsent(season, () => []).add(episode);
    }
    return Card(
      color: const Color(0xFF1E1E1E),
      child: ExpansionTile(
        leading: _thumbnail(first['thumbnail']?.toString() ?? ''),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          '${episodes.length} downloaded episode${episodes.length == 1 ? '' : 's'}',
          style: const TextStyle(color: Colors.white54),
        ),
        iconColor: Colors.white,
        collapsedIconColor: Colors.white70,
        children: seasons.entries.map((entry) {
          return ExpansionTile(
            title: Text(
              'Season ${entry.key}',
              style: const TextStyle(color: Colors.white70),
            ),
            iconColor: Colors.white,
            collapsedIconColor: Colors.white70,
            children: entry.value.map(_downloadTile).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _downloadTile(Map<String, dynamic> download) {
    final isEpisode = download['mediaType'] == 'episode';
    final episodeLabel = isEpisode
        ? 'S${download['seasonNumber']}E${download['episodeNumber']}'
        : 'Movie';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: _thumbnail(download['thumbnail']?.toString() ?? ''),
      title: Text(
        download['title']?.toString() ?? 'Downloaded video',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        episodeLabel,
        style: const TextStyle(color: Colors.white54),
      ),
      onTap: () => _play(download),
      trailing: IconButton(
        tooltip: 'Delete download',
        onPressed: () => _delete(download),
        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
    );
  }

  Widget _thumbnail(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 54,
        height: 70,
        child: url.isEmpty
            ? const ColoredBox(
                color: Colors.black38,
                child: Icon(Icons.movie, color: Colors.white38),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black38,
                  child: Icon(Icons.movie, color: Colors.white38),
                ),
              ),
      ),
    );
  }
}
