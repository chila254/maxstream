import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/movie.dart';
import '../../services/logger_service.dart';
import '../../services/tmdb_api_service.dart';
import '../../widgets/custom_loading_widget.dart';
import '../providers/tv_navigation_provider.dart';
import '../utils/tv_focus_manager.dart';
import '../widgets/tv_content_card.dart';
import 'tv_details_screen.dart';
import 'tv_series_screen.dart';

class TvGenreScreen extends StatefulWidget {
  const TvGenreScreen({super.key, this.onReturnToSidebar});

  final VoidCallback? onReturnToSidebar;

  @override
  State<TvGenreScreen> createState() => _TvGenreScreenState();
}

class _Genre {
  const _Genre(this.source, this.id, this.name);
  final String source;
  final int id;
  final String name;
  String get key => '$source:$id';
}

class _GenreItem {
  const _GenreItem(this.mediaType, this.data);
  final String mediaType;
  final Map<String, dynamic> data;
  String get key => '$mediaType:${data['id']}';
}

class _TvGenreScreenState extends State<TvGenreScreen> {
  static const _columns = 5;
  final _genreScroll = ScrollController();
  final _gridScroll = ScrollController();
  final Map<String, FocusNode> _genreNodes = {};
  final Map<String, FocusNode> _cardNodes = {};

