// Architectural regression tests for provider-based destination resolution.
//
// These prove resolution is NOT tied to a fixed city list and that unresolved
// queries fail truthfully — no Prayagraj/Kashi/default fallback, and an
// unresolved query can never be confirmed.
//
// NOTE: intentionally small + data-driven. We do NOT add dozens of hardcoded
// destinations to "make tests pass"; we exercise the pipeline behaviour.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathsaathi/services/destination_resolver.dart';
import 'package:pathsaathi/providers/travel_context.dart';
import 'package:pathsaathi/services/place_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  final svc = DestinationResolutionService.instance;

  group('normalizeQuery (unicode safety)', () {
    test('strips zero-width joiner/non-joiner/BOM', () {
      expect(normalizeQuery('Kedar\u200Cnath'), 'kedarnath');
      expect(normalizeQuery('\uFEFFDelhi'), 'delhi');
    });

    test('maps a Cyrillic homoglyph back to Latin (fixes STT confusable)', () {
      // 'н' is Cyrillic; the real word is "kedarnath".
      expect(normalizeQuery('kedar\u043dath'), 'kedarnath');
    });

    test('collapses whitespace and lowercases', () {
      expect(normalizeQuery('  Kedar   Nath  '.replaceAll('Nath', 'nath')),
          'kedar nath');
    });

    test('does not merge two distinct real place names', () {
      // Distinct names remain distinct after normalization.
      expect(normalizeQuery('Delhi') == normalizeQuery('Mumbai'), isFalse);
    });
  });

  group('resolution pipeline (offline / online boundary)', () {
    setUp(() => svc.onlineCheck = () => false); // default offline for determinism

    test('1. existing known destination resolves', () {
      final r = svc.resolve('Kedarnath');
      expect(r.isResolved, isTrue);
      expect(r.place, isNotNull);
    });

    test('2. natural-language query extracts + resolves', () {
      final r = svc.resolve('I want to go to Kedarnath');
      expect(r.isResolved, isTrue);
    });

    test('9a. Hindi natural-language resolves', () {
      final r = svc.resolve('मुझे वाराणसी जाना है');
      expect(r.isResolved, isTrue);
    });

    test('9b. Telugu natural-language resolves', () {
      final r = svc.resolve('నాకు హైదరాబాద్ వెళ్ళాలి');
      expect(r.isResolved, isTrue);
    });

    test('8a. Cyrillic-in-Latin confusable resolves safely (transliteration)',
        () {
      // "kedarнath" with Cyrillic 'н' → safely normalized to "kedarnath".
      final r = svc.resolve('go to kedar\u043dath');
      expect(r.isResolved, isTrue,
          reason: 'safe Cyrillic→Latin transliteration must recover this');
    });

    test('8b. Cyrillic corruption inside Indic script does NOT force a false match',
        () {
      // The exact device string 'కేదారнాథ్' is Telugu with a stray Cyrillic 'н'.
      // We CANNOT safely reconstruct the Telugu without dangerous fuzzy matching,
      // so the honest result is unresolved (→ UI asks the user to retry). It must
      // NEVER silently resolve to a wrong/default place.
      final r = svc.resolve('కేదారнాథ్');
      expect(r.place, anyOf(isNull, predicate((p) => (p as Place).id == 'kedarnath')),
          reason: 'either correct place or unresolved — never a wrong/default place');
    });

    test('4. unknown place returns truthful unresolved/unavailable (no fallback)',
        () {
      final r = svc.resolve('Zzxqwplace Nowhere');
      expect(r.isResolved, isFalse);
      expect(r.place, isNull);
      expect(
        r.kind == ResolutionKind.unresolved ||
            r.kind == ResolutionKind.unavailableOffline,
        isTrue,
      );
    });

    test('10. no default (Prayagraj/Kashi) leaks on an unresolved query', () {
      final r = svc.resolve('take me to Someplace That Does Not Exist 999');
      expect(r.place, isNull);
    });

    test('3. offline vs online boundary is distinguished', () {
      svc.onlineCheck = () => false;
      final offlineRes = svc.resolve('Someplace Not In Cache 123');
      expect(offlineRes.kind, ResolutionKind.unavailableOffline);

      svc.onlineCheck = () => true; // online, but no real geocoder configured
      final onlineRes = svc.resolve('Someplace Not In Cache 123');
      expect(onlineRes.kind, ResolutionKind.unresolved);
    });
  });

  group('confirmation safety (state boundary)', () {
    test('6/7. unresolved query cannot be confirmed; no leak from previous', () {
      final ctx = TravelContextNotifier();

      // First confirm a valid destination.
      final kedar = PlaceSearchService.instance.byId('kedarnath') ??
          svc.resolve('Kedarnath').place!;
      ctx.proposeDestination(kedar);
      ctx.confirmPending();
      final firstConfirmed = ctx.state.confirmedDestination;
      expect(firstConfirmed, isNotNull);

      // Now an unresolved request arrives. It must NOT become pending, so a
      // confirm attempt must be a no-op and must not mutate confirmedDestination.
      final unresolved = svc.resolve('Nonexistent Place 777');
      expect(unresolved.isResolved, isFalse);
      // (UI never calls proposeDestination for an unresolved result.)
      ctx.confirmPending(); // pending is still null → no-op
      expect(ctx.state.confirmedDestination, same(firstConfirmed),
          reason: 'previous destination must not leak, no new confirm allowed');
    });

    test('confirmPending with null pending never sets confirmedDestination', () {
      final ctx = TravelContextNotifier();
      expect(ctx.state.pendingDestination, isNull);
      ctx.confirmPending();
      expect(ctx.state.confirmedDestination, isNull);
    });
  });
}
