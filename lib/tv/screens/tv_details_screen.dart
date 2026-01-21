import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:ui' as ui;
import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
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

class _TvDetailsScreenState extends State<TvDetailsScreen>
    with TvDpadNavigationMixin {
  YoutubePlayerController? _youtubeController;
  bool isSaved = false;
  bool isLoading = true;
  String? trailerUrl;
  Map<String, dynamic>? details;
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> recommendations = [];
  List<Season> seasons = [];
  List<Episode> currentEpisodes = [];
  int selectedSeasonIndex = 0;
  bool isLoadingEpisodes = false;
  String? seriesStatus;
  late ScrollController _scrollController;
  int? _focusedButtonIndex;
  int _focusedActionIndex = 0;
  List<String> _selectedGenres = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadDetails();
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => 1; // 0: Watch Now, 1: Add to My List

  @override
  void onFocusChanged(int index) {
    setState(() => _focusedButtonIndex = index);
  }

  @override
  void onSelectPressed() {
    if (_focusedButtonIndex == 0) {
      playContent();
    } else if (_focusedButtonIndex == 1) {
      _toggleWatchlist();
    }
  }

  @override
  void onLeftPressed() {
    if (_focusedButtonIndex != null && _focusedButtonIndex! > 0) {
      setFocusIndex(_focusedButtonIndex! - 1);
    }
  }

  @override
  void onRightPressed() {
    if (_focusedButtonIndex != null && _focusedButtonIndex! < maxFocusIndex) {
      setFocusIndex(_focusedButtonIndex! + 1);
    }
  }

  void _initializeYouTubePlayer(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId != null) {
      setState(() {
        trailerUrl = url;
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: false,
            mute: false,
            enableCaption: true,
          ),
        );
      });
    }
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
          cast = List<Map<String, dynamic>>.from(
            detailsData['credits']?['cast'] ?? [],
          );
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

        final trailerUrlFromApi = await TmdbApiService.getTrailerUrl(
          id,
          isMovie: isMovie,
        );
        if (trailerUrlFromApi.isNotEmpty) {
          _initializeYouTubePlayer(trailerUrlFromApi);
        }
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
      print('Error toggling watchlist: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTvSeries = widget.mediaType == 'tv';

    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: PopScope(
        canPop: true,
        onPopInvoked: (didPop) {
          if (didPop) {
            _youtubeController?.pause();
          }
        },
        child: DarkModeBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(56),
              child: DarkModeAppBar(
                title: widget.item.title,
                onBackPressed: () {
                  _youtubeController?.pause();
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
                            if (_youtubeController != null) ...[
                              _buildTrailerSection(),
                              const SizedBox(height: 32),
                            ],
                            if (isTvSeries && seasons.isNotEmpty) ...[
                              _buildSeasonsSection(),
                              const SizedBox(height: 24),
                              _buildEpisodesSection(),
                              const SizedBox(height: 32),
                            ],
                            _buildInfoSection(),
                            if (cast.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              SectionDivider(
                                title: 'Cast',
                                icon: Icons.people,
                              ),
                              const SizedBox(height: 24),
                              _buildCastSection(),
                            ],
                            if (recommendations.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              SectionDivider(
                                title: 'More Like This',
                                icon: Icons.favorite,
                              ),
                              const SizedBox(height: 24),
                              _buildRecommendationsSection(),
                            ],
                            const SizedBox(height: 40),
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
              fontSize: TvUtils.responsiveFontSize(18, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: TvUtils.responsivePadding(12, context)),
          Wrap(
            spacing: TvUtils.responsivePadding(8, context),
            runSpacing: TvUtils.responsivePadding(8, context),
            children: widget.item.genres.map((genre) {
              final isSelected = _selectedGenres.contains(genre);
              return CategoryChip(
                label: genre,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedGenres.remove(genre);
                    } else {
                      _selectedGenres.add(genre);
                    }
                  });
                },
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
            Text(details!['overview'], style: TvTypography.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildTrailerSection() {
    final padding = TvUtils.responsivePadding(24, context);
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Text(
            'Trailer',
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 300,
              child: YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.red,
                progressColors: const ProgressBarColors(
                  playedColor: Colors.red,
                  handleColor: Colors.redAccent,
                ),
                onReady: () {
                  _youtubeController?.pause();
                },
              ),
            ),
          ),
        ),
      ],
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
          Text(
            'Episodes',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...currentEpisodes.map((episode) {
            return _buildEpisodeCard(episode);
          }),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Episode episode) {
    final padding = TvUtils.responsivePadding(16, context);
    final hasAirDate = episode.stillPath.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: padding),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
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

    if (cast.isNotEmpty) {
      final castNames = cast.take(3).map((c) => c['name']).join(', ');
      infoItems.add('Cast: $castNames');
    }

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
      addGlow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < infoItems.length; i++) ...[
            Row(
              children: [
                Icon(_getInfoIcon(i), color: const Color(0xFFE50914), size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    infoItems[i],
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: TvUtils.responsiveFontSize(14, context),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (i < infoItems.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: EnhancedDivider(addGradient: true),
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

  Widget _buildCastSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Text(
            'Cast',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: cast.take(10).length,
            itemBuilder: (context, index) {
              final actor = cast[index];
              return Container(
                width: 180,
                margin: EdgeInsets.only(
                  right: TvUtils.responsivePadding(20, context),
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: actor['profile_path'] != null
                          ? Image.network(
                              TmdbApiService.getProfileUrl(
                                actor['profile_path'],
                              ),
                              width: 180,
                              height: 180,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 180,
                              height: 180,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                                size: 60,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      actor['name'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TvUtils.responsiveFontSize(16, context),
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
    );
  }

  Widget _buildRecommendationsSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(padding),
          child: Text(
            'More Like This',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: recommendations.take(10).length,
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TvDetailsScreen(
                        item: Movie.fromJson(item),
                        mediaType: item['media_type'] ?? widget.mediaType,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 180,
                  margin: EdgeInsets.only(
                    right: TvUtils.responsivePadding(20, context),
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: item['poster_path'] != null
                            ? Image.network(
                                TmdbApiService.getPosterUrl(
                                  item['poster_path'],
                                ),
                                width: 180,
                                height: 270,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 180,
                                height: 270,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.movie,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'] ?? item['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TvUtils.responsiveFontSize(14, context),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
