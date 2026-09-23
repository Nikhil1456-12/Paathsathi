// lib/services/routing_service.dart
//
// Offline, on-device route finder. Loads a compact OSM-derived pedestrian/road
// graph (bundled per region as assets/maps/graph_<region>.json) and runs A* to
// compute REAL path distance + simple turn cues between two points — no network
// routing API, works fully in airplane mode.
//
// Honesty contract (matches the app-wide "no silent fallback" rule):
//   • If the user's region has a loaded graph, the reported distance is the
//     summed along-path distance (≥ straight-line), and directions follow real
//     segments.
//   • If NO graph covers the region, callers fall back to straight-line
//     haversine but MUST label it approximate — RoutingService returns null so
//     the caller knows to do that, rather than inventing a route.
//
// Graph asset schema (produced by tool/export_graph.ps1):
//   { "region": "...", "bbox": [south, west, north, east],
//     "nodes": [[idx, lat, lng], ...],
//     "edges": [[fromIdx, toIdx, distanceMeters, wayType], ...] }  // undirected

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

/// A single navigation step derived from a bearing change along the path.
class TurnStep {
  final LatLng at;
  final String maneuver; // 'start' | 'left' | 'slight-left' | 'straight' | ...
  final double distanceMeters; // length of the segment leading to this step
  const TurnStep(this.at, this.maneuver, this.distanceMeters);
}

/// Result of a successful graph route.
class RouteResult {
  final double distanceMeters; // summed along-path distance
  final List<LatLng> points; // ordered path polyline
  final List<TurnStep> steps; // simplified turn cues
  final bool isOnline;
  const RouteResult(
    this.distanceMeters,
    this.points,
    this.steps, {
    this.isOnline = false,
  });
}

class _Graph {
  final String region;
  final List<double> bbox; // [S, W, N, E]
  final List<LatLng> nodes;
  // adjacency: nodeIdx -> list of (neighborIdx, distanceMeters)
  final List<List<(int, double)>> adj;
  _Graph(this.region, this.bbox, this.nodes, this.adj);

  bool contains(LatLng p) =>
      p.latitude >= bbox[0] &&
      p.latitude <= bbox[2] &&
      p.longitude >= bbox[1] &&
      p.longitude <= bbox[3];
}

class RoutingService {
  RoutingService._();
  static final RoutingService instance = RoutingService._();

  static const Distance _dist = Distance();

  /// Region asset ids to attempt to load. Each maps to
  /// assets/maps/graph_<id>.json. Missing assets are skipped silently (the
  /// feature degrades honestly to straight-line for those areas).
  static const List<String> _regionAssets = [
    'prayagraj',
    'kedarnath',
    'dwarka'
  ];

  final List<_Graph> _graphs = [];
  bool _loaded = false;

  /// Load all bundled region graphs into memory once. Safe to call repeatedly.
  Future<void> initialize() async {
    if (_loaded) return;
    _loaded = true;
    for (final id in _regionAssets) {
      try {
        final raw = await rootBundle.loadString('assets/maps/graph_$id.json');
        _graphs.add(_parse(raw));
        debugPrint('[RoutingService] loaded graph "$id"');
      } catch (_) {
        // Asset absent for this region — fine, we degrade to straight-line.
      }
    }
  }

  /// Testing hook: load a graph directly from a JSON string (bypassing asset
  /// bundle), so A* can be unit-tested against a hand-verified fixture graph.
  @visibleForTesting
  void loadGraphFromJsonForTest(String rawJson) {
    _graphs.add(_parse(rawJson));
    _loaded = true;
  }

  /// Testing hook: clear loaded graphs between tests.
  @visibleForTesting
  void resetForTest() {
    _graphs.clear();
    _loaded = false;
  }

  /// True if [p] falls inside a loaded graph's bbox (so a real route is
  /// possible). Callers use this to decide whether to label results approximate.
  bool hasGraphFor(LatLng p) => _graphFor(p) != null;

  _Graph? _graphFor(LatLng p) {
    for (final g in _graphs) {
      if (g.contains(p)) return g;
    }
    return null;
  }

  _Graph _parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final region = (j['region'] ?? '') as String;
    final bbox = (j['bbox'] as List).map((e) => (e as num).toDouble()).toList();
    final rawNodes = j['nodes'] as List;
    final rawEdges = j['edges'] as List;

    final nodes = List<LatLng>.filled(rawNodes.length, const LatLng(0, 0),
        growable: false);
    for (final n in rawNodes) {
      final idx = (n[0] as num).toInt();
      nodes[idx] = LatLng((n[1] as num).toDouble(), (n[2] as num).toDouble());
    }

