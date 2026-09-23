// lib/services/transport_repository.dart
//
// Reads curated, offline transport options for a confirmed destination from the
// on-device SQLite DB. Times/prices are indicative prototype data (labelled in
// the UI), never a live/paid reservation. Returns an empty list truthfully when
// no data exists for a route (the UI must say so, not invent options).

import '../database/app_database.dart';
import '../models/journey_models.dart';
import 'place_search_service.dart';
import 'india_gazetteer.dart';
import 'package:latlong2/latlong.dart';

class TransportRepository {
  TransportRepository._();
  static final TransportRepository instance = TransportRepository._();

  /// Map a resolved [Place] to the transport dataset key (`destination_id`).
  ///
  /// Place ids can be more specific than the transport key (e.g.
  /// `varanasi_city`, `kashi_vishwanath` → `varanasi`). This keeps the curated
  /// dataset shared across a destination's variants without duplicating rows.
  static String destinationKeyForPlace(Place p) {
    final id = p.id.toLowerCase();
    // Explicit collapses for known place-id variants.
    if (id.startsWith('varanasi') || id.startsWith('kashi')) return 'varanasi';
    if (id.startsWith('dwarka') || id.startsWith('dwaraka')) return 'dwarka';
    // Default: the place id IS the key (kedarnath, mumbai, hyderabad, ...).
    return id;
  }

  /// Curated transport options for a destination place. Empty list = no data
  /// (the caller shows a truthful "no transport data" state).
  Future<List<TransportOption>> optionsForPlace(Place p) async {
    final key = destinationKeyForPlace(p);
    final rows = await AppDatabase.instance.getTransportOptions(key);
    return rows.map(TransportOption.fromRow).toList();
  }

  /// Bind indicative transport templates to the user's real origin. The
  /// database stores operator/schedule templates, not a universal route; the
  /// displayed ticket must never retain an unrelated seeded origin or target.
  Future<List<TransportOption>> optionsForRoute(
    Place destination, {
    required LatLng origin,
  }) async {
    final options = await optionsForPlace(destination);
    final originName = _originHubName(origin);
    final destinationHub = IndiaGazetteer.instance
            .byId(destinationKeyForPlace(destination))
            ?.transportHub ??
        '${destination.name} transport hub';
    return options
        .map((option) => option.copyWith(
              fromName: originName,
              toName: destinationHub,
              indicative: true,
              dataTier: 'route-bound-template',
            ))
        .toList();
  }

  String _originHubName(LatLng origin) {
    GazetteerEntry? nearest;
    var nearestDistance = double.infinity;
    for (final entry in IndiaGazetteer.entries) {
      final distance = const Distance().as(
        LengthUnit.Kilometer,
        origin,
        entry.coords,
      );
      if (distance < nearestDistance) {
        nearest = entry;
        nearestDistance = distance;
      }
    }
    if (nearest != null && nearestDistance <= 80) {
      return '${nearest.name} transport hub';
    }
    return 'Your current GPS location';
  }

  /// Options grouped by mode ('train', 'bus', 'bus+train') for display.
  Future<Map<String, List<TransportOption>>> groupedForPlace(Place p) async {
    final all = await optionsForPlace(p);
    final grouped = <String, List<TransportOption>>{};
    for (final o in all) {
      grouped.putIfAbsent(o.mode, () => []).add(o);
    }
    return grouped;
  }
}
