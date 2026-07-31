import 'package:flutter_test/flutter_test.dart';
import 'package:maxstream/services/media_download_service.dart';
import 'package:maxstream/services/stream_security.dart';

void main() {
  group('StreamSecurity URLs', () {
    test('allows public HTTP and HTTPS only', () {
      expect(
        StreamSecurity.isSafeNetworkUrl('https://cdn.example/video.m3u8'),
        isTrue,
      );
      expect(
        StreamSecurity.isSafeNetworkUrl('http://cdn.example/video.mp4'),
        isTrue,
      );
      for (final url in [
        'file:///tmp/video',
        'data:text/plain,x',
        'https://user:pass@example.com/x',
        'http://localhost/x',
        'http://127.0.0.1/x',
        'http://169.254.1.2/x',
        'http://10.1.2.3/x',
        'http://172.31.2.3/x',
        'http://192.168.1.2/x',
        'http://[::1]/x',
        'http://[fd00::1]/x',
        'http://[fe80::1]/x',
      ]) {
        expect(StreamSecurity.isSafeNetworkUrl(url), isFalse, reason: url);
      }
    });

    test('resolves and validates resource URLs', () {
      final base = Uri.parse('https://media.example/path/list.m3u8');
      expect(
        StreamSecurity.safeNetworkUri('../segment.ts', base: base)?.toString(),
        'https://media.example/segment.ts',
      );
      expect(
        StreamSecurity.safeNetworkUri('//127.0.0.1/x', base: base),
        isNull,
      );
    });
  });

  test('headers are case-insensitively allowlisted and injection-safe', () {
    final headers = StreamSecurity.sanitizeHeaders({
      'user-agent': 'player',
      'REFERER': 'https://example.com/',
      'Authorization': 'secret',
      'Cookie': 'safe=value',
      'Origin': 'ok\r\nX-Evil: yes',
    });
    expect(headers, {
      'user-agent': 'player',
      'REFERER': 'https://example.com/',
      'Cookie': 'safe=value',
    });
  });

  test('download defaults enforce requested limits', () {
    expect(
      MediaDownloadService.defaultMaxDownloadBytes,
      8 * 1024 * 1024 * 1024,
    );
    expect(MediaDownloadService.defaultMaxHlsResources, 20000);
    expect(MediaDownloadService.defaultMaxHlsResourceBytes, 32 * 1024 * 1024);
    expect(MediaDownloadService.defaultMaxPlaylistBytes, 2 * 1024 * 1024);
  });
}
