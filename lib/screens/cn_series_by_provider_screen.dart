import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import '../database/db_helper.dart';
import '../widgets/custom_loading_widget.dart';
import 'maxstream_series_screen.dart';

class StreamingProvider {
  final int id;
  final String name;
  final Color color;
  final IconData icon;

  StreamingProvider({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
  });
}

class CnSeriesByProviderScreen extends StatefulWidget {
  const CnSeriesByProviderScreen({super.key});

  @override
  State<CnSeriesByProviderScreen> createState() =>
      _CnSeriesByProviderScreenState();
}

class _CnSeriesByProviderScreenState extends State<CnSeriesByProviderScreen> {
  final List<StreamingProvider> providers = [
    StreamingProvider(
      id: 8,
      name: 'Netflix',
      color: const Color(0xFFE50914),
      icon: Icons.play_circle,
    ),
    StreamingProvider(
      id: 119,
      name: 'Prime Video',
      color: const Color(0xFF00A8E1),
      icon: Icons.video_library,
    ),
    StreamingProvider(
      id: 337,
      name: 'Disney+',
      color: const Color(0xFF113CCF),
      icon: Icons.movie,
    ),
  ];

  late Map<int, List<Map<String, dynamic>>> seriesByProvider;
  late Map<int, bool> isLoadingMap;
  late Map<int, bool> isPreferredMap;
  late Map<int, bool> isLoadingMoreMap;
  late Map<int, int> pageMap;
  late Map<int, ScrollController> scrollControllerMap;
  int selectedProviderIndex = 0;
  String searchQuery = '';
  late TextEditingController searchController;

  @override
  void initState() {
    searchController = TextEditingController();
    super.initState();
    seriesByProvider = {};
    isLoadingMap = {};
    isPreferredMap = {};
    isLoadingMoreMap = {};
    pageMap = {};
    scrollControllerMap = {};
    for (var provider in providers) {
      seriesByProvider[provider.id] = [];
      isLoadingMap[provider.id] = false;
      isPreferredMap[provider.id] = false;
      isLoadingMoreMap[provider.id] = false;
      pageMap[provider.id] = 1;
      scrollControllerMap[provider.id] = ScrollController();
      scrollControllerMap[provider.id]!.addListener(() => _onScroll(provider.id));
    }
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    await DBHelper.initializeProviderPreferences();
    await _loadPreferences();
    _loadSeriesForProvider(0);
  }

  Future<void> _loadPreferences() async {
    try {
      for (var provider in providers) {
        final isPreferred = await DBHelper.isProviderPreferred(provider.id);
        setState(() {
          isPreferredMap[provider.id] = isPreferred;
        });
      }
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  Future<void> _loadSeriesForProvider(int index) async {
    final provider = providers[index];

    setState(() {
      selectedProviderIndex = index;
      isLoadingMap[provider.id] = true;
      pageMap[provider.id] = 1;
    });

    try {
      final series = await TmdbApiService.getSeriesByProvider(provider.id, page: 1);
      if (mounted) {
        setState(() {
          seriesByProvider[provider.id] = series;
          isLoadingMap[provider.id] = false;
        });
      }
    } catch (e) {
      print('Error loading series for ${provider.name}: $e');
      if (mounted) {
        setState(() {
          isLoadingMap[provider.id] = false;
        });
      }
    }
  }

  void _onScroll(int providerId) {
    final scrollController = scrollControllerMap[providerId];
    if (scrollController != null &&
        scrollController.position.pixels ==
            scrollController.position.maxScrollExtent &&
        !isLoadingMoreMap[providerId]! &&
        seriesByProvider[providerId]!.isNotEmpty) {
      _loadMoreSeries(providerId);
    }
  }

  Future<void> _loadMoreSeries(int providerId) async {
    if (isLoadingMoreMap[providerId]!) return;

    setState(() {
      isLoadingMoreMap[providerId] = true;
    });

    try {
      final nextPage = (pageMap[providerId] ?? 1) + 1;
      final newSeries = await TmdbApiService.getSeriesByProvider(providerId, page: nextPage);

      if (newSeries.isNotEmpty && mounted) {
        setState(() {
          seriesByProvider[providerId]!.addAll(newSeries);
          pageMap[providerId] = nextPage;
          isLoadingMoreMap[providerId] = false;
        });
      } else if (mounted) {
        setState(() {
          isLoadingMoreMap[providerId] = false;
        });
      }
    } catch (e) {
      print('Error loading more series: $e');
      if (mounted) {
        setState(() {
          isLoadingMoreMap[providerId] = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (var controller in scrollControllerMap.values) {
      controller.dispose();
    }
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'TV Series by Streaming Service',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchController,
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search series...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          searchController.clear();
                          setState(() {
                            searchQuery = '';
                          });
                        },
                        child: const Icon(Icons.clear, color: Colors.grey),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red),
                ),
              ),
            ),
          ),
          // Provider tabs with icons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(providers.length, (index) {
                final provider = providers[index];
                final isSelected = index == selectedProviderIndex;
                final isPreferred = isPreferredMap[provider.id] ?? false;

                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 16 : 8,
                    right: index == providers.length - 1 ? 16 : 8,
                    top: 8,
                    bottom: 8,
                  ),
                  child: GestureDetector(
                    onTap: () => _loadSeriesForProvider(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? provider.color
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: provider.color, width: 2)
                            : Border.all(color: Colors.grey[700]!, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            provider.icon,
                            color: isSelected ? Colors.white : provider.color,
                            size: 24,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                          if (isPreferred) ...[
                            const SizedBox(height: 2),
                            Icon(
                              Icons.star,
                              size: 12,
                              color: isSelected ? Colors.white : Colors.amber,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          // Series grid
          Expanded(child: _buildSeriesGrid()),
        ],
      ),
    );
  }

  Widget _buildSeriesGrid() {
    final currentProvider = providers[selectedProviderIndex];
    final allSeries = seriesByProvider[currentProvider.id] ?? [];
    final isLoading = isLoadingMap[currentProvider.id] ?? false;

    // Filter series based on search query
    final filteredSeries = searchQuery.isEmpty
        ? allSeries
        : allSeries
            .where((series) =>
                (series['name'] ?? '').toLowerCase().contains(searchQuery))
            .toList();

    if (isLoading && searchQuery.isEmpty) {
      return _buildLoadingShimmer();
    }

    if (filteredSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty ? 'No series found' : 'No series available',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      controller: scrollControllerMap[currentProvider.id],
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.6,
      ),
      itemCount: filteredSeries.length +
          (isLoading && isLoadingMoreMap[currentProvider.id]! ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == filteredSeries.length) {
          return const Center(
            child: CustomLoadingWidget(
              size: 30,
              color: Color(0xFFE50914),
              style: LoadingStyle.dots,
            ),
          );
        }
        final item = filteredSeries[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    MaxStreamSeriesScreen(seriesItem: Movie.fromJson(item)),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: item['poster_path'] != null
                      ? Image.network(
                          TmdbApiService.getPosterUrl(item['poster_path']),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.tv,
                                color: Colors.grey,
                                size: 40,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(
                            Icons.tv,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _getYear(item),
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[600]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.6,
        ),
        itemCount: 12,
        itemBuilder: (context, index) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 12, color: Colors.grey[800]),
              const SizedBox(height: 4),
              Container(height: 10, width: 50, color: Colors.grey[800]),
            ],
          );
        },
      ),
    );
  }

  String _getYear(Map<String, dynamic> item) {
    final date = item['first_air_date'];
    if (date != null && date.toString().length >= 4) {
      return date.toString().substring(0, 4);
    }
    return '';
  }
}
