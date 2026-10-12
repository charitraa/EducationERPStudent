/// Tolerant readers for the backend's JSON. Decimals arrive as strings from
/// model serializers ("82.50") and as numbers from report endpoints (82.5);
/// both are read the same way.
double? asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

String? asString(Object? v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

bool asBool(Object? v) => v == true || v == 'true';

/// A `YYYY-MM-DD` date, kept as a local calendar day.
DateTime? asDate(Object? v) {
  final s = asString(v);
  if (s == null) return null;
  final d = DateTime.tryParse(s.length >= 10 ? s.substring(0, 10) : s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

/// An ISO-8601 timestamp, converted to the device's local time.
DateTime? asDateTime(Object? v) {
  final s = asString(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

/// `HH:MM[:SS]` as minutes since midnight.
int? asMinutes(Object? v) {
  final s = asString(v);
  if (s == null) return null;
  final parts = s.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  return (h == null || m == null) ? null : h * 60 + m;
}

List<Map<String, dynamic>> asMapList(Object? v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

Map<String, dynamic> asMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};

/// `2026-10-12`, the format the backend's date filters expect.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
