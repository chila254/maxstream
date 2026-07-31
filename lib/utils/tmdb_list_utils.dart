String tmdbItemKey(Map<String, dynamic> item, String fallbackMediaType) {
  return '${item['media_type'] ?? fallbackMediaType}:${item['id']}';
}

List<Map<String, dynamic>> uniqueTmdbItems(
  Iterable<Map<String, dynamic>> existing,
  Iterable<Map<String, dynamic>> incoming,
  String fallbackMediaType,
) {
  final items = <String, Map<String, dynamic>>{};
  for (final item in [...existing, ...incoming]) {
    items.putIfAbsent(tmdbItemKey(item, fallbackMediaType), () => item);
  }
  return items.values.toList();
}
