// lib/widgets/smart_offline_map_widget.dart
//
// Smart Offline Map Widget for PathSaathi
//
// Automatically picks the best available tile source:
//   1. Local MBTiles (offline) — when bundle is downloaded for this city
//   2. OSM online tiles         — when online and no local bundle
//   3. Vector-drawn fallback    — when completely offline and no bundle
//
// Key design decisions:
//   - NO stored _activeTileMode state — computed freshly every build (avoids
//     addPostFrameCallback-in-build infinite loop that caused the key crash)
//   - NO shared MapController across FlutterMap instances (avoids GlobalKey
//     duplication crash: !keyReservation.contains(key))
//   - Each FlutterMap creates its own internal MapController
//   - OfflineMapWidget fallback is only shown, never alongside another FlutterMap

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_mbtiles/flutter_map_mbtiles.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/city_map_bundle.dart';
import '../services/map_bundle_service.dart';
import '../services/connectivity_service.dart';
import '../services/tile_cache_service.dart';
import 'hybrid_tile_provider.dart';
import 'offline_map_widget.dart';

class SmartOfflineMapWidget extends ConsumerWidget {
  /// The city whose bundle to prefer for local tiles.
  final String? cityId;

  /// Map center and zoom.
  final LatLng initialCenter;
  final double initialZoom;

  /// Optional route polyline to draw on the map.
  final List<LatLng>? routePoints;

  /// Optional marker for a specific destination.
  final LatLng? destinationMarker;
  final String? destinationName;

  /// Optional REAL user position (from GPS) to render as a "you are here" dot.
  final LatLng? userMarker;
  final double? userAccuracyM;

  /// Show the download prompt banner when bundle is missing.
  final bool showDownloadBanner;

  /// Absolute path to the pre-cached OSM tiles dir (from TileCacheService).
  /// When set AND [regionTilesCached] is true, real street tiles are served
  /// offline from here — the highest-priority source.
  final String? cachedTilesRoot;
  final bool regionTilesCached;

  const SmartOfflineMapWidget({
    super.key,
    this.cityId,
    required this.initialCenter,
    this.initialZoom = 14.0,
    this.routePoints,
    this.destinationMarker,
    this.destinationName,
    this.userMarker,
    this.userAccuracyM,
    this.showDownloadBanner = true,
    this.cachedTilesRoot,
    this.regionTilesCached = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity == ConnectivityStatus.offline;

    // Compute tile mode directly — no state, no setState, no GlobalKey issues
    final id = cityId;
    final bundleReady = id != null && MapBundleService.instance.isReady(id);
    final bundleState =
        id != null ? MapBundleService.instance.stateFor(id) : null;

    // Banners can be hidden entirely (e.g. when a host screen draws its own
    // top header + status chip, like the navigation screen).
    final banners = <Widget>[
      if (showDownloadBanner &&
          id != null &&
          !bundleReady &&
          !isOffline &&
          bundleState != null)
        _DownloadBanner(cityId: id, bundleState: bundleState),
      if (showDownloadBanner && isOffline && !bundleReady)
        const _OfflineFallbackBanner(),
      if (showDownloadBanner && bundleReady) const _MbTilesActiveBanner(),
    ];

    return Column(
      children: [
        // Keep info banners clear of the device status bar.
        if (banners.isNotEmpty)
          SafeArea(bottom: false, child: Column(children: banners)),
        Expanded(child: _buildMap(bundleReady, isOffline, id)),
      ],
    );
  }

  Widget _buildMap(bool bundleReady, bool isOffline, String? id) {
    final hasSource = TileCacheService.instance.hasCompliantSource;

    // Priority 0: LIVE map when connected. Uses the configured compliant source
    // (MapTiler) so the user can pan ANYWHERE, not just the downloaded region.
    // Each tile falls back per-tile to the local cache if that specific network
    // request fails (flaky-signal resilience), and successful tiles are written
    // back to the cache opportunistically. Never OSM's public servers.
    if (!isOffline && hasSource) {
      return _OsmMap(
        center: initialCenter,
        zoom: initialZoom,
        cacheRoot: cachedTilesRoot,
        routePoints: routePoints,
        destinationMarker: destinationMarker,
        destinationName: destinationName,
        userMarker: userMarker,
        userAccuracyM: userAccuracyM,
      );
    }

    // Priority 1: OFFLINE — pre-cached real street tiles (TileCacheService).
    // This is the genuine offline city map for the trip destination, restricted
    // to whatever was actually downloaded (tiles outside show transparent, not
    // broken squares).
    if (regionTilesCached && cachedTilesRoot != null) {
      return _CachedTilesMap(
        tilesRoot: cachedTilesRoot!,
        center: initialCenter,
        zoom: initialZoom,
        routePoints: routePoints,
        destinationMarker: destinationMarker,
        destinationName: destinationName,
        userMarker: userMarker,
        userAccuracyM: userAccuracyM,
      );
    }

    // Priority 2: local MBTiles bundle (offline, if present for this city).
    if (bundleReady && id != null) {
      final tiles = MapBundleService.instance.tilesFor(id);
      if (tiles != null)
        return _MbTilesMap(
          center: initialCenter,
          zoom: initialZoom,
          tiles: tiles,
          routePoints: routePoints,
          destinationMarker: destinationMarker,
          destinationName: destinationName,
          userMarker: userMarker,
          userAccuracyM: userAccuracyM,
        );
    }

    // Priority 3: vector polygon fallback (no FlutterMap GlobalKey conflict).
    // Reached when offline with no cached region/bundle, or when no compliant
    // source is configured at all. Keep the whole world visible on the map so a
    // trip can be plotted regardless of destination.
    return OfflineMapWidget(
      initialCenter: userMarker ?? const LatLng(20.0, 0.0),
      initialZoom: userMarker != null ? 2.6 : 2.0,
      sourceMarker: userMarker,
      destination: destinationMarker ?? initialCenter,
      routePoints: routePoints,
      destinationName: destinationName,
      markers: [],
    );
  }
}

/// A blue "you are here" dot with an accuracy ring, for real GPS position.
class _UserDot extends StatelessWidget {
  final double? accuracyM;
  const _UserDot({this.accuracyM});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

// ── MBTiles Map (separate stateless widget — owns its own MapController) ──────

class _MbTilesMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final dynamic tiles; // MbTiles
  final List<LatLng>? routePoints;
  final LatLng? destinationMarker;
  final String? destinationName;
  final LatLng? userMarker;
  final double? userAccuracyM;

