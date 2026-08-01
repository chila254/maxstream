import 'package:flutter/material.dart';

import '../../models/movie.dart';
import '../widgets/tv_cinematic_details.dart';

class TvDetailsScreen extends StatelessWidget {
  const TvDetailsScreen({
    super.key,
    required this.item,
    required this.mediaType,
  });

  final Movie item;
  final String mediaType;

  @override
  Widget build(BuildContext context) =>
      TvCinematicDetails(item: item, mediaType: mediaType);
}
