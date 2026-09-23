// lib/screens/navigation_screen.dart
//
// Offline, GPS-driven navigation for a lost pilgrim.
//
// Truthful by design:
//   • Real device GPS via LocationService (no fake "GPS Lock").
//   • Offline place search (PlaceSearchService) — "Kashi" resolves locally.
//   • Road routing from the offline graph or online router, with live rerouting.
//   • Bearing/distance remains available when no road route can be obtained.
//   • One-glance Pilgrim Mode card for stressed users.
//   • Offline map via SmartOfflineMapWidget (MBTiles → OSM → vector fallback).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';
import '../services/guidance_service.dart';
import '../services/routing_service.dart';
import '../services/connectivity_service.dart';
import '../services/tts_service.dart';
import '../services/tile_cache_service.dart';
import '../providers/travel_context.dart';
import '../providers/language_provider.dart';
import '../widgets/smart_offline_map_widget.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});
  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  Place? _destination; // set from confirmed travel context, else Kashi fallback
  LatLng? _origin; // corridor anchor for off-route detection
  bool _pilgrimMode = true; // default to the simple, one-glance view
  final _searchCtrl = TextEditingController();
  List<Place> _results = const [];
  String? _routeCacheKey;
  RouteResult? _routeResult;
  LatLng? _routeRequestPosition;
  DateTime? _lastRouteRequestAt;
  bool _routeLoading = false;

  @override
  void initState() {
    super.initState();
    // Start GPS as soon as the screen opens.
    LocationService.instance.start();
    // Anchor the off-route corridor at the first known position (if any).
    _origin = LocationService.instance.last.position;
    // Load the pre-cached real-street-tile state for the destination so the
    // offline map shows actual city streets (not the decorative overview).
    _loadCachedTiles();
  }

  String? _cachedTilesRoot;
  bool _regionTilesCached = false;
  bool _offlineMapInstalled = false;
  bool _checkingTiles = true;

  // Offline-tile download state for the honest download UI.
  bool _downloading = false;
  double _downloadProgress = 0; // 0..1

  Future<void> _loadCachedTiles() async {
    final dest = _resolveActiveDestination();
    final root = await TileCacheService.instance.tilesRootPath();
    final installed = await TileCacheService.instance.isOfflineMapInstalled();
    final cached = await TileCacheService.instance.isRegionCached(dest.coords);
    if (!mounted) return;
    setState(() {
      _cachedTilesRoot = root;
      _regionTilesCached = cached;
      _offlineMapInstalled = installed;
      _checkingTiles = false;
    });
  }

  /// Download real street tiles for the ACTIVE destination so the map works
  /// fully offline. Requires internet the first time (uses the configured
  /// compliant MapTiler source — never OSM public servers). Honest about
  /// state: shows progress, and if no compliant source or no network, tells
  /// the user plainly instead of silently doing nothing.
  Future<void> _downloadTiles() async {
    if (_downloading) return;
    final svc = TileCacheService.instance;
    if (!svc.hasCompliantSource) {
      _snack('Offline map source not configured on this build.');
      return;
    }
    final dest = _resolveActiveDestination();
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    _snack('Downloading offline map for ${dest.name}… keep WiFi on.');
    final ok = await svc.downloadRegion(
      dest.coords,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _downloadProgress = p);
      },
    );
    if (!mounted) return;
    final cached = await svc.isRegionCached(dest.coords);
    if (cached) {
      await svc.markOfflineMapInstalled();
    }
    final installed = cached || await svc.isOfflineMapInstalled();
    setState(() {
      _downloading = false;
      _regionTilesCached = cached;
      _offlineMapInstalled = installed;
      _checkingTiles = false;
    });
    _snack(ok && cached
        ? 'Offline map ready for ${dest.name}. Works without internet now.'
        : 'Download did not complete. Check your connection and try again.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// The destination the map should use: the user's CONFIRMED destination if
  /// one exists (spoken + confirmed), else a local override from search, else
  /// Kashi as the pilgrimage default. Never silently swaps a confirmed place.
  Place _resolveActiveDestination() {
    if (_destination != null) return _destination!;
    final confirmed = ref.read(travelContextProvider).confirmedDestination;
    return confirmed ?? PlaceSearchService.instance.kashi;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    TTSService.instance.stop();
    super.dispose();
  }

  void _onSearch(String q) {
    setState(() => _results = PlaceSearchService.instance.search(q));
  }

  void _selectDestination(Place p) {
    setState(() {
      _destination = p;
      _results = const [];
      _searchCtrl.clear();
      // Re-anchor the corridor at the current position when a new destination
      // is chosen, so off-route is measured from where the user starts.
      _origin = LocationService.instance.last.position;
    });
    // A tapped search result is an explicit choice → treat as confirmed.
    ref.read(travelContextProvider.notifier).setConfirmed(p);
    FocusScope.of(context).unfocus();
  }

  Future<void> _recenter() async {
    final pos = await LocationService.instance.currentOnce();
    if (!mounted) return;
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('No GPS fix yet. Move to open sky and wait a few seconds.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
    // Rebuild recenters the map via the ValueKey on user position.
    setState(() {});
  }

  Future<void> _refreshRoute(LatLng user, LatLng destination) async {
    if (_routeLoading) return;
    _routeLoading = true;
    final localRoute = await RoutingService.instance.route(user, destination);
    final route = localRoute ??
        (ConnectivityService.instance.status != ConnectivityStatus.offline
            ? await RoutingService.instance.routeOnline(user, destination)
            : null);
    if (!mounted) {
      _routeLoading = false;
      return;
    }
    final key = '${destination.latitude.toStringAsFixed(5)}:'
        '${destination.longitude.toStringAsFixed(5)}';
    setState(() {
      _routeCacheKey = key;
      _routeResult = route;
      _routeRequestPosition = user;
      _lastRouteRequestAt = DateTime.now();
    });
    _routeLoading = false;
  }

  bool _needsRouteRefresh(LatLng user, LatLng destination) {
    final last = _routeRequestPosition;
    final at = _lastRouteRequestAt;
    if (last == null || at == null) return true;
    if (DateTime.now().difference(at) < const Duration(seconds: 10)) {
      return false;
    }
    final moved = const Distance().as(LengthUnit.Meter, last, user);
    final destinationKey = '${destination.latitude.toStringAsFixed(5)}:'
        '${destination.longitude.toStringAsFixed(5)}';
    return moved >= 50 || _routeCacheKey != destinationKey;
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final snap = ref.watch(locationProvider).maybeWhen(
          data: (s) => s,
          orElse: () => LocationService.instance.last,
        );

    final user = snap.state.hasFix ? snap.position : null;
    final activeDest = _resolveActiveDestination();
    final dest = activeDest.coords;
    final hasLiveLocation = user != null;

    if (user != null) {
      if (_needsRouteRefresh(user, dest)) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _refreshRoute(user, dest));
      }
    }

    // Anchor corridor lazily at first fix if we didn't have one at init.
    if (user != null && _origin == null) _origin = user;

    Guidance? g;
    if (user != null) {
      g = GuidanceService.instance.compute(
        user: user,
        destination: dest,
        origin: _origin,
      );
    }

    final route = connectivity == ConnectivityStatus.offline &&
            _routeResult?.isOnline == true
        ? null
        : _routeResult;
    final routePoints = user != null ? route?.points : null;
    final showBundledOverview =
        connectivity == ConnectivityStatus.offline && !_regionTilesCached;

    return Scaffold(
      body: Stack(children: [
        // ── Offline map ────────────────────────────────────────────────────
        Positioned.fill(
          child: SmartOfflineMapWidget(
            key: ValueKey('nav_${user?.latitude ?? 0}_${activeDest.id}'),
            cityId: activeDest.id == 'kashi_vishwanath' ||
                    activeDest.id == 'varanasi_city'
                ? 'varanasi'
                : 'prayagraj',
            // The map opens at the traveller's source. The destination stays
            // visible as a target marker, but must not replace the user's
            // current location as the map center.
            initialCenter:
                user ?? (showBundledOverview ? const LatLng(22.8, 80.0) : dest),
            initialZoom:
                user != null ? 15.5 : (showBundledOverview ? 4.8 : 12.0),
            destinationMarker: dest,
            destinationName: hasLiveLocation
                ? activeDest.name
                : 'Destination preview: ${activeDest.name}',
            userMarker: user,
            userAccuracyM: snap.accuracyM,
            routePoints: routePoints,
            // Nav screen draws its own header + GPS chip; suppress the map's
            // own top banners so nothing collides with the status bar / header.
            showDownloadBanner: false,
            // Serve REAL pre-cached OSM street tiles for the destination city
            // when they've been downloaded (offline). Falls back to the overview
            // map when not cached.
            cachedTilesRoot: _cachedTilesRoot,
            regionTilesCached: _regionTilesCached,
          ),
        ),

        // ── Top: truthful GPS chip + search ────────────────────────────────
        SafeArea(
          bottom: false,
          child: Column(children: [
            Container(
              color: _green,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(children: [
                IconButton(
                  onPressed: () => smartBack(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(child: _GpsChip(snap: snap)),
                IconButton(
                  key: const Key('open_journey_pack'),
                  tooltip: 'Offline Journey Pack',
                  onPressed: () => context.push('/journey-pack'),
                  icon: const Icon(Icons.inventory_2_outlined,
                      color: Colors.white),
                ),
                IconButton(
                  tooltip: _pilgrimMode ? 'Show map view' : 'Simple view',
                  onPressed: () => setState(() => _pilgrimMode = !_pilgrimMode),
                  icon: Icon(
                      _pilgrimMode ? Icons.map_rounded : Icons.explore_rounded,
                      color: Colors.white),
                ),
              ]),
            ),
            // Search box (offline)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8)
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearch,
                    decoration: InputDecoration(
                      hintText: 'Search offline: Kashi, station, hospital…',
                      hintStyle: GoogleFonts.outfit(
                          fontSize: 13, color: const Color(0xFF9CA3AF)),
                      prefixIcon: const Icon(Icons.search, color: _green),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 14),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 8)
                      ],
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: _results
                          .map((p) => ListTile(
                                dense: true,
                                leading: Icon(_catIcon(p.category),
                                    color: _saffron, size: 20),
                                title: Text(p.name,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                subtitle: p.note != null
                                    ? Text(p.note!,
                                        style: GoogleFonts.outfit(fontSize: 11))
                                    : null,
                                onTap: () => _selectDestination(p),
                              ))
                          .toList(),
                    ),
                  ),
              ]),
            ),
          ]),
        ),

        // ── Offline-map download status pill (honest: not-cached / downloading
        //    / ready). Lets the user pre-download real street tiles on WiFi so
        //    the map works offline. ────────────────────────────────────────
        if (!_checkingTiles)
          Positioned(
            left: 12,
            right: 12,
            bottom: _pilgrimMode ? 250 : 190,
            child: _OfflineTilePill(
              cached: _offlineMapInstalled,
              downloading: _downloading,
              progress: _downloadProgress,
              destinationName: activeDest.name,
              onDownload: _downloadTiles,
            ),
          ),

        // ── Bottom sheet: Pilgrim card OR map controls ─────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: _pilgrimMode
              ? _PilgrimCard(
                  destination: activeDest,
                  guidance: g,
                  route: route,
                  snap: snap,
                  onRecenter: _recenter,
                  onFixGps: () => _handleGpsAction(snap.state),
                  langCode: ref.watch(languageProvider).code,
                )
              : _MapControls(
                  destination: activeDest,
                  guidance: g,
                  onRecenter: _recenter,
                ),
        ),
      ]),
    );
  }

  Future<void> _handleGpsAction(GpsState s) async {
    if (s == GpsState.servicesOff) {
      await LocationService.instance.openLocationSettings();
    } else if (s == GpsState.permissionForever) {
      await LocationService.instance.openAppSettings();
    } else {
      await LocationService.instance.start();
    }
  }

  static IconData _catIcon(String c) {
    switch (c) {
      case 'temple':
        return Icons.temple_hindu_rounded;
      case 'station':
        return Icons.train_rounded;
      case 'hospital':
        return Icons.local_hospital_rounded;
      case 'ghat':
        return Icons.water_rounded;
      case 'transport':
        return Icons.directions_bus_rounded;
      case 'city':
        return Icons.location_city_rounded;
      default:
        return Icons.place_rounded;
    }
  }
}

