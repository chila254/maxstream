import 'package:flutter/material.dart';

import '../../models/movie.dart';
import '../widgets/tv_cinematic_details.dart';

class TvSeriesScreen extends StatelessWidget {
  const TvSeriesScreen({super.key, required this.seriesItem});

  final Movie seriesItem;

  @override
  Widget build(BuildContext context) =>
      TvCinematicDetails(item: seriesItem, mediaType: 'tv');
}
