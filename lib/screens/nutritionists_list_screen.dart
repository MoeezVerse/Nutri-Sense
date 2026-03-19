import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/google_places_service.dart';
import '../data/nutritionists_data.dart';
import '../models/nutritionist.dart';
import '../services/profile_storage.dart';
import '../widgets/skeleton_shimmer.dart';

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
  List<GooglePlaceSuggestion> _suggestions = [];
  bool _loadingSuggestions = false;
  Timer? _debounce;
  List<GooglePlaceResult> _nearbyPlaces = [];
  bool _loadingPlaces = false;
  bool _usingFallbackData = false;

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
      _nearbyPlaces = [];
    });
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _fetchSuggestions(q));
  }

  Future<void> _fetchSuggestions(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _loadingSuggestions = true);
    List<GooglePlaceSuggestion> list = [];
    if (GooglePlacesService.isEnabled) {
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
      _suggestions = [];
    });

    List<GooglePlaceResult> places;
    if (GooglePlacesService.isEnabled) {
      places = await GooglePlacesService.searchNearbyNutritionists(lat, lng);
    } else {
      final osm = await LocationService.fetchNearbyPlaces(lat, lng);
      places = osm
          .map(
            (p) => GooglePlaceResult(
              name: p.name,
              address: p.address ?? '',
              placeId: '${p.lat},${p.lng}',
              lat: p.lat,
              lng: p.lng,
            ),
          )
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _nearbyPlaces = places;
      _loadingPlaces = false;
      _usingFallbackData = false;
    });

    if (_nearbyPlaces.isEmpty) {
      final fallback = _buildFallbackPlaces(lat, lng);
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = fallback;
        _usingFallbackData = fallback.isNotEmpty;
      });
    }
  }

  Future<void> _findNearby() async {
    final query = _locationController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _locationError = 'Enter a city or address';
        _locationValid = false;
        _validatedLocation = null;
        _validatedLat = null;
        _nearbyPlaces = [];
      });
      return;
    }
    setState(() {
      _loadingLocation = true;
      _locationError = null;
      _locationValid = false;
      _validatedLocation = null;
      _validatedLat = null;
      _nearbyPlaces = [];
      _usingFallbackData = false;
    });
    final coords = await LocationService.geocode(query);
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
    });
    List<GooglePlaceResult> places;
    if (GooglePlacesService.isEnabled) {
      places = await GooglePlacesService.searchNearbyNutritionists(lat, lng);
    } else {
      final osm = await LocationService.fetchNearbyPlaces(lat, lng);
      places = osm
          .map(
            (p) => GooglePlaceResult(
              name: p.name,
              address: p.address ?? '',
              placeId: '${p.lat},${p.lng}',
              lat: p.lat,
              lng: p.lng,
            ),
          )
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _nearbyPlaces = places;
      _usingFallbackData = false;
    });

    if (_nearbyPlaces.isEmpty) {
      final fallback = _buildFallbackPlaces(lat, lng);
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = fallback;
        _usingFallbackData = fallback.isNotEmpty;
      });
    }
  }

  List<GooglePlaceResult> _buildFallbackPlaces(double lat, double lng) {
    final sorted = [...kNutritionists];
    sorted.sort((a, b) {
      final da = Nutritionist.distanceKm(lat, lng, a.lat, a.lng);
      final db = Nutritionist.distanceKm(lat, lng, b.lat, b.lng);
      return da.compareTo(db);
    });
    return sorted.take(5).map((n) {
      return GooglePlaceResult(
        name: n.name,
        address: n.address,
        placeId: '${n.lat},${n.lng}',
        lat: n.lat,
        lng: n.lng,
      );
    }).toList();
  }

  Future<void> _openGoogleMaps({String? location}) async {
    final loc = location ?? _locationController.text.trim();
    final search = (loc.isEmpty) ? 'nutritionist dietitian' : 'nutritionist dietitian near $loc';
    final uri = Uri.parse(
      'https://www.google.com/maps/search/${Uri.encodeComponent(search)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openPlaceInMaps(GooglePlaceResult place) async {
    final uri = Uri.parse(place.safeMapsUrl);
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
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              focusNode: _locationFocusNode,
              decoration: InputDecoration(
                hintText: 'e.g. Lahore, Karachi (suggestions show as you type)',
                prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF2ECC71)),
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
                if (q.length >= 2 && _suggestions.isEmpty && !_loadingSuggestions) {
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
                backgroundColor: const Color(0xFF2ECC71),
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
                  color: const Color(0xFF2ECC71).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Area: $_validatedLocation',
                        style: TextStyle(fontSize: 14, color: Colors.green.shade800, fontWeight: FontWeight.w500),
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
              if (_usingFallbackData)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3498DB).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Live places were unavailable, so showing nearest sample nutritionists for this location.',
                    style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
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
                    backgroundColor: Color(0xFF3498DB),
                    child: Icon(Icons.medical_services_outlined, color: Colors.white, size: 22),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: p.address.isNotEmpty
                      ? Text(
                          p.address,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        )
                      : null,
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openPlaceInMaps(p),
                ),
              )),
            ],
            if (!_loadingPlaces && _locationValid && _nearbyPlaces.isEmpty && _validatedLat != null) ...[
              const SizedBox(height: 20),
              Text(
                'No specific nutritionist places found in OpenStreetMap for this area.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 8),
              Text(
                'Open Google Maps to see nutritionists, dietitians, and clinics with reviews and directions.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
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
                backgroundColor: const Color(0xFF3498DB),
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
