import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// A place suggestion for location autocomplete.
class LocationSuggestion {
  final String displayName;
  final double lat;
  final double lng;
  const LocationSuggestion({required this.displayName, required this.lat, required this.lng});
}

/// Geocodes a place name or address to coordinates. Uses known cities first, then Photon, then Nominatim.
/// No API key required.
class LocationService {
  static const String _photonUrl = 'https://photon.komoot.io/api/';
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';

  /// Known cities so location works even when network/APIs fail. Key: lowercase name, value: [lat, lng].
  static const Map<String, List<double>> _knownCities = {
    'lahore': [31.5204, 74.3587],
    'karachi': [24.8607, 67.0011],
    'islamabad': [33.6844, 73.0479],
    'rawalpindi': [33.6007, 73.0679],
    'faisalabad': [31.4180, 73.0790],
    'multan': [30.1575, 71.5249],
    'peshawar': [34.0080, 71.5785],
    'quetta': [30.1798, 66.9750],
    'new york': [40.7128, -74.0060],
    'london': [51.5074, -0.1278],
    'dubai': [25.2048, 55.2708],
    'mumbai': [19.0760, 72.8777],
    'delhi': [28.7041, 77.1025],
    'chicago': [41.8781, -87.6298],
    'los angeles': [34.0522, -118.2437],
  };

  /// Returns place suggestions: known cities that match first, then from Photon API.
  static Future<List<LocationSuggestion>> getSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final lower = q.toLowerCase();
    final list = <LocationSuggestion>[];
    for (final entry in _knownCities.entries) {
      if (entry.key.startsWith(lower) || lower.startsWith(entry.key)) {
        final name = _keyToDisplayName(entry.key);
        list.add(LocationSuggestion(
          displayName: name,
          lat: entry.value[0],
          lng: entry.value[1],
        ));
      }
    }
    try {
      final uri = Uri.parse(_photonUrl).replace(
        queryParameters: {'q': q, 'limit': '8'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final features = map['features'] as List<dynamic>?;
        if (features != null && features.isNotEmpty) {
          final seen = <String>{};
          for (final name in list.map((e) => e.displayName)) {
            seen.add(name.toLowerCase());
          }
          for (final f in features) {
            final feat = f as Map<String, dynamic>;
            final props = feat['properties'] as Map<String, dynamic>?;
            final geom = feat['geometry'] as Map<String, dynamic>?;
            final coords = geom?['coordinates'] as List<dynamic>?;
            if (props == null || coords == null || coords.length < 2) continue;
            final name = _formatPhotonName(props);
            if (seen.add(name.toLowerCase())) {
              final lng = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              list.add(LocationSuggestion(displayName: name, lat: lat, lng: lng));
            }
          }
        }
      }
    } catch (_) {}
    return list;
  }

  static String _keyToDisplayName(String key) {
    const names = {
      'lahore': 'Lahore, Pakistan',
      'karachi': 'Karachi, Pakistan',
      'islamabad': 'Islamabad, Pakistan',
      'rawalpindi': 'Rawalpindi, Pakistan',
      'faisalabad': 'Faisalabad, Pakistan',
      'multan': 'Multan, Pakistan',
      'peshawar': 'Peshawar, Pakistan',
      'quetta': 'Quetta, Pakistan',
      'new york': 'New York, USA',
      'london': 'London, UK',
      'dubai': 'Dubai, UAE',
      'mumbai': 'Mumbai, India',
      'delhi': 'Delhi, India',
      'chicago': 'Chicago, USA',
      'los angeles': 'Los Angeles, USA',
    };
    return names[key] ?? '${key[0].toUpperCase()}${key.substring(1)}';
  }

  static String _formatPhotonName(Map<String, dynamic> props) {
    final name = props['name'] as String?;
    final street = props['street'] as String?;
    final city = props['city'] as String?;
    final state = props['state'] as String?;
    final country = props['country'] as String?;
    final parts = <String>[];
    if (name != null && name.isNotEmpty) parts.add(name);
    if (street != null && street.isNotEmpty) parts.add(street);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (state != null && state.isNotEmpty) parts.add(state);
    if (country != null && country.isNotEmpty) parts.add(country);
    if (parts.isEmpty) return 'Unknown';
    return parts.join(', ');
  }

