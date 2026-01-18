import 'package:flutter/material.dart';
import '../database/db_helper.dart';

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
      onTap: () => onChanged(!isSelected),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              provider.color.withValues(alpha: 0.2),
              provider.color.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? provider.color
                : Colors.grey[700]!.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: provider.color.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(provider.icon, color: provider.color, size: 28),
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
                        ? 'You\'ll get notifications for this service'
                        : 'Tap to enable notifications',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? provider.color : Colors.grey[700],
              ),
              padding: const EdgeInsets.all(2),
              child: Checkbox(
                value: isSelected,
                onChanged: (value) => onChanged(value ?? false),
                activeColor: provider.color,
                checkColor: Colors.white,
                side: BorderSide.none,
              ),
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