  List<_Genre> _genres = const [];
  List<_GenreItem> _items = const [];
  _Genre? _focusedGenre;
  _Genre? _selectedGenre;
  int? _focusedCard;
  bool _loadingGenres = true;
  bool _loadingContent = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _genreError;
  String? _contentError;
  String? _pagingError;
  int _page = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  @override
  void dispose() {
    _generation++;
    _genreScroll.dispose();
    _gridScroll.dispose();
    for (final node in [..._genreNodes.values, ..._cardNodes.values]) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _genreNode(_Genre genre) => _genreNodes.putIfAbsent(
    genre.key,
    () => FocusNode(debugLabel: genre.key),
  );
  FocusNode _cardNode(_GenreItem item) =>
      _cardNodes.putIfAbsent(item.key, () => FocusNode(debugLabel: item.key));

  Future<void> _loadGenres() async {
    final request = ++_generation;
    setState(() {
      _loadingGenres = true;
      _genreError = null;
    });
    try {
      final result = await Future.wait([
        TmdbApiService.fetchGenres('movie'),
        TmdbApiService.fetchGenres('tv'),
      ]);
      if (!mounted || request != _generation) return;
      final genres = <_Genre>[
        ...result[0].entries.map((e) => _Genre('movie', e.key, e.value)),
        ...result[1].entries.map((e) => _Genre('tv', e.key, e.value)),
      ];
      setState(() {
        _genres = genres;
        _focusedGenre = genres.firstOrNull;
        _loadingGenres = false;
      });
      if (genres.isNotEmpty) await _commitGenre(genres.first, initial: true);
    } catch (error) {
      LoggerService.error('Error loading TV genres: $error', error);
      if (!mounted || request != _generation) return;
      setState(() {
        _loadingGenres = false;
        _genreError = 'Genres could not be loaded.';
      });
      _scheduleFocus(null);
    }
  }

  Future<void> _commitGenre(_Genre genre, {bool initial = false}) async {
    if (!initial && _selectedGenre?.key == genre.key && _items.isNotEmpty) {
      _focusGrid(0);
      return;
    }
    final request = ++_generation;
    setState(() {
      _selectedGenre = genre;
      _focusedGenre = genre;
      _items = const [];
      _focusedCard = null;
      _page = 1;
      _hasMore = true;
      _loadingContent = true;
      _contentError = null;
      _pagingError = null;
    });
    try {
      final rows = await _fetch(genre, 1);
      if (!mounted || request != _generation) return;
      setState(() {
        _items = rows.map((e) => _GenreItem(genre.source, e)).toList();
        _hasMore = rows.isNotEmpty;
        _loadingContent = false;
      });
      final nav = context.read<TvNavigationProvider>();
      final restoreGrid = nav.getSectionFocusIndex(2) == 1;
      if (restoreGrid && _items.isNotEmpty) {
        _focusGrid(nav.getFocusedIndex(2).clamp(0, _items.length - 1));
      } else {
        _scheduleFocus(_genreNode(genre));
      }
    } catch (error) {
      LoggerService.error('Error loading genre content: $error', error);
      if (!mounted || request != _generation) return;
      setState(() {
        _loadingContent = false;
        _contentError = 'Content could not be loaded.';
      });
      _scheduleFocus(_genreNode(genre));
    }
  }

  Future<List<Map<String, dynamic>>> _fetch(_Genre genre, int page) =>
      genre.source == 'movie'
      ? TmdbApiService.getMoviesByGenre(genre.id, page: page)
      : TmdbApiService.getSeriesByGenre(genre.id, page: page);

  Future<void> _loadMore() async {
    final genre = _selectedGenre;
    if (genre == null || _loadingMore || !_hasMore) return;
    final request = _generation;
    final nextPage = _page + 1;
    setState(() {
      _loadingMore = true;
      _pagingError = null;
    });
    try {
      final rows = await _fetch(genre, nextPage);
      if (!mounted || request != _generation) return;
      setState(() {
        _items = [..._items, ...rows.map((e) => _GenreItem(genre.source, e))];
        _page = nextPage;
        _hasMore = rows.isNotEmpty;
        _loadingMore = false;
      });
    } catch (error) {
      LoggerService.error('Error paging genre content: $error', error);
      if (!mounted || request != _generation) return;
      setState(() {
        _loadingMore = false;
        _pagingError = 'More titles could not be loaded.';
      });
    }
  }

  void _scheduleFocus(FocusNode? node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) (node ?? _genreNodes.values.firstOrNull)?.requestFocus();
    });
  }

  void _focusGrid(int index) {
    if (_items.isEmpty) return;
    final target = index.clamp(0, _items.length - 1);
    context.read<TvNavigationProvider>()
      ..setSectionFocusIndex(2, 1)
      ..saveFocusedIndex(2, target);
    _scheduleFocus(_cardNode(_items[target]));
  }

  void _focusGenre() {
    final genre = _selectedGenre ?? _focusedGenre;
    if (genre == null) return;
    context.read<TvNavigationProvider>().setSectionFocusIndex(2, 0);
    _scheduleFocus(_genreNode(genre));
    final nodeContext = _genreNode(genre).context;
    if (nodeContext != null) {
      Scrollable.ensureVisible(
        nodeContext,
        duration: const Duration(milliseconds: 220),
      );
    }
  }

  void _sidebar() {
    (widget.onReturnToSidebar ?? TvFocusManager.focusSidebar).call();
  }

  KeyEventResult _onGenreKey(_Genre genre, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = _genres.indexWhere((e) => e.key == genre.key);
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final delta = event.logicalKey == LogicalKeyboardKey.arrowUp ? -1 : 1;
      final next = (index + delta).clamp(0, _genres.length - 1);
      setState(() => _focusedGenre = _genres[next]);
      _genreNode(_genres[next]).requestFocus();
      final targetContext = _genreNode(_genres[next]).context;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
        );
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      _commitGenre(genre);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      _sidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _onCardKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _focusGenre();
      return KeyEventResult.handled;
    }
    int? target;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % _columns == 0) {
        _focusGenre();
        return KeyEventResult.handled;
      }
      target = index - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index % _columns < _columns - 1 && index + 1 < _items.length) {
        target = index + 1;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      target = index - _columns;
      if (target < 0) target = index;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final column = index % _columns;
      final nextRowStart = (index ~/ _columns + 1) * _columns;
      if (nextRowStart < _items.length) {
        target = (nextRowStart + column).clamp(nextRowStart, _items.length - 1);
      }
    } else {
      return KeyEventResult.ignored;
    }
    if (target != null) _focusGrid(target);
    return KeyEventResult.handled;
  }

  Future<void> _open(int index) async {
    final item = _items[index];
    context.read<TvNavigationProvider>()
      ..saveFocusedIndex(2, index)
      ..setSectionFocusIndex(2, 1)
      ..saveActiveRowId(2, 'genre-grid')
      ..saveRowFocusedIndex('genre-grid', index);
    final movie = Movie.fromJson(item.data);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => item.mediaType == 'movie'
            ? TvDetailsScreen(item: movie, mediaType: 'movie')
            : TvSeriesScreen(seriesItem: movie),
      ),
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || index >= _items.length) return;
        _cardNode(_items[index]).requestFocus();
        final cardContext = _cardNode(_items[index]).context;
        if (cardContext != null) {
          Scrollable.ensureVisible(
            cardContext,
            duration: const Duration(milliseconds: 220),
          );
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 26, 34, 24),
      child: Row(
        children: [
          SizedBox(width: 276, child: _buildGenrePane()),
          const SizedBox(width: 30),
          Expanded(child: _buildDetailPane()),
        ],
      ),
    );
  }

  Widget _buildGenrePane() {
    if (_loadingGenres) {
      return const Center(child: CustomLoadingWidget(size: 38));
    }
    if (_genreError != null) {
      return _Message(
        message: _genreError!,
        action: 'Retry',
        onPressed: _loadGenres,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse Genres',
          style: TextStyle(fontSize: 31, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView.builder(
            controller: _genreScroll,
            itemCount: _genres.length + 2,
            itemBuilder: (context, index) {
              final movieCount = _genres
                  .where((e) => e.source == 'movie')
                  .length;
              if (index == 0) return _sectionLabel('Movie Genres');
              if (index == movieCount + 1) {
                return _sectionLabel('TV Series Genres');
              }
              final genreIndex = index <= movieCount ? index - 1 : index - 2;
              final genre = _genres[genreIndex];
              final selected = _selectedGenre?.key == genre.key;
              final focused = _focusedGenre?.key == genre.key;
              return Focus(
                focusNode: _genreNode(genre),
                onKeyEvent: (_, event) => _onGenreKey(genre, event),
                onFocusChange: (value) {
                  if (value) setState(() => _focusedGenre = genre);
                },
                child: GestureDetector(
                  onTap: () => _commitGenre(genre),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 7),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFE50914)
                          : focused
                          ? Colors.white12
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: focused
                          ? Border.all(color: Colors.white70)
                          : null,
                    ),
                    child: Text(
                      genre.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 15, 4, 9),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white60,
        letterSpacing: 1.1,
      ),
    ),
  );

  Widget _buildDetailPane() {
    final focused = _focusedCard != null && _focusedCard! < _items.length
        ? _items[_focusedCard!]
        : null;
    final title = focused?.data['title'] ?? focused?.data['name'];
    final date =
        focused?.data['release_date'] ?? focused?.data['first_air_date'];
    final rating = (focused?.data['vote_average'] as num?)?.toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _selectedGenre?.name ?? 'Choose a genre',
          style: const TextStyle(fontSize: 33, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            focused == null
                ? 'Select a title to see details'
                : '$title  •  ${date?.toString().split('-').first ?? '—'}  •  ${rating?.toStringAsFixed(1) ?? '—'} ★  •  ${focused.mediaType == 'movie' ? 'Movie' : 'TV Series'}',
            key: ValueKey(focused?.key),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_loadingContent) {
      return const Center(child: CustomLoadingWidget(size: 42));
    }
    if (_contentError != null) {
      return _Message(
        message: _contentError!,
        action: 'Retry',
        onPressed: () => _commitGenre(_selectedGenre!),
      );
    }
    if (_selectedGenre == null) return const SizedBox.shrink();
    if (_items.isEmpty) {
      return const _Message(message: 'No titles found for this genre.');
    }
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _gridScroll,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _columns,
              childAspectRatio: .68,
              crossAxisSpacing: 12,
              mainAxisSpacing: 14,
            ),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              final data = item.data;
              final date = data['release_date'] ?? data['first_air_date'];
              return TvContentCard(
                key: ValueKey(item.key),
                focusNode: _cardNode(item),
                posterUrl: TmdbApiService.getPosterUrl(
                  data['poster_path'] ?? '',
                ),
                title: data['title'] ?? data['name'] ?? 'Unknown',
                contentType: item.mediaType == 'movie'
                    ? ContentType.movie
                    : ContentType.series,
                rating: (data['vote_average'] as num?)?.toDouble(),
                year: date == null
                    ? null
                    : int.tryParse(date.toString().split('-').first),
                width: 130,
                height: 190,
                onTap: () => _open(index),
                onSelect: () => _open(index),
                onKeyEvent: (_, event) => _onCardKey(index, event),
                onFocusChanged: (value) {
                  if (!value) return;
                  setState(() => _focusedCard = index);
                  context.read<TvNavigationProvider>()
                    ..saveFocusedIndex(2, index)
                    ..setSectionFocusIndex(2, 1)
                    ..saveActiveRowId(2, 'genre-grid')
                    ..saveRowFocusedIndex('genre-grid', index);
                  if (index >= _items.length - _columns * 2) _loadMore();
                },
              );
            },
          ),
        ),
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.all(8),
            child: CustomLoadingWidget(size: 25),
          ),
        if (_pagingError != null)
          _Message(
            message: _pagingError!,
            action: 'Retry',
            onPressed: _loadMore,
            compact: true,
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.message,
    this.action,
    this.onPressed,
    this.compact = false,
  });
  final String message;
  final String? action;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          style: TextStyle(fontSize: compact ? 16 : 19, color: Colors.white70),
        ),
        if (action != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onPressed, child: Text(action!)),
        ],
      ],
    ),
  );
}
