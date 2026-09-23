// Journey Pack SCREEN — smallest targeted widget tests.
// Verifies the UI over the REAL JourneyPackService + travel context, for
// multiple unrelated destinations, with honest AVAILABLE/UNAVAILABLE/LIVE_ONLY.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pathsaathi/providers/travel_context.dart';
import 'package:pathsaathi/providers/language_provider.dart';
import 'package:pathsaathi/services/journey_pack_service.dart';
import 'package:pathsaathi/services/place_search_service.dart';
import 'package:pathsaathi/screens/journey_pack_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final places = PlaceSearchService.instance;

  // Minimal host router so context.go('/home') from the screen has a target.
  GoRouter router() => GoRouter(routes: [
        GoRoute(path: '/', builder: (c, s) => const JourneyPackScreen()),
        GoRoute(path: '/home', builder: (c, s) => const Scaffold()),
      ]);

  Future<void> pumpScreen(WidgetTester tester, {String? confirmId}) async {
    final container = ProviderContainer();
    // Assert against English labels deterministically (default provider is Hindi).
    container.read(languageProvider.notifier).select(languageByCode('en'));
    if (confirmId != null) {
      container.read(travelContextProvider.notifier).setConfirmed(places.byId(confirmId)!);
      // setConfirmed prepares the pack via fire-and-forget; ensure it's saved.
      await JourneyPackService.instance.prepareAndSave(places.byId(confirmId)!);
    }
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router()),
    ));
    await tester.pumpAndSettle();
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('no confirmed destination -> truthful empty state', (tester) async {
    await pumpScreen(tester); // no destination
    expect(find.byKey(const Key('jp_no_destination')), findsOneWidget);
  });

  testWidgets('confirmed but pack not prepared -> not-prepared state', (tester) async {
    // Rehydrate a CONFIRMED destination from persistence WITHOUT any saved pack.
    SharedPreferences.setMockInitialValues({
      'flutter.confirmed_destination_id': 'mumbai',
    });
    final container = ProviderContainer();
    // allow the notifier's async _restore() to run
    await container.read(travelContextProvider.notifier).stream.first
        .timeout(const Duration(seconds: 2), onTimeout: () => container.read(travelContextProvider));
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router()),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jp_not_prepared')), findsOneWidget);
  });

  // Destination-agnostic: identical UI path for unrelated destinations.
  for (final id in ['kedarnath', 'hyderabad', 'mumbai', 'bengaluru']) {
    testWidgets('renders pack for "$id" with honest statuses', (tester) async {
      await pumpScreen(tester, confirmId: id);

      // Destination name shown.
      expect(find.byKey(const Key('jp_destination_name')), findsOneWidget);

      // Expected honest status per category. As each section is scrolled into
      // view we assert BOTH that it renders AND that its status chip text is the
      // truthful one (lazy list keeps only visible items, so assert in-loop).
      const expectedStatus = {
        'destination_info': 'Available offline',
        'pharmacies': 'Unavailable offline',
        'hotels': 'Unavailable offline',
        'airports': 'Unavailable offline',
        'offline_map': 'Unavailable offline',
        'live_transport': 'Requires internet',
        'emergency_live': 'Requires internet',
      };
      for (final cat in [
        'destination_info', 'landmarks', 'hospitals', 'railway_stations',
        'transport', 'pharmacies', 'hotels', 'airports', 'offline_map',
        'live_transport', 'emergency_live',
      ]) {
        final sectionKey = find.byKey(Key('jp_section_$cat'));
        await tester.scrollUntilVisible(sectionKey, 250.0);
        expect(sectionKey, findsOneWidget, reason: 'section $cat must render for $id');
        final want = expectedStatus[cat];
        if (want != null) {
          expect(find.descendant(of: sectionKey, matching: find.text(want)),
              findsOneWidget,
              reason: '$cat must honestly show "$want" for $id');
        }
      }
    });
  }
}
