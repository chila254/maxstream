import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'notification_service.dart';

class UpdateInfo {
  final String downloadUrl;
  final String version;
  final String changelog;

  const UpdateInfo({
    required this.downloadUrl,
    required this.version,
    this.changelog = '',
  });
}

class DownloadProgressDialog extends StatefulWidget {
  const DownloadProgressDialog({super.key});

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    UpdateService._progressDialogState = this;
  }

  void updateProgress(double progress) {
    if (mounted) {
      setState(() {
        _progress = progress;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Downloading update...'),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toStringAsFixed(0)}%'),
        ],
      ),
    );
  }
}

class UpdateService {
  static const String githubOwner = 'chila254';
  static const String githubRepo = 'maxstream';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';

  static _DownloadProgressDialogState? _progressDialogState;
  static bool _hasNotifiedCurrentVersion = false;

  /// Check GitHub for a newer release. Returns UpdateInfo if an update exists.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await Dio().get(
        latestReleaseUrl,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );

      final tagName = response.data['tag_name'] as String? ?? '';
      final latestVersion = tagName.replaceFirst('v', '');
      final changelog = response.data['body'] as String? ?? '';

      if (latestVersion.isEmpty) return null;
      if (!_isVersionNewer(currentVersion, latestVersion)) return null;

      // Find the MaxStream.apk asset
      final assets = response.data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = asset['name'] as String? ?? '';
        if (name.toLowerCase().contains('maxstream') && name.endsWith('.apk')) {
          return UpdateInfo(
            downloadUrl: asset['browser_download_url'] as String,
            version: latestVersion,
            changelog: changelog,
          );
        }
      }

      return null;
    } catch (e) {
      print('Error checking for update: $e');
      return null;
    }
  }

  /// Check for updates and show a local notification if one is found.
  static Future<void> checkAndNotify() async {
    if (_hasNotifiedCurrentVersion) return;

    final info = await checkForUpdate();
    if (info == null) return;

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final notificationService = NotificationService();
    await notificationService.showNotification(
      id: 9999,
      title: 'Update Available',
      body: 'MaxStream ${info.version} is available (current: $currentVersion). Tap to download.',
      payload: 'update:${info.downloadUrl}',
    );

    _hasNotifiedCurrentVersion = true;
  }

  /// Download and install the APK from the given GitHub URL.
  static Future<void> downloadAndInstallUpdate(
    BuildContext context,
    String downloadUrl,
  ) async {
    try {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Storage permission is required to download updates'),
            ),
          );
        }
        return;
      }

      final directory = await getExternalStorageDirectory();
      final filePath = '${directory!.path}/MaxStream.apk';

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const DownloadProgressDialog(),
        );
      }

      await Dio().download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _progressDialogState?.updateProgress(progress);
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Download Complete'),
            content: const Text('The update has been downloaded. Install now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  final result = await OpenFile.open(filePath);
                  if (result.type != ResultType.done && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to install. Check your downloads folder.'),
                      ),
                    );
                  }
                },
                child: const Text('Install'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading update: $e')),
        );
      }
    }
  }

  static bool _isVersionNewer(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return latestParts.length > currentParts.length;
    } catch (e) {
      return false;
    }
  }
}
