import 'dart:convert';

import 'package:http/http.dart' as http;

/// One geocoding result from OpenCage Data.
class OpenCageSuggestion {
  final String formatted;
  final double lat;
  final double lng;

  const OpenCageSuggestion({
    required this.formatted,
    required this.lat,
    required this.lng,
  });
}

/// Forward geocoding via [OpenCage Geocoding API](https://opencagedata.com/api).
///
/// Set [apiKey] from `assets/.env` (`OPENCAGE_API_KEY`). Optional [geocodeBias]
/// (e.g. `Lahore, Pakistan` or `Pakistan`) is appended to the user query.
class OpenCageGeocoderService {
  OpenCageGeocoderService._();

  static String? apiKey;

  /// Appended to each search query, e.g. `Lahore, Pakistan` (matches common
  /// "search within Lahore" UX) or `Pakistan` for country-wide bias.
  static String geocodeBias = 'Lahore, Pakistan';

  static bool get isEnabled => apiKey != null && apiKey!.trim().isNotEmpty;

  static const String _host = 'api.opencagedata.com';
  static const String _path = '/geocode/v1/json';

  /// Returns up to [limit] suggestions; empty if disabled, on error, or bad response.
  static Future<List<OpenCageSuggestion>> search(
    String query, {
    int limit = 5,
  }) async {
    if (!isEnabled) return [];
    final q = query.trim();
    if (q.isEmpty) return [];

    final key = apiKey!.trim();
    final biased = '$q, $geocodeBias';

    final uri = Uri.https(_host, _path, <String, String>{
      'q': biased,
      'key': key,
      'limit': limit.clamp(1, 10).toString(),
      'no_annotations': '1',
      'countrycode': 'pk',
    });

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final status = json['status'] as Map<String, dynamic>?;
      final code = status?['code'] as int? ?? 0;
      if (code != 200) return [];

      final raw = json['results'] as List<dynamic>? ?? [];
      final out = <OpenCageSuggestion>[];
      for (final item in raw) {
        final m = item as Map<String, dynamic>;
        final formatted = (m['formatted'] ?? '').toString();
        final geom = m['geometry'] as Map<String, dynamic>?;
        final lat = (geom?['lat'] as num?)?.toDouble();
        final lng = (geom?['lng'] as num?)?.toDouble();
        if (formatted.isEmpty || lat == null || lng == null) continue;
        out.add(OpenCageSuggestion(formatted: formatted, lat: lat, lng: lng));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  /// Single best lat/lng for a free-text query (e.g. "Search this area").
  static Future<List<double>?> geocodeFirst(String query) async {
    final list = await search(query, limit: 1);
    if (list.isEmpty) return null;
    return <double>[list.first.lat, list.first.lng];
  }
}
