import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../services/opencage_geocoder_service.dart';
import '../services/profile_storage.dart';
import '../widgets/skeleton_shimmer.dart';
import '../data/nutritionists_sample_data.dart';

/// Find nutritionists by location. Uses Google Places when available, with OpenStreetMap fallback.
class NutritionistsListScreen extends StatefulWidget {
  const NutritionistsListScreen({super.key});

  @override
  State<NutritionistsListScreen> createState() => _NutritionistsListScreenState();
}

class _NutritionistsListScreenState extends State<NutritionistsListScreen> {
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _locationFocusNode = FocusNode();
  bool _loadingLocation = false;
  String? _locationError;
  bool _locationValid = false;
  String? _validatedLocation;
  double? _validatedLat;
  double? _validatedLng;
  List<GooglePlaceSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;
  List<GooglePlaceResult> _nearbyPlaces = [];
  bool _loadingPlaces = false;
  bool _loadingDetails = false;
  bool _usingSampleData = false;

  /// Avoid duplicate suggestions like "Lahore" vs "Lahore, Pakistan" crowding the list.
  static List<GooglePlaceSuggestion> _dedupeSuggestions(List<GooglePlaceSuggestion> input) {
    final byFirst = <String, GooglePlaceSuggestion>{};
    for (final s in input) {
      final key = s.description.toLowerCase().trim().split(',').first.trim();
      if (key.isEmpty) continue;
      final prev = byFirst[key];
      if (prev == null || s.description.length > prev.description.length) {
        byFirst[key] = s;
      }
    }
    return byFirst.values.toList();
  }

