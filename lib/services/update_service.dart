import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
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
  static String? _notifiedVersion;
  static Future<UpdateInfo?>? _inFlightCheck;
  static final Set<String> _shownDialogVersions = {};

  /// Check GitHub for a newer release. Returns UpdateInfo if an update exists.
  static Future<UpdateInfo?> checkForUpdate() async {
    final existing = _inFlightCheck;
    if (existing != null) return existing;
    final check = _performUpdateCheck();
    _inFlightCheck = check;
    try {
      return await check;
    } finally {
      if (identical(_inFlightCheck, check)) _inFlightCheck = null;
    }
  }

  static Future<UpdateInfo?> _performUpdateCheck() async {
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

      // Find the MaxStream.apk asset (never the TV variant).
      final assets = response.data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk') &&
            name.contains('maxstream') &&
            !name.contains('-tv')) {
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
  static Future<void> checkAndNotify({UpdateInfo? info}) async {
    final availableUpdate = info ?? await checkForUpdate();
    if (availableUpdate == null) return;
    if (_notifiedVersion == availableUpdate.version) return;
    _notifiedVersion = availableUpdate.version;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final notificationService = NotificationService();
      await notificationService.showNotification(
        id: 9999,
        title: 'Update Available',
        body:
            'MaxStream ${availableUpdate.version} is available (current: $currentVersion). Tap to download.',
        payload: 'update:${availableUpdate.downloadUrl}',
      );
    } catch (_) {
      if (_notifiedVersion == availableUpdate.version) _notifiedVersion = null;
      rethrow;
    }
  }

  static bool reserveUpdateDialog(String version) =>
      _shownDialogVersions.add(version);

  /// Download and install the APK from the given GitHub URL.
  static Future<void> downloadAndInstallUpdate(
    BuildContext context,
    String downloadUrl,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/MaxStream.apk';

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const DownloadProgressDialog(),
        );
      }

      final file = File(filePath);
      if (await file.exists()) await file.delete();

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

      final downloadedFile = File(filePath);
      final fileSize = await downloadedFile.length();
      if (fileSize < 1000) {
        throw StateError('Downloaded file is too small — likely an error page');
      }

      if (context.mounted) {
        Navigator.of(context).pop();

        final packageInfo = await PackageInfo.fromPlatform();
        final result = await const MethodChannel(
          'com.maxstream.app/install',
        ).invokeMethod<String>('installApk', {
          'filePath': filePath,
          'packageName': packageInfo.packageName,
        });

        if (result != 'ok' && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Failed to launch installer. Check your downloads folder.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
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
