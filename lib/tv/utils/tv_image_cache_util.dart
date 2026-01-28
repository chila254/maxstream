import 'package:flutter/material.dart';

/// Utility for optimized image caching on TV displays
/// Reduces memory usage on large 4K TVs by using appropriate cache dimensions
class TvImageCacheUtil {
  /// Standard TV poster dimensions for caching
  /// Used for content cards and carousels
  static const int posterCacheWidth = 256;
  static const int posterCacheHeight = 384;

  /// Hero banner cache dimensions - higher quality for hero section
  static const int heroBannerCacheWidth = 1280;
  static const int heroBannerCacheHeight = 720;

  /// Backdrop image cache dimensions
  static const int backdropCacheWidth = 1024;
  static const int backdropCacheHeight = 576;

  /// Get optimized cache dimensions for a given image type
  static ImageProvider getCachedImage(
    String imageUrl, {
    required ImageCacheType cacheType,
    BoxFit fit = BoxFit.cover,
  }) {
    if (imageUrl.isEmpty) {
      return const AssetImage('assets/images/placeholder.png');
    }

    final (cacheWidth, cacheHeight) = _getCacheDimensions(cacheType);

    return ResizeImage(
      NetworkImage(imageUrl),
      width: cacheWidth,
      height: cacheHeight,
    );
  }

  /// Get cache dimensions based on image type
  static (int, int) _getCacheDimensions(ImageCacheType type) {
    return switch (type) {
      ImageCacheType.poster => (posterCacheWidth, posterCacheHeight),
      ImageCacheType.heroBanner => (
        heroBannerCacheWidth,
        heroBannerCacheHeight,
      ),
      ImageCacheType.backdrop => (backdropCacheWidth, backdropCacheHeight),
    };
  }

  /// Preload images to improve perceived performance
  static Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls, {
    required ImageCacheType cacheType,
  }) async {
    final futures = imageUrls.map((url) {
      final provider = getCachedImage(url, cacheType: cacheType);
      return precacheImage(provider, context).catchError((e) {
        debugPrint('Error precaching image: $e');
      });
    }).toList();

    await Future.wait(futures);
  }

  /// Clear entire image cache (use sparingly)
  static void clearImageCache() {
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  /// Get memory-efficient Image widget with caching
  static Widget cachedImage(
    String imageUrl, {
    required ImageCacheType cacheType,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Color? backgroundColor,
    Widget? errorWidget,
  }) {
    final image = Image(
      image: getCachedImage(imageUrl, cacheType: cacheType),
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ??
            Container(
              width: width,
              height: height,
              color: backgroundColor ?? Colors.grey[900],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius, child: image);
    }

    return image;
  }
}

enum ImageCacheType {
  /// Standard poster image (180x270)
  poster,

  /// Large hero banner (1280x720)
  heroBanner,

  /// Backdrop image (1024x576)
  backdrop,
}
