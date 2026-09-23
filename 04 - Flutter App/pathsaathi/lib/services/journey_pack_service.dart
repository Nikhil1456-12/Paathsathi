// lib/services/journey_pack_service.dart
//
// Destination-AGNOSTIC Offline Journey Pack.
//
// Given ANY confirmed destination (a canonical `Place`), this service builds and
// persists an offline "Journey Pack" for it — with NO hardcoded city list and NO
// destination-specific logic. The confirmed Place (id / name / coords / category)
// is the sole source of truth.
//
// Honesty rules (never fabricate):
//   • Each category is tagged AVAILABLE (real local data), UNAVAILABLE (no local
//     source), or LIVE_ONLY (only obtainable online — must not be faked offline).
//   • Categories we can genuinely fill from existing on-device data:
//       - destination info (from the Place itself)
//       - nearby known POIs (other Places within a radius, by category)
//   • Everything requiring a real external source (live transport schedules,
//     hotel availability, prices, full street routing, exhaustive POIs) is left
//     UNAVAILABLE or LIVE_ONLY behind a provider boundary — not invented.
//
// Persistence reuses SharedPreferences (same mechanism as travel context /
// language), keyed by the destination id, so a prepared pack survives restart
// and is fully usable with no network.

import 'dart:convert';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'place_search_service.dart';

/// Availability status for each pack category — the caller/UI must show this and
/// never present UNAVAILABLE / LIVE_ONLY as current offline facts.
enum PackDataStatus { available, unavailable, liveOnly }

extension PackDataStatusX on PackDataStatus {
  String get label {
    switch (this) {
      case PackDataStatus.available: return 'DOWNLOADED/AVAILABLE';
      case PackDataStatus.unavailable: return 'UNAVAILABLE';
      case PackDataStatus.liveOnly: return 'LIVE/ONLINE ONLY';
    }
  }
}

/// One category section of a Journey Pack.
class PackSection {
  final String category;        // 'landmarks','hospitals','transport', etc.
  final PackDataStatus status;
  final List<Map<String, dynamic>> items; // real data only when AVAILABLE

  const PackSection({required this.category, required this.status, this.items = const []});

  Map<String, dynamic> toJson() => {
        'category': category,
        'status': status.name,
        'items': items,
      };

  factory PackSection.fromJson(Map<String, dynamic> j) => PackSection(
        category: j['category'] as String,
        status: PackDataStatus.values.firstWhere((s) => s.name == j['status'],
            orElse: () => PackDataStatus.unavailable),
        items: (j['items'] as List?)?.cast<Map<String, dynamic>>() ?? const [],
      );
}

/// The offline Journey Pack for one confirmed destination.
class JourneyPack {
  final String destinationId;
  final String destinationName;
  final double lat;
  final double lng;
  final String preparedAtIso; // when the pack was prepared (for freshness/honesty)
  final Map<String, PackSection> sections;

  const JourneyPack({
    required this.destinationId,
    required this.destinationName,
    required this.lat,
    required this.lng,
    required this.preparedAtIso,
    required this.sections,
  });

  LatLng get coords => LatLng(lat, lng);