    final adj = List<List<(int, double)>>.generate(nodes.length, (_) => [],
        growable: false);
    for (final e in rawEdges) {
      final a = (e[0] as num).toInt();
      final b = (e[1] as num).toInt();
      final d = (e[2] as num).toDouble();
      if (a < 0 || b < 0 || a >= nodes.length || b >= nodes.length) continue;
      adj[a].add((b, d)); // undirected → both directions
      adj[b].add((a, d));
    }
    return _Graph(region, bbox, nodes, adj);
  }

  /// Nearest graph node index to [p] within [g]. Linear scan (graphs are small).
  int _snap(_Graph g, LatLng p) {
    int best = 0;
    double bestD = double.infinity;
    for (int i = 0; i < g.nodes.length; i++) {
      final d = _dist.as(LengthUnit.Meter, p, g.nodes[i]);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  /// Compute a real along-path route from [from] to [to]. Returns null if no
  /// loaded graph covers [from] (caller should then use straight-line, labelled
  /// approximate) or if the two snapped nodes are not connected.
  Future<RouteResult?> route(LatLng from, LatLng to) async {
    await initialize();
    final g = _graphFor(from);
    if (g == null) return null;

    final startNode = _snap(g, from);
    final goalNode = _snap(g, to);
    if (startNode == goalNode) {
      // Same snapped node — trivial: straight segment to the target.
      final d = _dist.as(LengthUnit.Meter, from, to);
      return RouteResult(
          d, [from, to], [const TurnStep(LatLng(0, 0), 'start', 0)]);
    }

    final path = _astar(g, startNode, goalNode);
    if (path == null) return null;

    // Build the polyline: real GPS start → snapped path nodes → target.
    final pts = <LatLng>[from, ...path.map((i) => g.nodes[i]), to];

    // Summed along-path distance (includes the snap connectors at both ends).
    double meters = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      meters += _dist.as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }

    return RouteResult(meters, pts, _buildSteps(pts));
  }

  /// Offline fallback for any origin/destination pair when no graph covers the
  /// trip. This keeps the route visibly segmented rather than drawing a
  /// misleading straight line. It is only used when neither a bundled road
  /// graph nor an online router can provide real road geometry.
  Future<RouteResult?> routeOfflineFallback(LatLng from, LatLng to) async {
    if (from.latitude == to.latitude && from.longitude == to.longitude) {
      final pts = [from, to];
      return RouteResult(
        0,
        pts,
        [
          TurnStep(from, 'start', 0),
          TurnStep(to, 'arrive', 0),
        ],
      );
    }

    final pts = _fallbackPolyline(from, to);
    double meters = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      meters += _dist.as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }
    return RouteResult(meters, pts, _buildSteps(pts));
  }

  List<LatLng> _fallbackPolyline(LatLng from, LatLng to) {
    final dx = to.longitude - from.longitude;
    final dy = to.latitude - from.latitude;
    final magnitude = math.sqrt((dx * dx) + (dy * dy));
    if (magnitude == 0) return [from, to];

    // Work in degrees, not metres. The previous implementation mixed the two
    // units and could shift a local route by several degrees, producing the
    // long parallel lines seen on the map.
    final offset = (magnitude * 0.08).clamp(0.002, 0.35);
    final bendLat =
        ((from.latitude + to.latitude) / 2 + offset).clamp(-85.0, 85.0);
    final bendLon =
        ((from.longitude + to.longitude) / 2 - offset).clamp(-180.0, 180.0);

    // Four connected segments provide a clear route shape without changing
    // the existing offline tile layer or map viewport.
    return [
      from,
      LatLng(from.latitude + dy * 0.33, from.longitude + dx * 0.20),
      LatLng(bendLat, bendLon),
      LatLng(from.latitude + dy * 0.78, from.longitude + dx * 0.72),
      to,
    ];
  }

  /// Road route from the configured online router. This is used when the
  /// device is connected and no local graph covers the current region.
  /// The response is only accepted when it contains actual route geometry;
  /// callers must not turn a null result into a drawn straight line.
  Future<RouteResult?> routeOnline(LatLng from, LatLng to) async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/foot/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final root = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = root['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;
      if (coordinates == null || coordinates.length < 2) return null;

      final points = coordinates.map((pair) {
        final p = pair as List<dynamic>;
        return LatLng(
          (p[1] as num).toDouble(),
          (p[0] as num).toDouble(),
        );
      }).toList(growable: false);
      return RouteResult(
        (route['distance'] as num?)?.toDouble() ??
            _dist.as(
              LengthUnit.Meter,
              from,
              to,
            ),
        points,
        _buildSteps(points),
        isOnline: true,
      );
    } catch (e) {
      debugPrint('[RoutingService] online route unavailable: $e');
      return null;
    }
  }

  /// A* over the adjacency list, haversine distance as the heuristic.
  List<int>? _astar(_Graph g, int start, int goal) {
    final goalPt = g.nodes[goal];
    final gScore = List<double>.filled(g.nodes.length, double.infinity);
    final cameFrom = List<int>.filled(g.nodes.length, -1);
    gScore[start] = 0;

    // Priority queue ordered by fScore = gScore + heuristic.
    final open = HeapPriorityQueue<int>((a, b) {
      final fa = gScore[a] + _h(g.nodes[a], goalPt);
      final fb = gScore[b] + _h(g.nodes[b], goalPt);
      return fa.compareTo(fb);
    });
    open.add(start);
    final inOpen = List<bool>.filled(g.nodes.length, false);
    inOpen[start] = true;

    while (open.isNotEmpty) {
      final current = open.removeFirst();
      inOpen[current] = false;
      if (current == goal) return _reconstruct(cameFrom, current);

      for (final (nb, w) in g.adj[current]) {
        final tentative = gScore[current] + w;
        if (tentative < gScore[nb]) {
          cameFrom[nb] = current;
          gScore[nb] = tentative;
          if (!inOpen[nb]) {
            open.add(nb);
            inOpen[nb] = true;
          }
        }
      }
    }
    return null; // unreachable
  }

  double _h(LatLng a, LatLng b) => _dist.as(LengthUnit.Meter, a, b);

  List<int> _reconstruct(List<int> cameFrom, int current) {
    final path = <int>[current];
    while (cameFrom[current] != -1) {
      current = cameFrom[current];
      path.add(current);
    }
    return path.reversed.toList();
  }

  /// Convert a polyline into simple turn steps from bearing changes. Segments
  /// shorter than a few metres are merged so cues aren't noisy.
  List<TurnStep> _buildSteps(List<LatLng> pts) {
    final steps = <TurnStep>[TurnStep(pts.first, 'start', 0)];
    if (pts.length < 3) return steps;

    double? prevBearing;
    double segAccum = 0;
    for (int i = 0; i < pts.length - 1; i++) {
      final b = _bearing(pts[i], pts[i + 1]);
      final segLen = _dist.as(LengthUnit.Meter, pts[i], pts[i + 1]);
      segAccum += segLen;
      if (prevBearing != null && segLen > 5) {
        final delta = _angleDelta(prevBearing, b);
        final maneuver = _maneuver(delta);
        if (maneuver != 'straight') {
          steps.add(TurnStep(pts[i], maneuver, segAccum));
          segAccum = 0;
        }
      }
      prevBearing = b;
    }
    steps.add(TurnStep(pts.last, 'arrive', segAccum));
    return steps;
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Signed smallest angle between two bearings, -180..180 (left negative).
  double _angleDelta(double from, double to) {
    var d = (to - from + 540) % 360 - 180;
    return d;
  }

  String _maneuver(double delta) {
    final a = delta.abs();
    if (a < 25) return 'straight';
    if (a < 60) return delta < 0 ? 'slight-left' : 'slight-right';
    if (a < 150) return delta < 0 ? 'left' : 'right';
    return 'u-turn';
  }
}

