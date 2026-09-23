// lib/services/tile_cache_service.dart
//
// Offline map tiles for the trip region, cached at <appDocs>/tiles/z/x/y.png so
// flutter_map can serve them offline via FileTileProvider.
//
// IMPORTANT — TILE POLICY COMPLIANCE:
// We must NOT bulk-download from OpenStreetMap's public volunteer servers
// (tile.openstreetmap.org) — their usage policy forbids bulk downloading, and
// doing so gets the app IP-blocked (osm.wiki/blocked). Therefore this service
// only performs a region download when a COMPLIANT tile source is configured
// via [configureTileSource] (e.g. a MapTiler/Thunderforest/Stadia key, or a
// self-hosted server). With no source configured, region download is a no-op
// that reports honestly — it never hits OSM's public servers.

import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TileCacheService {
  TileCacheService._();
  static final TileCacheService instance = TileCacheService._();
  static const _offlineMapInstalledKey = 'offline_map_installed_v1';

  final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.bytes,
    headers: {
      'User-Agent': 'PathSaathi/1.0 (Infosys FYP pilgrim assistant)',
    },
  ));

  /// A COMPLIANT raster tile URL template, e.g.
  /// 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=YOUR_KEY'.
  /// Null means no permitted source is configured → no bulk download happens.
  String? _tileUrlTemplate;

  /// Configure a permitted tile source (keyed provider or self-hosted). Only
  /// when this is set will offline region caching actually download tiles.
  void configureTileSource(String urlTemplate) =>
      _tileUrlTemplate = urlTemplate;

  bool get hasCompliantSource =>
      _tileUrlTemplate != null && _tileUrlTemplate!.isNotEmpty;

  /// The configured compliant tile template, or '' if none. Never OSM public.
  String get tileUrlTemplateOrEmpty => _tileUrlTemplate ?? '';

  Future<Directory> _tilesRoot() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/tiles');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Local file path for a z/x/y tile.
  Future<File> _tileFile(int z, int x, int y) async {
    final root = await _tilesRoot();
    final dir = Directory('${root.path}/$z/$x');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$y.png');
  }

  /// Slippy-map tile coordinates for a lat/lng at zoom z.
  static (int x, int y) _lonLatToTile(double lat, double lng, int z) {
    final n = math.pow(2, z).toDouble();
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * math.pi / 180.0;
    final y = ((1 - _asinh(math.tan(latRad)) / math.pi) / 2 * n).floor();
    return (x.clamp(0, n.toInt() - 1), y.clamp(0, n.toInt() - 1));
  }

  static double _asinh(double x) => math.log(x + math.sqrt(x * x + 1));

  /// Whether the region tiles for [center] already exist on disk (offline-ready).
  /// Cheap check: the center tile at a mid zoom (14) exists.
  Future<bool> isRegionCached(LatLng center, {int checkZoom = 14}) async {
    final (x, y) = _lonLatToTile(center.latitude, center.longitude, checkZoom);
    final f = await _tileFile(checkZoom, x, y);
    return f.exists();
  }

  /// True after the first successful offline map installation. This is
  /// intentionally app-wide: a new destination must not trigger the same
  /// download prompt again. Detailed tiles remain opportunistically cached by
  /// coordinate, while the bundled overview covers locations without them.
  Future<bool> isOfflineMapInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_offlineMapInstalledKey) == true) return true;

    final root = await _tilesRoot();
    if (!await root.exists()) return false;
    await for (final entry in root.list(recursive: true)) {
      if (entry is File && entry.path.toLowerCase().endsWith('.png')) {
        await prefs.setBool(_offlineMapInstalledKey, true);
        return true;
      }
    }
    return false;
  }

  Future<void> markOfflineMapInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_offlineMapInstalledKey, true);
  }

  /// Download all tiles covering a square region around [center] for the given
  /// zoom range. Reports 0..1 progress. Skips tiles already on disk (resumable).
  /// Returns true if at least the region completed without a hard failure.
  Future<bool> downloadRegion(
    LatLng center, {
    int minZoom = 11,
    int maxZoom = 16, // street-level detail for a real city map
    double radiusKm = 8, // ~city-scale coverage around the destination
    void Function(double progress)? onProgress,
  }) async {
    // COMPLIANCE GATE: never bulk-download from OSM's public servers. Only
    // proceed if the operator configured a permitted tile source.
    if (!hasCompliantSource) {
      debugPrint('[TileCacheService] No compliant tile source configured — '
          'skipping region download (OSM public bulk download is not allowed).');
      return false;
    }
    try {
      // Build the tile list across zooms for a bounding box of ~radiusKm.
      final tiles = <(int, int, int)>[];
      final degLat = radiusKm / 111.0; // ~111 km per degree latitude
      final degLng = radiusKm /
          (111.0 * math.cos(center.latitude * math.pi / 180.0)).abs();
      final nw = LatLng(center.latitude + degLat, center.longitude - degLng);
      final se = LatLng(center.latitude - degLat, center.longitude + degLng);
      for (int z = minZoom; z <= maxZoom; z++) {
        final (x1, y1) = _lonLatToTile(nw.latitude, nw.longitude, z);
        final (x2, y2) = _lonLatToTile(se.latitude, se.longitude, z);
        for (int x = math.min(x1, x2); x <= math.max(x1, x2); x++) {
          for (int y = math.min(y1, y2); y <= math.max(y1, y2); y++) {
            tiles.add((z, x, y));
          }
        }
      }
      if (tiles.isEmpty) return false;

      int done = 0;
      for (final t in tiles) {
        final (z, x, y) = t;
        final file = await _tileFile(z, x, y);
        if (!await file.exists()) {
          try {
            final url = _tileUrlTemplate!
                .replaceAll('{z}', '$z')
                .replaceAll('{x}', '$x')
                .replaceAll('{y}', '$y');
            final resp = await _dio.get<List<int>>(url);
            if (resp.data != null && resp.data!.isNotEmpty) {
              await file.writeAsBytes(resp.data!);
            }
          } catch (e) {
            // Skip a failed tile but keep going — partial cache is still useful.
            debugPrint('[TileCacheService] tile $z/$x/$y failed: $e');
          }
          // Gentle throttle: be a good citizen even with a keyed provider.
          await Future.delayed(const Duration(milliseconds: 40));
        }
        done++;
        onProgress?.call(done / tiles.length);
      }
      await markOfflineMapInstalled();
      return true;
    } catch (e) {
      debugPrint('[TileCacheService] downloadRegion error: $e');
      return false;
    }
  }

  /// Number of cached tiles on disk (for UI/telemetry).
  Future<int> cachedTileCount() async {
    final root = await _tilesRoot();
    if (!await root.exists()) return 0;
    int count = 0;
    await for (final e in root.list(recursive: true)) {
      if (e is File && e.path.endsWith('.png')) count++;
    }
    return count;
  }

  /// The local tiles directory template for flutter_map's FileTileProvider
  /// style usage: callers build a path `<root>/{z}/{x}/{y}.png`.
  Future<String> tilesRootPath() async => (await _tilesRoot()).path;
}
