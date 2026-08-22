import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AppNetworkImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  int? _safeInt(double? value) {
    if (value == null || value.isInfinite || value.isNaN) return null;
    return value.toInt();
  }

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ?? _defaultError();
    }

    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: _safeInt(width),
      memCacheHeight: _safeInt(height),
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, _) => Container(
        width: width,
        height: height,
        color: Colors.grey[850],
      ),
      errorWidget: (context, url, error) => errorWidget ?? _defaultError(),
    );
  }

  Widget _defaultError() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[850],
      child: const Icon(Icons.movie, color: Colors.grey, size: 40),
    );
  }
}
