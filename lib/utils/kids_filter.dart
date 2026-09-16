import '../services/profile_scope.dart';

/// TMDB genre IDs for kid-friendly content.
const int _genreAnimation = 16;
const int _genreFamily = 10751;

/// Returns true if the item has kid-friendly genres.
bool _isKidFriendly(Map<String, dynamic> item) {
  final genreIds = item['genre_ids'];
  if (genreIds is! List) return false;
  return genreIds.contains(_genreAnimation) || genreIds.contains(_genreFamily);
}

/// Filters a list of TMDB items to only kid-friendly content
/// when the active profile is a kids profile.
List<Map<String, dynamic>> filterForKids(List<Map<String, dynamic>> items) {
  final isKids = ProfileScope.activeProfile.value?.isKids ?? false;
  if (!isKids) return items;
  return items.where(_isKidFriendly).toList();
}

/// Whether the current active profile is a kids profile.
bool get isKidsProfile => ProfileScope.activeProfile.value?.isKids ?? false;
