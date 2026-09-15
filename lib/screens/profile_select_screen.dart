import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../services/profile_scope.dart';
import '../services/profile_service.dart';
import 'maxstream_main_screen.dart';
import 'profile_create_screen.dart';

class ProfileSelectScreen extends StatefulWidget {
  /// When true (default), auto-selects single profiles and navigates to
  /// MaxStreamMainScreen. When false (profile switcher mode), just pops
  /// with the selected profile ID.
  final bool isLaunchScreen;

  const ProfileSelectScreen({super.key, this.isLaunchScreen = true});

  @override
  State<ProfileSelectScreen> createState() => _ProfileSelectScreenState();
}

class _ProfileSelectScreenState extends State<ProfileSelectScreen> {
  List<Profile> _profiles = [];
  bool _isLoading = true;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    await ProfileScope.initialize();
    final profiles = ProfileScope.profiles.value;
    if (!mounted) return;

    setState(() {
      _profiles = profiles;
      _isLoading = false;
    });

    // Launch screen: auto-select single profile
    if (widget.isLaunchScreen && profiles.length == 1 && !_navigated) {
      _navigated = true;
      await ProfileScope.selectProfile(profiles.first.id);
      _goToMain();
    }
  }

  void _goToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MaxStreamMainScreen()),
    );
  }

  void _selectProfile(Profile profile) async {
    await ProfileScope.selectProfile(profile.id);
    if (widget.isLaunchScreen) {
      _goToMain();
    } else {
      // Switcher mode: just pop back
      if (mounted) Navigator.pop(context);
    }
  }

  void _editProfile(Profile profile) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileCreateScreen(editProfile: profile),
      ),
    );
    if (result == true) {
      await ProfileScope.refresh();
      setState(() => _profiles = ProfileScope.profiles.value);
    }
  }

  void _addProfile() async {
    if (_profiles.length >= ProfileService.maxProfiles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${ProfileService.maxProfiles} profiles allowed.'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ProfileCreateScreen()),
    );
    if (result == true) {
      await ProfileScope.refresh();
      setState(() => _profiles = ProfileScope.profiles.value);
    }
  }

  void _deleteProfile(Profile profile) async {
    if (_profiles.length <= 1) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text(
          'Delete ${profile.name}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'This will remove the profile and its watch progress.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ProfileService.deleteProfile(profile.id);
      await ProfileScope.refresh();
      setState(() => _profiles = ProfileScope.profiles.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Image.asset(
              'assets/images/maxstream_logo.png',
              width: 80,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.play_circle_fill,
                size: 80,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Who's watching?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 40),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.red),
                    )
                  : _buildProfileGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 24,
                crossAxisSpacing: 24,
                childAspectRatio: 0.85,
              ),
              itemCount: _profiles.length + 1,
              itemBuilder: (context, index) {
                if (index < _profiles.length) {
                  return _buildProfileCard(_profiles[index]);
                }
                return _buildAddProfileCard();
              },
            ),
          ),
          if (_profiles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Text(
                'Tap a profile to start watching',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileCard(Profile profile) {
    final avatarColor = profile.avatar.color;
    final avatarIcon = profile.avatar.icon;

    return GestureDetector(
      onTap: () => _selectProfile(profile),
      onLongPress: () => _showProfileOptions(profile),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Material 3 avatar circle
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
              boxShadow: [
                BoxShadow(
                  color: avatarColor.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              avatarIcon,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            profile.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (profile.isKids)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'KIDS',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddProfileCard() {
    return GestureDetector(
      onTap: _addProfile,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
                width: 2,
              ),
              color: Colors.white.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.add,
              color: Colors.white.withValues(alpha: 0.5),
              size: 40,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add Profile',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showProfileOptions(Profile profile) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit Profile',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _editProfile(profile);
              },
            ),
            if (_profiles.length > 1)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Profile',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteProfile(profile);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.white54),
              title: const Text('Cancel',
                  style: TextStyle(color: Colors.white54)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}
