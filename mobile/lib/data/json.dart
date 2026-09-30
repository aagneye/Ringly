/// Small, forgiving readers for decoded JSON.
///
/// The API is ours, but a model written against a slightly older server should
/// degrade to an empty field rather than throw a cast error mid-render. Every
/// model's `fromJson` goes through these instead of raw `as` casts.
library;

typedef Json = Map<String, dynamic>;

String readString(Json json, String key, [String fallback = '']) {
  final value = json[key];
  return value is String ? value : (value?.toString() ?? fallback);
}

String? readStringOrNull(Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  final text = value is String ? value : value.toString();
  return text.isEmpty ? null : text;
}

int readInt(Json json, String key, [int fallback = 0]) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool readBool(Json json, String key, [bool fallback = false]) {
  final value = json[key];
  return value is bool ? value : fallback;
}

/// ISO-8601 timestamps from the server, converted to local time for display.
DateTime? readDate(Json json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// A list of objects, each mapped through [fromJson]. Non-object entries are
/// skipped rather than failing the whole list.
List<T> readList<T>(Json json, String key, T Function(Json) fromJson) {
  final value = json[key];
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map<String, dynamic>) fromJson(item),
  ];
}

List<String> readStringList(Json json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return [for (final item in value) if (item is String) item];
}

Json readObject(Json json, String key) {
  final value = json[key];
  return value is Map<String, dynamic> ? value : const {};
}