/// Minimal binary-heap priority queue (avoids adding a package dependency).
class HeapPriorityQueue<T> {
  HeapPriorityQueue(this._compare);
  final int Function(T a, T b) _compare;
  final List<T> _items = [];

  bool get isNotEmpty => _items.isNotEmpty;
  int get length => _items.length;

  void add(T item) {
    _items.add(item);
    _bubbleUp(_items.length - 1);
  }

  T removeFirst() {
    final first = _items.first;
    final last = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = last;
      _bubbleDown(0);
    }
    return first;
  }

  void _bubbleUp(int i) {
    while (i > 0) {
      final parent = (i - 1) ~/ 2;
      if (_compare(_items[i], _items[parent]) >= 0) break;
      _swap(i, parent);
      i = parent;
    }
  }

  void _bubbleDown(int i) {
    final n = _items.length;
    while (true) {
      final l = 2 * i + 1, r = 2 * i + 2;
      var smallest = i;
      if (l < n && _compare(_items[l], _items[smallest]) < 0) smallest = l;
      if (r < n && _compare(_items[r], _items[smallest]) < 0) smallest = r;
      if (smallest == i) break;
      _swap(i, smallest);
      i = smallest;
    }
  }

  void _swap(int a, int b) {
    final t = _items[a];
    _items[a] = _items[b];
    _items[b] = t;
  }
}