// ── Truthful GPS status chip ──────────────────────────────────────────────────
class _GpsChip extends StatelessWidget {
  final LocationSnapshot snap;
  const _GpsChip({required this.snap});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (snap.state) {
      GpsState.ready => (const Color(0xFF16A34A), Icons.gps_fixed),
      GpsState.lowAccuracy => (const Color(0xFFD97706), Icons.gps_not_fixed),
      GpsState.searching => (const Color(0xFFD97706), Icons.gps_not_fixed),
      GpsState.servicesOff => (
          const Color(0xFFDC2626),
          Icons.location_disabled
        ),
      GpsState.permissionDenied => (
          const Color(0xFFDC2626),
          Icons.location_disabled
        ),
      GpsState.permissionForever => (
          const Color(0xFFDC2626),
          Icons.location_disabled
        ),
      _ => (const Color(0xFF9CA3AF), Icons.location_searching),
    };
    final acc = snap.accuracyM;
    final label =
        snap.state == GpsState.ready || snap.state == GpsState.lowAccuracy
            ? '${snap.state.label}  ±${acc?.round() ?? '?'} m'
            : snap.state.label;
    return Row(children: [
      Icon(icon, color: Colors.white, size: 16),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600)),
      ),
      const SizedBox(width: 6),
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    ]);
  }
}

