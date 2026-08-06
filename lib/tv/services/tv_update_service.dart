import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TvUpdateInfo {
  final String downloadUrl;
  final String version;
  final String changelog;

  const TvUpdateInfo({
    required this.downloadUrl,
    required this.version,
    this.changelog = '',
  });
}

/// TV-styled "update available" dialog with D-pad friendly actions.
class TvUpdateDialog extends StatelessWidget {
  final TvUpdateInfo info;
  final VoidCallback onDownload;

  const TvUpdateDialog({
    super.key,
    required this.info,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final changelog = info.changelog.trim();
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      title: const Text(
        'Update available',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MaxStream TV v${info.version} is available. '
              'Download and install it now?',
              style: const TextStyle(color: Colors.white70, fontSize: 18),
            ),
            if (changelog.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                "What's new:",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    changelog,
                    style: const TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Later',
            style: TextStyle(color: Colors.grey, fontSize: 18),
          ),
        ),
        FilledButton(
          autofocus: true,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE50914),
          ),
          onPressed: onDownload,
          child: const Text(
            'Download Now',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class TvDownloadProgressDialog extends StatefulWidget {
  const TvDownloadProgressDialog({super.key});

  @override
  State<TvDownloadProgressDialog> createState() =>
      _TvDownloadProgressDialogState();
}

class _TvDownloadProgressDialogState extends State<TvDownloadProgressDialog> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    TvUpdateService._progressDialogState = this;
  }

  void updateProgress(double progress) {
    if (mounted) {
      setState(() => _progress = progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Downloading update…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 460,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 10,
                  backgroundColor: Colors.white24,
                  color: const Color(0xFFE50914),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$percent%',
              style: const TextStyle(color: Colors.white70, fontSize: 19),
            ),
          ],
        ),
      ),
    );
  }
}

class TvUpdateService {
  static const String githubOwner = 'chila254';
  static const String githubRepo = 'maxstream';
  static const String latestReleaseUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const String _apkFileName = 'MaxStream-Tv.apk';

  static _TvDownloadProgressDialogState? _progressDialogState;
  static Future<TvUpdateInfo?>? _inFlightCheck;
  static final Set<String> _shownDialogVersions = {};

  /// Check GitHub for a newer MaxStream TV build. Returns update info if one
  /// exists, otherwise null.
  static Future<TvUpdateInfo?> checkForUpdate() async {
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

  static Future<TvUpdateInfo?> _performUpdateCheck() async {
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

      // The TV APK is published as MaxStream-Tv.apk.
      final assets = response.data['assets'] as List<dynamic>? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk') && name.contains('maxstream-tv')) {
          return TvUpdateInfo(
            downloadUrl: asset['browser_download_url'] as String,
            version: latestVersion,
            changelog: changelog,
          );
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error checking for TV update: $e');
      return null;
    }
  }

  /// Marks a dialog version as shown. Returns false if it was already shown
  /// this session so the dialog is not presented twice.
  static bool reserveUpdateDialog(String version) =>
      _shownDialogVersions.add(version);

  /// Download and install the TV APK from the given GitHub URL. The screen is
  /// kept awake for the whole download.
  static Future<void> downloadAndInstallUpdate(
    BuildContext context,
    String downloadUrl,
  ) async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        throw StateError('App storage is unavailable');
      }
      final filePath = '${directory.path}/$_apkFileName';

      await WakelockPlus.enable();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const TvDownloadProgressDialog(),
        );
      }

      await Dio().download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            _progressDialogState?.updateProgress(received / total);
          }
        },
      );

      await WakelockPlus.disable();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E1E),
            title: const Text(
              'Download Complete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: const Text(
              'The update has been downloaded. Install it now?',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Later',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ),
              FilledButton(
                autofocus: true,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  final result = await OpenFile.open(filePath);
                  if (result.type != ResultType.done && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to install the update.'),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Install',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      await WakelockPlus.disable();
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
    } catch (_) {
      return false;
    }
  }
}
