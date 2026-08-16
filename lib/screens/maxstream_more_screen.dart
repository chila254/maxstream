import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../screens/sign_in_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../screens/watch_history_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/streaming_provider_settings_screen.dart';
import '../screens/tv_pairing_screen.dart';

import '../widgets/profile_avatar.dart';

class MaxStreamMoreScreen extends StatefulWidget {
  const MaxStreamMoreScreen({super.key});

  @override
  State<MaxStreamMoreScreen> createState() => _MaxStreamMoreScreenState();
}

class _MaxStreamMoreScreenState extends State<MaxStreamMoreScreen> {
  String _userName = 'MaxStream User';
  String _userEmail = 'user@maxstream.app';
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _userService.loadAvatar();
    _userService.loadProfilePicture();
  }

  void _loadUserInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _userName = user.displayName ?? 'MaxStream User';
        _userEmail = user.email ?? 'user@maxstream.app';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'More',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUserSection(),
            const SizedBox(height: 20),
            _buildMenuItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ProfileAvatar(size: 80, userService: _userService),
          const SizedBox(height: 12),
          Text(
            _userName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_userEmail.isNotEmpty)
            Text(
              _userEmail,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children: [
        _buildMenuItem(
          icon: Icons.person,
          title: 'Profile Settings',
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const ProfileSettingsScreen(),
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
            // No need to check result, ValueListenableBuilder will handle the update
          },
        ),
        _buildMenuItem(
          icon: Icons.history,
          title: 'Watch History',
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WatchHistoryScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.download_for_offline_outlined,
          title: 'Downloads',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DownloadsScreen()),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.tv,
          title: 'Streaming Services',
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StreamingProviderSettingsScreen(),
              ),
            );
          },
        ),
        _buildMenuItem(
          icon: Icons.tv_outlined,
          title: 'TV Pairing',
          onTap: () {
            if (!mounted) return;
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const TVPairingScreen(),
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
        ),
        _buildMenuItem(
          icon: Icons.help,
          title: 'Help & Support',
          onTap: () {
            _showHelpDialog();
          },
        ),
        _buildMenuItem(
          icon: Icons.info,
          title: 'About MaxStream',
          onTap: () {
            _showAboutDialog();
          },
        ),
        _buildMenuItem(
          icon: Icons.telegram,
          title: 'Join Community',
          onTap: () {
            _launchUrl('https://t.me/maxstream254');
          },
        ),
        const SizedBox(height: 20),
        _buildMenuItem(
          icon: Icons.logout,
          title: 'Sign Out',
          onTap: () {
            _signOut();
          },
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white),
        title: Text(
          title,
          style: TextStyle(
            color: isDestructive ? Colors.red : Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey,
          size: 16,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: Colors.transparent,
        hoverColor: Colors.white.withAlpha(12),
        splashColor: Colors.white.withAlpha(25),
      ),
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Help & Support',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'For help and support, please join our community or contact us through the app.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'About MaxStream',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MaxStream v1.1.0',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'A modern movie and TV discovery app powered by The Movie Database (TMDb).',
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              'Discover, explore, and manage your watchlist with ease.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.signOut();
                if (mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
