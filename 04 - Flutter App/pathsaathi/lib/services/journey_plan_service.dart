// lib/services/journey_plan_service.dart
//
// The CORE "online-prepares → offline-survives" logic.
//
//  • NearbyPlacesRepository — nearby help (hotel/hospital/food/water/help) with
//    coordinates, read from the on-device DB (works offline).
//  • JourneyPlanService — reads/holds the active journey plan.
//  • PreCacheService — while ONLINE (WiFi), caches everything the user will need
//    offline at the destination: real OSM map tiles + nearby places + a route
//    path to the stay. Reports honest progress + cache status. Offline it does
//    nothing (no network calls) and the app uses whatever is already cached.

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../database/app_database.dart';
import '../models/journey_models.dart';
import 'connectivity_service.dart';
import 'tile_cache_service.dart';

/// Nearby help places for a destination (offline, from the local DB).
class NearbyPlacesRepository {
  NearbyPlacesRepository._();
  static final NearbyPlacesRepository instance = NearbyPlacesRepository._();

  Future<List<NearbyPlace>> forDestination(String destinationKey,
      {String? category}) async {
    final rows = await AppDatabase.instance
        .getNearbyPlaces(destinationKey, category: category);
    return rows.map(NearbyPlace.fromRow).toList();
  }

  /// Nearby places sorted by real distance from a given position.
  Future<List<NearbyPlace>> nearestTo(String destinationKey, LatLng from,
      {String? category}) async {
    final list = await forDestination(destinationKey, category: category);
    const d = Distance();
    list.sort((a, b) => d
        .as(LengthUnit.Meter, from, a.coords)
        .compareTo(d.as(LengthUnit.Meter, from, b.coords)));
    return list;
  }
}

/// Reads and exposes the active journey plan.
class JourneyPlanService {
  JourneyPlanService._();
  static final JourneyPlanService instance = JourneyPlanService._();

  Future<JourneyPlan?> active() async {
    final row = await AppDatabase.instance.getActivePlan();
    return row == null ? null : JourneyPlan.fromRow(row);
  }
}

/// Progress + result of a pre-cache run.
class PreCacheProgress {
  final double tilesProgress; // 0..1
  final CacheStatus status;
  final String message;
  final bool done;

  const PreCacheProgress({
    this.tilesProgress = 0,
    this.status = const CacheStatus(),
    this.message = '',
    this.done = false,
  });
}

/// Orchestrates caching the destination-area data for offline use.
class PreCacheService {
  PreCacheService._();
  static final PreCacheService instance = PreCacheService._();

  /// Prepare the active plan for offline use. Emits progress via [onUpdate].
  /// Only performs network work when ONLINE (WiFi/ethernet → status.online);
  /// on mobile/offline it caches nothing new and reports honestly.
  Future<CacheStatus> prepare({
    void Function(PreCacheProgress p)? onUpdate,
  }) async {
    final plan = await JourneyPlanService.instance.active();
    if (plan == null || plan.destinationCoords == null) {
      onUpdate?.call(const PreCacheProgress(
          message: 'No active journey to prepare.', done: true));
      return const CacheStatus();
    }

    final online =
        ConnectivityService.instance.status == ConnectivityStatus.online;
    var status = plan.cacheStatus;

    // ── 1. Nearby places (from local DB — always available, no network) ──
    final places = await NearbyPlacesRepository.instance
        .forDestination(plan.destinationId);
    if (places.isNotEmpty) {
      status = status.copyWith(places: true);
      await AppDatabase.instance.updatePlanCacheStatus(plan.id, places: true);
    }
    onUpdate?.call(PreCacheProgress(
        status: status,
        message: places.isNotEmpty
            ? 'Nearby help ready (${places.length} places).'
            : 'No nearby places for this destination yet.'));

    // ── 2. Route path to the stay (curated straight path for Level A nav) ──
    // A simple 2-point path (destination center → nearest hotel) is enough for
    // offline direction+distance guidance; it needs no network.
    status = status.copyWith(route: true);
    await AppDatabase.instance.updatePlanCacheStatus(plan.id, route: true);

    // ── 3. Real OSM map tiles for the region (NETWORK — WiFi only) ──
    if (!online) {
      onUpdate?.call(PreCacheProgress(
          status: status,
          message: 'Offline — map tiles will download when on WiFi. '
              'Nearby help and guidance are ready now.',
          done: true));
      return status;
    }

    // Offline map installation is app-wide. Reuse it for every future trip;
    // detailed tiles for a destination are optional and must not re-trigger
    // the same download flow.
    final already = await TileCacheService.instance.isOfflineMapInstalled();
    if (already) {
      status = status.copyWith(tiles: true);
      await AppDatabase.instance.updatePlanCacheStatus(plan.id, tiles: true);
      onUpdate?.call(PreCacheProgress(
          tilesProgress: 1,
          status: status,
          message: 'Offline map ready.',
          done: true));
      return status;
    }

    // COMPLIANCE: we do not bulk-download from OSM's public servers. If no
    // permitted tile source is configured, skip street-tile caching truthfully
    // (nearby help + guidance still work offline).
    if (!TileCacheService.instance.hasCompliantSource) {
      onUpdate?.call(PreCacheProgress(
          status: status,
          message: 'Offline street map needs a configured map provider. '
              'Nearby help, route guidance and GPS direction work offline now.',
          done: true));
      return status;
    }

    onUpdate?.call(PreCacheProgress(
        status: status, message: 'Downloading offline map for the trip area…'));
    final ok = await TileCacheService.instance.downloadRegion(
      plan.destinationCoords!,
      onProgress: (p) => onUpdate?.call(PreCacheProgress(
          tilesProgress: p,
          status: status,
          message: 'Downloading offline map…')),
    );
    if (ok) {
      status = status.copyWith(tiles: true);
      await AppDatabase.instance.updatePlanCacheStatus(plan.id, tiles: true);
    }
    debugPrint('[PreCacheService] tiles cached=$ok');

    onUpdate?.call(PreCacheProgress(
        tilesProgress: ok ? 1 : 0,
        status: status,
        message: ok
            ? 'Journey ready for offline use.'
            : 'Map download incomplete — nearby help + guidance still work offline.',
        done: true));
    return status;
  }
}
