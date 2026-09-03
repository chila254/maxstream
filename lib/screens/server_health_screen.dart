import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ServerStatus {
  final String name;
  final String domain;
  final bool? healthy;
  final String? error;
  final int? responseMs;

  const ServerStatus({
    required this.name,
    required this.domain,
    this.healthy,
    this.error,
    this.responseMs,
  });

  ServerStatus copyWith({bool? healthy, String? error, int? responseMs}) {
    return ServerStatus(
      name: name,
      domain: domain,
      healthy: healthy,
      error: error,
      responseMs: responseMs,
    );
  }
}

class ServerHealthScreen extends StatefulWidget {
  const ServerHealthScreen({super.key});

  @override
  State<ServerHealthScreen> createState() => _ServerHealthScreenState();
}

class _ServerHealthScreenState extends State<ServerHealthScreen> {
  final List<ServerStatus> _servers = const [
    ServerStatus(name: 'VixSrc', domain: 'vixsrc.to'),
    ServerStatus(name: 'VidLink', domain: 'vidlink.pro'),
    ServerStatus(name: '2Embed', domain: '2embed.cc'),
    ServerStatus(name: 'Videasy', domain: 'player.videasy.to'),
    ServerStatus(name: 'VidFast', domain: 'vidfast.vc'),
    ServerStatus(name: 'VidsrcRu', domain: 'vidsrc.ru'),
    ServerStatus(name: 'Moflix', domain: 'moflix-stream.xyz'),
    ServerStatus(name: 'Community', domain: 'streamingunity.dog'),
    ServerStatus(name: 'Vidrock', domain: 'vidrock.net'),
    ServerStatus(name: 'Vidzee', domain: 'vidzee.space'),
    ServerStatus(name: 'PrimeSrc', domain: 'primesrc.me'),
    ServerStatus(name: 'Frembed', domain: 'frembed.click'),
  ];

  List<ServerStatus> _results = [];
  bool _testing = false;
  bool _testComplete = false;

  @override
  void initState() {
    super.initState();
    _results = List.from(_servers);
  }

  Future<void> _testAllServers() async {
    if (_testing) return;
    setState(() {
      _testing = true;
      _testComplete = false;
      _results = _servers.map((s) => s.copyWith()).toList();
    });

    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 8);
    dio.options.receiveTimeout = const Duration(seconds: 8);

    // Test all servers in parallel
    final futures = <Future<void>>[];
    for (int i = 0; i < _results.length; i++) {
      futures.add(_testServer(dio, i));
    }
    await Future.wait(futures);

    dio.close();
    if (mounted) {
      setState(() {
        _testing = false;
        _testComplete = true;
      });
    }
  }

  Future<void> _testServer(Dio dio, int index) async {
    final server = _results[index];
    final url = 'https://${server.domain}';
    final sw = Stopwatch()..start();
    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          followRedirects: true,
        ),
      );
      sw.stop();
      if (mounted) {
        setState(() {
          _results[index] = server.copyWith(
            healthy: response.statusCode != null && response.statusCode! < 500,
            responseMs: sw.elapsedMilliseconds,
          );
        });
      }
    } on DioException catch (e) {
      sw.stop();
      // Connection errors (timeout, DNS, etc.) count as unhealthy
      // But 4xx responses from CDN protection are common and count as healthy
      final isHealthy = e.response?.statusCode != null && e.response!.statusCode! < 500;
      if (mounted) {
        setState(() {
          _results[index] = server.copyWith(
            healthy: isHealthy,
            error: isHealthy ? null : (e.message ?? 'Connection failed'),
            responseMs: sw.elapsedMilliseconds,
          );
        });
      }
    } catch (e) {
      sw.stop();
      if (mounted) {
        setState(() {
          _results[index] = server.copyWith(
            healthy: false,
            error: e.toString(),
            responseMs: sw.elapsedMilliseconds,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final healthyCount = _results.where((s) => s.healthy == true).length;
    final unhealthyCount = _results.where((s) => s.healthy == false).length;
    final pendingCount = _results.where((s) => s.healthy == null).length;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'Server Health',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_testing)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _testAllServers,
            ),
        ],
      ),
      body: Column(
        children: [
          // Summary card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Healthy', healthyCount, Colors.green),
                _buildSummaryItem('Unhealthy', unhealthyCount, Colors.red),
                _buildSummaryItem('Unknown', pendingCount, Colors.grey),
              ],
            ),
          ),
          // Server list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final server = _results[index];
                return _buildServerCard(server);
              },
            ),
          ),
          // Test button
          if (!_testComplete && !_testing)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _testAllServers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Test All Servers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildServerCard(ServerStatus server) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (server.healthy == true) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = server.responseMs != null ? '${server.responseMs}ms' : 'OK';
    } else if (server.healthy == false) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = server.error ?? 'Failed';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
      statusText = 'Not tested';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  server.domain,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
