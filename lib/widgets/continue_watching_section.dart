import 'package:flutter/material.dart';
import '../screens/inapp_video_player_screen.dart';

class ContinueWatchingSection extends StatelessWidget {
  final List<Map<String, dynamic>> continueWatching;

  const ContinueWatchingSection({super.key, required this.continueWatching});

  @override
  Widget build(BuildContext context) {
    if (continueWatching.isEmpty) return const SizedBox();

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
            itemCount: continueWatching.length,
            itemBuilder: (context, index) {
              final item = continueWatching[index];
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InAppVideoPlayerScreen(
              title: item['title'],
              tmdbId: item['tmdbId'],
              isMovie: item['isMovie'],
              season: item['season'] ?? 1,
              episode: item['episode'] ?? 1,
            ),
          ),
        );
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
                  Container(
                    width: 140,
                    height: 160,
                    color: Colors.grey[800],
                    child: const Icon(
                      Icons.movie,
                      color: Colors.grey,
                      size: 40,
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
}
