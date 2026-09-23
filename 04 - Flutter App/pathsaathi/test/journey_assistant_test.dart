// Targeted tests for the Journey Assistant's PURE logic (no DB / no GPS / no
// network). Covers the model round-trips, cache-status semantics, transport
// destination-key mapping, and reservation reference format.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pathsaathi/models/journey_models.dart';
import 'package:pathsaathi/services/transport_repository.dart';
import 'package:pathsaathi/services/place_search_service.dart';

void main() {
  group('CacheStatus semantics', () {
    test('empty is neither complete nor partial', () {
      const s = CacheStatus();
      expect(s.isComplete, isFalse);
      expect(s.isPartial, isFalse);
    });

    test('some-but-not-all is partial', () {
      const s = CacheStatus(tiles: true, places: true);
      expect(s.isComplete, isFalse);
      expect(s.isPartial, isTrue);
    });

    test('all three is complete (not partial)', () {
      const s = CacheStatus(tiles: true, places: true, route: true);
      expect(s.isComplete, isTrue);
      expect(s.isPartial, isFalse);
    });

    test('copyWith updates only the given field', () {
      const s = CacheStatus();
      final s2 = s.copyWith(places: true);
      expect(s2.places, isTrue);
      expect(s2.tiles, isFalse);
      expect(s2.route, isFalse);
    });
  });

  group('TransportOption.fromRow', () {
    test('maps a DB row correctly', () {
      final o = TransportOption.fromRow({
        'id': 5,
        'destination_id': 'dwarka',
        'mode': 'train',
        'from_name': 'Ahmedabad Jn',
        'to_name': 'Dwarka',
        'dep_time': '05:40 AM',
        'arr_time': '12:10 PM',
        'price_inr': 420,
        'operator': 'Saurashtra Mail',
        'indicative': 1,
      });
      expect(o.id, 5);
      expect(o.mode, 'train');
      expect(o.priceInr, 420);
      expect(o.indicative, isTrue);
    });

    test('tolerates missing fields with safe defaults', () {
      final o = TransportOption.fromRow({'id': 1});
      expect(o.mode, 'bus');
      expect(o.priceInr, 0);
      expect(o.destinationId, '');
    });
  });

  group('NearbyPlace.fromRow', () {
    test('parses coords into a LatLng', () {
      final p = NearbyPlace.fromRow({
        'id': 2,
        'destination_id': 'dwarka',
        'category': 'hospital',
        'name': 'Dwarka Sub-District Hospital',
        'lat': 22.2405,
        'lng': 68.9705,
        'note': 'Govt hospital',
        'source': 'curated',
      });
      expect(p.category, 'hospital');
      expect(p.coords.latitude, closeTo(22.2405, 1e-6));
      expect(p.coords.longitude, closeTo(68.9705, 1e-6));
    });
  });

  group('Reservation round-trip + ref format', () {
    test('toRow/fromRow round-trips', () {
      final r = Reservation(
        id: 3,
        refCode: 'PS-7F3K9Q',
        type: 'transport',
        title: 'TRAIN to Dwaraka',
        details: 'Saurashtra Mail',
        status: 'confirmed',
        createdAt: DateTime.parse('2026-09-06T10:00:00.000'),
      );
      final back = Reservation.fromRow({...r.toRow(), 'id': 3});
      expect(back.refCode, 'PS-7F3K9Q');
      expect(back.type, 'transport');
      expect(back.status, 'confirmed');
    });
  });

  group('JourneyPlan round-trip', () {
    test('toRow/fromRow preserves destination coords + cache flags', () {
      final plan = JourneyPlan(
        id: 1,
        destinationId: 'dwarka',
        destinationName: 'Dwaraka',
        destinationCoords: const LatLng(22.2394, 68.9678),
        transportOptionId: 5,
        cacheStatus: const CacheStatus(tiles: true, places: true, route: true),
        createdAt: DateTime.now(),
      );
      final back = JourneyPlan.fromRow({...plan.toRow(), 'id': 1});
      expect(back.destinationName, 'Dwaraka');
      expect(back.destinationCoords!.latitude, closeTo(22.2394, 1e-6));
      expect(back.transportOptionId, 5);
      expect(back.cacheStatus.isComplete, isTrue);
    });
  });

  group('TransportRepository.destinationKeyForPlace', () {
    Place p(String id) => Place(id: id, name: id, category: 'city', coords: const LatLng(0, 0));

    test('varanasi variants collapse to "varanasi"', () {
      expect(TransportRepository.destinationKeyForPlace(p('varanasi_city')), 'varanasi');
      expect(TransportRepository.destinationKeyForPlace(p('varanasi_jn')), 'varanasi');
      expect(TransportRepository.destinationKeyForPlace(p('kashi_vishwanath')), 'varanasi');
    });

    test('dwarka/dwaraka collapse to "dwarka"', () {
      expect(TransportRepository.destinationKeyForPlace(p('dwarka')), 'dwarka');
      expect(TransportRepository.destinationKeyForPlace(p('dwaraka')), 'dwarka');
    });

    test('simple ids pass through lowercased', () {
      expect(TransportRepository.destinationKeyForPlace(p('kedarnath')), 'kedarnath');
      expect(TransportRepository.destinationKeyForPlace(p('Mumbai')), 'mumbai');
    });
  });
}
