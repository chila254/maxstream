import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
import '../../widgets/custom_loading_widget.dart';
import '../widgets/tv_visual_enhancements.dart';
import 'tv_details_screen.dart';
import '../../models/movie.dart';

/// Streaming Providers Screen for TV
/// Displays movies/series grouped by streaming platform in grid columns
class TvStreamingProvidersScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvStreamingProvidersScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvStreamingProvidersScreen> createState() =>
      _TvStreamingProvidersScreenState();
}

class _TvStreamingProvidersScreenState extends State<TvStreamingProvidersScreen>
    with TvDpadNavigationMixin {
  // Streaming providers with their logos
  final Map<String, String> _providers = {
    'Netflix': '🎬',
    'Disney+': '🏰',
    'Amazon Prime': '🎥',
    'Hulu': '📺',
    'Apple TV+': '🍎',
    'HBO Max': '🎭',
  };

  String? _selectedProvider;
  List<Map<String, dynamic>> _providerContent = [];
  bool _isLoadingContent = false;
  bool _showDetailView = false;
  int? _focusedContentIndex;
  late ScrollController _scrollController;
  static const int _columnsPerRow = 3;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => _showDetailView
      ? (_providerContent.isNotEmpty ? _providerContent.length - 1 : 0)
      : (_providers.length - 1).clamp(0, 100);

  @override
  void onFocusChanged(int index) {
    setState(() {
      if (_showDetailView) {
        _focusedContentIndex = index;
      }
    });
  }

  @override
  void onSelectPressed() {
    // Selection handled by provider/content cards
  }

  @override
  void onLeftPressed() {
    if (_showDetailView) {
      final currentFocus = getFocusIndex();
      if (currentFocus > 0 && currentFocus % _columnsPerRow != 0) {
        // Navigate left within grid
        setFocusIndex(currentFocus - 1);
      } else if (currentFocus % _columnsPerRow == 0 &&
          widget.onReturnToSidebar != null) {
        // At leftmost column: return to sidebar
        widget.onReturnToSidebar!();
      }
    }
  }

  @override
  void onRightPressed() {
    if (_showDetailView) {
      final currentFocus = getFocusIndex();
      if (currentFocus + 1 < _providerContent.length &&
          (currentFocus + 1) % _columnsPerRow != 0) {
        setFocusIndex(currentFocus + 1);
      }
    }
  }

  @override
  void handleKeyEvent(RawKeyEvent event) {
    if (_showDetailView) {
      if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
        _moveDown();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
        _moveUp();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowLeft)) {
        onLeftPressed();
      } else if (event.isKeyPressed(LogicalKeyboardKey.arrowRight)) {
        onRightPressed();
      }
    } else {
      super.handleKeyEvent(event);
    }
  }

  void _moveDown() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus + _columnsPerRow;
    if (newIndex < _providerContent.length) {
      setFocusIndex(newIndex);
    }
  }

  void _moveUp() {
    final currentFocus = getFocusIndex();
    int newIndex = currentFocus - _columnsPerRow;
    if (newIndex >= 0) {
      setFocusIndex(newIndex);
    }
  }

  void _selectProvider(String provider) {
    setState(() {
      _selectedProvider = provider;
      _showDetailView = true;
      _isLoadingContent = true;
      // Simulate loading content for this provider
      _providerContent = _generateMockContent();
      _isLoadingContent = false;
    });
  }

  List<Map<String, dynamic>> _generateMockContent() {
    // Mock data - in production, this would fetch from API
    return List.generate(12, (index) {
      return {
        'id': index + 1,
        'title': '${_selectedProvider} Content ${index + 1}',
        'poster_path': '/sample_poster.jpg',
        'release_date': '2024-01-${(index + 1).toString().padLeft(2, '0')}',
        'vote_average': 7.5 + (index % 3),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: _showDetailView ? _buildDetailView() : _buildProvidersListView(),
    );
  }

  Widget _buildProvidersListView() {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(TvUtils.responsivePadding(24, context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            GradientText(
              'Streaming Providers',
              baseStyle: TextStyle(
                fontSize: TvUtils.responsiveFontSize(32, context, maxSize: 48),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: TvUtils.responsivePadding(32, context)),
            // Provider Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.2,
                crossAxisSpacing: TvUtils.responsivePadding(16, context),
                mainAxisSpacing: TvUtils.responsivePadding(16, context),
              ),
              itemCount: _providers.length,
              itemBuilder: (context, index) {
                final providerName =
                    _providers.keys.toList()[index];
                final emoji = _providers[providerName]!;

                return GestureDetector(
                  onTap: () => _selectProvider(providerName),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      border:
                          Border.all(color: Colors.grey[700]!, width: 2),
                      borderRadius: BorderRadius.circular(
                        TvUtils.responsivePadding(12, context),
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectProvider(providerName),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              emoji,
                              style: TextStyle(
                                fontSize: TvUtils.responsiveFontSize(48,
                                    context,
                                    maxSize: 64),
                              ),
                            ),
                            SizedBox(
                              height:
                                  TvUtils.responsivePadding(16, context),
                            ),
                            Text(
                              providerName,
                              style: TvTypography.cardTitle,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView() {
    return WillPopScope(
      onWillPop: () async {
        setState(() => _showDetailView = false);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            _selectedProvider ?? 'Provider',
            style: TvTypography.subsectionTitle,
          ),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              size: TvUtils.responsiveFontSize(24, context, maxSize: 36),
            ),
            onPressed: () => setState(() => _showDetailView = false),
          ),
          elevation: 0,
        ),
        body: _isLoadingContent
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CustomLoadingWidget(
                      size: 40,
                      color: Color(0xFFE50914),
                      style: LoadingStyle.dots,
                    ),
                    SizedBox(height: TvUtils.responsivePadding(16, context)),
                    Text(
                      'Loading content...',
                      style: TvTypography.bodyMedium,
                    ),
                  ],
                ),
              )
            : _providerContent.isEmpty
                ? Center(
                    child: Text(
                      'No content available',
                      style: TvTypography.bodyMedium,
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(
                        TvUtils.responsivePadding(16, context)),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.6,
                      crossAxisSpacing:
                          TvUtils.responsivePadding(16, context),
                      mainAxisSpacing:
                          TvUtils.responsivePadding(16, context),
                    ),
                    itemCount: _providerContent.length,
                    itemBuilder: (context, index) {
                      final item = _providerContent[index];
                      final isFocused =
                          _focusedContentIndex == index;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  TvDetailsScreen(
                                item: Movie.fromJson(item),
                                mediaType: 'movie',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                            border: isFocused
                                ? Border.all(
                                    color: const Color(
                                        0xFFE50914),
                                    width: 3)
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(
                                          8),
                                  child: Container(
                                    color: Colors.grey[800],
                                    child: const Icon(
                                      Icons
                                          .image_not_supported,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.all(
                                  TvUtils
                                      .responsivePadding(
                                          8, context),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      item['title'] ??
                                          'Unknown',
                                      style: TextStyle(
                                        color:
                                            Colors.white,
                                        fontSize: TvUtils
                                            .responsiveFontSize(
                                                13,
                                                context),
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow:
                                          TextOverflow
                                              .ellipsis,
                                    ),
                                    Text(
                                      item['release_date']
                                              ?.toString()
                                              .split('-')[0] ??
                                          '',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: TvUtils
                                            .responsiveFontSize(
                                                11,
                                                context),
                                      ),
                                    ),
                                  ],
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
  }
}
