import 'package:flutter/material.dart';
import '../screens/m3u8_video_player_screen.dart';
import '../services/watch_history_service.dart';

class ContinueWatchingSection extends StatefulWidget {
  final List<Map<String, dynamic>> continueWatching;
  final Future<void> Function()? onChanged;

  const ContinueWatchingSection({
    super.key,
    required this.continueWatching,
    this.onChanged,
  });

  @override
  State<ContinueWatchingSection> createState() =>
      _ContinueWatchingSectionState();
}

class _ContinueWatchingSectionState extends State<ContinueWatchingSection> {
  late Map<String, bool> _resumableMap;

  @override
  void initState() {
    super.initState();
    _resumableMap = {};
    _loadResumableStates();
  }

  @override
  void didUpdateWidget(covariant ContinueWatchingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.continueWatching != widget.continueWatching) {
      _loadResumableStates();
    }
  }

  Future<void> _loadResumableStates() async {
    final resumableMap = <String, bool>{};

    for (final item in widget.continueWatching) {
      final key = '${item['tmdbId']}_${item['season']}_${item['episode']}';
      final isResumable = await WatchHistoryService.isResumable(
        item['tmdbId'],
        item['isMovie'],
        item['season'] ?? 1,
        item['episode'] ?? 1,
      );
      resumableMap[key] = isResumable;
    }

    if (mounted) {
      setState(() {
        _resumableMap = resumableMap;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.continueWatching.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Continue Watching',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.continueWatching.length,
            itemBuilder: (context, index) {
              final item = widget.continueWatching[index];
              return _buildContinueWatchingCard(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildContinueWatchingCard(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final progress = (item['position'] ?? 0) / (item['duration'] ?? 1);
    final progressPercent = (progress * 100).round();
    final key = '${item['tmdbId']}_${item['season']}_${item['episode']}';
    final isResumable = _resumableMap[key] ?? false;

    return GestureDetector(
      onTap: () {
        _playContent(context, item);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  SizedBox(
                    width: 140,
                    height: 160,
                    child: Image.network(
                      item['posterUrl']?.toString() ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => ColoredBox(
                        color: Colors.grey[800]!,
                        child: const Icon(
                          Icons.movie,
                          color: Colors.grey,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: progress,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Resume button overlay for resumable content
                  if (isResumable)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.play_circle_filled,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Resume',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                      color: Colors.black.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    const Positioned.fill(
                      child: Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item['title'] ?? 'Unknown Title',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (!item['isMovie'])
              Text(
                'S${item['season']}E${item['episode']}',
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            Text(
              '$progressPercent% watched',
              style: const TextStyle(
                color: Colors.red,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playContent(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => M3U8VideoPlayerScreen(
          title: item['title'],
          tmdbId: item['tmdbId'],
          isMovie: item['isMovie'],
          season: item['season'] ?? 1,
          episode: item['episode'] ?? 1,
        ),
      ),
    );
    await widget.onChanged?.call();
  }
}
