import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/db_helper.dart';
import '../services/content_notification_service.dart';
import '../widgets/app_network_image.dart';

class StreamingProvider {
  final int id;
  final String name;
  final Color color;
  final IconData icon;
  final String? logoPath;

  StreamingProvider({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    this.logoPath,
  });
}

class StreamingProviderSettingsScreen extends StatefulWidget {
  const StreamingProviderSettingsScreen({super.key});

  @override
  State<StreamingProviderSettingsScreen> createState() =>
      _StreamingProviderSettingsScreenState();
}

class _StreamingProviderSettingsScreenState
    extends State<StreamingProviderSettingsScreen> {
  final List<StreamingProvider> providers = [
    StreamingProvider(
      id: 8,
      name: 'Netflix',
      color: const Color(0xFFE50914),
      icon: Icons.play_circle,
      logoPath: '/pbpMk2JmcoNnQwx5JGpXngfoWtp.jpg',
    ),
    StreamingProvider(
      id: 9,
      name: 'Prime Video',
      color: const Color(0xFF00A8E1),
      icon: Icons.video_library,
      logoPath: '/pvske1MyAoymrs5bguRfVqYiM9a.jpg',
    ),
    StreamingProvider(
      id: 337,
      name: 'Disney+',
      color: const Color(0xFF113CCF),
      icon: Icons.movie,
      logoPath: '/97yvRBw1GzX7fXprcF80er19ot.jpg',
    ),
    StreamingProvider(
      id: 15,
      name: 'Hulu',
      color: const Color(0xFF1CE783),
      icon: Icons.live_tv,
      logoPath: '/bxBlRPEPpMVDc4jMhSrTf2339DW.jpg',
    ),
    StreamingProvider(
      id: 350,
      name: 'Apple TV',
      color: const Color(0xFF1F1F1F),
      icon: Icons.apple,
      logoPath: '/mcbz1LgtErU9p4UdbZ0rG6RTWHX.jpg',
    ),
    StreamingProvider(
      id: 1899,
      name: 'HBO Max',
      color: const Color(0xFF542DBF),
      icon: Icons.hd,
      logoPath: '/jbe4gVSfRlbPTdESXhEKpornsfu.jpg',
    ),
    StreamingProvider(
      id: 386,
      name: 'Peacock',
      color: const Color(0xFF1B365D),
      icon: Icons.tv,
      logoPath: '/2aGrp1xw3qhwCYvNGAJZPdjfeeX.jpg',
    ),
    StreamingProvider(
      id: 582,
      name: 'Paramount+',
      color: const Color(0xFF0064FF),
      icon: Icons.live_tv_sharp,
      logoPath: '/5qda0qKT6I1tm5EUOlw3YqQ5w.jpg',
    ),
    StreamingProvider(
      id: 526,
      name: 'AMC+',
      color: const Color(0xFF1A1A1A),
      icon: Icons.theaters,
      logoPath: '/ovmu6uot1XVvsemM2dDySXLiX57.jpg',
    ),
  ];

  late Map<int, bool> providerPreferences;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    providerPreferences = {};
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    setState(() => isLoading = true);
    try {
      await DBHelper.initializeProviderPreferences();
      final prefs = await DBHelper.getProviderPreferences();

      setState(() {
        for (var pref in prefs) {
          providerPreferences[pref['providerId'] as int] =
              (pref['isPreferred'] as int) == 1;
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading preferences: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _toggleProviderPreference(int providerId, bool value) async {
    try {
      await DBHelper.setProviderPreference(providerId, value);
      setState(() {
        providerPreferences[providerId] = value;
      });

      // Kick off a check for this provider right away so the user gets
      // new-release notifications shortly after enabling it.
      if (value) {
        ContentNotificationService.checkAndNotifyNewContent(
          onlyProviderId: providerId,
        );
      }

      // Show confirmation
      final provider = providers.firstWhere((p) => p.id == providerId);
      final message = value
          ? '${provider.name} added to favorites'
          : '${provider.name} removed from favorites';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: value ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error updating preference: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error updating preference'),
            backgroundColor: Colors.red,
          ),
        );
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
          'Streaming Services',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Your Favorite Providers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Get notified when new content arrives on your favorite streaming services',
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ...List.generate(providers.length, (index) {
                      final provider = providers[index];
                      final isSelected =
                          providerPreferences[provider.id] ?? false;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildProviderCard(
                          provider: provider,
                          isSelected: isSelected,
                          onChanged: (value) {
                            _toggleProviderPreference(provider.id, value);
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProviderCard({
    required StreamingProvider provider,
    required bool isSelected,
    required Function(bool) onChanged,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!isSelected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: provider.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: provider.color.withValues(alpha: 0.5),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: isSelected ? 3 : 2,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: provider.logoPath != null
                  ? AppNetworkImage(
                      url: 'https://image.tmdb.org/t/p/w92${provider.logoPath}',
                      fit: BoxFit.contain,
                      errorWidget: Center(
                        child: Text(
                          provider.name.substring(0, 1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        provider.name.substring(0, 1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSelected
                        ? 'Notifications enabled'
                        : 'Tap to enable notifications',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isSelected,
              onChanged: onChanged,
              activeColor: Colors.white,
              activeTrackColor: Colors.white.withValues(alpha: 0.5),
              inactiveThumbColor: Colors.white.withValues(alpha: 0.7),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.blue[300], size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'About Notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• Receive instant notifications when new movies or series are added\n'
            '• Get alerts when content becomes available on your favorite services\n'
            '• Customize which providers you want to track\n'
            '• Never miss out on trending content',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
