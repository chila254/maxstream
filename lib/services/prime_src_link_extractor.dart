import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

const String _desktopUA =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

/// Hidden WebView that loads PrimeSrc link endpoint, solves Cloudflare,
/// and extracts the actual provider URL from the JSON response.
class PrimeSrcLinkExtractor extends StatefulWidget {
  final String apiKey;
  final Duration timeout;
  final void Function(String link) onResolved;
  final void Function(Object error)? onError;

  const PrimeSrcLinkExtractor({
    super.key,
    required this.apiKey,
    required this.onResolved,
    this.onError,
    this.timeout = const Duration(seconds: 20),
  });

  @override
  State<PrimeSrcLinkExtractor> createState() => _PrimeSrcLinkExtractorState();
}

class _PrimeSrcLinkExtractorState extends State<PrimeSrcLinkExtractor> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.timeout, _onTimeout);
  }

  void _onTimeout() {
    if (!_done && mounted) {
      _done = true;
      widget.onError?.call(TimeoutException('PrimeSrc link resolution timed out'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: true,
      child: SizedBox(
        width: 1,
        height: 1,
        child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri('https://primesrc.me/api/v1/l?key=${widget.apiKey}'),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            userAgent: _desktopUA,
            cacheEnabled: false,
          ),
          shouldInterceptRequest: (controller, request) async {
            final url = request.url.toString();
            if (_done) return null;

            // Check if the response is JSON with a "link" field
            if (url.contains('/api/v1/l') || url.contains('primesrc.me')) {
              try {
                final dio = Dio();
                final resp = await dio.get<dynamic>(
                  url,
                  options: Options(
                    headers: {
                      'User-Agent': _desktopUA,
                      'Accept': 'application/json',
                      'Referer': 'https://primesrc.me/',
                    },
                    responseType: ResponseType.json,
                  ),
                );

                if (resp.statusCode == 200 && resp.data is Map) {
                  final link = resp.data['link']?.toString();
                  if (link != null && link.isNotEmpty && !_done) {
                    _done = true;
                    widget.onResolved(link);
                    controller.stopLoading();
                  }
                }
              } catch (_) {}
            }
            return null;
          },
          onLoadStop: (controller, url) async {
            if (_done) return;

            // Try to extract JSON from the page
            try {
              final result = await controller.evaluateJavascript(
                source: '''
                (function() {
                  try {
                    var text = document.body.innerText || document.body.textContent || '';
                    var data = JSON.parse(text);
                    if (data && data.link) {
                      return data.link;
                    }
                  } catch(e) {}
                  return null;
                })();
                ''',
              );

              if (result != null && result != 'null' && result.isNotEmpty && !_done) {
                _done = true;
                widget.onResolved(result.toString());
              }
            } catch (_) {}
          },
        ),
      ),
    );
  }
}
