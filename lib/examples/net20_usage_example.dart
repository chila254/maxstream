import 'package:flutter/material.dart';
import '../services/net20_service.dart';

/// Example of how to use Net20Service in your app
class Net20UsageExample extends StatefulWidget {
  const Net20UsageExample({Key? key}) : super(key: key);

  @override
  State<Net20UsageExample> createState() => _Net20UsageExampleState();
}

class _Net20UsageExampleState extends State<Net20UsageExample> {
  bool _isLoading = false;
  Map<String, dynamic>? _videoData;
  String? _error;

  Future<void> _searchAndGetVideo() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _videoData = null;
    });

    try {
      // Search for content and get video URL in one call
      final result = await Net20Service.getVideoUrl(
        'Stranger Things',
        season: 5,
        episode: 1,
      );

      if (result != null) {
        setState(() {
          _videoData = result;
        });
      } else {
        setState(() {
          _error = 'Video not found';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Net20 Example')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchAndGetVideo,
                icon: const Icon(Icons.search),
                label: const Text('Search & Get Video'),
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null) ...[
                Text('Error:', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ] else if (_videoData != null) ...[
                Text(
                  'Video Found!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                _buildVideoInfo('Title', _videoData!['title']),
                _buildVideoInfo('Quality', _videoData!['quality']),
                _buildVideoInfo('Duration', '${_videoData!['duration']}s'),
                _buildVideoInfo('Type', _videoData!['type']),
                _buildVideoInfo('Source', _videoData!['source']),
                _buildVideoInfo('Playable', '${_videoData!['isPlayable']}'),
                const SizedBox(height: 16),
                Text(
                  'Video URL:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _videoData!['videoUrl'] ?? 'N/A',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoInfo(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value?.toString() ?? 'N/A')),
        ],
      ),
    );
  }
}
