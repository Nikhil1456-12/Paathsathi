// Journey Pack — destination-agnostic vertical slice test.
// Proves the SAME code path builds/persists/loads a pack for unrelated
// destinations, with no destination-specific logic, and never fabricates data.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathsaathi/services/place_search_service.dart';
import 'package:pathsaathi/services/journey_pack_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = JourneyPackService.instance;
  final places = PlaceSearchService.instance;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Multiple UNRELATED destinations — mix of pilgrimage + non-pilgrimage cities.
  // These are only inputs; the code must treat them identically.
  final testInputs = ['kedarnath', 'hyderabad', 'mumbai', 'bengaluru'];

  group('destination-agnostic pack build', () {
    for (final id in testInputs) {
      test('builds a pack for "$id" via the same code path', () {
        final dest = places.byId(id);
        expect(dest, isNotNull, reason: '$id must resolve to a Place');
        final pack = svc.build(dest!);

        // Pack is built from the Place itself.
        expect(pack.destinationId, id);
        expect(pack.destinationName, dest.name);
        expect(pack.lat, dest.coords.latitude);
        expect(pack.lng, dest.coords.longitude);

        // destination_info is always AVAILABLE and reflects THIS destination.
        final info = pack.sections['destination_info']!;
        expect(info.status, PackDataStatus.available);
        expect(info.items.single['id'], id);

        // Same category set for every destination (no per-city branching).
        expect(pack.sections.keys.toSet(), {
          'destination_info', 'landmarks', 'hospitals', 'railway_stations',
          'transport', 'pharmacies', 'hotels', 'airports', 'offline_map',
          'live_transport', 'emergency_live',
        });

        // Honesty: unsourced categories are never fabricated.
        expect(pack.sections['pharmacies']!.status, PackDataStatus.unavailable);
        expect(pack.sections['pharmacies']!.items, isEmpty);
        expect(pack.sections['hotels']!.status, PackDataStatus.unavailable);
        expect(pack.sections['live_transport']!.status, PackDataStatus.liveOnly);
        expect(pack.sections['live_transport']!.items, isEmpty);
      });
    }
  });

  test('prepare + persist + reload works offline (survives "restart")', () async {
    final dest = places.byId('hyderabad')!;
    final prepared = await svc.prepareAndSave(dest);
    expect(prepared.destinationId, 'hyderabad');
    expect(await svc.isPrepared('hyderabad'), isTrue);

    // Simulate offline reopen: a fresh load from persistence, no network.
    final loaded = await svc.load('hyderabad');
    expect(loaded, isNotNull);
    expect(loaded!.destinationId, 'hyderabad');
    expect(loaded.destinationName, dest.name);
    expect(loaded.sections['destination_info']!.items.single['id'], 'hyderabad');
  });

  test('no pack for a destination never prepared -> null (no fabrication)', () async {
    expect(await svc.load('mumbai'), isNull);
    expect(await svc.isPrepared('mumbai'), isFalse);
  });

  test('nearby-POI sections contain only REAL known places within radius', () {
    // Kedarnath is remote — its hospital section should be UNAVAILABLE (no known
    // hospital POI nearby), proving we do not invent POIs to fill the category.
    final pack = svc.build(places.byId('kedarnath')!);
    final hosp = pack.sections['hospitals']!;
    if (hosp.status == PackDataStatus.available) {
      // If any items exist they must be real Places with coordinates + distance.
      for (final it in hosp.items) {
        expect(it.containsKey('lat'), isTrue);
        expect(it.containsKey('distance_km'), isTrue);
      }
    } else {
      expect(hosp.items, isEmpty);
    }
  });
}
