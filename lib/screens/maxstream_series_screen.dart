import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movie.dart';
import '../models/series.dart';
import '../services/media_download_manager.dart';
import '../services/direct_m3u8_service.dart';
import '../services/tmdb_api_service.dart';
import '../services/watch_history_service.dart';
import '../database/db_helper.dart';
import '../services/cloud_sync_service.dart';
import '../widgets/app_network_image.dart';
import '../widgets/video_player_screen.dart';

class MaxStreamSeriesScreen extends StatefulWidget {
  final Movie seriesItem;

  const MaxStreamSeriesScreen({super.key, required this.seriesItem});

  @override
  State<MaxStreamSeriesScreen> createState() => _MaxStreamSeriesScreenState();
}

class _MaxStreamSeriesScreenState extends State<MaxStreamSeriesScreen> {
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
  final Set<String> _downloadingEpisodes = {};
  bool _downloadingSeason = false;
  int _seasonDownloadCurrent = 0;
  int _seasonDownloadTotal = 0;
  String _seasonDownloadStatus = '';
  late final MediaDownloadManager _downloadManager;
  final Set<String> _downloadedEpisodeKeys = {};
  Map<String, dynamic>? _watchProgress;

  @override
  void initState() {
    super.initState();
    _downloadManager = MediaDownloadManager.instance;
    _downloadManager.addListener(_onDownloadChanged);
    CloudSyncService.watchlistRevision.addListener(_onSyncedWatchlist);
    _loadSeriesDetails();
    _checkWatchlistStatus();
    _loadWatchProgress();
  }

  void _onSyncedWatchlist() {
    if (mounted) _checkWatchlistStatus();
  }

  @override
  void dispose() {
    CloudSyncService.watchlistRevision.removeListener(_onSyncedWatchlist);
    _youtubeController?.dispose();
    _downloadManager.removeListener(_onDownloadChanged);
    super.dispose();
  }

  void _onDownloadChanged() {
    if (mounted) {
      _refreshDownloadedStatus();
      setState(() {});
    }
  }

  String _episodeDownloadKey(int season, int episode) =>
      'series_${widget.seriesItem.id}_s${season}_e$episode';

