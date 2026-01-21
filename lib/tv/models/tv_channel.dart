/// Model for TV channel data from scraper
class TvChannel {
  final String id;
  final String name;
  final String m3u8Url;
  final String source;
  final String? logo;
  final String? category;
  final String? country;
  final bool isPlayable;
  final DateTime? fetchedAt;

  TvChannel({
    required this.id,
    required this.name,
    required this.m3u8Url,
    required this.source,
    this.logo,
    this.category,
    this.country,
    this.isPlayable = true,
    this.fetchedAt,
  });

  /// Create TvChannel from API response
  factory TvChannel.fromJson(Map<String, dynamic> json) {
    return TvChannel(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Unknown Channel',
      m3u8Url: json['m3u8Url'] as String? ?? json['url'] as String? ?? '',
      source: json['source'] as String? ?? 'Unknown',
      logo: json['logo'] as String?,
      category: json['category'] as String?,
      country: json['country'] as String?,
      isPlayable: json['isPlayable'] as bool? ?? true,
      fetchedAt: json['fetchedAt'] != null 
          ? DateTime.parse(json['fetchedAt'] as String)
          : DateTime.now(),
    );
  }

  /// Convert TvChannel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'm3u8Url': m3u8Url,
      'source': source,
      'logo': logo,
      'category': category,
      'country': country,
      'isPlayable': isPlayable,
      'fetchedAt': fetchedAt?.toIso8601String(),
    };
  }

  /// Create a copy with modified fields
  TvChannel copyWith({
    String? id,
    String? name,
    String? m3u8Url,
    String? source,
    String? logo,
    String? category,
    String? country,
    bool? isPlayable,
    DateTime? fetchedAt,
  }) {
    return TvChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      m3u8Url: m3u8Url ?? this.m3u8Url,
      source: source ?? this.source,
      logo: logo ?? this.logo,
      category: category ?? this.category,
      country: country ?? this.country,
      isPlayable: isPlayable ?? this.isPlayable,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  @override
  String toString() {
    return 'TvChannel(id: $id, name: $name, source: $source, isPlayable: $isPlayable)';
  }
}
