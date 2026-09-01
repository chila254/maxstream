import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie.dart';
import '../services/tmdb_api_service.dart';
import 'maxstream_details_screen.dart';
import 'maxstream_series_screen.dart';
import '../widgets/app_network_image.dart';

class ActorDetailsScreen extends StatefulWidget {
  final int actorId;

  const ActorDetailsScreen({super.key, required this.actorId});

  @override
  State<ActorDetailsScreen> createState() => _ActorDetailsScreenState();
}

class _ActorDetailsScreenState extends State<ActorDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  Map<String, dynamic>? actorDetails;
  List<Map<String, dynamic>> movieCredits = [];
  List<Map<String, dynamic>> tvCredits = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadActorDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadActorDetails() async {
    setState(() => isLoading = true);

    try {
      final details = await TmdbApiService.getActorDetails(widget.actorId);
      if (details != null) {
        setState(() {
          actorDetails = details;
          movieCredits = List<Map<String, dynamic>>.from(
            details['movie_credits']?['cast'] ?? [],
          );
          tvCredits = List<Map<String, dynamic>>.from(
            details['tv_credits']?['cast'] ?? [],
          );
        });

        // Sort credits by popularity/release date
        movieCredits.sort((a, b) {
          final dateA = a['release_date'] ?? '';
          final dateB = b['release_date'] ?? '';
          return dateB.compareTo(dateA);
        });

        tvCredits.sort((a, b) {
          final dateA = a['first_air_date'] ?? '';
          final dateB = b['first_air_date'] ?? '';
          return dateB.compareTo(dateA);
        });
      }
    } catch (e) {
      // Error loading additional credits, continue with what we have
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _launchInstagram() async {
    final externalIds = actorDetails?['external_ids'];
    final instagramId = externalIds?['instagram_id'];

    if (instagramId != null) {
      final url = Uri.parse('https://instagram.com/$instagramId');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Actor Details',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.red)),
      );
    }

    if (actorDetails == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text(
            'Actor Details',
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: const Center(
          child: Text(
            'Failed to load actor details',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(children: [_buildActorInfo(), _buildTabBar()]),
          ),
          _buildTabBarView(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final profilePath = actorDetails?['profile_path'];
    final name = actorDetails?['name'] ?? 'Unknown Actor';

    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (profilePath != null)
              AppNetworkImage(
                url: TmdbApiService.getFullImageUrl(profilePath),
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.person,
                    size: 100,
                    color: Colors.grey,
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[900],
                child: const Icon(Icons.person, size: 100, color: Colors.grey),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha((255 * 0.8).round()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (actorDetails?['external_ids']?['instagram_id'] != null)
          IconButton(
            onPressed: _launchInstagram,
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            tooltip: 'View Instagram',
          ),
      ],
    );
  }

  Widget _buildActorInfo() {
    final birthday = actorDetails?['birthday'];
    final deathday = actorDetails?['deathday'];
    final placeOfBirth = actorDetails?['place_of_birth'];
    final biography = actorDetails?['biography'];
    final knownFor = actorDetails?['known_for_department'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (biography != null && biography.isNotEmpty) ...[
            const Text(
              'Biography',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              biography,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text(
            'Personal Info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (knownFor != null) _buildInfoRow('Known For', knownFor),
          if (birthday != null)
            _buildInfoRow('Birthday', _formatDate(birthday)),
          if (deathday != null) _buildInfoRow('Death', _formatDate(deathday)),
          if (placeOfBirth != null)
            _buildInfoRow('Place of Birth', placeOfBirth),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.red,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: [
          Tab(text: 'Movies (${movieCredits.length})'),
          Tab(text: 'TV Shows (${tvCredits.length})'),
        ],
      ),
    );
  }

  Widget _buildTabBarView() {
    return SliverFillRemaining(
      child: TabBarView(
        controller: _tabController,
        children: [
          _buildCreditsGrid(movieCredits, 'movie'),
          _buildCreditsGrid(tvCredits, 'tv'),
        ],
      ),
    );
  }

  Widget _buildCreditsGrid(
    List<Map<String, dynamic>> credits,
    String mediaType,
  ) {
    if (credits.isEmpty) {
      return const Center(
        child: Text(
          'No credits found',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: credits.length,
      itemBuilder: (context, index) {
        final credit = credits[index];
        return _buildCreditCard(credit, mediaType);
      },
    );
  }

  Widget _buildCreditCard(Map<String, dynamic> credit, String mediaType) {
    return GestureDetector(
      onTap: () {
        // Enforce the tab's mediaType — TMDB actor credits don't include
        // seasons/episodes, so inferring tv vs movie from missing fields
        // mixes them up. The movie_credits / tv_credits split is authoritative.
        final normalized = Map<String, dynamic>.from(credit)
          ..['media_type'] = mediaType;
        final isTv = mediaType == 'tv';
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => isTv
                ? MaxStreamSeriesScreen(seriesItem: Movie.fromJson(normalized))
                : MaxStreamDetailsScreen(
                    item: Movie.fromJson(normalized),
                    mediaType: mediaType,
                  ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: credit['poster_path'] != null
                  ? AppNetworkImage(
                      url: TmdbApiService.getPosterUrl(credit['poster_path']),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Colors.grey[800],
                      child: const Icon(Icons.movie, color: Colors.grey),
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            credit['title'] ?? credit['name'] ?? 'Unknown',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (credit['character'] != null)
            Text(
              'as ${credit['character']}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            _getYear(credit, mediaType),
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _getYear(Map<String, dynamic> credit, String mediaType) {
    final date = mediaType == 'movie'
        ? credit['release_date']
        : credit['first_air_date'];

    if (date != null && date.length >= 4) {
      return date.substring(0, 4);
    }
    return '';
  }

  String _formatDate(String date) {
    try {
      final parsedDate = DateTime.parse(date);
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date;
    }
  }
}
