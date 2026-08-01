import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/db_helper.dart';
import '../../models/movie.dart';
import '../../models/series.dart';
import '../../services/tmdb_api_service.dart';
import '../screens/tv_details_screen.dart';
import '../screens/tv_series_screen.dart';
import '../screens/tv_video_player_screen.dart';

class TvCinematicDetails extends StatefulWidget {
  const TvCinematicDetails({
    super.key,
    required this.item,
    required this.mediaType,
  });

  final Movie item;
  final String mediaType;

  @override
  State<TvCinematicDetails> createState() => _TvCinematicDetailsState();
}

class _TvCinematicDetailsState extends State<TvCinematicDetails>
    with SingleTickerProviderStateMixin {
  static const _red = Color(0xffe50914);
  final _scroll = ScrollController();
  final _playNode = FocusNode(debugLabel: 'details play');
  final _watchlistNode = FocusNode(debugLabel: 'details watchlist');
  final Map<String, FocusNode> _nodes = {};
  late final AnimationController _entry;
  Map<String, dynamic>? _details;
  List<Season> _seasons = [];
  List<Episode> _episodes = [];
  List<Map<String, dynamic>> _cast = [];
  List<Map<String, dynamic>> _recommendations = [];
  int _seasonIndex = 0;
  int _episodeRequest = 0;
  bool _loading = true;
  bool _loadingEpisodes = false;
  bool _saved = false;

  bool get _isSeries => widget.mediaType == 'tv';
  FocusNode _node(String key) =>
      _nodes.putIfAbsent(key, () => FocusNode(debugLabel: key));

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _playNode.dispose();
    _watchlistNode.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    _entry.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final id = int.parse(widget.item.id);
      final result = _isSeries
          ? await TmdbApiService.getSeriesDetails(id)
          : await TmdbApiService.getMovieDetails(id);
      final watchlist = await DBHelper.getWatchlistItems();
      if (!mounted) return;
      setState(() {
        _details = result;
        _cast = List<Map<String, dynamic>>.from(
          result?['credits']?['cast'] ?? const [],
        );
        _recommendations = List<Map<String, dynamic>>.from(
          result?['recommendations']?['results'] ?? const [],
        );
        if (_isSeries) {
          _seasons = (result?['seasons'] as List? ?? const [])
              .map((value) => Season.fromJson(value))
              .where((season) => season.seasonNumber > 0)
              .toList();
        }
        _saved = watchlist.any(
          (item) =>
              item.id == widget.item.id &&
              item.mediaType == widget.item.mediaType,
        );
        _loading = false;
      });
      if (_seasons.isNotEmpty) await _selectSeason(0, moveFocus: false);
      if (!mounted) return;
      _entry.forward();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _playNode.requestFocus(),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _entry.forward();
    }
  }

  Future<void> _selectSeason(int index, {bool moveFocus = true}) async {
    final request = ++_episodeRequest;
    setState(() {
      _seasonIndex = index;
      _episodes = [];
      _loadingEpisodes = true;
    });
    try {
      final data = await TmdbApiService.getSeasonEpisodes(
        int.parse(widget.item.id),
        _seasons[index].seasonNumber,
      );
      if (!mounted || request != _episodeRequest) return;
      setState(() {
        _episodes = data.map(Episode.fromJson).toList();
        _loadingEpisodes = false;
      });
      if (moveFocus && _episodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _nodes['episode:0']?.requestFocus(),
        );
      }
    } catch (_) {
      if (mounted && request == _episodeRequest) {
        setState(() => _loadingEpisodes = false);
      }
    }
  }

  Future<void> _toggleWatchlist() async {
    if (_saved) {
      await DBHelper.removeFromWatchlist(widget.item.id, widget.item.mediaType);
    } else {
      await DBHelper.addToWatchlist(widget.item);
    }
    if (!mounted) return;
    setState(() => _saved = !_saved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_saved ? 'Added to Watchlist' : 'Removed from Watchlist'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _play([Episode? episode]) async {
    if (_isSeries && (episode == null || _loadingEpisodes)) return;
    final season = _isSeries ? _seasons[_seasonIndex].seasonNumber : null;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TvVideoPlayerScreen(
          title: episode == null
              ? widget.item.title
              : '${widget.item.title} - S${season}E${episode.episodeNumber}: ${episode.name}',
          tmdbId: widget.item.id,
          isMovie: !_isSeries,
          season: season ?? 1,
          episode: episode?.episodeNumber ?? 1,
        ),
      ),
    );
    if (!mounted) return;
    (episode == null
            ? _playNode
            : _nodes['episode:${_episodes.indexOf(episode)}'])
        ?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: const Color(0xff090909),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _red))
            : FadeTransition(
                opacity: CurvedAnimation(parent: _entry, curve: Curves.easeOut),
                child: SlideTransition(
                  position:
                      Tween(
                        begin: const Offset(0, .025),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _entry,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: FocusTraversalGroup(
                    policy: OrderedTraversalPolicy(),
                    child: CustomScrollView(
                      controller: _scroll,
                      slivers: [
                        SliverToBoxAdapter(child: _hero()),
                        if (_isSeries && _seasons.isNotEmpty)
                          SliverToBoxAdapter(child: _seasonRow()),
                        if (_isSeries) SliverToBoxAdapter(child: _episodeRow()),
                        if (_cast.isNotEmpty)
                          SliverToBoxAdapter(child: _castRow()),
                        if (_recommendations.isNotEmpty)
                          SliverToBoxAdapter(child: _recommendationRow()),
                        const SliverToBoxAdapter(child: SizedBox(height: 64)),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _hero() {
    final backdrop = (_details?['backdrop_path'] as String?)?.isNotEmpty == true
        ? TmdbApiService.getBackdropUrl(_details!['backdrop_path'])
        : widget.item.backdropPath;
    final genres = (_details?['genres'] as List? ?? const [])
        .map((genre) => genre['name'].toString())
        .take(3)
        .toList();
    final year =
        (_details?['release_date'] ??
                _details?['first_air_date'] ??
                widget.item.year)
            .toString()
            .split('-')
            .first;
    final runtime = _details?['runtime'];
    final metadata = <String>[
      if (widget.item.rating > 0) '★ ${widget.item.rating.toStringAsFixed(1)}',
      if (year.isNotEmpty) year,
      if (runtime is int && runtime > 0) '${runtime}m',
      if (_isSeries && _seasons.isNotEmpty) '${_seasons.length} Seasons',
      ...(genres.isNotEmpty ? genres : widget.item.genres.take(3)),
    ];
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: SizedBox(
        key: ValueKey(backdrop),
        height: 550,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.network(
                backdrop,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const ColoredBox(color: Colors.black),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xff090909),
                      Color(0xdd090909),
                      Colors.transparent,
                    ],
                    stops: [0, .38, .82],
                  ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color(0x33090909),
                      Color(0xff090909),
                    ],
                    stops: [.42, .72, 1],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 54,
              bottom: 42,
              width: MediaQuery.sizeOf(context).width * .58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      height: 1.05,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    metadata.join('  •  '),
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    (_details?['overview'] ?? widget.item.overview).toString(),
                    maxLines: 7,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xffdddddd),
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _TvButton(
                        node: _playNode,
                        order: 1,
                        icon: Icons.play_arrow_rounded,
                        label: _isSeries
                            ? (_loadingEpisodes
                                  ? 'Loading Episodes…'
                                  : 'Watch S${_seasons.isEmpty ? 1 : _seasons[_seasonIndex].seasonNumber}E${_episodes.isEmpty ? 1 : _episodes.first.episodeNumber}')
                            : 'Play',
                        enabled:
                            !_isSeries ||
                            (!_loadingEpisodes && _episodes.isNotEmpty),
                        primary: true,
                        onPressed: () => _play(
                          _isSeries && _episodes.isNotEmpty
                              ? _episodes.first
                              : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      _TvButton(
                        node: _watchlistNode,
                        order: 2,
                        icon: _saved ? Icons.check : Icons.add,
                        label: _saved ? 'In Watchlist' : 'Watchlist',
                        onPressed: _toggleWatchlist,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, double height, Widget child) => Padding(
    padding: const EdgeInsets.fromLTRB(54, 26, 0, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(height: height, child: child),
      ],
    ),
  );

  Widget _seasonRow() => _section(
    'Seasons',
    52,
    ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 54),
      itemCount: _seasons.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (_, index) => _TvTile(
        node: _node('season:$index'),
        order: 10 + index / 100,
        selected: index == _seasonIndex,
        onPressed: () => _selectSeason(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          child: Text(
            _seasons[index].name,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );

  Widget _episodeRow() => _section(
    'Episodes',
    190,
    AnimatedSwitcher(
      duration: const Duration(milliseconds: 450),
      child: _loadingEpisodes
          ? const Align(
              alignment: Alignment.centerLeft,
              child: CircularProgressIndicator(color: _red),
            )
          : ListView.separated(
              key: ValueKey(_seasonIndex),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: 54),
              itemCount: _episodes.length,
              separatorBuilder: (_, _) => const SizedBox(width: 16),
              itemBuilder: (_, index) {
                final episode = _episodes[index];
                return _TvTile(
                  node: _node('episode:$index'),
                  order: 20 + index / 100,
                  onPressed: () => _play(episode),
                  child: SizedBox(
                    width: 286,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: episode.stillPath.isEmpty
                                ? const ColoredBox(
                                    color: Color(0xff242424),
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white54,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    'https://image.tmdb.org/t/p/w500${episode.stillPath}',
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'E${episode.episodeNumber}  ${episode.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          episode.overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    ),
  );

  Widget _castRow() => _section(
    'Cast',
    150,
    ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 54),
      itemCount: _cast.take(12).length,
      separatorBuilder: (_, _) => const SizedBox(width: 18),
      itemBuilder: (_, index) {
        final person = _cast[index];
        return _TvTile(
          node: _node('cast:$index'),
          order: 30 + index / 100,
          onPressed: () {},
          child: SizedBox(
            width: 105,
            child: Column(
              children: [
                ClipOval(
                  child: person['profile_path'] == null
                      ? const ColoredBox(
                          color: Color(0xff242424),
                          child: SizedBox(
                            width: 92,
                            height: 92,
                            child: Icon(Icons.person, color: Colors.white54),
                          ),
                        )
                      : Image.network(
                          TmdbApiService.getProfileUrl(person['profile_path']),
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  person['name'] ?? '',
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget _recommendationRow() => _section(
    'More Like This',
    260,
    ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(right: 54),
      itemCount: _recommendations.take(12).length,
      separatorBuilder: (_, _) => const SizedBox(width: 18),
      itemBuilder: (_, index) {
        final data = _recommendations[index];
        return _TvTile(
          node: _node('recommendation:$index'),
          order: 40 + index / 100,
          onPressed: () {
            final type =
                data['media_type'] ??
                (data['first_air_date'] != null ? 'tv' : 'movie');
            final movie = Movie.fromJson({...data, 'media_type': type});
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => type == 'tv'
                    ? TvSeriesScreen(seriesItem: movie)
                    : TvDetailsScreen(item: movie, mediaType: 'movie'),
              ),
            );
          },
          child: SizedBox(
            width: 150,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.network(
                      TmdbApiService.getPosterUrl(data['poster_path'] ?? ''),
                      width: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(
                        color: Color(0xff242424),
                        child: Center(
                          child: Icon(Icons.movie, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['title'] ?? data['name'] ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _TvButton extends StatelessWidget {
  const _TvButton({
    required this.node,
    required this.order,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.enabled = true,
  });
  final FocusNode node;
  final double order;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) => FocusTraversalOrder(
    order: NumericFocusOrder(order),
    child: _TvTile(
      node: node,
      order: order,
      enabled: enabled,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
        decoration: BoxDecoration(
          color: enabled
              ? (primary
                    ? _TvCinematicDetailsState._red
                    : const Color(0xbb222222))
              : const Color(0x88333333),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: enabled ? Colors.white : Colors.white38),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: enabled ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TvTile extends StatefulWidget {
  const _TvTile({
    required this.node,
    required this.order,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.enabled = true,
  });
  final FocusNode node;
  final double order;
  final VoidCallback onPressed;
  final Widget child;
  final bool selected;
  final bool enabled;

  @override
  State<_TvTile> createState() => _TvTileState();
}

class _TvTileState extends State<_TvTile> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => FocusTraversalOrder(
    order: NumericFocusOrder(widget.order),
    child: Focus(
      focusNode: widget.node,
      canRequestFocus: widget.enabled,
      onFocusChange: (value) {
        setState(() => focused = value);
        if (value) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 260),
            alignment: .5,
            curve: Curves.easeOutCubic,
          );
        }
      },
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          if (widget.enabled) widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: focused ? 1.02 : 1,
          duration: const Duration(milliseconds: 180),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: widget.selected
                  ? const Color(0x44e50914)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: focused
                    ? Colors.white
                    : (widget.selected
                          ? const Color(0xffe50914)
                          : Colors.transparent),
                width: 2,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}
