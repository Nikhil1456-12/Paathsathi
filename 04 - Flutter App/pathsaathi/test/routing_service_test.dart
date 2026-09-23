// test/routing_service_test.dart
//
// Unit tests for the offline A* RoutingService over a small, hand-verified
// fixture graph. No assets, no network — pure graph search.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pathsaathi/services/routing_service.dart';

void main() {
  // A diamond graph with an intentionally-expensive direct diagonal:
  //
  //     2 ───────── 3 (goal)
  //     │           │
  //     │           │
  //     0 ───────── 1
  //   (start)
  //
  // Sides (0-1, 1-3, 0-2, 2-3) each ~1.1 km. A direct 0->3 diagonal edge exists
  // but is weighted 5000 m (absurdly long), so a correct A* must route via a
  // two-hop side path (~2.2 km), NOT take the cheap-looking straight diagonal.
  const fixture = {
    'region': 'test',
    'bbox': [0.0, 0.0, 0.02, 0.02], // covers the nodes
    'nodes': [
      [0, 0.0, 0.0], // start
      [1, 0.0, 0.01], // east
      [2, 0.01, 0.0], // north
      [3, 0.01, 0.01], // goal (NE)
    ],
    'edges': [
      [0, 1, 1113.2, 'residential'],
      [1, 3, 1110.6, 'residential'],
      [0, 2, 1110.6, 'residential'],
      [2, 3, 1113.2, 'residential'],
      [0, 3, 5000.0, 'residential'], // deliberately long direct edge
    ],
  };

  setUp(() {
    RoutingService.instance.resetForTest();
    RoutingService.instance.loadGraphFromJsonForTest(jsonEncode(fixture));
  });

  tearDown(() => RoutingService.instance.resetForTest());

  test('A* picks the two-hop side path over the expensive direct diagonal',
      () async {
    // Route from node 0 to node 3.
    final res = await RoutingService.instance.route(
      const LatLng(0.0, 0.0),
      const LatLng(0.01, 0.01),
    );

    expect(res, isNotNull, reason: 'start is inside the graph bbox');
    // Two-hop path is ~2223 m; the direct edge is 5000 m. The result must be
    // much closer to the two-hop distance than the diagonal.
    expect(res!.distanceMeters, lessThan(3000),
        reason: 'A* must reject the 5000 m direct edge for the ~2.2 km path');
    expect(res.distanceMeters, greaterThan(2000),
        reason: 'real path distance is the summed two sides (~2.2 km)');
  });

  test('route distance is >= straight-line (roads never beat a straight line)',
      () async {
    const start = LatLng(0.0, 0.0);
    const goal = LatLng(0.01, 0.01);
    final res = await RoutingService.instance.route(start, goal);
    const dist = Distance();
    final straight = dist.as(LengthUnit.Meter, start, goal);

    expect(res, isNotNull);
    expect(res!.distanceMeters, greaterThanOrEqualTo(straight),
        reason: 'along-path distance can never be shorter than straight-line');
  });

  test('returns null when the start point is outside any loaded graph',
      () async {
    // Far away from the fixture bbox → no graph covers it → honest null so the
    // caller falls back to straight-line (labelled approximate).
    final res = await RoutingService.instance.route(
      const LatLng(45.0, 45.0),
      const LatLng(45.01, 45.01),
    );
    expect(res, isNull);
  });

  test('hasGraphFor reflects bbox coverage', () {
    expect(RoutingService.instance.hasGraphFor(const LatLng(0.005, 0.005)),
        isTrue);
    expect(
        RoutingService.instance.hasGraphFor(const LatLng(10.0, 10.0)), isFalse);
  });

  test('produces turn steps that start and arrive', () async {
    final res = await RoutingService.instance.route(
      const LatLng(0.0, 0.0),
      const LatLng(0.01, 0.01),
    );
    expect(res, isNotNull);
    expect(res!.steps.first.maneuver, 'start');
    expect(res.steps.last.maneuver, 'arrive');
  });

  test('offline fallback is segmented and keeps coordinates near the trip',
      () async {
    const start = LatLng(17.72, 83.30);
    const goal = LatLng(17.77, 83.25);
    final res = await RoutingService.instance.routeOfflineFallback(start, goal);

    expect(res, isNotNull);
    expect(res!.points.length, greaterThan(2));
    expect(res.points.first, start);
    expect(res.points.last, goal);
    expect(res.distanceMeters,
        greaterThan(const Distance().as(LengthUnit.Meter, start, goal)));
    for (final point in res.points) {
      expect(point.latitude, inInclusiveRange(17.60, 17.90));
      expect(point.longitude, inInclusiveRange(83.10, 83.45));
    }
  });
}
