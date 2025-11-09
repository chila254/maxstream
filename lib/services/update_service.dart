import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

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

  @override
  void dispose() {
    // Don't set to null here as it might be accessed after dispose
    super.dispose();
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
  static const String updateUrl = 'https://your-server.com/api/latest-version'; // Replace with your server URL
  static const String apkDownloadUrl = 'https://your-server.com/apk/maxstream-latest.apk'; // Replace with your APK URL

  static late _DownloadProgressDialogState _progressDialogState;

  static Future<bool> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await Dio().get(updateUrl);
      final latestVersion = response.data['version'] as String;

      return _isVersionNewer(currentVersion, latestVersion);
    } catch (e) {
      print('Error checking for update: $e');
      return false;
    }
  }

  static Future<void> downloadAndInstallUpdate(BuildContext context) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage permission is required to download updates')),
        );
        return;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      final filePath = '${directory!.path}/maxstream_update.apk';

      // Show download progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => DownloadProgressDialog(),
      );

      // Download APK
      await Dio().download(
        apkDownloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            // Update progress in dialog
            UpdateService._progressDialogState.updateProgress(progress);
          }
        },
      );

      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog

        // Show installation dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Download Complete'),
            content: const Text('The update has been downloaded. Installing now...'),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  // Install APK
                  final result = await OpenFile.open(filePath);
                  if (result.type != ResultType.done) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to install update. Please check your downloads folder.')),
                      );
                    }
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
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }

    return latestParts.length > currentParts.length;
  }
}