import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_utils.dart';

/// Streaming provider data with TMDB information
class StreamingProvider {
  final int id;
  final String name;
  final String? logoPath; // TMDB logo path
  final Color accentColor;

  StreamingProvider({
    required this.id,
    required this.name,
    this.logoPath,
    required this.accentColor,
  });
}

/// Provider logos map with TMDB logo paths (matching MaxStream mobile app)
class StreamingProviders {
  static final Map<int, StreamingProvider> providers = {
    8: StreamingProvider(
      id: 8,
      name: 'Netflix',
      logoPath: '/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg',
      accentColor: const Color(0xFFE50914),
    ),
    9: StreamingProvider(
      id: 9,
      name: 'Prime Video',
      logoPath: '/pvske1MyAoymrs5bguRfVqYiM9a.jpg',
      accentColor: const Color(0xFF00A8E1),
    ),
    337: StreamingProvider(
      id: 337,
      name: 'Disney+',
      logoPath: '/97yvRBw1GzX7fXprcF80er19ot.jpg',
      accentColor: const Color(0xFF113CCF),
    ),
    15: StreamingProvider(
      id: 15,
      name: 'Hulu',
      logoPath: '/bxBlRPEPpMVDc4jMhSrTf2339DW.jpg',
      accentColor: const Color(0xFF1CE783),
    ),
    350: StreamingProvider(
      id: 350,
      name: 'Apple TV',
      logoPath: '/mcbz1LgtErU9p4UdbZ0rG6RTWHX.jpg',
      accentColor: const Color(0xFF1F1F1F),
    ),
    1899: StreamingProvider(
      id: 1899,
      name: 'HBO Max',
      logoPath: '/jbe4gVSfRlbPTdESXhEKpornsfu.jpg',
      accentColor: const Color(0xFF542DBF),
    ),
    386: StreamingProvider(
      id: 386,
      name: 'Peacock',
      logoPath: '/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg',
      accentColor: const Color(0xFF1B365D),
    ),
    582: StreamingProvider(
      id: 582,
      name: 'Paramount+',
      logoPath: '/5qda0qKT6I1tm5EUOlw3YqQ5w.jpg',
      accentColor: const Color(0xFF0064FF),
    ),
    526: StreamingProvider(
      id: 526,
      name: 'AMC+',
      logoPath: '/ovmu6uot1XVvsemM2dDySXLiX57.jpg',
      accentColor: const Color(0xFF1A1A1A),
    ),
  };

  static StreamingProvider? getProvider(int id) => providers[id];

  static String getProviderLogoUrl(String? logoPath) {
    if (logoPath == null) return '';
    return 'https://image.tmdb.org/t/p/w154$logoPath';
  }
}

/// TV-optimized streaming provider logo widget
class TvStreamingProviderLogo extends StatelessWidget {
  final StreamingProvider provider;
  final double size;
  final bool showLabel;
  final VoidCallback? onTap;
  final bool isFocused;

  const TvStreamingProviderLogo({
    super.key,
    required this.provider,
    this.size = 100,
    this.showLabel = true,
    this.onTap,
    this.isFocused = false,
  });

