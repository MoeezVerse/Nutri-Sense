import 'dart:convert';
import 'package:http/http.dart' as http;

/// Suggestion from Google Places autocomplete.
class GooglePlaceSuggestion {
  final String description;
  final String placeId;

  const GooglePlaceSuggestion({
    required this.description,
    required this.placeId,
  });
}

/// Result from Google Places Nearby Search.
class GooglePlaceResult {
  final String name;
  final String address;
  final String placeId;
  final double lat;
  final double lng;
  final String? phoneNumber;
  final String? website;
  final String? mapsDeepLink;
  final bool detailsLoaded;

  GooglePlaceResult({
    required this.name,
    required this.address,
    required this.placeId,
    required this.lat,
    required this.lng,
    this.phoneNumber,
    this.website,
    this.mapsDeepLink,
    this.detailsLoaded = false,
  });

  String get mapsUrl => 'https://www.google.com/maps/place/?q=place_id:$placeId';
  String get safeMapsUrl {
    if (mapsDeepLink != null && mapsDeepLink!.isNotEmpty) {
      return mapsDeepLink!;
    }
    if (placeId.contains(',')) {
      return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }
    return mapsUrl;
  }

  GooglePlaceResult copyWith({
    String? name,
    String? address,
    String? placeId,
    double? lat,
    double? lng,
    String? phoneNumber,
    String? website,
    String? mapsDeepLink,
    bool? detailsLoaded,
  }) {
    return GooglePlaceResult(
      name: name ?? this.name,
      address: address ?? this.address,
      placeId: placeId ?? this.placeId,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      website: website ?? this.website,
      mapsDeepLink: mapsDeepLink ?? this.mapsDeepLink,
      detailsLoaded: detailsLoaded ?? this.detailsLoaded,
    );
  }
}

/// Wrapper around Google Places Web API (Autocomplete + Nearby Search).
class GooglePlacesService {
  /// Set this from `main.dart` after loading `.env`.
  static String? apiKey;

