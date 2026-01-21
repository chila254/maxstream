import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/user_service.dart';
import '../../services/auth_service.dart';
import '../utils/tv_utils.dart';
import '../utils/tv_typography.dart';
import '../utils/tv_dpad_navigation_mixin.dart';
import '../../widgets/profile_avatar.dart';
import '../widgets/tv_focus_widget.dart';

class TvMoreScreen extends StatefulWidget {
  final VoidCallback? onReturnToSidebar;

  const TvMoreScreen({super.key, this.onReturnToSidebar});

  @override
  State<TvMoreScreen> createState() => _TvMoreScreenState();
}

class _TvMoreScreenState extends State<TvMoreScreen> with TvDpadNavigationMixin {
  String _userName = 'MaxStream User';
  String _userEmail = 'user@maxstream.app';
  final UserService _userService = UserService();
  int? _focusedMenuItemIndex;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _userService.loadAvatar();
    _userService.loadProfilePicture();
  }

  void _handleMenuItemTap(String item) {
    switch (item) {
      case 'Help':
        _showHelpDialog();
        break;
      case 'About':
        _showAboutDialog();
        break;
      case 'Community':
        _launchUrl('https://t.me/maxstream254');
        break;
      case 'Sign Out':
        _signOut();
        break;
    }
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

  // D-Pad Navigation Implementation
  @override
  int get maxFocusIndex => 3; // Help, About, Community, Sign Out

  @override
  void onFocusChanged(int index) {
    setState(() => _focusedMenuItemIndex = index);
  }

  @override
  void onSelectPressed() {
    final menuItems = ['Help', 'About', 'Community', 'Sign Out'];
    if (_focusedMenuItemIndex != null && _focusedMenuItemIndex! < menuItems.length) {
      _handleMenuItemTap(menuItems[_focusedMenuItemIndex!]);
    }
  }

  @override
  void onLeftPressed() {
    // Return to sidebar
    if (widget.onReturnToSidebar != null) {
      widget.onReturnToSidebar!();
    }
  }

  @override
  void onRightPressed() {}

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      onKey: handleKeyEvent,
      focusNode: focusNode,
      child: Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
           'More',
           style: TvTypography.sectionTitle,
         ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildUserSection(),
            SizedBox(height: TvUtils.responsivePadding(32, context)),
            _buildMenuItems(),
            SizedBox(height: TvUtils.responsivePadding(32, context)),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildUserSection() {
    final padding = TvUtils.responsivePadding(24, context);

    return Container(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          ProfileAvatar(
            size: TvUtils.responsiveFontSize(120, context, maxSize: 160),
            userService: _userService,
          ),
          SizedBox(height: TvUtils.responsivePadding(16, context)),
          Text(
            _userName,
            style: TvTypography.subsectionTitle,
          ),
          if (_userEmail.isNotEmpty)
            Text(
              _userEmail,
              style: TvTypography.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    return Column(
      children: [
        TvMenuItem(
          isFocused: _focusedMenuItemIndex == 0,
          onTap: () => _showHelpDialog(),
          child: _buildMenuItem(
            icon: Icons.help,
            title: 'Help & Support',
            onTap: () {
              _showHelpDialog();
            },
          ),
        ),
        TvMenuItem(
          isFocused: _focusedMenuItemIndex == 1,
          onTap: () => _showAboutDialog(),
          child: _buildMenuItem(
            icon: Icons.info,
            title: 'About MaxStream',
            onTap: () {
              _showAboutDialog();
            },
          ),
        ),
        TvMenuItem(
          isFocused: _focusedMenuItemIndex == 2,
          onTap: () => _launchUrl('https://t.me/maxstream254'),
          child: _buildMenuItem(
            icon: Icons.telegram,
            title: 'Join Community',
            onTap: () {
              _launchUrl('https://t.me/maxstream254');
            },
          ),
        ),
        SizedBox(height: TvUtils.responsivePadding(24, context)),
        TvMenuItem(
          isFocused: _focusedMenuItemIndex == 3,
          onTap: () => _signOut(),
          child: _buildMenuItem(
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: () {
              _signOut();
            },
            isDestructive: true,
          ),
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
    final padding = TvUtils.responsivePadding(16, context);
    final fontSize = TvUtils.responsiveFontSize(18, context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: TvUtils.responsivePadding(12, context),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ListTile(
          leading: Icon(
            icon,
            color: isDestructive ? Colors.red : Colors.white,
            size: TvUtils.responsiveFontSize(28, context),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: fontSize,
            ),
          ),
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: Colors.grey,
            size: TvUtils.responsiveFontSize(20, context),
          ),
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          tileColor: Colors.grey[900],
          hoverColor: Colors.white.withAlpha(12),
          splashColor: Colors.white.withAlpha(25),
          minLeadingWidth: 24,
        ),
      ),
    );
  }

  void _showHelpDialog() {
    final fontSize = TvUtils.responsiveFontSize(18, context);
    final titleFontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Help & Support',
          style: TextStyle(color: Colors.white, fontSize: titleFontSize),
        ),
        content: Text(
          'For help and support, please join our community or contact us through the app.',
          style: TextStyle(color: Colors.white, fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.red, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    final fontSize = TvUtils.responsiveFontSize(16, context);
    final titleFontSize = TvUtils.responsiveFontSize(20, context, maxSize: 28);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'About MaxStream',
          style: TextStyle(color: Colors.white, fontSize: titleFontSize),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MaxStream v1.1.0',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: fontSize,
              ),
            ),
            SizedBox(height: TvUtils.responsivePadding(12, context)),
            Text(
              'A modern movie and TV discovery app powered by The Movie Database (TMDb).',
              style: TextStyle(color: Colors.white, fontSize: fontSize),
            ),
            SizedBox(height: TvUtils.responsivePadding(12, context)),
            Text(
              'Discover, explore, and manage your watchlist with ease.',
              style: TextStyle(color: Colors.grey, fontSize: fontSize),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.red, fontSize: fontSize),
            ),
          ),
        ],
      ),
    );
  }

  void _signOut() async {
    final fontSize = TvUtils.responsiveFontSize(18, context);
    final titleFontSize = TvUtils.responsiveFontSize(22, context, maxSize: 28);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Sign Out',
          style: TextStyle(color: Colors.white, fontSize: titleFontSize),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Colors.white, fontSize: fontSize),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: fontSize),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await AuthService.signOut();
                // AuthGate will handle navigation when auth state changes
                if (mounted) {
                  Navigator.of(context).pop();
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
            child: Text(
              'Sign Out',
              style: TextStyle(color: Colors.red, fontSize: fontSize),
            ),
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
