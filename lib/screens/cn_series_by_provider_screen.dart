import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_shimmer.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import '../utils/tmdb_list_utils.dart';
import '../database/db_helper.dart';
import '../widgets/custom_loading_widget.dart';
import 'maxstream_series_screen.dart';
import '../widgets/app_network_image.dart';

class StreamingProvider {
  final int id;
  final String name;
  final Color color;
  final IconData icon;
  final String? logoPath; // Path to provider logo asset

  StreamingProvider({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.logoPath,
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
      id: 9,
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
    StreamingProvider(
      id: 15,
      name: 'Hulu',
      color: const Color(0xFF1CE783),
      icon: Icons.live_tv,
    ),
    StreamingProvider(
      id: 350,
      name: 'Apple TV',
      color: const Color(0xFF1F1F1F),
      icon: Icons.apple,
    ),
    StreamingProvider(
      id: 1899,
      name: 'HBO Max',
      color: const Color(0xFF542DBF),
      icon: Icons.hd,
    ),
    StreamingProvider(
      id: 386,
      name: 'Peacock',
      color: const Color(0xFF1B365D),
      icon: Icons.tv,
    ),
    StreamingProvider(
      id: 582,
      name: 'Paramount+',
      color: const Color(0xFF0064FF),
      icon: Icons.live_tv_sharp,
    ),
    StreamingProvider(
      id: 526,
      name: 'AMC+',
      color: const Color(0xFF1A1A1A),
      icon: Icons.theaters,
    ),
  ];

  late Map<int, List<Map<String, dynamic>>> seriesByProvider;
  late Map<int, bool> isLoadingMap;
  late Map<int, bool> isPreferredMap;
  late Map<int, bool> isLoadingMoreMap;
  late Map<int, int> pageMap;
  late Map<int, bool> hasMoreMap;
  late Map<int, ScrollController> scrollControllerMap;
  int selectedProviderIndex = 0;

  @override
  void initState() {
    super.initState();
    seriesByProvider = {};
    isLoadingMap = {};
    isPreferredMap = {};
    isLoadingMoreMap = {};
    pageMap = {};
    hasMoreMap = {};
    scrollControllerMap = {};
    for (var provider in providers) {
      seriesByProvider[provider.id] = [];
      isLoadingMap[provider.id] = false;
      isPreferredMap[provider.id] = false;
      isLoadingMoreMap[provider.id] = false;
      pageMap[provider.id] = 1;
      hasMoreMap[provider.id] = true;
      scrollControllerMap[provider.id] = ScrollController();
      scrollControllerMap[provider.id]!.addListener(
        () => _onScroll(provider.id),
      );
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
      // Error loading preferences
    }
  }

  Future<void> _loadSeriesForProvider(int index) async {
    final provider = providers[index];

    setState(() {
      selectedProviderIndex = index;
      isLoadingMap[provider.id] = true;
      pageMap[provider.id] = 1;
      hasMoreMap[provider.id] = true;
    });

    try {
      final series = await TmdbApiService.getSeriesByProvider(
        provider.id,
        page: 1,
      );
      // Loaded ${series.length} series for ${provider.name}
      if (series.isEmpty) {
        // No series found for ${provider.name}
      }
      if (mounted) {
        setState(() {
          seriesByProvider[provider.id] = series;
          isLoadingMap[provider.id] = false;
        });
      }
    } catch (e) {
      // Error loading series for ${provider.name}
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
        hasMoreMap[providerId]! &&
        seriesByProvider[providerId]!.isNotEmpty) {
      _loadMoreSeries(providerId);
    }
  }

  Future<void> _loadMoreSeries(int providerId) async {
    if (isLoadingMoreMap[providerId]! || !hasMoreMap[providerId]!) return;

    setState(() {
      isLoadingMoreMap[providerId] = true;
    });

    try {
      final nextPage = (pageMap[providerId] ?? 1) + 1;
      final newSeries = await TmdbApiService.getSeriesByProvider(
        providerId,
        page: nextPage,
      );

      if (mounted) {
        final current = seriesByProvider[providerId]!;
        final merged = uniqueTmdbItems(current, newSeries, 'tv');
        setState(() {
          hasMoreMap[providerId] = merged.length > current.length;
          seriesByProvider[providerId] = merged;
          if (hasMoreMap[providerId]!) pageMap[providerId] = nextPage;
          isLoadingMoreMap[providerId] = false;
        });
      }
    } catch (e) {
      // Error loading more series
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
          // Provider grid
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: providers.length,
              itemBuilder: (context, index) {
                final provider = providers[index];
                final isSelected = index == selectedProviderIndex;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _loadSeriesForProvider(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? provider.color.withValues(alpha: 0.95)
                          : provider.color,
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : Border.all(color: Colors.grey[700]!, width: 1),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: provider.color.withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
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

    if (isLoading) {
      return _buildLoadingShimmer();
    }

    if (allSeries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tv_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No series available',
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
      itemCount:
          allSeries.length + (isLoadingMoreMap[currentProvider.id]! ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == allSeries.length) {
          return const Center(
            child: CustomLoadingWidget(
              size: 30,
              color: Color(0xFFE50914),
              style: LoadingStyle.dots,
            ),
          );
        }
        final item = allSeries[index];
        return GestureDetector(
          key: ValueKey(tmdbItemKey(item, 'tv')),
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
                      ? AppNetworkImage(
                          url: TmdbApiService.getPosterUrl(item['poster_path']),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.tv,
                              color: Colors.grey,
                              size: 40,
                            ),
                          ),
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
    return AppShimmer(
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