  static List<GooglePlaceResult> _mergePlaces(List<GooglePlaceResult> lists) {
    final out = <GooglePlaceResult>[];
    final seen = <String>{};
    for (final p in lists) {
      final key = p.placeId.contains(',') ? '${p.lat.toStringAsFixed(5)}|${p.lng.toStringAsFixed(5)}' : p.placeId;
      if (seen.add(key)) out.add(p);
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _prefillCityFromProfile();
  }

  Future<void> _prefillCityFromProfile() async {
    final p = await ProfileStorage.load();
    if (!mounted) return;
    if ((p?.city ?? '').trim().isNotEmpty && _locationController.text.trim().isEmpty) {
      _locationController.text = p!.city.trim();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _locationFocusNode.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _onLocationChanged(String value) {
    setState(() {
      _locationError = null;
      _locationValid = false;
      _validatedLocation = null;
      _validatedLat = null;
      _validatedLng = null;
      _nearbyPlaces = [];
      _usingSampleData = false;
    });
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    // OpenCage recommends debouncing ~500ms for autocomplete (free tier friendly).
    final delayMs = OpenCageGeocoderService.isEnabled ? 500 : 300;
    _debounce = Timer(Duration(milliseconds: delayMs), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _loadingSuggestions = true);
    List<GooglePlaceSuggestion> list = [];

    // OpenCage: forward geocode with Lahore/Pakistan bias (same idea as the web snippet).
    if (OpenCageGeocoderService.isEnabled && q.length >= 3) {
      final oc = await OpenCageGeocoderService.search(q, limit: 5);
      list = oc
          .map(
            (e) => GooglePlaceSuggestion(
              description: e.formatted,
              placeId: '${e.lat},${e.lng}',
            ),
          )
          .toList();
    }

    if (list.isEmpty && GooglePlacesService.isEnabled) {
      list = await GooglePlacesService.autocomplete(q);
    }
    // Fallback: use LocationService suggestions if Google is disabled or returned nothing.
    if (list.isEmpty) {
      final loc = await LocationService.getSuggestions(q);
      list = loc
          .map(
            (s) => GooglePlaceSuggestion(
              description: s.displayName,
              placeId: '${s.lat},${s.lng}', // encode coordinates in placeId
            ),
          )
          .toList();
    }
    list = _dedupeSuggestions(list);
    if (!mounted) return;
    setState(() {
      _suggestions = list;
      _loadingSuggestions = false;
    });
  }

  void _selectSuggestion(GooglePlaceSuggestion s) async {
    _locationController.text = s.description;
    setState(() {
      _locationError = null;
      _loadingPlaces = true;
      _nearbyPlaces = [];
      _usingSampleData = false;
    });

    double? lat;
    double? lng;

    if (GooglePlacesService.isEnabled && !s.placeId.contains(',')) {
      final coords = await GooglePlacesService.getPlaceLocation(s.placeId);
      if (coords != null && coords.length == 2) {
        lat = coords[0];
        lng = coords[1];
      }
    } else {
      // Fallback: decode "lat,lng" placeId from LocationService suggestion.
      final parts = s.placeId.split(',');
      if (parts.length == 2) {
        lat = double.tryParse(parts[0]);
        lng = double.tryParse(parts[1]);
      }
    }

    if (!mounted) return;

    if (lat == null || lng == null) {
      setState(() {
        _loadingPlaces = false;
        _locationError = 'Could not resolve this place. Try another address.';
      });
      return;
    }

    setState(() {
      _locationValid = true;
      _validatedLocation = s.description;
      _validatedLat = lat;
      _validatedLng = lng;
      _suggestions = [];
    });

    final places = await _fetchLivePlaces(lat, lng, areaLabel: s.description);

    if (!mounted) return;
    final filled = places.isEmpty
        ? sampleNutritionistsNear(lat, lng, areaLabel: s.description)
        : places;
    setState(() {
      _nearbyPlaces = filled;
      _usingSampleData = places.isEmpty;
      _loadingPlaces = false;
    });

    await _enrichVisiblePlacesWithContact();
  }

  Future<void> _findNearby() async {
    final query = _locationController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _locationError = 'Enter a city or address';
        _locationValid = false;
        _validatedLocation = null;
        _validatedLat = null;
        _validatedLng = null;
        _nearbyPlaces = [];
        _usingSampleData = false;
      });
      return;
    }
    setState(() {
      _loadingLocation = true;
      _locationError = null;
      _locationValid = false;
      _validatedLocation = null;
      _validatedLat = null;
      _validatedLng = null;
      _nearbyPlaces = [];
      _usingSampleData = false;
    });
    var coords = await LocationService.geocode(query);
    if ((coords == null || coords.length < 2) && OpenCageGeocoderService.isEnabled) {
      coords = await OpenCageGeocoderService.geocodeFirst(query);
    }
    if (!mounted) return;
    if (coords == null || coords.length < 2) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'Location not found. Try another city or pick a suggestion below.';
      });
      return;
    }
    final lat = coords[0];
    final lng = coords[1];
    setState(() {
      _loadingLocation = false;
      _locationError = null;
      _locationValid = true;
      _validatedLocation = query;
      _validatedLat = lat;
      _validatedLng = lng;
      _loadingPlaces = true;
    });
    final places = await _fetchLivePlaces(lat, lng, areaLabel: query);

    if (!mounted) return;
    final filled = places.isEmpty ? sampleNutritionistsNear(lat, lng, areaLabel: query) : places;
    setState(() {
      _nearbyPlaces = filled;
      _usingSampleData = places.isEmpty;
      _loadingPlaces = false;
    });

    await _enrichVisiblePlacesWithContact();
  }

  Future<List<GooglePlaceResult>> _fetchLivePlaces(
    double lat,
    double lng, {
    required String areaLabel,
  }) async {
    // Always prefer real providers. If Google is enabled but returns no data
    // (quota/billing/coverage), automatically fallback to free OSM results.
    if (GooglePlacesService.isEnabled) {
      // Lahore can be large; use a wider radius to match what users see in Maps.
      final nearby = await GooglePlacesService.searchNearbyNutritionists(
        lat,
        lng,
        radiusMeters: 25000,
      );

      // City text search often matches what users see in Google Maps for a city query.
      final label = areaLabel.trim();
      final textA = label.isEmpty
          ? <GooglePlaceResult>[]
          : await GooglePlacesService.textSearchNutritionists(
              'nutritionist OR dietitian near $label',
            );
      final textB = label.isEmpty
          ? <GooglePlaceResult>[]
          : await GooglePlacesService.textSearchNutritionists(
              'nutrition clinic near $label',
            );

      final googleMerged = _mergePlaces([...nearby, ...textA, ...textB]);
      if (googleMerged.isNotEmpty) return googleMerged;
    }
    // Use a wider OSM/Nominatim radius so Lahore yields results.
    final osm = await LocationService.fetchNearbyPlaces(
      lat,
      lng,
      radiusMeters: 40000,
      areaLabel: areaLabel.trim(),
    );
    return osm
        .map(
          (p) => GooglePlaceResult(
            name: p.name,
            address: p.address ?? '',
            placeId: '${p.lat},${p.lng}',
            lat: p.lat,
            lng: p.lng,
            phoneNumber: p.phone,
            website: p.website,
          ),
        )
        .toList();
  }

  Future<void> _enrichVisiblePlacesWithContact() async {
    if (!GooglePlacesService.isEnabled || _nearbyPlaces.isEmpty) return;
    setState(() => _loadingDetails = true);
    final enriched = await GooglePlacesService.enrichPlacesWithDetails(_nearbyPlaces);
    if (!mounted) return;
    setState(() {
      _nearbyPlaces = enriched;
      _loadingDetails = false;
    });
  }

  Future<void> _openGoogleMaps({String? location}) async {
    final loc = location ?? _locationController.text.trim();
    final uri = Uri.parse(googleMapsSearchUrlForArea(loc));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // After opening Maps, refresh the in-app list using the same intent (Google Places Text Search).
    if (_validatedLat != null && _validatedLng != null) {
      setState(() {
        _loadingPlaces = true;
      });
      final label = (_validatedLocation ?? loc).trim();
      final refreshed = await _fetchLivePlaces(
        _validatedLat!,
        _validatedLng!,
        areaLabel: label.isEmpty ? loc : label,
      );
      if (!mounted) return;
      final area = label.isEmpty ? loc : label;
      final filled = refreshed.isEmpty
          ? sampleNutritionistsNear(_validatedLat!, _validatedLng!, areaLabel: area)
          : refreshed;
      setState(() {
        _nearbyPlaces = filled;
        _usingSampleData = refreshed.isEmpty;
        _loadingPlaces = false;
      });
      await _enrichVisiblePlacesWithContact();
    }
  }

  Future<void> _openPlaceInMaps(GooglePlaceResult place) async {
    final uri = Uri.parse(place.safeMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callPlace(String phoneNumber) async {
    final raw = phoneNumber.trim();
    if (raw.isEmpty) return;
    final normalized = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openWebsite(String website) async {
    final trimmed = website.trim();
    if (trimmed.isEmpty) return;
    final url = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find nutritionists near you'),
        backgroundColor: const Color(0xFF1A1D29),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Type your city or area — suggestions will appear. Then tap "Search this area" to find nutritionists.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            if (!GooglePlacesService.isEnabled || !OpenCageGeocoderService.isEnabled) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Text(
                  kDebugMode
                      ? (!OpenCageGeocoderService.isEnabled && !GooglePlacesService.isEnabled
                          ? 'Tips: add OPENCAGE_API_KEY to assets/.env for OpenCage address search (type 3+ letters for suggestions). '
                              'Add GOOGLE_PLACES_API_KEY for Google Places business results. '
                              'Without keys, the app uses built-in geocoding + OpenStreetMap.'
                          : !OpenCageGeocoderService.isEnabled
                              ? 'Tip: add OPENCAGE_API_KEY to assets/.env for OpenCage address suggestions (type 3+ letters). '
                                  'Bias is controlled by OPENCAGE_GEOCODE_BIAS (default: Lahore, Pakistan).'
                              : 'Tip: add GOOGLE_PLACES_API_KEY to assets/.env to match Google Maps business results more closely. '
                                  'Without it, the app uses free OpenStreetMap data for listings.')
                      : 'Results use free map data. For richer listings, add optional API keys in assets/.env (see README).',
                  style: TextStyle(fontSize: 13, color: Colors.orange.shade900, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              focusNode: _locationFocusNode,
              decoration: InputDecoration(
                hintText: OpenCageGeocoderService.isEnabled
                    ? 'Search Lahore area… (3+ letters for suggestions)'
                    : 'e.g. Lahore, Karachi (suggestions show as you type)',
                prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF22C55E)),
                suffixIcon: _loadingSuggestions
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
              onSubmitted: (_) => _findNearby(),
              onChanged: _onLocationChanged,
              onTap: () {
                final q = _locationController.text.trim();
                final minLen = OpenCageGeocoderService.isEnabled ? 3 : 2;
                if (q.length >= minLen && _suggestions.isEmpty && !_loadingSuggestions) {
                  _fetchSuggestions(q);
                }
              },
            ),
            if (_loadingSuggestions || _suggestions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: _loadingSuggestions
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final s = _suggestions[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.place, size: 22, color: Colors.grey.shade700),
                              title: Text(
                                s.description,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _loadingLocation ? null : _findNearby,
              icon: _loadingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.search, size: 20),
              label: Text(_loadingLocation ? 'Searching...' : 'Search this area'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: TextStyle(fontSize: 14, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ],
            if (_locationValid && _validatedLocation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: const Color(0xFF22C55E).withValues(alpha: 1.0), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Area: $_validatedLocation',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_loadingPlaces) ...[
              const SizedBox(height: 20),
              const SkeletonShimmer(
                child: Column(
                  children: [
                    _NutritionistSkeletonCard(),
                    SizedBox(height: 10),
                    _NutritionistSkeletonCard(),
                    SizedBox(height: 10),
                    _NutritionistSkeletonCard(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Finding nutritionists and healthcare places nearby...',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
            if (!_loadingPlaces && _nearbyPlaces.isNotEmpty) ...[
              const SizedBox(height: 20),
              if (_loadingDetails)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Loading contact details...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              if (_usingSampleData)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF22C55E).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.green.shade800, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No live listings were returned for this search. Showing sample cards for layout/demo. '
                          'Use Open in Google Maps below to see real businesses (same search as this button).',
                          style: TextStyle(fontSize: 13, color: Colors.green.shade900, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                'Places nearby',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1D29),
                ),
              ),
              const SizedBox(height: 10),
              ..._nearbyPlaces.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF22C55E),
                    child: Icon(Icons.medical_services_outlined, color: Colors.white, size: 22),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: p.address.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.address,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            if ((p.phoneNumber ?? '').isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  'Call: ${p.phoneNumber}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1D29),
                                  ),
                                ),
                              ),
                          ],
                        )
                      : null,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      if ((p.phoneNumber ?? '').isNotEmpty)
                        IconButton(
                          tooltip: 'Call',
                          icon: const Icon(Icons.call, size: 20, color: Color(0xFF22C55E)),
                          onPressed: () => _callPlace(p.phoneNumber!),
                        ),
                      if ((p.website ?? '').isNotEmpty)
                        IconButton(
                          tooltip: 'Website',
                          icon: const Icon(Icons.language, size: 20, color: Color(0xFF22C55E)),
                          onPressed: () => _openWebsite(p.website!),
                        ),
                      IconButton(
                        tooltip: 'Open Maps',
                        icon: const Icon(Icons.open_in_new, size: 20),
                        onPressed: () => _openPlaceInMaps(p),
                      ),
                    ],
                  ),
                ),
              )),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Search on Google Maps',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1D29),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Open Google Maps for more results, reviews, and contact details.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.map, size: 22),
              label: const Text('Open in Google Maps'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NutritionistSkeletonCard extends StatelessWidget {
  const _NutritionistSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5EAF0)),
      ),
      child: const Row(
        children: [
          SkeletonBox(height: 42, width: 42, radius: 999),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 12, width: 130),
                SizedBox(height: 8),
                SkeletonBox(height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonBox(height: 16, width: 16, radius: 4),
        ],
      ),
    );
  }
}
