import 'package:flutter/material.dart';
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

/// Provider logos map with TMDB logo paths
class StreamingProviders {
  static final Map<int, StreamingProvider> providers = {
    8: StreamingProvider(
      id: 8,
      name: 'Netflix',
      logoPath: '/wwemzKWzDG0at4JZebuCT0IB2Fr.jpg',
      accentColor: const Color(0xFFE50914),
    ),
    9: StreamingProvider(
      id: 9,
      name: 'Amazon Prime Video',
      logoPath: '/68MNrwlkpF7WnmNvQEzL05O5Vuk.jpg',
      accentColor: const Color(0xFF00A8E1),
    ),
    337: StreamingProvider(
      id: 337,
      name: 'Disney Plus',
      logoPath: '/dgPuNKd5E1ejscPr0Yu3Outa11G.jpg',
      accentColor: const Color(0xFF113CCF),
    ),
    15: StreamingProvider(
      id: 15,
      name: 'Hulu',
      logoPath: '/5NyLm42sCqWAGJogoKB3wAvGEwu.jpg',
      accentColor: const Color(0xFF1CE783),
    ),
    2: StreamingProvider(
      id: 2,
      name: 'Apple TV Plus',
      logoPath: '/fSK1xQ7s5W1tnW2gDA2LzNtulqF.jpg',
      accentColor: const Color(0xFF000000),
    ),
    3: StreamingProvider(
      id: 3,
      name: 'Google Play',
      logoPath: '/AwqLmV6OWP5x70z2BcXyb5GrSJt.jpg',
      accentColor: const Color(0xFF4285F4),
    ),
    5: StreamingProvider(
      id: 5,
      name: 'iTunes',
      logoPath: '/peURlLlr8jGsmMNuZiZXeeedQoL.jpg',
      accentColor: const Color(0xFFFB233B),
    ),
    14: StreamingProvider(
      id: 14,
      name: 'HBO Max',
      logoPath: '/JsPd0Pf8Xyf5WcsZN9aX3inmaW.jpg',
      accentColor: const Color(0xFF5D1049),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.all(TvUtils.responsivePadding(8, context)),
          decoration: BoxDecoration(
            color: isFocused
                ? provider.accentColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? provider.accentColor : Colors.grey[800]!,
              width: isFocused ? 2 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: provider.accentColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
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
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[900],
                ),
                child: logoUrl.isNotEmpty
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              provider.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: TvUtils.responsiveFontSize(
                                  32,
                                  context,
                                ),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      )
                    : Center(
                        child: Icon(
                          Icons.smart_display,
                          color: provider.accentColor,
                          size: size * 0.6,
                        ),
                      ),
              ),
              // Label
              if (showLabel) ...[
                SizedBox(height: TvUtils.responsivePadding(8, context)),
                Text(
                  provider.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: TvUtils.responsiveFontSize(12, context),
                    fontWeight: FontWeight.w600,
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
            child: TvStreamingProviderLogo(
              provider: provider,
              size: 80,
              showLabel: true,
              isFocused: isSelected,
              onTap: () => widget.onProviderSelected(provider),
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
