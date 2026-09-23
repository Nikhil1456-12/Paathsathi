// Focused regression test for the "Delhi must not become Prayagraj" bug and
// multilingual destination resolution. Pure logic — no device needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:pathsaathi/services/place_search_service.dart';
import 'package:pathsaathi/core/voice_strings.dart';

void main() {
  final svc = PlaceSearchService.instance;

  group('resolveDestination — critical Delhi bug', () {
    test('English "I want to go to Delhi" -> Delhi (NOT Prayagraj)', () {
      final p = svc.resolveDestination('I want to go to Delhi');
      expect(p, isNotNull);
      expect(p!.id, 'delhi');
      expect(p.id, isNot('prayagraj'));
      expect(p.id, isNot('sangam'));
    });

    test('Hindi "मुझे दिल्ली जाना है" -> Delhi', () {
      final p = svc.resolveDestination('मुझे दिल्ली जाना है');
      expect(p?.id, 'delhi');
    });

    test('Telugu "నేను ఢిల్లీకి వెళ్లాలి" -> Delhi', () {
      final p = svc.resolveDestination('నేను ఢిల్లీకి వెళ్లాలి');
      expect(p?.id, 'delhi');
    });

    test('Tamil "நான் டெல்லிக்கு செல்ல வேண்டும்" -> Delhi', () {
      final p = svc.resolveDestination('நான் டெல்லிக்கு செல்ல வேண்டும்');
      expect(p?.id, 'delhi');
    });

    test('Mixed language "मुझे Delhi जाना है" -> Delhi', () {
      final p = svc.resolveDestination('मुझे Delhi जाना है');
      expect(p?.id, 'delhi');
    });
  });

  group('resolveDestination — other destinations & no-false-default', () {
    test('Kashi / Banaras / काशी all map to Kashi Vishwanath', () {
      expect(svc.resolveDestination('take me to Kashi')?.id, 'kashi_vishwanath');
      expect(svc.resolveDestination('Banaras')?.id, 'kashi_vishwanath');
      expect(svc.resolveDestination('काशी जाना है')?.id, 'kashi_vishwanath');
    });

    test('Mumbai / मुंबई -> Mumbai', () {
      expect(svc.resolveDestination('go to Mumbai')?.id, 'mumbai');
      expect(svc.resolveDestination('मुंबई')?.id, 'mumbai');
    });

    test('Nonsense returns null (NO fake default destination)', () {
      expect(svc.resolveDestination('asdfghjkl zzz'), isNull);
      expect(svc.resolveDestination('hello how are you'), isNull);
    });
  });

  group('multilingual yes/no detection', () {
    test('yes in multiple languages', () {
      expect(VoiceStrings.isYes('yes'), isTrue);
      expect(VoiceStrings.isYes('हाँ'), isTrue);
      expect(VoiceStrings.isYes('సరైనదే'), isTrue);
      expect(VoiceStrings.isYes('ஆம்'), isTrue);
    });
    test('no in multiple languages', () {
      expect(VoiceStrings.isNo('no'), isTrue);
      expect(VoiceStrings.isNo('नहीं'), isTrue);
      expect(VoiceStrings.isNo('కాదు'), isTrue);
    });
    test('yes is not no', () {
      expect(VoiceStrings.isYes('नहीं'), isFalse);
    });
  });
}