// ── Offline-map download status pill ──────────────────────────────────────────
// Honest three-state control:
//   • ready      → green "Offline map ready" (tiles are on disk, no network)
//   • downloading→ progress bar with % (fetching real street tiles)
//   • not cached → tappable "Download offline map" (needs WiFi once)
class _OfflineTilePill extends StatelessWidget {
  final bool cached;
  final bool downloading;
  final double progress;
  final String destinationName;
  final VoidCallback onDownload;

  const _OfflineTilePill({
    required this.cached,
    required this.downloading,
    required this.progress,
    required this.destinationName,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    if (cached) {
      return _pill(
        color: const Color(0xFF16A34A),
        icon: Icons.offline_pin_rounded,
        child: Text('Offline map ready',
            style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
    }
    if (downloading) {
      final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
      return _pill(
        color: const Color(0xFF0F766E),
        icon: Icons.downloading_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Downloading offline map… $pct%',
                style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress <= 0 ? null : progress,
                minHeight: 4,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ],
        ),
      );
    }
    // Not cached → offer download.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onDownload,
        child: _pill(
          color: _saffron,
          icon: Icons.download_for_offline_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Download offline map',
                  style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('Real streets of $destinationName · needs WiFi once',
                  overflow: TextOverflow.ellipsis,
                  style:
                      GoogleFonts.outfit(fontSize: 11, color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill({
    required Color color,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3))
        ],
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: child),
      ]),
    );
  }
}

