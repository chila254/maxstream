import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../services/logger_service.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
import 'tv_video_player_screen.dart';
import 'tv_series_screen.dart';

class TvDetailsScreen extends StatefulWidget {
  final Movie item;
  final String mediaType;

  const TvDetailsScreen({
    super.key,
    required this.item,
    required this.mediaType,
  });

  @override
  State<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends State<TvDetailsScreen> {
  bool isSaved = false;
  bool isLoading = true;
  Map<String, dynamic>? details;
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> recommendations = [];
  List<Season> seasons = [];
  List<Episode> currentEpisodes = [];
  int selectedSeasonIndex = 0;
  bool isLoadingEpisodes = false;
  String? seriesStatus;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadDetails();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => isLoading = true);

    try {
      final id = int.parse(widget.item.id);
      final isMovie = widget.mediaType == 'movie';
      final detailsData = isMovie
          ? await TmdbApiService.getMovieDetails(id)
          : await TmdbApiService.getSeriesDetails(id);

      if (detailsData != null) {
        setState(() {
          details = detailsData;
          recommendations = List<Map<String, dynamic>>.from(
            detailsData['recommendations']?['results'] ?? [],
          );
          cast = List<Map<String, dynamic>>.from(
            detailsData['credits']?['cast'] ?? [],
          );

          if (!isMovie && detailsData['seasons'] != null) {
            seasons = (detailsData['seasons'] as List)
                .map((season) => Season.fromJson(season))
                .where((season) => season.seasonNumber > 0)
                .toList();
            seriesStatus = detailsData['status'] ?? 'Unknown';
            selectedSeasonIndex = 0;

            if (seasons.isNotEmpty) {
              _loadSeasonEpisodes(seasons[0].seasonNumber);
            }
          }
        });
      }
      _checkWatchlistStatus();
    } catch (e) {
      LoggerService.error('Error loading details: $e', e);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _checkWatchlistStatus() async {
    final watchlist = await DBHelper.getWatchlistItems();
    if (mounted) {
      setState(() {
        isSaved = watchlist.any((item) => item.id == widget.item.id);
      });
    }
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    setState(() => isLoadingEpisodes = true);

    try {
      final episodesData = await TmdbApiService.getSeasonEpisodes(
        int.parse(widget.item.id),
        seasonNumber,
      );

      final episodes = episodesData.map((ep) => Episode.fromJson(ep)).toList();

      if (mounted) {
        setState(() {
          currentEpisodes = episodes;
          isLoadingEpisodes = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoadingEpisodes = false);
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      final wasAdded = !isSaved;

      if (isSaved) {
        await DBHelper.removeFromWatchlist(widget.item.id);
      } else {
        await DBHelper.addToWatchlist(widget.item);
      }
      await _checkWatchlistStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  wasAdded ? Icons.favorite : Icons.favorite_border,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  wasAdded ? 'Added to Watchlist' : 'Removed from Watchlist',
                ),
              ],
            ),
            backgroundColor:
                wasAdded ? Colors.green.shade600 : Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      LoggerService.error('Error toggling watchlist: $e', e);
    }
  }

  void _playContent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
          title: widget.item.title,
          tmdbId: widget.item.id.toString(),
          isMovie: widget.mediaType == 'movie',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKey: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            Navigator.pop(context);
            TvFocusManager.focusSidebar();
            context.read<TvNavigationProvider>().returnToSidebar();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      autofocus: true,
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          if (didPop) {
            context.read<TvNavigationProvider>().setDeepNavigating(false);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0F0F0F),
          body: isLoading ? _buildLoadingShimmer() : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isTvSeries = widget.mediaType == 'tv';

