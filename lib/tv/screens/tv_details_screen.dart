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
import '../widgets/tv_breadcrumb_navigation.dart';
import '../widgets/tv_quick_actions.dart';
import '../widgets/tv_visual_enhancements.dart';
import '../widgets/tv_dark_mode_polish.dart';
import 'tv_video_player_screen.dart';

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
  int selectedEpisodeIndex = 0;
  bool isLoadingEpisodes = false;
  String? seriesStatus;
  late ScrollController _scrollController;
  int _focusedActionIndex = 0;
  bool _episodeFocused = false;

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

          // Load seasons for TV series
          if (!isMovie && detailsData['seasons'] != null) {
            seasons = (detailsData['seasons'] as List)
                .map((season) => Season.fromJson(season))
                .where((season) => season.seasonNumber > 0)
                .toList();
            seriesStatus = detailsData['status'] ?? 'Unknown';
            selectedSeasonIndex = 0;

            // Load episodes for first season
            if (seasons.isNotEmpty) {
              _loadSeasonEpisodes(seasons[0].seasonNumber);
            }
          }
        });
      }
      _checkWatchlistStatus();
    } catch (e) {
      // Error loading details
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
    setState(() {
      isLoadingEpisodes = true;
    });

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
      // Error loading episodes
      if (mounted) {
        setState(() {
          isLoadingEpisodes = false;
        });
      }
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
            backgroundColor: wasAdded
                ? Colors.green.shade600
                : Colors.red.shade600,
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

  @override
  Widget build(BuildContext context) {
    final isTvSeries = widget.mediaType == 'tv';

    return Focus(
      onKey: (node, event) {
        if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft) &&
            event.isKeyPressed(LogicalKeyboardKey.escape) == false) {
          Navigator.pop(context);
          TvFocusManager.focusSidebar();
          context.read<TvNavigationProvider>().returnToSidebar();
          return KeyEventResult.handled;
        } else if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
          Navigator.pop(context);
          TvFocusManager.focusSidebar();
          context.read<TvNavigationProvider>().returnToSidebar();
          return KeyEventResult.handled;
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
        child: Stack(
          children: [
            // Background Image with Blur
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      TmdbApiService.getBackdropUrl(widget.item.backdropPath),
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Main Content
            Scaffold(
              backgroundColor: Colors.transparent,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: DarkModeAppBar(
                  title: widget.item.title,
                  onBackPressed: () {
                    context.read<TvNavigationProvider>().setDeepNavigating(
                      false,
                    );
                    Navigator.pop(context);
                  },
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share, color: Color(0xFFE50914)),
                      onPressed: () => _shareContent(),
                    ),
                  ],
                ),
              ),
              body: isLoading
                  ? _buildLoadingShimmer()
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Breadcrumb Navigation
                        SliverToBoxAdapter(child: _buildBreadcrumb(isTvSeries)),
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailsSection(),
                              const SizedBox(height: 24),
                              // Quick Action Buttons
                              _buildQuickActions(),
                              const SizedBox(height: 24),
                              // Genre Chips
                              _buildGenreChips(),
                              const SizedBox(height: 24),
                              if (isTvSeries && seasons.isNotEmpty) ...[
                                _buildSeasonsSection(),
                                const SizedBox(height: 16),
                                _buildEpisodesSection(),
                                const SizedBox(height: 24),
                              ],
                              _buildInfoSection(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(bool isTvSeries) {
    return TvBreadcrumb(
      items: [
        BreadcrumbItem(
          label: 'Home',
          icon: 'home',
          onTap: () => Navigator.pop(context),
        ),
        BreadcrumbItem(label: 'Browse', icon: 'movies'),
        BreadcrumbItem(
          label: isTvSeries ? 'Series' : 'Movies',
          icon: isTvSeries ? 'series' : 'movies',
        ),
        BreadcrumbItem(label: widget.item.title),
      ],
      currentIndex: 3,
      onItemTapped: (index) {
        if (index == 0) {
          Navigator.pop(context);
        }
      },
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      QuickAction(
        label: 'Play',
        icon: Icons.play_arrow,
        onPressed: () => playContent(),
        color: const Color(0xFFE50914),
      ),
      QuickAction(
        label: isSaved ? 'Remove' : 'Add to List',
        icon: isSaved ? Icons.favorite : Icons.favorite_border,
        onPressed: () => _toggleWatchlist(),
      ),
      QuickAction(
        label: 'Share',
        icon: Icons.share,
        onPressed: () => _shareContent(),
      ),
    ];

    return TvQuickActionsBar(
      actions: actions,
      focusedIndex: _focusedActionIndex,
      onFocusChanged: (index) {
        setState(() => _focusedActionIndex = index);
      },
    );
  }

  Widget _buildGenreChips() {
    if (widget.item.genres.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(24, context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Genres',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(16, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(8, context)),
          Wrap(
            spacing: TvUtils.responsivePadding(6, context),
            runSpacing: TvUtils.responsivePadding(6, context),
            children: widget.item.genres.take(5).map((genre) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE50914)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  genre,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _shareContent() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Share: ${widget.item.title}'),
        backgroundColor: const Color(0xFFE50914),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            flexibleSpace: Container(color: Colors.grey[800]),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 24, width: 200, color: Colors.grey[800]),
                  const SizedBox(height: 8),
                  Container(height: 16, width: 150, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  ...List.generate(
                    5,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(height: 16, color: Colors.grey[800]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TvSpacing.sectionPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with Gradient
          GradientText(widget.item.title, baseStyle: TvTypography.heroTitle),
          const SizedBox(height: TvSpacing.md),
          // Rating and Year
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TvSpacing.md,
                      vertical: TvSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.item.rating.toStringAsFixed(1)}/10',
                          style: TvTypography.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: TvSpacing.md),
              Text(getYear(), style: TvTypography.bodyMedium),
            ],
          ),
          const SizedBox(height: TvSpacing.lg),
          // Description
          if (details?['overview'] != null)
            Text(
              details!['overview'],
              style: TvTypography.bodyLarge,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildSeasonsSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Text(
            'Seasons',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(seasons.length, (index) {
              final season = seasons[index];
              final isSelected = index == selectedSeasonIndex;
              return FilterChip(
                label: Text(
                  season.name,
                  style: TextStyle(
                    fontSize: TvUtils.responsiveFontSize(14, context),
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      selectedSeasonIndex = index;
                    });
                    _loadSeasonEpisodes(season.seasonNumber);
                  }
                },
                selectedColor: Colors.red,
                backgroundColor: const Color(0xFF2A2A2A),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey,
                  fontSize: TvUtils.responsiveFontSize(14, context),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodesSection() {
    final padding = TvUtils.responsivePadding(24, context);
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    if (isLoadingEpisodes) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(color: Colors.red),
          ),
        ),
      );
    }

    if (currentEpisodes.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'No episodes available',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Episodes (${currentEpisodes.length})',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Season ${seasons[selectedSeasonIndex].seasonNumber}',
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: TvUtils.responsiveFontSize(14, context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingEpisodes)
            Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFFE50914),
                ),
              ),
            )
          else
            ...currentEpisodes.take(6).toList().asMap().entries.map((e) {
              final index = e.key;
              final episode = e.value;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedEpisodeIndex = index;
                    _episodeFocused = true;
                  });
                },
                child: _buildEpisodeCard(
                  episode,
                  isFocused: _episodeFocused && selectedEpisodeIndex == index,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Episode episode, {bool isFocused = false}) {
    final padding = TvUtils.responsivePadding(16, context);
    final hasAirDate = episode.stillPath.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: isFocused ? const Color(0xFF2a2a3e) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: isFocused
              ? Border.all(color: const Color(0xFFE50914), width: 2)
              : null,
        ),
        child: Row(
          children: [
            // Episode still/poster with play overlay
            Container(
              width: 200,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(12),
                ),
                color: const Color(0xFF2A2A2A),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasAirDate)
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      child: Image.network(
                        'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      child: Container(
                        color: Colors.grey[800],
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white54,
                          size: 60,
                        ),
                      ),
                    ),
                  // Play overlay - only show if aired
                  if (hasAirDate)
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Episode info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${episode.episodeNumber}. ',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: TvUtils.responsiveFontSize(18, context),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            episode.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: TvUtils.responsiveFontSize(16, context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (episode.overview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        episode.overview,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: TvUtils.responsiveFontSize(14, context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Play icon or coming soon date
            Padding(
              padding: const EdgeInsets.all(16),
              child: hasAirDate
                  ? Icon(
                      Icons.play_arrow,
                      color: Colors.red,
                      size: TvUtils.responsiveFontSize(32, context),
                    )
                  : Text(
                      'Coming Soon',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: TvUtils.responsiveFontSize(12, context),
                      ),
                      textAlign: TextAlign.center,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    final padding = TvUtils.responsivePadding(24, context);
    final isTvSeries = widget.mediaType == 'tv';

    final infoItems = <String>[];

    if (widget.item.genres.isNotEmpty) {
      infoItems.add('Genre: ${widget.item.genres.join(', ')}');
    }

    if (details?['production_companies'] != null) {
      final companies = (details!['production_companies'] as List)
          .take(2)
          .map((c) => c['name'])
          .join(', ');
      if (companies.isNotEmpty) {
        String productionInfo = 'Production: $companies';
        if (widget.item.country.isNotEmpty) {
          productionInfo += ' (${widget.item.country})';
        }
        infoItems.add(productionInfo);
      }
    } else if (widget.item.country.isNotEmpty) {
      infoItems.add('Country: ${widget.item.country}');
    }

    if (isTvSeries && seriesStatus != null) {
      infoItems.add('Status: $seriesStatus');
    }

    if (infoItems.isEmpty) return const SizedBox.shrink();

    return DarkModePanelEnhanced(
      padding: EdgeInsets.all(padding),
      margin: EdgeInsets.symmetric(horizontal: padding),
      addPattern: true,
      addGlow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < infoItems.length; i++) ...[
            Row(
              children: [
                Icon(_getInfoIcon(i), color: const Color(0xFFE50914), size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    infoItems[i],
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: TvUtils.responsiveFontSize(13, context),
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (i < infoItems.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: EnhancedDivider(addGradient: false),
              ),
          ],
        ],
      ),
    );
  }

  IconData _getInfoIcon(int index) {
    final icons = [
      Icons.people,
      Icons.local_movies,
      Icons.business,
      Icons.info,
    ];
    return icons[index % icons.length];
  }

  String getYear() {
    final date = details?['release_date'] ?? details?['first_air_date'];
    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return 'N/A';
  }

  void playContent() {
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
}