// ── One-glance Pilgrim Mode card ──────────────────────────────────────────────
class _PilgrimCard extends StatelessWidget {
  final Place destination;
  final Guidance? guidance;
  final RouteResult? route;
  final LocationSnapshot snap;
  final VoidCallback onRecenter;
  final VoidCallback onFixGps;
  final String langCode;

  const _PilgrimCard({
    required this.destination,
    required this.guidance,
    required this.route,
    required this.snap,
    required this.onRecenter,
    required this.onFixGps,
    this.langCode = 'en',
  });

  @override
  Widget build(BuildContext context) {
    final hasFix = snap.state.hasFix && snap.position != null;
    final g = guidance;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Destination line
            Row(children: [
              const Icon(Icons.flag_rounded, color: _saffron, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text('To: ${destination.name}',
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _green),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 12),

            if (!hasFix) ...[
              // No GPS → honest guidance, never fake a position
              _NoGpsBlock(state: snap.state, onFixGps: onFixGps),
            ] else if (g != null) ...[
              // Big direction arrow + distance — understandable in 1-2 seconds
              Row(children: [
                Transform.rotate(
                  angle: g.bearingDeg * 3.1415926535 / 180.0,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: g.offRoute
                          ? const Color(0xFFFEF3C7)
                          : const Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: g.offRoute ? const Color(0xFFF59E0B) : _green,
                          width: 3),
                    ),
                    child: Icon(Icons.navigation_rounded,
                        color: g.offRoute ? const Color(0xFFD97706) : _green,
                        size: 44),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.directionText,
                            style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF111827))),
                        Text(
                            '${g.distanceLabel} to ${destination.name.split(' ').first}',
                            style: GoogleFonts.outfit(
                                fontSize: 15, color: const Color(0xFF4B5563))),
                        if (snap.state == GpsState.lowAccuracy)
                          Text('GPS weak — direction is approximate',
                              style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFFD97706))),
                      ]),
                ),
              ]),
              const SizedBox(height: 8),
              // Honesty label — scale-aware: for a far destination it truthfully
              // says to take transport (not walk); locally it says follow the arrow.
              Text(
                  route == null
                      ? 'No road route is available for this region yet. '
                          '${g.scaleNote(langCode)}'
                      : (route!.isOnline
                          ? 'Live road route • updates as you move'
                          : 'Offline road route • updates as you move'),
                  style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: route == null ? const Color(0xFF9CA3AF) : _green,
                      fontStyle: FontStyle.italic)),
              if (g.offRoute) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(
                      'You have drifted ${g.offRouteMeters?.round()} m off the direct line. '
                      'Turn toward the arrow — no need to worry.',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: const Color(0xFF92400E))),
                ),
              ],
            ],
            const SizedBox(height: 14),

            // Actions: big buttons
            Row(children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () async {
                      final g2 = guidance;
                      // Speak the guidance in the user's SELECTED language (offline TTS),
                      // not just English. Falls back to the GPS state when no fix.
                      final lang = langCode;
                      final text = !hasFix
                          ? snap.state.label
                          : (g2 != null
                              ? g2.spokenGuidance(lang, destination.name)
                              : '');
                      if (text.isNotEmpty) {
                        await TTSService.instance.initialize(langCode: lang);
                        await TTSService.instance.speak(text);
                      }
                    },
                    icon: const Icon(Icons.volume_up_rounded),
                    label: Text('Speak',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: onRecenter,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text('Where am I?',
                        style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ]),
          ]),
    );
  }
}

