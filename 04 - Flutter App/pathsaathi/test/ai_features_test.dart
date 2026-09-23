// Targeted tests for the three new real capabilities:
//   1. LLM structured planning (QueryPlan.parse — task decomposition)
//   2. Offline navigation math (NavMath — distance/bearing/compass)
//   3. Offline semantic search (SemanticSearchService — ranking + honest null)
//
// These exercise the PURE logic (no model / no GPS), so they are deterministic.

import 'package:flutter_test/flutter_test.dart';
import 'package:pathsaathi/services/llm_service.dart';
import 'package:pathsaathi/agents/navigation_agent.dart';
import 'package:pathsaathi/services/semantic_search_service.dart';

void main() {
  group('QueryPlan.parse — task decomposition', () {
    test('single intent', () {
      final p = QueryPlan.parse('transport', 'when is the next bus');
      expect(p.primaryIntent, 'transport');
      expect(p.isMultiTask, isFalse);
    });

    test('multi-task decomposition preserves order', () {
      final p = QueryPlan.parse('transport, accommodation, place=ghat',
          'book a bus and a tent near the ghat');
      expect(p.intents, ['transport', 'accommodation']);
      expect(p.isMultiTask, isTrue);
      expect(p.place, 'ghat');
    });

    test('maps synonyms to canonical intents', () {
      final p = QueryPlan.parse('I will show you the map and the aarti schedule', 'q');
      expect(p.intents.contains('navigation'), isTrue); // map -> navigation
      expect(p.intents.contains('itinerary'), isTrue);  // aarti/schedule -> itinerary
    });

    test('de-duplicates repeated intents', () {
      final p = QueryPlan.parse('safety safety emergency', 'help');
      expect(p.intents, ['safety']); // emergency also maps to safety
    });

    test('nonsense output → unknown (no fabrication)', () {
      final p = QueryPlan.parse('the weather is nice today', 'q');
      expect(p.primaryIntent, 'unknown');
    });
  });

  group('NavMath — offline navigation math', () {
    test('normalizeBearing wraps negative atan2 output into 0..360', () {
      expect(NavMath.normalizeBearing(-90), 270);
      expect(NavMath.normalizeBearing(0), 0);
      expect(NavMath.normalizeBearing(450), 90);
    });

    test('distanceLabel: metres under 1km, km with one decimal above', () {
      expect(NavMath.distanceLabel(850), '850 m');
      expect(NavMath.distanceLabel(1500), '1.5 km');
    });

    test('walkMinutes is at least 1 and scales with distance', () {
      expect(NavMath.walkMinutes(5), 1); // clamps up
      final near = NavMath.walkMinutes(200);
      final far = NavMath.walkMinutes(2000);
      expect(far, greaterThan(near));
    });

    test('compass 8-point directions', () {
      expect(NavMath.compass(0), 'North');
      expect(NavMath.compass(90), 'East');
      expect(NavMath.compass(180), 'South');
      expect(NavMath.compass(270), 'West');
      expect(NavMath.compass(45), 'North-East');
      expect(NavMath.compass(-90), 'West'); // normalized
    });
  });

  group('SemanticSearchService — offline ranking', () {
    final svc = SemanticSearchService.instance;

    test('free-form emergency question ranks to the SOS/safety answer', () {
      final m = svc.search('someone collapsed I need urgent help');
      expect(m, isNotNull);
      // Should hit an emergency-type doc, not something unrelated.
      expect(['sos', 'first_aid', 'medical'].contains(m!.doc.id), isTrue);
    });

    test('water question ranks to the water answer', () {
      final m = svc.search('where can I find drinking water');
      expect(m, isNotNull);
      expect(m!.doc.id, 'water');
    });

    test('device regression: "where can I drink water" is water, NOT toilet', () {
      final m = svc.search('where can I drink water');
      expect(m, isNotNull);
      expect(m!.doc.id, 'water', reason: 'must not be pulled to the toilet doc');
    });

    test('toilet question still ranks to toilet', () {
      final m = svc.search('where is the nearest toilet');
      expect(m, isNotNull);
      expect(m!.doc.id, 'toilet');
    });

    test('multilingual (Hindi) food question resolves', () {
      final m = svc.search('मुझे खाना कहाँ मिलेगा');
      expect(m, isNotNull);
      expect(m!.doc.id, 'food');
    });

    test('irrelevant query returns null (honest, no forced match)', () {
      final m = svc.search('what is the stock price of a technology company');
      expect(m, isNull);
    });

    test('reports the method truthfully (lexical unless embedding model present)',
        () {
      final m = svc.search('toilet nearby');
      expect(m, isNotNull);
      expect(['lexical', 'embedding'].contains(m!.method), isTrue);
    });
  });
}
