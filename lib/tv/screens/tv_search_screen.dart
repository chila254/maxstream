import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/movie.dart';
import '../../services/tmdb_api_service.dart';
import '../../widgets/custom_loading_widget.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/index.dart';
import '../widgets/tv_content_card.dart';
import '../widgets/tv_dark_mode_polish.dart';
import '../widgets/tv_keyboard.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

class TvSearchScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvSearchScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _ResultEntry {
  final String section;
  final Map<String, dynamic> item;
  final int index;
  final int row;
  final int column;

  const _ResultEntry(
    this.section,
    this.item,
    this.index,
    this.row,
    this.column,
  );

  String get identity =>
      '$section:${item['media_type'] ?? 'movie'}:${item['id']}';
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  static const _columns = 5;
  final _scrollController = ScrollController();
  final _keyboardNode = FocusNode(debugLabel: 'search-keyboard');
  final _keyboardManager = TvKeyboardFocusManager();
  final Map<String, FocusNode> _cardNodes = {};
  List<_ResultEntry> _entries = const [];
  List<Map<String, dynamic>> _movies = const [];
  List<Map<String, dynamic>> _series = const [];
  List<Map<String, dynamic>> _discover = const [];
  String _query = '';
  String? _rememberedIdentity;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  TvNavigationProvider? _navProvider;