class _NoGpsBlock extends StatelessWidget {
  final GpsState state;
  final VoidCallback onFixGps;
  const _NoGpsBlock({required this.state, required this.onFixGps});

  @override
  Widget build(BuildContext context) {
    final (msg, action) = switch (state) {
      GpsState.servicesOff => (
          'Location is turned OFF. Turn on GPS to see where you are.',
          'Turn on GPS'
        ),
      GpsState.permissionDenied => (
          'PathSaathi needs location permission to guide you.',
          'Allow location'
        ),
      GpsState.permissionForever => (
          'Location permission is blocked. Enable it in Settings.',
          'Open Settings'
        ),
      GpsState.searching => (
          'Searching for GPS… stand in open sky for a few seconds.',
          'Retry'
        ),
      _ => (
          'GPS not available right now. You can still search and read map info.',
          'Retry'
        ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.location_off_rounded,
              color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: const Color(0xFF991B1B)))),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white),
            onPressed: onFixGps,
            child: Text(action,
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── Compact map controls (non-pilgrim view) ──────────────────────────────────
class _MapControls extends StatelessWidget {
  final Place destination;
  final Guidance? guidance;
  final VoidCallback onRecenter;
  const _MapControls(
      {required this.destination,
      required this.guidance,
      required this.onRecenter});

  @override
  Widget build(BuildContext context) {
    final g = guidance;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 16, offset: Offset(0, -3))
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(destination.name,
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _green),
                overflow: TextOverflow.ellipsis),
            Text(
                g != null
                    ? '${g.directionText} • ${g.distanceLabel}'
                    : 'Waiting for GPS…',
                style: GoogleFonts.outfit(
                    fontSize: 12, color: const Color(0xFF4B5563))),
          ]),
        ),
        IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: _green),
          onPressed: onRecenter,
          icon: const Icon(Icons.my_location_rounded, color: Colors.white),
        ),
      ]),
    );
  }
}