    return Stack(
      children: [
        // Full-screen backdrop
        Positioned.fill(
          child: Image.network(
            TmdbApiService.getBackdropUrl(widget.item.backdropPath),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
        ),
        // Left gradient for readability
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0xCC0F0F0F),
                  Color(0x660F0F0F),
                  Color(0xCC0F0F0F),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ),
        // Bottom gradient
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Color(0xF00F0F0F),
                ],
                stops: [0.3, 0.7],
              ),
            ),
          ),
        ),
        // Content
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Top spacing for back button
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
            // Hero section: poster + info + actions
            SliverToBoxAdapter(child: _buildHeroSection()),
            // Season tabs (series only)
            if (isTvSeries && seasons.isNotEmpty)
              SliverToBoxAdapter(child: _buildSeasonTabs()),
            // Episodes row (series only)
            if (isTvSeries && currentEpisodes.isNotEmpty)
              SliverToBoxAdapter(child: _buildEpisodesRow()),
            // Cast section
            if (cast.isNotEmpty)
              SliverToBoxAdapter(child: _buildCastSection()),
            // More Like This
            if (recommendations.isNotEmpty)
              SliverToBoxAdapter(child: _buildRecommendations()),
            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
        // Back button overlay
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.read<TvNavigationProvider>().returnToSidebar();
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    final title = widget.item.title;
    final rating = widget.item.rating;
    final year = _getYear();
    final overview = details?['overview'] ?? widget.item.overview;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poster
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              TmdbApiService.getPosterUrl(widget.item.posterPath),
              width: 180,
              height: 270,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 180,
                height: 270,
                color: Colors.grey[800],
                child: const Icon(Icons.movie, color: Colors.grey, size: 60),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // Metadata badges
                Row(
                  children: [
                    if (rating > 0) ...[
                      _Badge(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (year != null) ...[
                      _Badge(label: year),
                      const SizedBox(width: 8),
                    ],
                    if (widget.item.genres.isNotEmpty)
                      _Badge(label: widget.item.genres.first),
                  ],
                ),
                const SizedBox(height: 16),
                // Action buttons
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.play_arrow,
                      label: 'Play',
                      primary: true,
                      onTap: _playContent,
                    ),
                    const SizedBox(width: 10),
                    _ActionButton(
                      icon: isSaved ? Icons.favorite : Icons.favorite_border,
                      label: isSaved ? 'Saved' : 'Save',
                      onTap: _toggleWatchlist,
                    ),
                    const SizedBox(width: 10),
                    if (widget.mediaType != 'movie')
                      _ActionButton(
                        icon: Icons.info_outline,
                        label: 'Details',
                        onTap: () {},
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Overview
                Text(
                  overview,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                    height: 1.5,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeasonTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seasons',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = index == selectedSeasonIndex;

                return Focus(
                  onKey: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.select) {
                      setState(() => selectedSeasonIndex = index);
                      _loadSeasonEpisodes(season.seasonNumber);
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: GestureDetector(
                    onTap: () {
                      setState(() => selectedSeasonIndex = index);
                      _loadSeasonEpisodes(season.seasonNumber);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.red
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected
                              ? Colors.red
                              : Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        season.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodesRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Episodes (${currentEpisodes.length})',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isLoadingEpisodes)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: currentEpisodes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final episode = currentEpisodes[index];
                  return _EpisodeCard(
                    episode: index + 1,
                    title: episode.name,
                    overview: episode.overview,
                    stillPath: episode.stillPath,
                    onTap: () {
                      final season = seasons[selectedSeasonIndex];
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TvVideoPlayerScreen(
                            title:
                                '${widget.item.title} - S${season.seasonNumber}E${episode.episodeNumber}: ${episode.name}',
                            tmdbId: widget.item.id.toString(),
                            isMovie: false,
                            season: season.seasonNumber,
                            episode: episode.episodeNumber,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCastSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cast.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final member = cast[index];
                return SizedBox(
                  width: 100,
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: member['profile_path'] != null
                            ? Image.network(
                                TmdbApiService.getProfileUrl(
                                    member['profile_path']),
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[800],
                                child: const Icon(Icons.person,
                                    color: Colors.grey, size: 36),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'More Like This',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recommendations.take(10).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final item = recommendations[index];
                final posterUrl = TmdbApiService.getPosterUrl(
                  item['poster_path'] ?? '',
                );
                final itemTitle = item['name'] ?? item['title'] ?? 'Unknown';
                final releaseDate = item['release_date'] as String?;
                final firstAirDate = item['first_air_date'] as String?;
                final year = releaseDate != null && releaseDate.length >= 4
                    ? releaseDate.substring(0, 4)
                    : firstAirDate != null && firstAirDate.length >= 4
                        ? firstAirDate.substring(0, 4)
                        : null;

                return _RecommendationCard(
                  posterUrl: posterUrl,
                  title: itemTitle,
                  year: year,
                  onTap: () {
                    final type = item['media_type'] ??
                        (item['first_air_date'] != null ? 'tv' : 'movie');
                    if (type == 'tv') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TvSeriesScreen(
                            seriesItem: Movie.fromJson(item),
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TvDetailsScreen(
                            item: Movie.fromJson(item),
                            mediaType: 'movie',
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getYear() {
    final date = details?['release_date'] ?? details?['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return 'N/A';
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 180,
                  height: 270,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 32, width: 300, color: Colors.grey[800]),
                      const SizedBox(height: 16),
                      Container(height: 20, width: 150, color: Colors.grey[800]),
                      const SizedBox(height: 16),
                      ...List.generate(
                        4,
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child:
                              Container(height: 14, color: Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String? label;
  final Widget? child;

  const _Badge({this.label, this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: child ??
          Text(
            label ?? '',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.primary = false,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKey: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: widget.primary
                ? Colors.red
                : _isFocused
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: _isFocused
                ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final int episode;
  final String title;
  final String overview;
  final String stillPath;
  final VoidCallback onTap;

  const _EpisodeCard({
    required this.episode,
    required this.title,
    required this.overview,
    required this.stillPath,
    required this.onTap,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKey: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 280,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(10),
            border: _isFocused
                ? Border.all(color: Colors.red, width: 2)
                : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              Stack(
                children: [
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: widget.stillPath.isNotEmpty
                        ? Image.network(
                            'https://image.tmdb.org/t/p/w300${widget.stillPath}',
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[800],
                              child: const Icon(Icons.play_circle_outline,
                                  color: Colors.white54, size: 40),
                            ),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.play_circle_outline,
                                color: Colors.white54, size: 40),
                          ),
                  ),
                  if (_isFocused)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.4),
                        child: const Center(
                          child: Icon(Icons.play_arrow,
                              color: Colors.white, size: 36),
                        ),
                      ),
                    ),
                ],
              ),
              // Info
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'E${widget.episode}',
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: TextStyle(
                              color:
                                  _isFocused ? Colors.white : Colors.grey[300],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.overview.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.overview,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatefulWidget {
  final String posterUrl;
  final String title;
  final String? year;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.posterUrl,
    required this.title,
    this.year,
    required this.onTap,
  });

  @override
  State<_RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<_RecommendationCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onKey: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.select) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? 1.06 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border:
                  _isFocused ? Border.all(color: Colors.red, width: 2) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.network(
                      widget.posterUrl,
                      fit: BoxFit.cover,
                      width: 130,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[800],
                        child: const Icon(Icons.movie,
                            color: Colors.grey, size: 40),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A1A1A),
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(8)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color:
                              _isFocused ? Colors.white : Colors.grey[300],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.year != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          widget.year!,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
