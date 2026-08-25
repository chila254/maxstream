import 'dart:async';

import 'package:flutter/material.dart';

import '../services/miniplayer_service.dart';

class MiniplayerBar extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onClose;

  const MiniplayerBar({
    super.key,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<MiniplayerBar> createState() => _MiniplayerBarState();
}

class _MiniplayerBarState extends State<MiniplayerBar> {
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _progressTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = MiniplayerService.instance;
    final controller = service.controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    final value = controller.value;
    final position = value.position;
    final duration = value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    final title = service.isMovie
        ? service.title
        : '${service.title} S${service.season}E${service.episode}';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 200,
        height: 130,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video area background
            Container(
              color: Colors.black,
              child: const Center(
                child: Icon(
                  Icons.movie,
                  color: Colors.white12,
                  size: 36,
                ),
              ),
            ),
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Title + progress
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 2,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            // Play/pause button
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    if (value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                    setState(() {});
                  },
                  icon: Icon(
                    value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
