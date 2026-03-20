import '../services/google_places_service.dart';

/// Illustrative listings when live APIs/OSM return nothing. Not real businesses.
/// Each card’s “Open Maps” uses the same intent as [googleMapsSearchUrlForArea].
List<GooglePlaceResult> sampleNutritionistsNear(
  double lat,
  double lng, {
  required String areaLabel,
}) {
  final label = areaLabel.trim().isEmpty ? 'this area' : areaLabel.trim();
  final mapsSearchUrl = googleMapsSearchUrlForArea(label);

  // Small offsets (~1–3 km) so pins spread around the searched center.
  const offsets = <List<double>>[
    [0.0, 0.0],
    [0.011, 0.006],
    [-0.008, 0.009],
    [0.005, -0.011],
    [-0.012, -0.005],
  ];

  final names = <String>[
    'Community Nutrition & Diet Clinic',
    'Clinical Dietitian & Weight Management',
    'Sports Nutrition & Lifestyle Clinic',
    'Family Health & Nutrition Center',
    'Pediatric & Women Nutrition Care',
  ];

  final hints = <String>[
    'Main boulevard / commercial district',
    'Near medical complex',
    'Residential & wellness district',
    'Near hospital corridor',
    'Community health zone',
  ];

  return List<GooglePlaceResult>.generate(names.length, (i) {
    final dlat = offsets[i][0];
    final dlng = offsets[i][1];
    final plat = lat + dlat;
    final plng = lng + dlng;
    return GooglePlaceResult(
      name: '${names[i]} (sample)',
      address: '${hints[i]} • $label — open Google Maps below for real, up-to-date businesses.',
      placeId: '$plat,$plng',
      lat: plat,
      lng: plng,
      phoneNumber: '+92 300 0000000',
      mapsDeepLink: mapsSearchUrl,
      detailsLoaded: true,
    );
  });
}

/// Same search URL as the “Open in Google Maps” button on [NutritionistsListScreen].
String googleMapsSearchUrlForArea(String locationQuery) {
  final q = locationQuery.trim().isEmpty
      ? 'nutritionist dietitian'
      : 'nutritionist dietitian near $locationQuery';
  return 'https://www.google.com/maps/search/${Uri.encodeComponent(q)}';
}