  const _MbTilesMap({
    required this.center,
    required this.zoom,
    required this.tiles,
    this.routePoints,
    this.destinationMarker,
    this.destinationName,
    this.userMarker,
    this.userAccuracyM,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 4.0,
        maxZoom: 18.0,
      ),
      children: [
        TileLayer(
          tileProvider: MbTilesTileProvider(
            mbtiles: tiles,
            silenceTileNotFound: true,
          ),
          // NO online fallback. Missing MBTiles tiles must NOT fetch from OSM
          // (that caused the 403 "Access blocked"). Offline map = local only.
          errorTileCallback: (_, __, ___) {},
          evictErrorTileStrategy: EvictErrorTileStrategy.none,
        ),
        if (routePoints != null && routePoints!.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: routePoints!,
              color: const Color(0xFFFF6B00),
              strokeWidth: 4,
              pattern: const StrokePattern.solid(),
            ),
          ]),
        MarkerLayer(markers: [
          if (destinationMarker != null)
            Marker(
              point: destinationMarker!,
              width: 60,
              height: 70,
              child: _DestinationPin(label: destinationName ?? ''),
            ),
          if (userMarker != null)
            Marker(
              point: userMarker!,
              width: 40,
              height: 40,
              child: _UserDot(accuracyM: userAccuracyM),
            ),
        ]),
        RichAttributionWidget(attributions: [
          TextSourceAttribution('© OpenStreetMap contributors'),
          TextSourceAttribution('Offline — PathSaathi'),
        ]),
      ],
    );
  }
}

// ── Cached OSM tiles (offline) — real street tiles pre-downloaded by
//    TileCacheService into <appDocs>/tiles/{z}/{x}/{y}.png. Served locally with
//    FileTileProvider, so the destination city's real streets show OFFLINE. ──

class _CachedTilesMap extends StatelessWidget {
  final String tilesRoot; // absolute path to the tiles cache dir
  final LatLng center;
  final double zoom;
  final List<LatLng>? routePoints;
  final LatLng? destinationMarker;
  final String? destinationName;
  final LatLng? userMarker;
  final double? userAccuracyM;

  const _CachedTilesMap({
    required this.tilesRoot,
    required this.center,
    required this.zoom,
    this.routePoints,
    this.destinationMarker,
    this.destinationName,
    this.userMarker,
    this.userAccuracyM,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3.0,
        maxZoom: 19.0,
      ),
      children: [
        TileLayer(
          // Serve the pre-cached PNG tiles straight from local storage.
          tileProvider: FileTileProvider(),
          urlTemplate: '$tilesRoot/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pathsaathi.pathsaathi',
          errorTileCallback: (_, __, ___) {},
          evictErrorTileStrategy: EvictErrorTileStrategy.none,
        ),
        if (routePoints != null && routePoints!.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: routePoints!,
              color: const Color(0xFFFF6B00),
              strokeWidth: 4,
              pattern: const StrokePattern.solid(),
            ),
          ]),
        MarkerLayer(markers: [
          if (destinationMarker != null)
            Marker(
              point: destinationMarker!,
              width: 60,
              height: 70,
              child: _DestinationPin(label: destinationName ?? ''),
            ),
          if (userMarker != null)
            Marker(
              point: userMarker!,
              width: 40,
              height: 40,
              child: _UserDot(accuracyM: userAccuracyM),
            ),
        ]),
        RichAttributionWidget(attributions: [
          TextSourceAttribution('© OpenStreetMap contributors (offline cache)'),
        ]),
      ],
    );
  }
}

