import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../../database/db_helper.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
import '../widgets/tv_breadcrumb_navigation.dart';
import '../widgets/tv_dark_mode_polish.dart';
import 'tv_video_player_screen.dart';

class TvSeriesScreen extends StatefulWidget {
  final Movie seriesItem;

  const TvSeriesScreen({super.key, required this.seriesItem});

  @override
  State<TvSeriesScreen> createState() => _TvSeriesScreenState();
}

class _TvSeriesScreenState extends State<TvSeriesScreen>
    with TvDpadNavigationMixin {
  YoutubePlayerController? _youtubeController;
  Map<String, dynamic>? seriesDetails;
  List<Season> seasons = [];
  int selectedSeasonIndex = 0;
  List<Episode> currentEpisodes = [];
  bool isLoading = true;
  bool isInWatchlist = false;
  bool isLoadingEpisodes = false;
  String? trailerUrl;
  List<Map<String, dynamic>> cast = [];
  List<Map<String, dynamic>> recommendations = [];
  late ScrollController _scrollController;
  int? _focusedButtonIndex;
  final List<String> _selectedGenres = [];

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadSeriesDetails();
    _checkWatchlistStatus();
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
      if (currentEpisodes.isNotEmpty) {
        _playEpisode(currentEpisodes[0]);
      }
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

  @override
  void dispose() {
    _youtubeController?.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _loadSeriesDetails() async {
    setState(() => isLoading = true);

    try {
      final details = await TmdbApiService.getSeriesDetails(
        int.parse(widget.seriesItem.id),
      );
      if (details != null && mounted) {
        setState(() {
          seriesDetails = details;
          seasons = (details['seasons'] as List)
              .map((season) => Season.fromJson(season))
              .where((season) => season.seasonNumber > 0)
              .toList();
          cast = List<Map<String, dynamic>>.from(
            details['credits']?['cast'] ?? [],
          );
          recommendations = List<Map<String, dynamic>>.from(
            details['recommendations']?['results'] ?? [],
          );
        });

        if (seasons.isNotEmpty) {
          _loadSeasonEpisodes(seasons[0].seasonNumber);
        }

        final trailerUrlFromApi = await TmdbApiService.getTrailerUrl(
          int.parse(widget.seriesItem.id),
          isMovie: false,
        );
        if (trailerUrlFromApi.isNotEmpty) {
          _initializeYouTubePlayer(trailerUrlFromApi);
        }
      }
    } catch (e) {
      debugPrint('Error loading series details: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    setState(() {
      isLoadingEpisodes = true;
    });

    try {
      final episodesData = await TmdbApiService.getSeasonEpisodes(
        int.parse(widget.seriesItem.id),
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
      debugPrint('Error loading episodes: $e');
      if (mounted) {
        setState(() {
          isLoadingEpisodes = false;
        });
      }
    }
  }

  Future<void> _checkWatchlistStatus() async {
    final watchlist = await DBHelper.getWatchlistItems();
    if (mounted) {
      setState(() {
        isInWatchlist = watchlist.any(
          (item) => item.id == widget.seriesItem.id,
        );
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      final wasAdded = !isInWatchlist;

      if (isInWatchlist) {
        await DBHelper.removeFromWatchlist(widget.seriesItem.id);
      } else {
        await DBHelper.addToWatchlist(widget.seriesItem);
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
      debugPrint('Error toggling watchlist: $e');
    }
  }

  void _playEpisode(Episode episode) {
    final season = seasons[selectedSeasonIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvVideoPlayerScreen(
          title:
              '${widget.seriesItem.title} - S${season.seasonNumber}E${episode.episodeNumber}: ${episode.name}',
          tmdbId: widget.seriesItem.id.toString(),
          isMovie: false,
          season: season.seasonNumber,
          episode: episode.episodeNumber,
        ),
      ),
    );
  }

  void _shareContent() {
    // Share functionality placeholder
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Container(height: 400, color: Colors.grey[800])],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final fontSize = TvUtils.responsiveFontSize(22, context, maxSize: 32);
    final padding = TvUtils.responsivePadding(24, context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.seriesItem.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (widget.seriesItem.rating > 0)
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFE50914), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.seriesItem.rating.toStringAsFixed(1)}/10',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: TvUtils.responsiveFontSize(16, context),
                      ),
                    ),
                  ],
                ),
              const SizedBox(width: 24),
              Expanded(
                child: Text(
                  widget.seriesItem.overview,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: TvUtils.responsiveFontSize(14, context),
                    height: 1.6,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(24, context),
      ),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () {
              if (currentEpisodes.isNotEmpty) {
                _playEpisode(currentEpisodes[0]);
              }
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Watch Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              padding: EdgeInsets.symmetric(
                horizontal: TvUtils.responsivePadding(24, context),
                vertical: TvUtils.responsivePadding(12, context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _toggleWatchlist,
            icon: Icon(isInWatchlist ? Icons.check : Icons.add),
            label: Text(isInWatchlist ? 'In Watchlist' : 'Add to Watchlist'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: TvUtils.responsivePadding(24, context),
                vertical: TvUtils.responsivePadding(12, context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: _shareContent,
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreChips() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(24, context),
      ),
      child: Wrap(
        spacing: TvUtils.responsivePadding(8, context),
        children:
            (_selectedGenres.isEmpty ? ['Drama', 'Series'] : _selectedGenres)
                .map(
                  (genre) => Chip(
                    label: Text(genre),
                    backgroundColor: Colors.grey[800],
                    labelStyle: const TextStyle(color: Colors.white),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildTrailerSection() {
    if (_youtubeController == null) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(24, context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trailer',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(20, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: YoutubePlayer(
                controller: _youtubeController!,
                showVideoProgressIndicator: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCastSection() {
    if (cast.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: TvUtils.responsivePadding(24, context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cast',
            style: TextStyle(
              color: Colors.white,
              fontSize: TvUtils.responsiveFontSize(20, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: cast.take(10).length,
              itemBuilder: (context, index) {
                final member = cast[index];
                return Container(
                  width: 150,
                  margin: EdgeInsets.only(
                    right: TvUtils.responsivePadding(12, context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: member['profile_path'] != null
                            ? Image.network(
                                TmdbApiService.getProfileUrl(
                                  member['profile_path'],
                                ),
                                width: 150,
                                height: 150,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 150,
                                height: 150,
                                color: Colors.grey[800],
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        member['name'] ?? 'Unknown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: TvUtils.responsiveFontSize(12, context),
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member['character'] ?? '',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: TvUtils.responsiveFontSize(10, context),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
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

  Widget _buildEpisodesSection() {
    final fontSize = TvUtils.responsiveFontSize(20, context, maxSize: 24);
    final padding = TvUtils.responsivePadding(24, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: Text(
            'Select Season',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: padding),
            itemCount: seasons.length,
            itemBuilder: (context, index) {
              final season = seasons[index];
              final isSelected = selectedSeasonIndex == index;

              return Padding(
                padding: EdgeInsets.only(
                  right: TvUtils.responsivePadding(8, context),
                ),
                child: FilterChip(
                  label: Text(
                    'Season ${season.seasonNumber}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey,
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
                    fontSize: TvUtils.responsiveFontSize(16, context),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        if (isLoadingEpisodes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.red),
            ),
          )
        else if (currentEpisodes.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Column(
              children: currentEpisodes
                  .map(
                    (episode) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () => _playEpisode(episode),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 200,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(12),
                                  ),
                                  color: const Color(0xFF2A2A2A),
                                ),
                                child: episode.stillPath.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                              left: Radius.circular(12),
                                            ),
                                        child: Image.network(
                                          'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white54,
                                        size: 60,
                                      ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            '${episode.episodeNumber}. ',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize:
                                                  TvUtils.responsiveFontSize(
                                                    18,
                                                    context,
                                                  ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              episode.name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                fontSize:
                                                    TvUtils.responsiveFontSize(
                                                      18,
                                                      context,
                                                    ),
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
                                            fontSize:
                                                TvUtils.responsiveFontSize(
                                                  14,
                                                  context,
                                                ),
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Colors.red,
                                  size: TvUtils.responsiveFontSize(32, context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
        else
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No episodes available',
                style: TextStyle(color: Colors.grey),
              ),
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
                      builder: (context) =>
                          TvSeriesScreen(seriesItem: Movie.fromJson(item)),
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
                                  Icons.tv,
                                  color: Colors.grey,
                                  size: 60,
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['name'] ?? 'Unknown',
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

  Widget _buildBreadcrumb() {
    return TvBreadcrumb(
      items: [
        BreadcrumbItem(
          label: 'Home',
          icon: 'home',
          onTap: () => Navigator.pop(context),
        ),
        BreadcrumbItem(label: 'Browse', icon: 'tv'),
        BreadcrumbItem(label: widget.seriesItem.title),
      ],
      currentIndex: 2,
      onItemTapped: (int value) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        _youtubeController?.pause();
      },
      child: DarkModeBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(56),
            child: DarkModeAppBar(
              title: widget.seriesItem.title,
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
                    SliverToBoxAdapter(child: _buildBreadcrumb()),
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
                            const SizedBox(height: 24),
                          ],
                          _buildEpisodesSection(),
                          if (cast.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            EnhancedDivider(addGradient: true),
                            const SizedBox(height: 24),
                            _buildCastSection(),
                          ],
                          if (recommendations.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            EnhancedDivider(addGradient: true),
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
    );
  }
}