  static bool get isEnabled => apiKey != null && apiKey!.isNotEmpty;

  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  /// Text search (good for city-wide queries like "nutritionist in Lahore").
  /// This often aligns better with what users see when searching in Google Maps.
  static Future<List<GooglePlaceResult>> textSearchNutritionists(String query) async {
    if (!isEnabled) return [];
    final key = apiKey!;
    final q = query.trim();
    if (q.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/textsearch/json').replace(
      queryParameters: <String, String>{
        'query': q,
        // Bias toward Pakistan when the user types a Pakistani city.
        'region': 'pk',
        'key': key,
      },
    );

    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];
    final list = <GooglePlaceResult>[];
    for (final r in results) {
      final m = r as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      final address = m['formatted_address'] as String? ?? '';
      final pid = m['place_id'] as String? ?? '';
      final geom = m['geometry'] as Map<String, dynamic>?;
      final loc = geom?['location'] as Map<String, dynamic>?;
      final plat = (loc?['lat'] as num?)?.toDouble();
      final plng = (loc?['lng'] as num?)?.toDouble();
      if (name.isEmpty || pid.isEmpty || plat == null || plng == null) continue;
      list.add(
        GooglePlaceResult(
          name: name,
          address: address,
          placeId: pid,
          lat: plat,
          lng: plng,
        ),
      );
    }
    return list;
  }

  /// Autocomplete address/place input (restricted to Pakistan for better results).
  static Future<List<GooglePlaceSuggestion>> autocomplete(String input) async {
    if (!isEnabled) return [];
    final key = apiKey!;
    final uri = Uri.parse('$_baseUrl/autocomplete/json').replace(
      queryParameters: <String, String>{
        'input': input,
        'types': 'geocode',
        'components': 'country:pk',
        'key': key,
      },
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return [];
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final preds = json['predictions'] as List<dynamic>? ?? [];
    final results = <GooglePlaceSuggestion>[];
    for (final p in preds) {
      final m = p as Map<String, dynamic>;
      final desc = m['description'] as String? ?? '';
      final pid = m['place_id'] as String? ?? '';
      if (desc.isEmpty || pid.isEmpty) continue;
      results.add(GooglePlaceSuggestion(description: desc, placeId: pid));
    }
    return results;
  }

  /// Get coordinates for a place ID (from autocomplete).
  static Future<List<double>?> getPlaceLocation(String placeId) async {
    if (!isEnabled) return null;
    final key = apiKey!;
    final uri = Uri.parse('$_baseUrl/details/json').replace(
      queryParameters: <String, String>{
        'place_id': placeId,
        'fields': 'geometry',
        'key': key,
      },
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 8));
    if (resp.statusCode != 200) return null;
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final result = json['result'] as Map<String, dynamic>?;
    final geom = result?['geometry'] as Map<String, dynamic>?;
    final loc = geom?['location'] as Map<String, dynamic>?;
    if (loc == null) return null;
    final lat = (loc['lat'] as num?)?.toDouble();
    final lng = (loc['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return <double>[lat, lng];
  }

  /// Nearby search for nutritionists / dietitians around [lat],[lng].
  static Future<List<GooglePlaceResult>> searchNearbyNutritionists(
    double lat,
    double lng, {
    int radiusMeters = 5000,
  }) async {
    if (!isEnabled) return [];
    final key = apiKey!;
    final uri = Uri.parse('$_baseUrl/nearbysearch/json').replace(
      queryParameters: <String, String>{
        'location': '$lat,$lng',
        'radius': radiusMeters.toString(),
        'keyword': 'nutritionist dietitian nutrition clinic',
        'key': key,
      },
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];
    final list = <GooglePlaceResult>[];
    for (final r in results) {
      final m = r as Map<String, dynamic>;
      final name = m['name'] as String? ?? '';
      final address = m['vicinity'] as String? ?? (m['formatted_address'] as String? ?? '');
      final pid = m['place_id'] as String? ?? '';
      final geom = m['geometry'] as Map<String, dynamic>?;
      final loc = geom?['location'] as Map<String, dynamic>?;
      final plat = (loc?['lat'] as num?)?.toDouble();
      final plng = (loc?['lng'] as num?)?.toDouble();
      if (name.isEmpty || pid.isEmpty || plat == null || plng == null) continue;
      list.add(
        GooglePlaceResult(
          name: name,
          address: address,
          placeId: pid,
          lat: plat,
          lng: plng,
        ),
      );
    }
    return list;
  }

  /// Fetches contact details for a single place.
  static Future<GooglePlaceResult?> getPlaceDetails(GooglePlaceResult place) async {
    if (!isEnabled || place.placeId.contains(',')) {
      return place.copyWith(detailsLoaded: true);
    }
    final key = apiKey!;
    final uri = Uri.parse('$_baseUrl/details/json').replace(
      queryParameters: <String, String>{
        'place_id': place.placeId,
        'fields': 'formatted_phone_number,international_phone_number,website,url',
        'key': key,
      },
    );
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        return place.copyWith(detailsLoaded: true);
      }
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final result = json['result'] as Map<String, dynamic>?;
      if (result == null) {
        return place.copyWith(detailsLoaded: true);
      }
      final intlPhone = result['international_phone_number'] as String?;
      final localPhone = result['formatted_phone_number'] as String?;
      final website = result['website'] as String?;
      final mapsUrl = result['url'] as String?;
      return place.copyWith(
        phoneNumber: (intlPhone != null && intlPhone.isNotEmpty)
            ? intlPhone
            : localPhone,
        website: website,
        mapsDeepLink: mapsUrl,
        detailsLoaded: true,
      );
    } catch (_) {
      return place.copyWith(detailsLoaded: true);
    }
  }

  /// Enriches top place results with phone/website/maps deep links.
  static Future<List<GooglePlaceResult>> enrichPlacesWithDetails(
    List<GooglePlaceResult> places, {
    int maxItems = 6,
  }) async {
    if (!isEnabled || places.isEmpty) return places;
    final enriched = <GooglePlaceResult>[];
    for (var i = 0; i < places.length; i++) {
      if (i >= maxItems) {
        enriched.add(places[i]);
        continue;
      }
      final detailed = await getPlaceDetails(places[i]);
      enriched.add(detailed ?? places[i]);
    }
    return enriched;
  }
}