  Future<void> _refreshDownloadedStatus() async {
    final downloads = await DBHelper.getMediaDownloads();
    final keys = <String>{};
    for (final d in downloads) {
      final key = d['downloadKey']?.toString() ?? '';
      if (key.isNotEmpty) keys.add(key);
    }
    // Also include active downloads
    for (final active in _downloadManager.activeDownloads) {
      keys.add(active.downloadKey);
    }
    if (mounted) {
      setState(() {
        _downloadedEpisodeKeys
          ..clear()
          ..addAll(keys);
      });
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
              .where((season) => season.seasonNumber > 0) // Filter out specials
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

        // Load trailer
        final trailerUrlFromApi = await TmdbApiService.getTrailerUrl(
          int.parse(widget.seriesItem.id),
          isMovie: false,
        );
        if (trailerUrlFromApi.isNotEmpty) {
          _initializeYouTubePlayer(trailerUrlFromApi);
        }
      }
      _refreshDownloadedStatus();
    } catch (e) {
      // Error loading series details
    } finally {
      if (mounted) setState(() => isLoading = false);
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
        _refreshDownloadedStatus();
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

  Future<void> _checkWatchlistStatus() async {
    await CloudSyncService.pullToDevice();
    final watchlist = await DBHelper.getWatchlistItems();
    if (mounted) {
      setState(() {
        isInWatchlist = watchlist.any(
          (item) =>
              item.id == widget.seriesItem.id &&
              item.mediaType == widget.seriesItem.mediaType,
        );
      });
    }
  }

  Future<void> _toggleWatchlist() async {
    try {
      final wasAdded = !isInWatchlist;

      if (isInWatchlist) {
        await DBHelper.removeFromWatchlist(
          widget.seriesItem.id,
          widget.seriesItem.mediaType,
        );
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
      // Error toggling watchlist
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('Error updating watchlist: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  void _playEpisode(Episode episode) {
    final season = seasons[selectedSeasonIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => buildVideoPlayerScreen(
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

  void _showEpisodeQualitySheet(Episode episode) {
    final season = seasons[selectedSeasonIndex].seasonNumber;
    final episodeTitle =
        '${widget.seriesItem.title} - S${season}E${episode.episodeNumber}: ${episode.name}';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return _EpisodeQualitySheet(
          title: episodeTitle,
          tmdbId: widget.seriesItem.id,
          season: season,
          episode: episode.episodeNumber,
          onDownload: (selectedStream) {
            _downloadEpisode(
              episode,
              seasonNumber: season,
              selectedStream: selectedStream,
            );
          },
        );
      },
    );
  }

  Future<bool> _downloadEpisode(
    Episode episode, {
    bool showResult = true,
    int? seasonNumber,
    String? resolverTitle,
    Map<String, dynamic>? selectedStream,
  }) async {
    final season = seasonNumber ?? seasons[selectedSeasonIndex].seasonNumber;
    final key = _episodeDownloadKey(season, episode.episodeNumber);
    if (_downloadingEpisodes.contains(key)) return true;
    if (mounted) setState(() => _downloadingEpisodes.add(key));
    try {
      bool found;
      if (selectedStream != null) {
        final url = selectedStream['url']?.toString() ?? '';
        if (url.isEmpty) {
          found = false;
        } else {
          final headers = <String, String>{};
          if (selectedStream['referer'] != null) {
            headers['Referer'] = selectedStream['referer'].toString();
          }
          if (selectedStream['headers'] is Map) {
            (selectedStream['headers'] as Map).forEach((k, v) {
              headers[k.toString()] = v.toString();
            });
          }
          final isHls =
              selectedStream['type'] == 'direct_m3u8' ||
              url.toLowerCase().contains('.m3u8');
          await MediaDownloadManager.instance.start(
            downloadKey: key,
            url: url,
            headers: headers,
            isHls: isHls,
            mediaId: widget.seriesItem.id,
            isMovie: false,
            title:
                '${widget.seriesItem.title} - S${season}E${episode.episodeNumber}: ${episode.name}',
            resolverTitle: resolverTitle ?? widget.seriesItem.title,
            thumbnail: episode.stillPath.isNotEmpty
                ? 'https://image.tmdb.org/t/p/w500${episode.stillPath}'
                : widget.seriesItem.thumbnail,
            seriesId: widget.seriesItem.id,
            seasonNumber: season,
            episodeNumber: episode.episodeNumber,
            subtitles: (selectedStream['subtitles'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (track) =>
                      track.map((key, value) => MapEntry(key.toString(), value)),
                )
                .toList(),
          );
          found = true;
        }
      } else {
        found = await MediaDownloadManager.instance.resolveAndStart(
          downloadKey: key,
          mediaId: widget.seriesItem.id,
          isMovie: false,
          resolverTitle: resolverTitle ?? widget.seriesItem.title,
          title:
              '${widget.seriesItem.title} - S${season}E${episode.episodeNumber}: ${episode.name}',
          thumbnail: episode.stillPath.isNotEmpty
              ? 'https://image.tmdb.org/t/p/w500${episode.stillPath}'
              : widget.seriesItem.thumbnail,
          seasonNumber: season,
          episodeNumber: episode.episodeNumber,
        );
      }
      if (showResult && mounted && !found) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No downloadable stream found for episode ${episode.episodeNumber}',
            ),
          ),
        );
      }
      return found;
    } catch (error) {
      if (showResult && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Episode download failed: $error')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _downloadingEpisodes.remove(key));
        _refreshDownloadedStatus();
      }
    }
  }

  Future<void> _downloadCurrentSeason() async {
    if (_downloadingSeason || currentEpisodes.isEmpty) return;
    final season = seasons[selectedSeasonIndex].seasonNumber;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download Season $season?'),
        content: Text(
          '${currentEpisodes.length} episodes will be downloaded one at a time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _downloadingSeason = true;
      _seasonDownloadTotal = currentEpisodes.length;
      _seasonDownloadCurrent = 0;
      _seasonDownloadStatus = 'Preparing...';
    });
    var completed = 0;
    final episodes = List<Episode>.from(currentEpisodes);
    try {
      for (final episode in episodes) {
        if (!mounted) break;
        setState(() {
          _seasonDownloadCurrent = episodes.indexOf(episode) + 1;
          _seasonDownloadStatus =
              'Resolving S${season}E${episode.episodeNumber}: ${episode.name}';
        });
        final ok = await _downloadEpisode(
          episode,
          showResult: false,
          seasonNumber: season,
        );
        if (ok) completed++;
        if (!mounted) break;
        setState(() {
          _seasonDownloadStatus = ok
              ? 'S${season}E${episode.episodeNumber} complete'
              : 'S${season}E${episode.episodeNumber} failed, continuing...';
        });
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              completed == episodes.length
                  ? 'All $completed episodes from Season $season downloaded'
                  : 'Downloaded $completed of ${episodes.length} episodes from Season $season',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingSeason = false;
          _seasonDownloadStatus = '';
        });
      }
    }
  }

  Future<void> _loadWatchProgress() async {
    await CloudSyncService.pullToDevice();
    final continueWatching = await WatchHistoryService.getContinueWatching();
    if (!mounted) return;
    final match = continueWatching.firstWhere(
      (item) =>
          item['tmdbId']?.toString() == widget.seriesItem.id &&
          item['isMovie'] == false,
      orElse: () => {},
    );
    if (match.isNotEmpty) {
      setState(() => _watchProgress = match);
      return;
    }

    final allHistory = await WatchHistoryService.getWatchHistory();
    if (!mounted) return;

    final matches = allHistory
        .where((item) =>
            item['tmdbId']?.toString() == widget.seriesItem.id &&
            item['isMovie'] == false)
        .toList()
      ..sort(
          (a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

    if (matches.isNotEmpty) {
      final first = matches.first;
      final position = (first['position'] as num?)?.toInt() ?? 0;
      final duration = (first['duration'] as num?)?.toInt() ?? 1;
      if (position > 30 && duration > 0) {
        setState(() => _watchProgress = first);
      }
    }
  }

  Widget _buildContinueWatching() {
    final position = (_watchProgress!['position'] as num?)?.toInt() ?? 0;
    final duration = (_watchProgress!['duration'] as num?)?.toInt() ?? 1;
    final progress =
        duration > 0 ? (position / duration).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).round();
    final remaining = duration - position;
    final remainingMin = (remaining / 60).round();
    final season = _watchProgress!['season'] ?? 1;
    final episode = _watchProgress!['episode'] ?? 1;
    final epTitle = _watchProgress!['title'] ?? '';

    return GestureDetector(
      onTap: () async {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => buildVideoPlayerScreen(
              title: '${widget.seriesItem.title} - S${season}E$episode',
              tmdbId: widget.seriesItem.id.toString(),
              isMovie: false,
              season: season,
              episode: episode,
            ),
          ),
        ).then((_) => _loadWatchProgress());
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.play_circle_fill,
                    color: Colors.red, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Continue Watching',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style:
                      const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'S$season E$episode${epTitle.isNotEmpty ? ' - $epTitle' : ''}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[800],
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.red),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$remainingMin min remaining',
              style:
                  const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String getYear() {
    final firstAirDate = seriesDetails?['first_air_date'];
    if (firstAirDate != null && firstAirDate.toString().length >= 4) {
      return firstAirDate.toString().substring(0, 4);
    }
    return 'N/A';
  }

  String formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (didPop) {
          _youtubeController?.pause();
        }
      },
      child: Scaffold(
        body: isLoading
            ? buildLoadingShimmer()
            : CustomScrollView(
                slivers: [
                  buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildDetailsSection(),
                        if (_watchProgress != null) _buildContinueWatching(),
                        if (cast.isNotEmpty) buildCastSection(),
                        if (seasons.isNotEmpty) buildSeasonsSection(),
                        if (recommendations.isNotEmpty)
                          buildRecommendationsSection(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 350,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(color: Colors.grey[800]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster and title skeleton
                  Row(
                    children: [
                      Container(
                        width: 100,
                        height: 150,
                        color: Colors.grey[800],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 24,
                              width: 150,
                              color: Colors.grey[800],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 16,
                              width: 100,
                              color: Colors.grey[800],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 16,
                              width: 80,
                              color: Colors.grey[800],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Overview skeleton
                  Container(height: 24, width: 100, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  ...List.generate(
                    4,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(height: 12, color: Colors.grey[800]),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Cast section skeleton
                  Container(height: 24, width: 80, color: Colors.grey[800]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 160,
                          color: Colors.grey[800],
                          margin: const EdgeInsets.only(right: 8),
                        ),
                      ),
                      Expanded(
                        child: Container(height: 160, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildSliverAppBar() {
    final backdropPath =
        seriesDetails?['backdrop_path'] ?? widget.seriesItem.backdropPath;
    final posterPath =
        seriesDetails?['poster_path'] ?? widget.seriesItem.posterPath;

    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (backdropPath != null && backdropPath.isNotEmpty)
              AppNetworkImage(
                url: TmdbApiService.getBackdropUrl(backdropPath),
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.broken_image,
                    size: 50,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Container(color: Colors.grey[900]),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),

            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: posterPath != null && posterPath.isNotEmpty
                        ? AppNetworkImage(
                            url: TmdbApiService.getPosterUrl(posterPath),
                            width: 100,
                            height: 150,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 150,
                            color: Colors.grey[800],
                            child: const Icon(Icons.tv),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          seriesDetails?['name'] ?? widget.seriesItem.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          getYear(),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              '${seriesDetails?['vote_average']?.toStringAsFixed(1) ?? widget.seriesItem.rating.toStringAsFixed(1)}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            if (seriesDetails?['number_of_seasons'] != null)
                              Text(
                                '${seriesDetails!['number_of_seasons']} Seasons',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            const SizedBox(width: 16),
                            IconButton(
                              onPressed: _toggleWatchlist,
                              icon: Icon(
                                isInWatchlist
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: isInWatchlist
                                    ? Colors.red
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: currentEpisodes.isNotEmpty
                                ? () => _playEpisode(currentEpisodes.first)
                                : null,
                            icon: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Watch Now',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
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

  Widget buildDetailsSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_youtubeController != null) ...[
            const Text(
              'Trailer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
            const SizedBox(height: 16),
          ],

          const Text(
            'Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            seriesDetails?['overview'] ??
                widget.seriesItem.overview ??
                'No overview available.',
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 16),
          buildInfoGrid(),
        ],
      ),
    );
  }

  Widget buildInfoGrid() {
    final firstAirDate = seriesDetails?['first_air_date'];
    final lastAirDate = seriesDetails?['last_air_date'];
    final genres = (seriesDetails?['genres'] as List<dynamic>?)
        ?.map((g) => g['name'].toString())
        .join(', ');

    return Column(
      children: [
        if (firstAirDate != null)
          buildInfoRow('First Air Date', formatDate(firstAirDate)),
        if (lastAirDate != null && lastAirDate != firstAirDate)
          buildInfoRow('Last Air Date', formatDate(lastAirDate)),
        if (genres != null) buildInfoRow('Genres', genres),
        buildInfoRow(
          'Language',
          seriesDetails?['original_language']?.toUpperCase() ?? 'N/A',
        ),
        buildInfoRow('Status', seriesDetails?['status'] ?? 'Unknown'),
        if (seriesDetails?['episode_run_time'] != null &&
            (seriesDetails!['episode_run_time'] as List).isNotEmpty)
          buildInfoRow(
            'Episode Runtime',
            '~${seriesDetails!['episode_run_time'][0]} minutes',
          ),
      ],
    );
  }

  Widget buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCastSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Cast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cast.take(10).length,
            itemBuilder: (context, index) {
              final actor = cast[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: actor['profile_path'] != null
                          ? AppNetworkImage(
                              url: TmdbApiService.getProfileUrl(
                                actor['profile_path'],
                              ),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 120,
                              height: 120,
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.person,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      actor['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      actor['character'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 10),
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
    );
  }

  Widget buildSeasonsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Seasons & Episodes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _downloadingSeason || currentEpisodes.isEmpty
                    ? null
                    : _downloadCurrentSeason,
                icon: _downloadingSeason
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(
                  _downloadingSeason
                      ? '$_seasonDownloadCurrent/$_seasonDownloadTotal'
                      : 'Download Season',
                ),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
        if (_downloadingSeason && _seasonDownloadStatus.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _seasonDownloadStatus,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: seasons.length,
              itemBuilder: (context, index) {
                final season = seasons[index];
                final isSelected = index == selectedSeasonIndex;

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ChoiceChip(
                    label: Text('Season ${season.seasonNumber}'),
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
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (isLoadingEpisodes)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.red),
            ),
          )
        else if (currentEpisodes.isNotEmpty)
          ...currentEpisodes.map((episode) => _buildEpisodeTile(episode))
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

  Widget _buildEpisodeTile(Episode episode) {
    final season = seasons[selectedSeasonIndex].seasonNumber;
    final key = _episodeDownloadKey(season, episode.episodeNumber);
    final isDownloading = _downloadingEpisodes.contains(key);
    final isDownloaded = _downloadedEpisodeKeys.contains(key);
    final activeTask = _downloadManager.taskFor(key);
    final isCurrentlyDownloading = activeTask != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _playEpisode(episode),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  color: const Color(0xFF2A2A2A),
                ),
                child: episode.stillPath.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(8),
                        ),
                        child: AppNetworkImage(
                          url: 'https://image.tmdb.org/t/p/w300${episode.stillPath}',
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(
                        Icons.play_circle_outline,
                        color: Colors.white54,
                        size: 40,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${episode.episodeNumber}. ',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              episode.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (episode.overview.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          episode.overview,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (isCurrentlyDownloading) ...[
                        const SizedBox(height: 8),
                        _buildEpisodeDownloadProgress(activeTask),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: isDownloaded
                      ? 'Downloaded'
                      : isCurrentlyDownloading
                      ? 'Downloading'
                      : 'Download episode',
                  onPressed: isDownloading || isCurrentlyDownloading
                      ? null
                      : isDownloaded
                      ? null
                      : () => _showEpisodeQualitySheet(episode),
                  icon: isDownloading || isCurrentlyDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : isDownloaded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(
                          Icons.download_for_offline_outlined,
                          color: Colors.red,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeDownloadProgress(ActiveMediaDownload task) {
    final percent = (task.progress * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: task.progress,
                minHeight: 4,
                color: task.isPaused ? Colors.orange : Colors.red,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$percent%',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          task.isPaused ? 'Paused' : task.sizeLabel,
          style: TextStyle(
            color: task.isPaused ? Colors.orange : Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget buildRecommendationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'More Like This',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recommendations.take(10).length,
            itemBuilder: (context, index) {
              final item = recommendations[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          MaxStreamSeriesScreen(
                            seriesItem: Movie.fromJson(item),
                          ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.fastOutSlowIn,
                                    ),
                                  ),
                              child: child,
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 250),
                    ),
                  );
                },
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: item['poster_path'] != null
                            ? AppNetworkImage(
                                url: TmdbApiService.getPosterUrl(
                                  item['poster_path'],
                                ),
                                width: 120,
                                height: 160,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 120,
                                height: 160,
                                color: Colors.grey[800],
                                child: const Icon(Icons.tv, color: Colors.grey),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
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
}

/// Bottom sheet for server and quality selection before episode download.
class _EpisodeQualitySheet extends StatefulWidget {
  final String title;
  final String tmdbId;
  final int season;
  final int episode;
  final void Function(Map<String, dynamic>? selectedStream) onDownload;

  const _EpisodeQualitySheet({
    required this.title,
    required this.tmdbId,
    required this.season,
    required this.episode,
    required this.onDownload,
  });

  @override
  State<_EpisodeQualitySheet> createState() => _EpisodeQualitySheetState();
}

class _EpisodeQualitySheetState extends State<_EpisodeQualitySheet> {
  bool _loadingStreams = true;
  List<Map<String, dynamic>> _availableStreams = [];
  String? _error;
  int? _selectedServerIndex;
  int? _selectedQualityIndex;

  @override
  void initState() {
    super.initState();
    _fetchAvailableStreams();
  }

  Future<void> _fetchAvailableStreams() async {
    try {
      final streams = await DirectM3u8Service.fetchAvailableStreams(
        title: widget.title,
        tmdbId: widget.tmdbId,
        isMovie: false,
        season: widget.season,
        episode: widget.episode,
      );
      if (mounted) {
        setState(() {
          _availableStreams = streams;
          _loadingStreams = false;
          if (streams.isNotEmpty) _selectedServerIndex = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingStreams = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedStream {
    if (_selectedServerIndex == null) return null;
    if (_selectedServerIndex! >= _availableStreams.length) return null;
    final server = _availableStreams[_selectedServerIndex!];
    final qualities = server['qualities'];
    if (qualities is List && qualities.isNotEmpty) {
      final idx = _selectedQualityIndex ?? 0;
      if (idx < qualities.length) {
        final q = qualities[idx] as Map<String, dynamic>;
        return {
          'url': q['url']?.toString() ?? server['url']?.toString() ?? '',
          'source': server['source']?.toString() ?? 'Server',
          'headers': server['headers'],
          'referer': server['referer']?.toString(),
          'type': server['type']?.toString() ?? '',
          'subtitles': server['subtitles'],
          'label': q['label']?.toString() ?? 'Auto',
        };
      }
    }
    return {
      'url': server['url']?.toString() ?? '',
      'source': server['source']?.toString() ?? 'Server',
      'headers': server['headers'],
      'referer': server['referer']?.toString(),
      'type': server['type']?.toString() ?? '',
      'subtitles': server['subtitles'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Download',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.title,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          if (_loadingStreams)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.red),
              ),
            )
          else if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Could not fetch servers',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    _buildAutoOption(),
                  ],
                ),
              ),
            )
          else if (_availableStreams.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      color: Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No servers available',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    _buildAutoOption(),
                  ],
                ),
              ),
            )
          else ...[
            _buildAutoOption(),
            const SizedBox(height: 12),
            const Text(
              'Servers',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _availableStreams.length,
                itemBuilder: (context, serverIdx) {
                  final server = _availableStreams[serverIdx];
                  final source = server['source']?.toString() ?? 'Server';
                  final qualities = server['qualities'];
                  final hasQualities = qualities is List && qualities.isNotEmpty;
                  final isServerSelected = _selectedServerIndex == serverIdx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedServerIndex = serverIdx;
                              _selectedQualityIndex = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isServerSelected
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isServerSelected
                                    ? Colors.red
                                    : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.dns,
                                  color: isServerSelected
                                      ? Colors.red
                                      : Colors.grey,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        source,
                                        style: TextStyle(
                                          color: isServerSelected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (hasQualities) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${qualities.length} quality option(s)',
                                          style: TextStyle(
                                            color: isServerSelected
                                                ? Colors.white60
                                                : Colors.grey,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (isServerSelected)
                                  const Icon(
                                    Icons.radio_button_checked,
                                    color: Colors.red,
                                    size: 18,
                                  )
                                else
                                  const Icon(
                                    Icons.radio_button_off,
                                    color: Colors.grey,
                                    size: 18,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (isServerSelected && hasQualities) ...[
                          const SizedBox(height: 6),
                          ...List.generate(qualities.length, (qIdx) {
                            final q = qualities[qIdx] as Map<String, dynamic>;
                            final label = q['label']?.toString() ?? 'Auto';
                            final height =
                                int.tryParse(q['height']?.toString() ?? '') ??
                                0;
                            final isQSelected =
                                (_selectedQualityIndex ?? 0) == qIdx;
                            final subtitle =
                                height > 0 ? '${height}p' : 'Adaptive bitrate';

                            return Padding(
                              padding: const EdgeInsets.only(left: 12, bottom: 4),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedQualityIndex = qIdx;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isQSelected
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : const Color(0xFF252525),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isQSelected
                                          ? Colors.red.withValues(alpha: 0.5)
                                          : Colors.transparent,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        height >= 720
                                            ? Icons.high_quality
                                            : Icons.hd,
                                        color: isQSelected
                                            ? Colors.red
                                            : Colors.grey,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          color: isQSelected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          color: isQSelected
                                              ? Colors.white60
                                              : Colors.grey,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onDownload(_selectedStream);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Download',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildAutoOption() {
    final isSelected = _selectedServerIndex == null;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedServerIndex = null;
        _selectedQualityIndex = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.red.withValues(alpha: 0.15)
              : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: isSelected ? Colors.red : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _availableStreams.isNotEmpty
                        ? 'Best available from ${_availableStreams.length} server(s)'
                        : 'Let the app choose the best server',
                    style: TextStyle(
                      color: isSelected ? Colors.white60 : Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.radio_button_checked,
                color: Colors.red,
                size: 20,
              )
            else
              const Icon(
                Icons.radio_button_off,
                color: Colors.grey,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
