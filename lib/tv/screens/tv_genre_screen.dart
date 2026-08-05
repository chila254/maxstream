import 'dart:async';

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
  static const _typeOptions = <MapEntry<String, String>>[
    MapEntry('movie', 'Movies'),
    MapEntry('tv', 'TV Shows'),
  ];

  final _genreScroll = ScrollController();
  final _gridScroll = ScrollController();
  final Map<String, FocusNode> _typeNodes = {};
  final Map<String, FocusNode> _genreNodes = {};
  final Map<String, FocusNode> _cardNodes = {};
  Timer? _genreDebounce;
  bool _pendingEnterGrid = false;

  String _selectedType = 'movie';
  String _focusedType = 'movie';
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
    _selectType('movie', initial: true);
  }

  @override
  void dispose() {
    _generation++;
    _genreDebounce?.cancel();
    _genreScroll.dispose();
    _gridScroll.dispose();
    for (final node in [
      ..._typeNodes.values,
      ..._genreNodes.values,
      ..._cardNodes.values,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  FocusNode _typeNode(String source) =>
      _typeNodes.putIfAbsent(source, () => FocusNode(debugLabel: 'type:$source'));
  FocusNode _genreNode(_Genre genre) =>
      _genreNodes.putIfAbsent(genre.key, () => FocusNode(debugLabel: genre.key));
  FocusNode _cardNode(_GenreItem item) =>
      _cardNodes.putIfAbsent(item.key, () => FocusNode(debugLabel: item.key));

  /// Switches the active media type (movie/tv): loads its genres and
  /// auto-commits the first genre. Focus stays wherever it is unless
  /// [enterGenreBar] requests moving into the genre rail.
  Future<void> _selectType(
    String source, {
    bool enterGenreBar = false,
    bool initial = false,
  }) async {
    if (_selectedType == source && _genres.isNotEmpty) {
      if (enterGenreBar) {
        final idx = _genres.indexWhere((e) => e.key == _selectedGenre?.key);
        _focusGenreChip(idx < 0 ? 0 : idx);
      }
      return;
    }
    final request = ++_generation;
    setState(() {
      _selectedType = source;
      _focusedType = source;
      _genres = const [];
      _selectedGenre = null;
      _focusedGenre = null;
      _items = const [];
      _focusedCard = null;
      _page = 1;
      _hasMore = true;
      _loadingGenres = true;
      _loadingContent = true;
      _genreError = null;
      _contentError = null;
      _pagingError = null;
    });
    try {
      final genresMap = await TmdbApiService.fetchGenres(source);
      if (!mounted || request != _generation) return;
      final genres = genresMap.entries
          .map((e) => _Genre(source, e.key, e.value))
          .toList();
      setState(() {
        _genres = genres;
        _selectedGenre = genres.firstOrNull;
        _focusedGenre = genres.firstOrNull;
        _loadingGenres = false;
      });
      if (genres.isNotEmpty) {
        final future = _loadGenreContent(genres.first);
        if (initial) await future;
      } else {
        setState(() => _loadingContent = false);
      }
      if (enterGenreBar) {
        _focusGenreChip(0);
      } else if (initial) {
        _restoreFocus();
      }
    } catch (error) {
      LoggerService.error('Error loading $source genres: $error', error);
      if (!mounted || request != _generation) return;
      setState(() {
        _loadingGenres = false;
        _loadingContent = false;
        _genreError = 'Genres could not be loaded.';
      });
      _scheduleFocus(_typeNode(source));
    }
  }

  /// Loads the first page for [genre]. In auto mode (hover) focus is left on
  /// the rail; with [enterGrid] the focus drops into the content grid once
  /// titles are ready.
  Future<void> _loadGenreContent(_Genre genre, {bool enterGrid = false}) async {
    if (_selectedGenre?.key == genre.key && _items.isNotEmpty) {
      if (enterGrid) _enterGrid(genre);
      return;
    }
    if (_selectedGenre?.key == genre.key && _loadingContent) {
      if (enterGrid) _pendingEnterGrid = true;
      return;
    }
    _genreDebounce?.cancel();
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
      _pendingEnterGrid = enterGrid;
    });
    try {
      final rows = await _fetch(genre, 1);
      if (!mounted || request != _generation) return;
      setState(() {
        _items = rows.map((e) => _GenreItem(genre.source, e)).toList();
        _hasMore = rows.isNotEmpty;
        _loadingContent = false;
      });
      if (_pendingEnterGrid && _items.isNotEmpty) {
        _pendingEnterGrid = false;
        _enterGrid(genre);
      }
    } catch (error) {
      LoggerService.error('Error loading genre content: $error', error);
      if (!mounted || request != _generation) return;
      setState(() {
        _loadingContent = false;
        _contentError = 'Content could not be loaded.';
      });
    }
  }

  void _enterGrid(_Genre genre) {
    final genreIndex = _genres.indexWhere((e) => e.key == genre.key);
    final target = (genreIndex < 0 ? 0 : genreIndex % _columns)
        .clamp(0, _items.length - 1);
    _focusGrid(target);
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

  void _restoreFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final nav = context.read<TvNavigationProvider>();
      final section = nav.getSectionFocusIndex(2);
      if (section == 2 && _items.isNotEmpty) {
        _focusGrid(nav.getFocusedIndex(2).clamp(0, _items.length - 1));
      } else if (section == 1 && _selectedGenre != null) {
        final idx = _genres.indexWhere((e) => e.key == _selectedGenre!.key);
        _focusGenreChip(idx < 0 ? 0 : idx);
      } else {
        _scheduleFocus(_typeNode(_selectedType));
      }
    });
  }

  void _scheduleFocus(FocusNode? node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) node?.requestFocus();
    });
  }

  void _focusGrid(int index) {
    if (_items.isEmpty) return;
    final target = index.clamp(0, _items.length - 1);
    context.read<TvNavigationProvider>()
      ..setSectionFocusIndex(2, 2)
      ..saveFocusedIndex(2, target);
    _scheduleFocus(_cardNode(_items[target]));
  }

  void _focusGenreChip(int index) {
    if (_genres.isEmpty) return;
    final target = index.clamp(0, _genres.length - 1);
    final genre = _genres[target];
    context.read<TvNavigationProvider>().setSectionFocusIndex(2, 1);
    _scheduleFocus(_genreNode(genre));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _genreNode(genre).context;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _focusType(String source) {
    context.read<TvNavigationProvider>().setSectionFocusIndex(2, 0);
    _scheduleFocus(_typeNode(source));
  }

  void _sidebar() {
    (widget.onReturnToSidebar ?? TvFocusManager.focusSidebar).call();
  }

  KeyEventResult _onTypeKey(String source, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final index = _typeOptions.indexWhere((e) => e.key == source);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      final delta = key == LogicalKeyboardKey.arrowUp ? -1 : 1;
      final next = (index + delta).clamp(0, _typeOptions.length - 1);
      setState(() => _focusedType = _typeOptions[next].key);
      _typeNode(_typeOptions[next].key).requestFocus();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
      _selectType(source, enterGenreBar: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _sidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onTypeFocus(String source) {
    setState(() => _focusedType = source);
    if (source != _selectedType || _genres.isEmpty) {
      _selectType(source);
    }
  }

  KeyEventResult _onGenreKey(_Genre genre, int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        _focusType(_selectedType);
      } else {
        _focusGenreChip(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index + 1 < _genres.length) _focusGenreChip(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter) {
      _genreDebounce?.cancel();
      _loadGenreContent(genre, enterGrid: true);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      _sidebar();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onGenreFocus(_Genre genre) {
    setState(() => _focusedGenre = genre);
    if (genre.key == _selectedGenre?.key && _items.isNotEmpty) return;
    _genreDebounce?.cancel();
    _genreDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _loadGenreContent(genre);
    });
  }

  KeyEventResult _onCardKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _sidebar();
      return KeyEventResult.handled;
    }
    int? target;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % _columns == 0) {
        _focusType(_selectedType);
        return KeyEventResult.handled;
      }
      target = index - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index % _columns < _columns - 1 && index + 1 < _items.length) {
        target = index + 1;
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (_genres.isNotEmpty) {
        _focusGenreChip((index % _columns).clamp(0, _genres.length - 1));
      }
      return KeyEventResult.handled;
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
      ..setSectionFocusIndex(2, 2)
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 168, child: _buildMediaTypePane()),
          const SizedBox(width: 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGenreBar(),
                const SizedBox(height: 14),
                _buildDetailPane(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTypePane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Browse',
          style: TextStyle(fontSize: 31, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        for (final option in _typeOptions) ...[
          _buildTypeButton(option.key, option.value),
          const SizedBox(height: 10),
        ],
        if (_loadingGenres)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: CustomLoadingWidget(size: 28),
          ),
        if (_genreError != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: _Message(
              message: _genreError!,
              action: 'Retry',
              onPressed: () =>
                  _selectType(_selectedType, enterGenreBar: true),
              compact: true,
            ),
          ),
      ],
    );
  }

  Widget _buildTypeButton(String source, String label) {
    final selected = _selectedType == source;
    final focused = _focusedType == source;
    return Focus(
      focusNode: _typeNode(source),
      onKeyEvent: (_, event) => _onTypeKey(source, event),
      onFocusChange: (value) {
        if (value) _onTypeFocus(source);
      },
      child: GestureDetector(
        onTap: () => _selectType(source, enterGenreBar: true),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE50914)
                : focused
                ? Colors.white12
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: focused ? Border.all(color: Colors.white70) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                source == 'movie' ? Icons.movie_outlined : Icons.tv,
                color: selected || focused ? Colors.white : Colors.white70,
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenreBar() {
    if (_genres.isEmpty) return const SizedBox(height: 46);
    return SizedBox(
      height: 46,
      child: ListView.builder(
        controller: _genreScroll,
        scrollDirection: Axis.horizontal,
        itemCount: _genres.length,
        itemBuilder: (context, index) {
          final genre = _genres[index];
          final selected = _selectedGenre?.key == genre.key;
          final focused = _focusedGenre?.key == genre.key;
          return Padding(
            padding: const EdgeInsets.only(right: 9),
            child: Focus(
              focusNode: _genreNode(genre),
              onKeyEvent: (_, event) => _onGenreKey(genre, index, event),
              onFocusChange: (value) {
                if (value) _onGenreFocus(genre);
              },
              child: GestureDetector(
                onTap: () => _loadGenreContent(genre, enterGrid: true),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFE50914)
                        : focused
                        ? Colors.white12
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: focused
                        ? Border.all(color: Colors.white70)
                        : null,
                  ),
                  child: Text(
                    genre.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          selected || focused
                              ? FontWeight.w700
                              : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailPane() {
    final focused = _focusedCard != null && _focusedCard! < _items.length
        ? _items[_focusedCard!]
        : null;
    final title = focused?.data['title'] ?? focused?.data['name'];
    final date =
        focused?.data['release_date'] ?? focused?.data['first_air_date'];
    final rating = (focused?.data['vote_average'] as num?)?.toDouble();
    final typeLabel = _typeOptions
        .firstWhere((e) => e.key == _selectedType)
        .value;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedGenre == null
                ? typeLabel
                : '$typeLabel  •  ${_selectedGenre!.name}',
            style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
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
          const SizedBox(height: 14),
          Expanded(child: _buildContent()),
        ],
      ),
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
        onPressed: () {
          final genre = _selectedGenre;
          if (genre != null) {
            _loadGenreContent(genre, enterGrid: true);
          } else {
            _selectType(_selectedType, enterGenreBar: true);
          }
        },
      );
    }
    if (_selectedGenre == null || _items.isEmpty) {
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
                    ..setSectionFocusIndex(2, 2)
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
