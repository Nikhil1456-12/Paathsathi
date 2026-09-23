// Kedarnath QA campaign — destination resolution across languages, and the
// state-corruption sequences from the reliability gate. Pure logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:pathsaathi/services/place_search_service.dart';
import 'package:pathsaathi/providers/travel_context.dart';

void main() {
  final svc = PlaceSearchService.instance;
  Place p(String id) => PlaceSearchService.places.firstWhere((x) => x.id == id);

  group('Kedarnath multilingual resolution', () {
    final inputs = {
      'I want to go to Kedarnath': 'kedarnath',
      'take me to kedarnath': 'kedarnath',
      'मुझे केदारनाथ जाना है': 'kedarnath',
      'केदारनाथ': 'kedarnath',
      'కేదార్‌నాథ్ వెళ్లాలి': 'kedarnath',
      'கேதார்நாத்': 'kedarnath',
      'Mujhe Kedarnath जाना है': 'kedarnath', // mixed
      'Badrinath': 'badrinath',
      'Tirupati': 'tirupati',
      'Shirdi': 'shirdi',
    };
    inputs.forEach((input, id) {
      test('"$input" -> $id', () => expect(svc.resolveDestination(input)?.id, id));
    });
  });

  group('state-corruption sequences', () {
    test('Seq1: Kedarnath -> No -> Mumbai -> Yes => Mumbai', () {
      final n = TravelContextNotifier();
      n.proposeDestination(p('kedarnath'));
      n.rejectPending();
      n.proposeDestination(p('mumbai'));
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'mumbai');
      expect(n.state.pendingDestination, isNull);
    });

    test('Seq2: Kedarnath -> Yes -> Mumbai -> Yes => Mumbai (replaces)', () {
      final n = TravelContextNotifier();
      n.proposeDestination(p('kedarnath'));
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'kedarnath');
      n.proposeDestination(p('mumbai'));
      expect(n.state.confirmedDestination?.id, 'kedarnath'); // still old until confirm
      n.confirmPending();
      expect(n.state.confirmedDestination?.id, 'mumbai');
    });

    test('Seq3: Kedarnath -> change mind (Mumbai pending, no confirm) => confirmed stays null', () {
      final n = TravelContextNotifier();
      n.proposeDestination(p('kedarnath'));
      n.proposeDestination(p('mumbai'));
      expect(n.state.pendingDestination?.id, 'mumbai');
      expect(n.state.confirmedDestination, isNull); // never confirmed -> map unaffected
    });

    test('diverse chain deterministic', () {
      final n = TravelContextNotifier();
      for (final id in ['kedarnath', 'mumbai', 'kashi_vishwanath', 'hyderabad', 'kedarnath', 'ayodhya_city', 'mumbai']) {
        n.proposeDestination(p(id));
        n.confirmPending();
        expect(n.state.confirmedDestination?.id, id);
      }
    });

    // Invariant 6: general questions never become travel commands
    test('Invariant6: general knowledge question -> null', () {
      expect(svc.resolveDestination('what is the capital of india'), isNull);
      expect(svc.resolveDestination('how are you today'), isNull);
    });
  });
}
