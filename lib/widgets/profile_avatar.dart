import 'package:flutter/material.dart';
import 'dart:io';
import '../services/user_service.dart';

class ProfileAvatar extends StatelessWidget {
  final double size;
  final UserService userService;
  final VoidCallback? onTap;

  const ProfileAvatar({
    super.key,
    this.size = 80,
    required this.userService,
    this.onTap,
  });

  bool _isNetworkUrl(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: userService.profilePictureUrl,
      builder: (context, profilePictureUrl, child) {
        return ValueListenableBuilder<String>(
          valueListenable: userService.avatar,
          builder: (context, selectedAvatar, child) {
            final hasProfilePicture = profilePictureUrl != null &&
                (profilePictureUrl.startsWith('http') ||
                    File(profilePictureUrl).existsSync());

            Widget imageWidget;
            if (hasProfilePicture) {
              if (_isNetworkUrl(profilePictureUrl)) {
                imageWidget = Image.network(
                  profilePictureUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(
                      selectedAvatar.isNotEmpty ? selectedAvatar : '🐰',
                      style: TextStyle(fontSize: size * 0.65),
                    ),
                  ),
                );
              } else {
                imageWidget = Image.file(
                  File(profilePictureUrl),
                  fit: BoxFit.cover,
                );
              }
            } else {
              imageWidget = Center(
                child: Text(
                  selectedAvatar.isNotEmpty ? selectedAvatar : '🐰',
                  style: TextStyle(fontSize: size * 0.65),
                ),
              );
            }

            final container = Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: ClipOval(child: imageWidget),
            );

            if (onTap != null) {
              return GestureDetector(
                onTap: onTap,
                child: container,
              );
            }

            return container;
          },
        );
      },
    );
  }
}