  @override
  void initState() {
    super.initState();
    _keyboardManager.activateKeyboard();
    // Resolve the provider in initState so dispose() never does a context
    // lookup: by the time dispose runs the inherited element is already torn
    // down, and Provider.of returns null there.
    _navProvider = context.read<TvNavigationProvider>();
    _navProvider?.setSearchFocused(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _keyboardNode.requestFocus();
    });
    _loadRecommendations();
  }

  @override
  void dispose() {
    _navProvider?.setSearchFocused(false);
    for (final node in _cardNodes.values) {
      node.dispose();
    }
    _keyboardNode.dispose();
    _keyboardManager.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _tagged(List<Map<String, dynamic>> items, String type) {
    return [
      for (final item in items) {...item, 'media_type': type},
    ];
  }

  List<Map<String, dynamic>> _dedupe(List<Map<String, dynamic>> items) {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add('${item['media_type']}:${item['id']}')) item,
    ];
  }

  Future<void> _loadRecommendations() async {
    try {
      final values = await Future.wait([
        TmdbApiService.fetchTrendingMovies(),
        TmdbApiService.fetchTrendingSeries(),
        TmdbApiService.fetchPopularMovies(),
        TmdbApiService.fetchPopularSeries(),
        TmdbApiService.fetchTopRatedMovies(),
        TmdbApiService.fetchTopRatedSeries(),
      ]);
      if (!mounted) return;
      setState(() {
        // Mix movies and series from every category into one grid instead of
        // grouping them under Trending / Popular / Top Rated headers.
        _discover = _dedupe([
          ..._tagged(values[0].take(12).toList(), 'movie'),
          ..._tagged(values[1].take(12).toList(), 'tv'),
          ..._tagged(values[2].take(12).toList(), 'movie'),
          ..._tagged(values[3].take(12).toList(), 'tv'),
          ..._tagged(values[4].take(12).toList(), 'movie'),
          ..._tagged(values[5].take(12).toList(), 'tv'),
        ]);
        _rebuildEntries();
      });
    } catch (error) {
      debugPrint('Error loading search recommendations: $error');
    }
  }

  Future<void> _performSearch(String value) async {
    final query = value.trim();
    final generation = ++_generation;
    setState(() {
      _query = value;
      _error = null;
      if (query.isEmpty) {
        _movies = const [];
        _series = const [];
        _loading = false;
        _rebuildEntries();
      } else {
        _loading = true;
      }
    });
    if (query.isEmpty) return;
    try {
      final results = await TmdbApiService.searchAll(query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _movies = results.where((e) => e['media_type'] == 'movie').toList();
        _series = results.where((e) => e['media_type'] == 'tv').toList();
        _loading = false;
        _rebuildEntries();
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Search is unavailable right now. Please try again.';
        _movies = const [];
        _series = const [];
        _rebuildEntries();
      });
    }
  }

  void _rebuildEntries() {
    final sections = _query.trim().isEmpty
        ? [('Discover', _discover)]
        : [('Movies', _movies), ('TV Series', _series)];
    final next = <_ResultEntry>[];
    for (final section in sections) {
      for (var i = 0; i < section.$2.length; i++) {
        next.add(
          _ResultEntry(
            section.$1,
            section.$2[i],
            next.length,
            i ~/ _columns,
            i % _columns,
          ),
        );
      }
    }
    final identities = next.map((e) => e.identity).toSet();
    for (final identity in _cardNodes.keys.toList()) {
      if (!identities.contains(identity)) {
        _cardNodes.remove(identity)?.dispose();
      }
    }
    for (final entry in next) {
      _cardNodes.putIfAbsent(
        entry.identity,
        () => FocusNode(debugLabel: 'search-${entry.identity}'),
      );
    }
    _entries = next;
    if (_rememberedIdentity != null &&
        !identities.contains(_rememberedIdentity)) {
      _rememberedIdentity = null;
    }
  }

  void _focusResults() {
    if (_entries.isEmpty) return;
    final entry = _entries.firstWhere(
      (e) => e.identity == _rememberedIdentity,
      orElse: () => _entries.first,
    );
    _focusEntry(entry);
  }

  void _focusEntry(_ResultEntry entry) {
    _rememberedIdentity = entry.identity;
    _keyboardManager.focusOnContent();
    _cardNodes[entry.identity]?.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardContext = _cardNodes[entry.identity]?.context;
      if (cardContext != null) {
        Scrollable.ensureVisible(
          cardContext,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: .12,
        );
      }
    });
  }

  void _submitSearch() {
    if (_query.trim().isEmpty) return;
    _performSearch(_query).then((_) {
      if (mounted) _focusResults();
    });
  }

  KeyEventResult _onCardKey(_ResultEntry entry, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _keyboardManager.activateKeyboard();
      _keyboardNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && entry.column == 0) {
      _keyboardManager.activateKeyboard();
      _keyboardNode.requestFocus();
      return KeyEventResult.handled;
    }
    _ResultEntry? destination;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (entry.index > 0) {
        destination = _entries[entry.index - 1];
      }
    } else if (key == LogicalKeyboardKey.arrowRight &&
        entry.index + 1 < _entries.length &&
        _entries[entry.index + 1].section == entry.section) {
      destination = _entries[entry.index + 1];
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final direction = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
      final sectionNames = _entries.map((e) => e.section).toSet().toList();
      final sectionIndex = sectionNames.indexOf(entry.section);
      final sameSection = _entries
          .where((e) => e.section == entry.section)
          .toList();
      final targetRow = entry.row + direction;
      final rowMatches = sameSection.where((e) => e.row == targetRow).toList();
      if (rowMatches.isNotEmpty) {
        destination = rowMatches.reduce(
          (a, b) =>
              (a.column - entry.column).abs() <= (b.column - entry.column).abs()
              ? a
              : b,
        );
      } else {
        final targetSection = sectionIndex + direction;
        if (targetSection >= 0 && targetSection < sectionNames.length) {
          final candidates = _entries
              .where((e) => e.section == sectionNames[targetSection])
              .toList();
          final targetSectionRow = direction > 0 ? 0 : candidates.last.row;
          final row = candidates
              .where((e) => e.row == targetSectionRow)
              .toList();
          destination = row.reduce(
            (a, b) =>
                (a.column - entry.column).abs() <=
                    (b.column - entry.column).abs()
                ? a
                : b,
          );
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _keyboardManager.activateKeyboard();
          _keyboardNode.requestFocus();
        }
      }
    }
    if (destination != null) {
      _focusEntry(destination);
      return KeyEventResult.handled;
    }
    // Unhandled keys (e.g. select/enter) must fall through to the card so its
    // own onSelect/onTap handler can navigate to the details screen.
    return KeyEventResult.ignored;
  }

  Future<void> _open(_ResultEntry entry) async {
    _rememberedIdentity = entry.identity;
    final item = entry.item;
    final isMovie = (item['media_type'] ?? 'movie') == 'movie';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isMovie
            ? TvDetailsScreen(item: Movie.fromJson(item), mediaType: 'movie')
            : TvSeriesScreen(seriesItem: Movie.fromJson(item)),
      ),
    );
    if (!mounted) return;
    final match = _entries.where((e) => e.identity == _rememberedIdentity);
    if (match.isNotEmpty) _focusEntry(match.first);
  }

  @override
  Widget build(BuildContext context) {
    return DarkModeBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF20A0D13), Color(0xE6111620), Color(0xFF050608)],
            ),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(34, 24, 34, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 350, child: _buildSearchPanel()),
                const SizedBox(width: 34),
                Expanded(child: _buildResultsTransition()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchPanel() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'MAXSTREAM',
        style: TextStyle(
          color: Color(0xFFE50914),
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Search',
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Find movies and series',
        style: TextStyle(
          color: Colors.white.withValues(alpha: .55),
          fontSize: 15,
        ),
      ),
      const SizedBox(height: 24),
      Expanded(
        child: TvKeyboard(
          initialText: _query,
          onInput: _performSearch,
          onSubmit: _submitSearch,
          focusManager: _keyboardManager,
          focusNode: _keyboardNode,
          onMoveRight: _focusResults,
          onMoveLeft: () {
            widget.onReturnToSidebar?.call();
            TvFocusManager.focusSidebar();
            context.read<TvNavigationProvider>().setFocusOnSidebar(true);
          },
        ),
      ),
    ],
  );

  Widget _buildResultsTransition() => AnimatedSwitcher(
    duration: const Duration(milliseconds: 350),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(.025, 0),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    ),
    child: KeyedSubtree(
      key: ValueKey('$_query:$_loading:${_entries.length}:$_error'),
      child: _buildResults(),
    ),
  );

  Widget _buildResults() {
    if (_loading) {
      return const Center(
        child: CustomLoadingWidget(
          size: 52,
          color: Color(0xFFE50914),
          style: LoadingStyle.dots,
        ),
      );
    }
    if (_error != null) return _message(Icons.cloud_off_outlined, _error!);
    if (_entries.isEmpty) {
      return _message(
        Icons.search_off_rounded,
        _query.trim().isEmpty
            ? 'Loading discoveries…'
            : 'No matches for “${_query.trim()}”',
      );
    }
    final sections = _entries.map((e) => e.section).toSet();
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              _query.trim().isEmpty
                  ? 'Discover'
                  : 'Results for “${_query.trim()}”',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 29,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        for (final section in sections) ...[
          SliverToBoxAdapter(child: _sectionHeader(section)),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              childAspectRatio: .68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, index) => _buildCard(
                _entries.where((e) => e.section == section).elementAt(index),
              ),
              childCount: _entries.where((e) => e.section == section).length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 34)),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 23,
          decoration: BoxDecoration(
            color: const Color(0xFFE50914),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _buildCard(_ResultEntry entry) {
    final item = entry.item;
    final isMovie = (item['media_type'] ?? 'movie') == 'movie';
    final date =
        (isMovie ? item['release_date'] : item['first_air_date']) as String?;
    return TvContentCard(
      key: ValueKey(entry.identity),
      focusNode: _cardNodes[entry.identity],
      posterUrl: TmdbApiService.getPosterUrl(item['poster_path'] ?? ''),
      title: (isMovie ? item['title'] : item['name']) ?? 'Untitled',
      contentType: isMovie ? ContentType.movie : ContentType.series,
      rating: (item['vote_average'] as num?)?.toDouble(),
      year: date == null || date.isEmpty
          ? null
          : int.tryParse(date.split('-').first),
      onTap: () => _open(entry),
      onSelect: () => _open(entry),
      onFocusChanged: (focused) {
        if (focused) _rememberedIdentity = entry.identity;
      },
      onKeyEvent: (_, event) => _onCardKey(entry, event),
      width: 130,
      height: 190,
    );
  }

  Widget _message(IconData icon, String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 58),
        const SizedBox(height: 16),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
      ],
    ),
  );
}
