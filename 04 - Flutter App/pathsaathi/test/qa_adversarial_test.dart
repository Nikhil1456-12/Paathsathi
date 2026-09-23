// Adversarial QA matrix — destination resolution, confirmation-gate state
// machine, language/travel-context separation, and negative inputs.
// Pure logic (no device). Mirrors the exact flow the screens use.

import 'package:flutter_test/flutter_test.dart';
import 'package:pathsaathi/services/place_search_service.dart';
import 'package:pathsaathi/providers/travel_context.dart';
import 'package:pathsaathi/core/voice_strings.dart';

void main() {
  final svc = PlaceSearchService.instance;

  // ── DESTINATION RESOLUTION MATRIX ────────────────────────────────────────
  // (input, expectedId or null). Covers cities, aliases, speech styles, langs,
  // mixed language, and adversarial/nonsense.
  final cases = <List<dynamic>>[
    // direct + alt names
    ['Delhi', 'delhi'],
    ['New Delhi', 'delhi'],
    ['take me to delhi', 'delhi'],
    ['I want to go to Delhi', 'delhi'],
    ['Delhi jaana hai', 'delhi'],
    ['Mumbai', 'mumbai'],
    ['Bombay', 'mumbai'],
    ['go to bombay', 'mumbai'],
    ['Hyderabad', 'hyderabad'],
    ['Chennai', 'chennai'],
    ['Madras', 'chennai'],
    ['Bengaluru', 'bengaluru'],
    ['Bangalore', 'bengaluru'],
    ['Kolkata', 'kolkata'],
    ['Calcutta', 'kolkata'],
    ['Kashi', 'kashi_vishwanath'],
    ['Banaras', 'kashi_vishwanath'],
    ['Ayodhya', 'ayodhya_city'],
    // scripts
    ['मुझे दिल्ली जाना है', 'delhi'],
    ['दिल्ली', 'delhi'],
    ['నాకు ఢిల్లీ వెళ్లాలి', 'delhi'],
    ['ఢిల్లీ', 'delhi'],
    ['நான் டெல்லிக்கு செல்ல வேண்டும்', 'delhi'],
    ['मुंबई', 'mumbai'],
    ['ముంబై', 'mumbai'],
    ['काशी', 'kashi_vishwanath'],
    // mixed
    ['मुझे Delhi जाना है', 'delhi'],
    ['नाकు Delhi కి train కావాలి', 'delhi'],
    ['Delhi jana hai train dikhao', 'delhi'],
    // adversarial / must be null (no fake default)
    ['', null],
    ['   ', null],
    ['asdfghjkl', null],
    ['hello how are you', null],
    ['what is the capital of india', null], // general question — NOT a travel command (must not guess Delhi)
    ['xyz123', null],
    ['go to', null],
    ['मुझे जाना है', null],
  ];

  group('resolveDestination matrix', () {
    for (final c in cases) {
      final input = c[0] as String;
      final expected = c[1] as String?;
      test('"$input" -> ${expected ?? "null"}', () {
        final r = svc.resolveDestination(input);
        expect(r?.id, expected,
            reason: 'input="$input" resolved to ${r?.id}, expected $expected');
      });
    }
  });

  // ── CONFIRMATION-GATE STATE MACHINE ──────────────────────────────────────
  group('confirmation gate — pending never drives map', () {
    test('propose does NOT set confirmed', () {
      final n = TravelContextNotifier();
      n.proposeDestination(svc.resolveDestination('Delhi')!);
      expect(n.state.pendingDestination?.id, 'delhi');
      expect(n.state.confirmedDestination, isNull); // map must NOT move yet
    });

    test('Delhi -> confirm -> Delhi confirmed', () {
      final n = TravelContextNotifier();
      n.proposeDestination(svc.resolveDestination('Delhi')!);
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'delhi');
      expect(n.state.pendingDestination, isNull);
    });

    test('ADVERSARIAL: Delhi -> (before confirm) actually Mumbai -> Yes => Mumbai', () {
      final n = TravelContextNotifier();
      n.proposeDestination(svc.resolveDestination('Delhi')!);
      // user changes mind before confirming
      n.proposeDestination(svc.resolveDestination('actually Mumbai')!);
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'mumbai'); // NOT stale delhi
    });

    test('ADVERSARIAL: Delhi -> No -> Mumbai -> Yes => Mumbai', () {
      final n = TravelContextNotifier();
      n.proposeDestination(svc.resolveDestination('Delhi')!);
      n.rejectPending();
      expect(n.state.pendingDestination, isNull);
      expect(n.state.confirmedDestination, isNull);
      n.proposeDestination(svc.resolveDestination('Mumbai')!);
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'mumbai');
    });

    test('ADVERSARIAL: Delhi -> Yes -> Mumbai (pending) keeps Delhi confirmed until re-confirm', () {
      final n = TravelContextNotifier();
      n.proposeDestination(svc.resolveDestination('Delhi')!);
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'delhi');
      // user now speaks Mumbai — becomes pending, confirmed stays Delhi
      n.proposeDestination(svc.resolveDestination('Mumbai')!);
      expect(n.state.pendingDestination?.id, 'mumbai');
      expect(n.state.confirmedDestination?.id, 'delhi'); // map still Delhi until confirm
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'mumbai');
    });

    test('confirm with NO pending does nothing (no crash, no fake dest)', () {
      final n = TravelContextNotifier();
      n.confirmPending();
      expect(n.state.confirmedDestination, isNull);
    });

    test('destination chain Delhi->Mumbai->Kashi->Hyderabad->Delhi deterministic', () {
      final n = TravelContextNotifier();
      for (final id in ['delhi', 'mumbai', 'kashi_vishwanath', 'hyderabad', 'delhi']) {
        final place = PlaceSearchService.places.firstWhere((p) => p.id == id);
        n.proposeDestination(place);
        n.confirmPending();
        expect(n.state.confirmedDestination?.id, id);
        expect(n.state.pendingDestination, isNull);
      }
    });
  });

  // ── YES/NO ROBUSTNESS ────────────────────────────────────────────────────
  group('confirmation words — no ambiguous acceptance', () {
    for (final y in ['yes', 'correct', "that's correct", 'okay', 'हाँ', 'सही है', 'అవును', 'ஆம்']) {
      test('"$y" is YES', () => expect(VoiceStrings.isYes(y), isTrue));
    }
    for (final nn in ['no', 'cancel', 'change it', 'नहीं', 'కాదు', 'இல்லை']) {
      test('"$nn" is NO', () => expect(VoiceStrings.isNo(nn), isTrue));
    }
    // ambiguous / unrelated must NOT be yes
    for (final amb in ['maybe', 'what', 'hello', 'train', 'repeat', 'umm', '']) {
      test('ambiguous "$amb" is NOT yes', () => expect(VoiceStrings.isYes(amb), isFalse));
    }
    test('"actually Mumbai" is NOT a yes (must re-propose, not confirm)', () {
      expect(VoiceStrings.isYes('actually Mumbai'), isFalse);
    });
  });
}