// ── OSM Online Map (separate stateless widget — owns its own MapController) ───

class _OsmMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final String? cacheRoot; // local tile cache for per-tile fallback
  final List<LatLng>? routePoints;
  final LatLng? destinationMarker;
  final String? destinationName;
  final LatLng? userMarker;
  final double? userAccuracyM;

  const _OsmMap({
    required this.center,
    required this.zoom,
    this.cacheRoot,
    this.routePoints,
    this.destinationMarker,
    this.destinationName,
    this.userMarker,
    this.userAccuracyM,
  });

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        minZoom: 3.0,
        maxZoom: 19.0,
      ),
      children: [
        TileLayer(
          // Uses ONLY the operator-configured compliant tile source (e.g. a
          // MapTiler key) — never OSM's public servers. This layer is only
          // reached when online AND hasCompliantSource is true (see _buildMap
          // gate). HybridTileProvider fetches each tile from the network, falls
          // back per-tile to the local cache when a request fails, and writes
          // successful tiles back to the cache for future offline use.
          urlTemplate: TileCacheService.instance.tileUrlTemplateOrEmpty,
          userAgentPackageName: 'com.pathsaathi.pathsaathi',
          tileProvider: HybridTileProvider(
            cacheRoot: cacheRoot,
            // NOTE: must be a MUTABLE map — flutter_map's TileLayer injects the
            // 'User-Agent' into this map, which throws if it's const/unmodifiable.
            headers: {
              'User-Agent': 'PathSaathi/1.0 (Infosys FYP pilgrim assistant)',
            },
          ),
          errorTileCallback: (_, __, ___) {},
          evictErrorTileStrategy: EvictErrorTileStrategy.none,
        ),
        if (routePoints != null && routePoints!.isNotEmpty)
          PolylineLayer(polylines: [
            Polyline(
              points: routePoints!,
              color: const Color(0xFFFF6B00),
              strokeWidth: 4,
              pattern: const StrokePattern.solid(),
            ),
          ]),
        MarkerLayer(markers: [
          if (destinationMarker != null)
            Marker(
              point: destinationMarker!,
              width: 60,
              height: 70,
              child: _DestinationPin(label: destinationName ?? ''),
            ),
          if (userMarker != null)
            Marker(
              point: userMarker!,
              width: 40,
              height: 40,
              child: _UserDot(accuracyM: userAccuracyM),
            ),
        ]),
        RichAttributionWidget(attributions: [
          TextSourceAttribution('© OpenStreetMap contributors'),
        ]),
      ],
    );
  }
}

// ── Banner Widgets ────────────────────────────────────────────────────────────

class _DownloadBanner extends StatelessWidget {
  final String cityId;
  final BundleDownloadState bundleState;

  const _DownloadBanner({
    required this.cityId,
    required this.bundleState,
  });

  @override
  Widget build(BuildContext context) {
    final bundle = CityBundleCatalog.findById(cityId);
    if (bundle == null) return const SizedBox.shrink();
    final isDownloading = bundleState.isActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFFFFF7ED),
      child: Row(children: [
        const Icon(Icons.download_for_offline_rounded,
            color: Color(0xFFF97316), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDownloading
                    ? 'Downloading offline map…'
                    : 'Download map (${bundle.mbtilesSize} MB) — use without internet',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9A3412)),
              ),
              if (isDownloading) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: bundleState.progress,
                    backgroundColor: const Color(0xFFFFE4CC),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFF97316)),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(bundleState.progressLabel,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9A3412))),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (!isDownloading)
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFF97316),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => MapBundleService.instance.downloadBundle(cityId),
            child: const Text('Download',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          )
        else
          TextButton(
            onPressed: () => MapBundleService.instance.cancelDownload(cityId),
            child: const Text('Cancel',
                style: TextStyle(fontSize: 11, color: Color(0xFF9A3412))),
          ),
      ]),
    ).animate().slideY(begin: -0.5, duration: 300.ms);
  }
}

class _OfflineFallbackBanner extends StatelessWidget {
  const _OfflineFallbackBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFFFEF2F2),
      child: const Row(children: [
        Icon(Icons.wifi_off_rounded, color: Color(0xFFDC2626), size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'No internet. Showing basic map. Download offline map on WiFi for street detail.',
            style: TextStyle(fontSize: 11, color: Color(0xFF991B1B)),
          ),
        ),
      ]),
    );
  }
}

class _MbTilesActiveBanner extends StatelessWidget {
  const _MbTilesActiveBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      color: const Color(0xFFF0FDF4),
      child: const Row(children: [
        Icon(Icons.offline_bolt_rounded, color: Color(0xFF16A34A), size: 16),
        SizedBox(width: 8),
        Text(
          '✓ Offline map active — full street detail without internet',
          style: TextStyle(
              fontSize: 11,
              color: Color(0xFF166534),
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }
}

class _DestinationPin extends StatelessWidget {
  final String label;
  const _DestinationPin({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        const Icon(Icons.location_pin, color: Color(0xFFFF6B00), size: 36),
      ],
    );
  }
}
