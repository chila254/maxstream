import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import '../database/db_helper.dart';
import 'onstream_series_screen.dart';

class StreamingProvider {
  final int id;
  final String name;
  final Color color;

  StreamingProvider({
    required this.id,
    required this.name,
    required this.color,
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
    StreamingProvider(id: 8, name: 'Netflix', color: const Color(0xFFE50914)),
    StreamingProvider(
      id: 119,
      name: 'Prime Video',
      color: const Color(0xFF00A8E1),
    ),
    StreamingProvider(id: 337, name: 'Disney+', color: const Color(0xFF113CCF)),
  ];

  late Map<int, List<Map<String, dynamic>>> seriesByProvider;
  late Map<int, bool> isLoadingMap;
  late Map<int, bool> isPreferredMap;
  int selectedProviderIndex = 0;

  @override
  void initState() {
    super.initState();
    seriesByProvider = {};
    isLoadingMap = {};
    isPreferredMap = {};
    for (var provider in providers) {
      seriesByProvider[provider.id] = [];
      isLoadingMap[provider.id] = false;
      isPreferredMap[provider.id] = false;
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
    });

    try {
      final series = await TmdbApiService.getSeriesByProvider(provider.id);
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
          // Provider tabs
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
                    top: 12,
                    bottom: 12,
                  ),
                  child: GestureDetector(
                    onTap: () => _loadSeriesForProvider(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? provider.color
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: provider.color, width: 2)
                            : Border.all(color: Colors.grey[700]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            provider.name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                          if (isPreferred) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.star,
                              size: 14,
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
    final series = seriesByProvider[currentProvider.id] ?? [];
    final isLoading = isLoadingMap[currentProvider.id] ?? false;

    if (isLoading) {
      return _buildLoadingShimmer();
    }

    if (series.isEmpty) {
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
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.6,
      ),
      itemCount: series.length,
      itemBuilder: (context, index) {
        final item = series[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    OnStreamSeriesScreen(seriesItem: Movie.fromJson(item)),
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