  Map<String, dynamic> toJson() => {
        'destinationId': destinationId,
        'destinationName': destinationName,
        'lat': lat,
        'lng': lng,
        'preparedAt': preparedAtIso,
        'sections': sections.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory JourneyPack.fromJson(Map<String, dynamic> j) => JourneyPack(
        destinationId: j['destinationId'] as String,
        destinationName: j['destinationName'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        preparedAtIso: j['preparedAt'] as String,
        sections: (j['sections'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, PackSection.fromJson(v as Map<String, dynamic>)),
        ),
      );
}

/// Provider boundary for pack data sources. The default implementation derives
/// what it honestly can from the on-device place index; missing real sources
/// return UNAVAILABLE / LIVE_ONLY rather than fabricating data. Real providers
/// (offline maps, live transport, etc.) can be plugged in later WITHOUT changing
/// the destination-agnostic pack pipeline.
abstract class PackDataProvider {
  /// Category name this provider fills (e.g. 'hospitals').
  String get category;

  /// Build the section for [destination]. Must never fabricate data.
  PackSection build(Place destination, List<Place> allPlaces);
}

/// Destination info — always AVAILABLE (derived from the Place itself).
class _DestinationInfoProvider extends PackDataProvider {
  @override
  String get category => 'destination_info';
  @override
  PackSection build(Place d, List<Place> all) => PackSection(
        category: category,
        status: PackDataStatus.available,
        items: [
          {
            'id': d.id,
            'name': d.name,
            'category': d.category,
            'lat': d.coords.latitude,
            'lng': d.coords.longitude,
            if (d.note != null) 'note': d.note,
          }
        ],
      );
}

/// Nearby-known-POI provider: for a given target category, include OTHER places
/// from the on-device index within [radiusKm] of the destination. This is real,
/// non-fabricated data. If none are known locally, status = UNAVAILABLE (we do
/// not invent POIs). Works for ANY destination purely by proximity + category.
class _NearbyPoiProvider extends PackDataProvider {
  final String _category;
  final Set<String> _matchCategories; // Place.category values that qualify
  static const double radiusKm = 60;
  static const _dist = Distance();

  _NearbyPoiProvider(this._category, this._matchCategories);

  @override
  String get category => _category;

  @override
  PackSection build(Place d, List<Place> all) {
    final items = <Map<String, dynamic>>[];
    for (final p in all) {
      if (p.id == d.id) continue;
      if (!_matchCategories.contains(p.category)) continue;
      final km = _dist.as(LengthUnit.Kilometer, d.coords, p.coords);
      if (km <= radiusKm) {
        items.add({
          'id': p.id,
          'name': p.name,
          'category': p.category,
          'lat': p.coords.latitude,
          'lng': p.coords.longitude,
          'distance_km': double.parse(km.toStringAsFixed(1)),
        });
      }
    }
    items.sort((a, b) => (a['distance_km'] as double).compareTo(b['distance_km'] as double));
    return PackSection(
      category: _category,
      status: items.isNotEmpty ? PackDataStatus.available : PackDataStatus.unavailable,
      items: items,
    );
  }
}

/// A category whose real data requires an external/online source we do not have
/// on-device. It is honestly reported (UNAVAILABLE offline or LIVE_ONLY) — never
/// fabricated. Plug a real provider in later without touching the pipeline.
class _UnsourcedProvider extends PackDataProvider {
  final String _category;
  final PackDataStatus _status;
  _UnsourcedProvider(this._category, this._status);
  @override
  String get category => _category;
  @override
  PackSection build(Place d, List<Place> all) =>
      PackSection(category: _category, status: _status, items: const []);
}

class JourneyPackService {
  JourneyPackService._();
  static final JourneyPackService instance = JourneyPackService._();

  static const _keyPrefix = 'journey_pack_'; // + destinationId

  /// The set of providers. Adding a real data source later = add a provider;
  /// no destination-specific code anywhere.
  final List<PackDataProvider> _providers = [
    _DestinationInfoProvider(),
    // Real, derivable-from-local-index categories (by POI category + proximity):
    _NearbyPoiProvider('landmarks', {'temple', 'ghat', 'city'}),
    _NearbyPoiProvider('hospitals', {'hospital'}),
    _NearbyPoiProvider('railway_stations', {'station'}),
    _NearbyPoiProvider('transport', {'transport'}),
    // Categories with no on-device source yet — honest placeholders (no data):
    _UnsourcedProvider('pharmacies', PackDataStatus.unavailable),
    _UnsourcedProvider('hotels', PackDataStatus.unavailable),
    _UnsourcedProvider('airports', PackDataStatus.unavailable),
    _UnsourcedProvider('offline_map', PackDataStatus.unavailable),
    // Genuinely live-only categories (must never be presented as current offline):
    _UnsourcedProvider('live_transport', PackDataStatus.liveOnly),
    _UnsourcedProvider('emergency_live', PackDataStatus.liveOnly),
  ];

  /// Build a pack for ANY confirmed destination. Pure/synchronous — no network,
  /// no fabrication. Uses the existing on-device place index for real POIs.
  JourneyPack build(Place destination) {
    const all = PlaceSearchService.places;
    final sections = <String, PackSection>{};
    for (final prov in _providers) {
      sections[prov.category] = prov.build(destination, all);
    }
    return JourneyPack(
      destinationId: destination.id,
      destinationName: destination.name,
      lat: destination.coords.latitude,
      lng: destination.coords.longitude,
      preparedAtIso: DateTime.now().toIso8601String(),
      sections: sections,
    );
  }

  /// "Download"/prepare + persist locally for the confirmed destination.
  /// (Preparation is local here; a future real provider may fetch/store tiles
  /// behind the same call without changing callers.)
  Future<JourneyPack> prepareAndSave(Place destination) async {
    final pack = build(destination);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPrefix${destination.id}', jsonEncode(pack.toJson()));
    } catch (_) {}
    return pack;
  }

  /// Load a previously-prepared pack by destination id (offline-safe). Returns
  /// null if no pack was prepared for that destination.
  Future<JourneyPack?> load(String destinationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyPrefix$destinationId');
      if (raw == null || raw.isEmpty) return null;
      return JourneyPack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> isPrepared(String destinationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_keyPrefix$destinationId') != null;
    } catch (_) {
      return false;
    }
  }
}
