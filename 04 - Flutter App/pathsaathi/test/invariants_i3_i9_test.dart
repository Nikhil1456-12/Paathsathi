// Invariant regression tests I3 and I9 (additive coverage — approved D2).
//
// These exercise the REAL implementations:
//   • TravelContextNotifier (lib/providers/travel_context.dart) including its
//     actual SharedPreferences persist (_persistConfirmed) and rehydrate
//     (_restore) path — a brand-new notifier instance is created to simulate an
//     app restart, so the genuine restore code runs.
//   • LanguageNotifier (lib/providers/language_provider.dart) to prove language
//     selection is decoupled from travel state.
//
// SharedPreferences.setMockInitialValues backs the platform channel only; the
// production persistence code under test is unchanged and unmocked.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathsaathi/providers/travel_context.dart';
import 'package:pathsaathi/providers/language_provider.dart';
import 'package:pathsaathi/services/place_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Place place(String id) =>
      PlaceSearchService.places.firstWhere((p) => p.id == id);

  setUp(() {
    // Fresh, empty persistence for each test (real plugin, mock backing store).
    SharedPreferences.setMockInitialValues({});
  });

  test('I3: changing selected language does NOT mutate the confirmed destination',
      () async {
    final travel = TravelContextNotifier();
    final lang = LanguageNotifier();

    // Establish a confirmed destination.
    travel.proposeDestination(place('kedarnath'));
    travel.confirmPending();
    expect(travel.state.confirmedDestination?.id, 'kedarnath');

    // Change the selected language repeatedly through the REAL language API.
    lang.select(languageByCode('hi'));
    lang.select(languageByCode('te'));
    lang.select(languageByCode('ta'));
    lang.select(languageByCode('en'));

    // Travel context is language-independent: destination is untouched, and no
    // pending/ origin was introduced by language changes.
    expect(travel.state.confirmedDestination?.id, 'kedarnath',
        reason: 'language change must not mutate confirmed destination');
    expect(travel.state.pendingDestination, isNull);
    expect(travel.state.origin, isNull);
  });

  test(
      'I9: after restart, confirmed destination is restored but a prior pending is NOT',
      () async {
    // Session 1: confirm Kedarnath, then propose (but do NOT confirm) Mumbai.
    final session1 = TravelContextNotifier();
    session1.proposeDestination(place('kedarnath'));
    session1.confirmPending(); // persists 'kedarnath'
    session1.proposeDestination(place('mumbai')); // pending only, NOT persisted
    expect(session1.state.confirmedDestination?.id, 'kedarnath');
    expect(session1.state.pendingDestination?.id, 'mumbai');

    // Let async _persistConfirmed complete before "restart".
    await pumpEventQueue();

    // Session 2: brand-new notifier = simulated app restart. Its constructor
    // runs the real _restore() from SharedPreferences.
    final session2 = TravelContextNotifier();
    await pumpEventQueue(); // allow async _restore() to finish

    // Confirmed destination restored…
    expect(session2.state.confirmedDestination?.id, 'kedarnath',
        reason: 'confirmed destination must survive restart');
    // …but the unconfirmed pending (Mumbai) must NOT resurface.
    expect(session2.state.pendingDestination, isNull,
        reason: 'a prior pending/unconfirmed destination must not be restored');
  });
}