  /// Returns [lat, lng] for the given query (e.g. "Lahore", "New York"), or null if not found.
  static Future<List<double>?> geocode(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    final lower = q.toLowerCase();
    if (_knownCities.containsKey(lower)) return List<double>.from(_knownCities[lower]!);
    for (final entry in _knownCities.entries) {
      if (entry.key.startsWith(lower) || lower.startsWith(entry.key)) {
        return List<double>.from(entry.value);
      }
    }

    final coords = await _geocodePhoton(q);
    if (coords != null) return coords;

    final queries = [q];
    final words = q.split(RegExp(r'\s+'));
    if (words.length <= 2) {
      queries.add('$q, Pakistan');
      queries.add('$q, India');
      queries.add('$q, USA');
      queries.add('$q, UK');
    }
    for (final qq in queries) {
      final c = await _geocodeNominatim(qq);
      if (c != null) return c;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    }
    return null;
  }

  static Future<List<double>?> _geocodePhoton(String query) async {
    try {
      final uri = Uri.parse(_photonUrl).replace(
        queryParameters: {'q': query, 'limit': '1'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final features = map['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) return null;
      final geom = (features[0] as Map<String, dynamic>)['geometry'] as Map<String, dynamic>?;
      final coords = geom?['coordinates'] as List<dynamic>?;
      if (coords == null || coords.length < 2) return null;
      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      return [lat, lng];
    } catch (_) {
      return null;
    }
  }

  static Future<List<double>?> _geocodeNominatim(String query) async {
    try {
      final uri = Uri.parse(_nominatimUrl).replace(
        queryParameters: {'q': query, 'format': 'json', 'limit': '1'},
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'NutriSense/1.0 (nutrition app; contact support@example.com)'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final list = jsonDecode(response.body) as List<dynamic>;
      if (list.isEmpty) return null;
      final item = list[0] as Map<String, dynamic>;
      final lat = (item['lat'] as num?)?.toDouble();
      final lon = (item['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) return null;
      return [lat, lon];
    } catch (_) {
      return null;
    }
  }

  /// A place found near a location (e.g. from OpenStreetMap).
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Fetches nutritionist/dietitian/healthcare places near [lat], [lng] (radius [radiusMeters]).
  /// [areaLabel] is used to build city-specific queries (e.g. "Lahore") when OSM tags are sparse.
  static Future<List<NearbyPlace>> fetchNearbyPlaces(
    double lat,
    double lng, {
    int radiusMeters = 8000,
    String? areaLabel,
  }) async {
    try {
      final query = '''
[out:json][timeout:15];
( node(around:$radiusMeters,$lat,$lng)["healthcare"~"nutrition|dietitian|nutritionist",i];
  node(around:$radiusMeters,$lat,$lng)["name"~"nutrition|dietitian|nutritionist|diet",i];
  way(around:$radiusMeters,$lat,$lng)["healthcare"~"nutrition|dietitian|nutritionist",i];
  way(around:$radiusMeters,$lat,$lng)["name"~"nutrition|dietitian|nutritionist|diet",i];
  node(around:$radiusMeters,$lat,$lng)["office"="dietitian"];
  way(around:$radiusMeters,$lat,$lng)["office"="dietitian"];
);
out body center;
''';
      final response = await http.post(
        Uri.parse(_overpassUrl),
        body: {'data': query},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final elements = map['elements'] as List<dynamic>? ?? [];
      final list = <NearbyPlace>[];
      for (final e in elements) {
        final el = e as Map<String, dynamic>;
        final tags = el['tags'] as Map<String, dynamic>? ?? {};
        final name = tags['name'] as String? ?? 'Healthcare place';
        final addr = _formatAddress(tags);
        final phone = _pickFirstTag(tags, const [
          'contact:phone',
          'phone',
          'contact:mobile',
          'mobile',
        ]);
        final email = _pickFirstTag(tags, const [
          'contact:email',
          'email',
        ]);
        final website = _pickFirstTag(tags, const [
          'contact:website',
          'website',
          'url',
        ]);
        double? placeLat = (el['lat'] as num?)?.toDouble();
        double? placeLng = (el['lon'] as num?)?.toDouble();
        if (placeLat == null && placeLng == null && el['center'] != null) {
          final c = el['center'] as Map<String, dynamic>;
          placeLat = (c['lat'] as num?)?.toDouble();
          placeLng = (c['lon'] as num?)?.toDouble();
        }
        if (placeLat != null && placeLng != null) {
          list.add(
            NearbyPlace(
              name: name,
              address: addr,
              lat: placeLat,
              lng: placeLng,
              phone: phone,
              email: email,
              website: website,
            ),
          );
        }
      }
      if (list.isNotEmpty) {
        return list;
      }
      // Fallback when Overpass has sparse tags or temporary issues.
      final nominatim = await _searchNearbyWithNominatim(
        lat,
        lng,
        radiusMeters: radiusMeters,
        areaLabel: areaLabel,
      );
      if (nominatim.isNotEmpty) return nominatim;
      return _searchPhotonHealthPlaces(lat, lng, radiusMeters: radiusMeters, areaLabel: areaLabel);
    } catch (_) {
      final nominatim = await _searchNearbyWithNominatim(
        lat,
        lng,
        radiusMeters: radiusMeters,
        areaLabel: areaLabel,
      );
      if (nominatim.isNotEmpty) return nominatim;
      return _searchPhotonHealthPlaces(lat, lng, radiusMeters: radiusMeters, areaLabel: areaLabel);
    }
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthKm * c;
  }

  static String? _formatAddress(Map<String, dynamic> tags) {
    final street = tags['addr:street'] as String?;
    final city = tags['addr:city'] as String?;
    final state = tags['addr:state'] as String?;
    final country = tags['addr:country'] as String?;
    final parts = <String>[];
    if (street != null && street.isNotEmpty) parts.add(street);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (state != null && state.isNotEmpty) parts.add(state);
    if (country != null && country.isNotEmpty) parts.add(country);
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  static String? _pickFirstTag(Map<String, dynamic> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key] as String?;
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  static Future<List<NearbyPlace>> _searchNearbyWithNominatim(
    double lat,
    double lng, {
    required int radiusMeters,
    String? areaLabel,
  }) async {
    final list = <NearbyPlace>[];
    final seen = <String>{};
    final al = areaLabel?.trim() ?? '';
    // City-scoped queries (critical for places like Lahore where generic queries return nothing).
    final queries = <String>[
      if (al.isNotEmpty) ...[
        'nutritionist $al Pakistan',
        'dietitian $al Pakistan',
        'nutrition clinic $al',
        'diet clinic $al',
        'dietitian near $al',
        'nutritionist near $al',
        'nutrition $al',
        'hospital $al',
        'medical clinic $al',
      ],
      'nutritionist',
      'dietitian',
      'nutrition clinic',
    ];

    // Approximate viewbox from radius (degrees).
    final degLat = math.max(0.18, radiusMeters / 110000.0);
    final degLon = math.max(0.18, radiusMeters / (110000.0 * math.cos(lat * math.pi / 180)));
    final left = (lng - degLon).toStringAsFixed(6);
    final right = (lng + degLon).toStringAsFixed(6);
    final top = (lat + degLat).toStringAsFixed(6);
    final bottom = (lat - degLat).toStringAsFixed(6);
    final maxKm = radiusMeters / 1000.0 + 8;

    for (var i = 0; i < queries.length; i++) {
      final q = queries[i];
      if (i > 0) {
        await Future<void>.delayed(const Duration(milliseconds: 1100));
      }
      try {
        final uri = Uri.parse(_nominatimUrl).replace(
          queryParameters: {
            'q': q,
            'format': 'jsonv2',
            'limit': '15',
            'bounded': '1',
            'viewbox': '$left,$top,$right,$bottom',
            'addressdetails': '1',
            'extratags': '1',
          },
        );
        final response = await http.get(
          uri,
          headers: {
            'User-Agent': 'NutriSense/1.0 (nutrition app; contact support@example.com)',
          },
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final raw = jsonDecode(response.body) as List<dynamic>;
        for (final item in raw) {
          final m = item as Map<String, dynamic>;
          final plat = double.tryParse((m['lat'] ?? '').toString());
          final plng = double.tryParse((m['lon'] ?? '').toString());
          if (plat == null || plng == null) continue;

          if (_distanceKm(lat, lng, plat, plng) > maxKm) continue;

          final displayName = (m['display_name'] ?? '').toString();
          final name = (m['name'] ?? '').toString();
          final title = name.isNotEmpty ? name : _deriveName(displayName);
          if (title.isEmpty) continue;

          final dedupe = '$title|$plat|$plng';
          if (!seen.add(dedupe)) continue;

          final extra = m['extratags'] as Map<String, dynamic>?;
          final phone = _pickFirstTag(extra ?? const {}, const [
            'contact:phone',
            'phone',
            'contact:mobile',
            'mobile',
          ]);
          final email = _pickFirstTag(extra ?? const {}, const [
            'contact:email',
            'email',
          ]);
          final website = _pickFirstTag(extra ?? const {}, const [
            'contact:website',
            'website',
            'url',
          ]);

          list.add(
            NearbyPlace(
              name: title,
              address: displayName,
              lat: plat,
              lng: plng,
              phone: phone,
              email: email,
              website: website,
            ),
          );
          if (list.length >= 14) {
            return list;
          }
        }
      } catch (_) {
        // Try next query keyword.
      }
    }
    return list;
  }

  /// Photon-based fallback (biased toward [lat],[lng]) when Overpass/Nominatim are sparse.
  static Future<List<NearbyPlace>> _searchPhotonHealthPlaces(
    double lat,
    double lng, {
    required int radiusMeters,
    String? areaLabel,
  }) async {
    final list = <NearbyPlace>[];
    final seen = <String>{};
    final al = areaLabel?.trim() ?? '';
    final queries = <String>[
      if (al.isNotEmpty) ...[
        'nutritionist $al',
        'dietitian $al',
        'nutrition clinic $al',
        'medical clinic $al',
        'hospital $al',
      ],
      'nutritionist',
      'dietitian',
    ];
    final maxKm = radiusMeters / 1000.0 + 8;

    for (final q in queries) {
      try {
        final uri = Uri.parse(_photonUrl).replace(
          queryParameters: <String, String>{
            'q': q,
            'limit': '12',
            'lat': lat.toString(),
            'lon': lng.toString(),
          },
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final map = jsonDecode(response.body) as Map<String, dynamic>;
        final features = map['features'] as List<dynamic>? ?? [];
        for (final f in features) {
          final feat = f as Map<String, dynamic>;
          final props = feat['properties'] as Map<String, dynamic>?;
          final geom = feat['geometry'] as Map<String, dynamic>?;
          final coords = geom?['coordinates'] as List<dynamic>?;
          if (props == null || coords == null || coords.length < 2) continue;
          final plng = (coords[0] as num).toDouble();
          final plat = (coords[1] as num).toDouble();
          if (_distanceKm(lat, lng, plat, plng) > maxKm) continue;

          final displayName = _formatPhotonName(props);
          if (displayName.isEmpty || displayName == 'Unknown') continue;

          final dedupe = '$displayName|$plat|$plng';
          if (!seen.add(dedupe)) continue;

          list.add(
            NearbyPlace(
              name: displayName.split(',').first.trim(),
              address: displayName,
              lat: plat,
              lng: plng,
            ),
          );
        }
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    return list;
  }

  static String _deriveName(String displayName) {
    final first = displayName.split(',').first.trim();
    return first;
  }
}

/// A place near the user (e.g. nutritionist, dietitian, healthcare).
class NearbyPlace {
  final String name;
  final String? address;
  final double lat;
  final double lng;
  final String? phone;
  final String? email;
  final String? website;

  const NearbyPlace({
    required this.name,
    this.address,
    required this.lat,
    required this.lng,
    this.phone,
    this.email,
    this.website,
  });
}