  @override
  Widget build(BuildContext context) {
    final logoUrl = StreamingProviders.getProviderLogoUrl(provider.logoPath);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 1.0, end: isFocused ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.all(TvUtils.responsivePadding(12, context)),
            decoration: BoxDecoration(
              color: isFocused
                  ? provider.accentColor.withValues(alpha: 0.2)
                  : Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isFocused ? provider.accentColor : Colors.grey[800]!,
                width: isFocused ? 3 : 2,
              ),
              boxShadow: [
                if (isFocused)
                  BoxShadow(
                    color: provider.accentColor.withValues(alpha: 0.5),
                    blurRadius: 16,
                    spreadRadius: 3,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Image
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[950],
                  ),
                  padding: EdgeInsets.all(TvUtils.responsivePadding(4, context)),
                  child: logoUrl.isNotEmpty
                      ? Image.network(
                          logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: provider.accentColor
                                    .withValues(alpha: 0.2),
                              ),
                              child: Center(
                                child: Text(
                                  provider.name.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: provider.accentColor,
                                    fontSize: TvUtils.responsiveFontSize(
                                      40,
                                      context,
                                    ),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: provider.accentColor
                                .withValues(alpha: 0.1),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.smart_display,
                              color: provider.accentColor,
                              size: size * 0.6,
                            ),
                          ),
                        ),
                ),
                // Label
                if (showLabel) ...[
                  SizedBox(height: TvUtils.responsivePadding(10, context)),
                  Text(
                    provider.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: TvUtils.responsiveFontSize(13, context),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable provider list widget
class TvStreamingProvidersHorizontalList extends StatefulWidget {
  final List<int> providerIds;
  final Function(StreamingProvider) onProviderSelected;
  final int? selectedProviderId;

  const TvStreamingProvidersHorizontalList({
    super.key,
    required this.providerIds,
    required this.onProviderSelected,
    this.selectedProviderId,
  });

  @override
  State<TvStreamingProvidersHorizontalList> createState() =>
      _TvStreamingProvidersHorizontalListState();
}

class _TvStreamingProvidersHorizontalListState
    extends State<TvStreamingProvidersHorizontalList> {
  late ScrollController _scrollController;

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

  @override
  Widget build(BuildContext context) {
    final validProviders = widget.providerIds
        .map((id) => StreamingProviders.getProvider(id))
        .where((p) => p != null)
        .cast<StreamingProvider>()
        .toList();

    if (validProviders.isEmpty) {
      return Center(
        child: Text(
          'No streaming providers available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: TvUtils.responsiveFontSize(14, context),
          ),
        ),
      );
    }

    return SizedBox(
      height: TvUtils.responsiveWidth(
        180,
        context,
        maxWidth: 200,
      ), // Responsive height
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: validProviders.length,
        itemBuilder: (context, index) {
          final provider = validProviders[index];
          final isSelected = widget.selectedProviderId == provider.id;

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: TvUtils.responsivePadding(8, context),
              vertical: TvUtils.responsivePadding(4, context),
            ),
            child: Focus(
              onKey: (node, event) {
                if (event.isKeyPressed(LogicalKeyboardKey.select)) {
                  widget.onProviderSelected(provider);
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: TvStreamingProviderLogo(
                provider: provider,
                size: 80,
                showLabel: true,
                isFocused: isSelected,
                onTap: () => widget.onProviderSelected(provider),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// TV-optimized provider grid (3 columns)
class TvStreamingProvidersGrid extends StatefulWidget {
  final List<int> providerIds;
  final Function(StreamingProvider) onProviderSelected;
  final int? selectedProviderId;

  const TvStreamingProvidersGrid({
    super.key,
    required this.providerIds,
    required this.onProviderSelected,
    this.selectedProviderId,
  });

  @override
  State<TvStreamingProvidersGrid> createState() =>
      _TvStreamingProvidersGridState();
}

class _TvStreamingProvidersGridState extends State<TvStreamingProvidersGrid> {
  @override
  Widget build(BuildContext context) {
    final validProviders = widget.providerIds
        .map((id) => StreamingProviders.getProvider(id))
        .where((p) => p != null)
        .cast<StreamingProvider>()
        .toList();

    if (validProviders.isEmpty) {
      return Center(
        child: Text(
          'No streaming providers available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: TvUtils.responsiveFontSize(14, context),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(TvUtils.responsivePadding(16, context)),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.9,
        crossAxisSpacing: TvUtils.responsivePadding(12, context),
        mainAxisSpacing: TvUtils.responsivePadding(12, context),
      ),
      itemCount: validProviders.length,
      itemBuilder: (context, index) {
        final provider = validProviders[index];
        final isSelected = widget.selectedProviderId == provider.id;

        return TvStreamingProviderLogo(
          provider: provider,
          size: 100,
          showLabel: true,
          isFocused: isSelected,
          onTap: () => widget.onProviderSelected(provider),
        );
      },
    );
  }
}
