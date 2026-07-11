import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _desktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/// Headless extractor for resolving a direct VidLink playlist.
/// Loads the VidLink embed page in a hidden WebView and intercepts the
/// XHR to `/api/b/` which returns JSON with the direct HLS playlist.
class VidLinkExtractor extends StatefulWidget {
  final String embedUrl;
  final Duration timeout;
  final void Function(String playlistUrl, Map<String, String> headers)
      onExtracted;
  final void Function(Object error)? onError;

  const VidLinkExtractor({
    super.key,
    required this.embedUrl,
    required this.onExtracted,
    this.onError,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  State<VidLinkExtractor> createState() => _VidLinkExtractorState();
}

class _VidLinkExtractorState extends State<VidLinkExtractor> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.timeout, _onTimeout);
  }

  void _onTimeout() {
    if (!_done && mounted) {
      _done = true;
      widget.onError?.call(TimeoutException('VidLink extraction timed out'));
    }
  }

  Future<void> _handlePlaylist(String playlist) async {
    if (_done) return;
    _done = true;
    widget.onExtracted(playlist, {'Referer': 'https://vidlink.pro/'});
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(widget.embedUrl)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            userAgent: _desktopUserAgent,
            cacheEnabled: false,
          ),
          onWebViewCreated: (controller) {
            controller.addJavaScriptHandler(
              handlerName: 'onPlaylist',
              callback: (args) {
                final playlist = args.isNotEmpty ? args[0] : null;
                if (playlist is String && playlist.isNotEmpty) {
                  _handlePlaylist(playlist);
                }
              },
            );
          },
          shouldInterceptRequest: (controller, request) async {
            final url = request.url.toString();
            if (url.contains('/api/b/') && !_done) {
              try {
                final response = await Dio().get<dynamic>(
                  url,
                  options: Options(
                    headers: {'Referer': 'https://vidlink.pro/'},
                    responseType: ResponseType.json,
                  ),
                );
                final stream = response.data is Map
                    ? (response.data as Map)['stream']
                    : null;
                final playlist = stream is Map ? stream['playlist'] : null;
                if (playlist is String && playlist.isNotEmpty) {
                  await _handlePlaylist(playlist);
                  controller.stopLoading();
                }
              } catch (_) {}
            }
            return null;
          },
          onLoadStop: (controller, _) async {
            await controller.evaluateJavascript(
              source: '''
              (function() {
                if (window.__maxstreamHooked) return;
                window.__maxstreamHooked = true;
                const orig = window.fetch;
                window.fetch = async function(...args) {
                  const resp = await orig.apply(this, args);
                  try {
                    const url = resp.url || (args[0] && args[0].url) || '';
                    if (url.indexOf('/api/b/') !== -1) {
                      const clone = resp.clone();
                      clone.json().then(function(data) {
                        if (data && data.stream && data.stream.playlist) {
                          window.flutter_inappwebview.callHandler(
                            'onPlaylist',
                            data.stream.playlist
                          );
                        }
                      }).catch(function(){});
                    }
                  } catch (e) {}
                  return resp;
                };
              })();
            ''',
            );
          },
        ),
      ),
    );
  }
}
