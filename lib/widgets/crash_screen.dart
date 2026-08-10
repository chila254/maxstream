import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../services/logger_service.dart';

void installGlobalCrashHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    recordCrash(
      'FlutterError',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    recordCrash('PlatformDispatcher', error, stack);
    return true;
  };
}

class CrashInfo {
  const CrashInfo({
    required this.tag,
    required this.error,
    required this.stack,
    required this.time,
  });

  final String tag;
  final Object error;
  final StackTrace stack;
  final DateTime time;
}

final ValueNotifier<CrashInfo?> crashReport = ValueNotifier<CrashInfo?>(null);

Future<void> recordCrash(String tag, Object error, StackTrace stack) async {
  final time = DateTime.now();
  LoggerService.error('[$tag] $error', error, stack);
  unawaited(_appendCrashLog('[$time] [$tag] $error\n$stack\n'));
  if (crashReport.value == null) {
    crashReport.value = CrashInfo(tag: tag, error: error, stack: stack, time: time);
  }
}

Future<File?> _crashLogFile() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/maxstream_crash.log');
  } catch (_) {
    return null;
  }
}

Future<void> _appendCrashLog(String line) async {
  try {
    final file = await _crashLogFile();
    await file?.writeAsString(line, mode: FileMode.append);
  } catch (_) {
    // Logging must never crash the app.
  }
}

Future<void> restartApp() async {
  const channel = MethodChannel('com.maxstream.app/restart');
  try {
    await channel.invokeMethod<void>('restartApp');
  } catch (_) {
    await SystemNavigator.pop();
  }
}

class CrashReportGate extends StatelessWidget {
  const CrashReportGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CrashInfo?>(
      valueListenable: crashReport,
      builder: (context, report, _) {
        if (report == null) return child;
        return CrashScreen(report: report);
      },
    );
  }
}

class CrashScreen extends StatelessWidget {
  const CrashScreen({super.key, required this.report});

  final CrashInfo report;

  /// First app-owned frame in the stack, e.g.
  /// `lib/tv/screens/tv_search_screen.dart:74  TvSearchScreenState.dispose`.
  /// Null-able formatting in a tiny box so the report names the widget/screen
  /// that crashed instead of burying it in the long stack below.
  String? get _origin {
    final frames = report.stack.toString().split('\n');
    for (final frame in frames) {
      final app = RegExp(r'package:maxstream/([^\s]+)').firstMatch(frame);
      if (app == null) continue;
      final symbol = frame.trim().split(' (')[0];
      return '${app.group(1)}${symbol.isNotEmpty ? '  $symbol' : ''}';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final summary = '${report.tag}: ${report.error}';
    final shortSummary = summary.length > 180
        ? '${summary.substring(0, 177)}...'
        : summary;
    return MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${report.time}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      shortSummary,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  if (_origin != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0x33FF5252),
                        border: Border.all(color: const Color(0x66FF5252)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Crashed in: $_origin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SizedBox(
                        height: 240,
                        child: SingleChildScrollView(
                          child: Text(
                            report.stack.toString(),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: () => SystemNavigator.pop(),
                              icon: const Icon(Icons.close),
                              label: const Text('Exit'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white38),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: SizedBox(
                            height: 56,
                            child: FilledButton.icon(
                              autofocus: true,
                              onPressed: () => unawaited(restartApp()),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Restart app'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}