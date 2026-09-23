import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pathsaathi/models/agent_response.dart';
import 'package:pathsaathi/agents/intent_planner.dart';
import 'package:pathsaathi/agents/transport_agent.dart';
import 'package:pathsaathi/agents/accommodation_agent.dart';
import 'package:pathsaathi/agents/navigation_agent.dart';
import 'package:pathsaathi/agents/itinerary_agent.dart';
import 'package:pathsaathi/agents/safety_agent.dart';
import 'package:pathsaathi/agents/document_agent.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('🧠 1. Multilingual Semantic Intent Planner Tests (25 Scenarios)', () {
    test('Scenario 1: English "Where is my bus?" routes to Navigation', () async {
      final res = await IntentPlanner.instance.planAndExecute('Where is my bus?');
      expect(res.type, AgentType.navigation);
      // NavigationAgent now resolves a REAL place name (no hardcoded "Gate 3").
      expect(res.title.toLowerCase(), contains('route to'));
    });

    test('Scenario 2: Hindi "Mera bus kahan hai?" routes to Navigation', () async {
      final res = await IntentPlanner.instance.planAndExecute('मेरा बस कहाँ है?');
      expect(res.type, AgentType.navigation);
      expect(res.destinationCoords, isNotNull);
    });

    test('Scenario 3: Telugu "Na bus ekkada undi?" routes to Navigation', () async {
      final res = await IntentPlanner.instance.planAndExecute('నా బస్ ఎక్కడ ఉంది?');
      expect(res.type, AgentType.navigation);
    });

    test('Scenario 4: English "When is the bus?" routes to Transport Schedule', () async {
      final res = await IntentPlanner.instance.planAndExecute('When is the next bus to Sangam?');
      expect(res.type, AgentType.transport);
      expect(res.primaryValue, contains('06:00 AM'));
    });

    test('Scenario 5: Hindi "Bus kab aayegi?" routes to Transport Schedule', () async {
      final res = await IntentPlanner.instance.planAndExecute('बस कब छूटेगी?');
      expect(res.type, AgentType.transport);
    });

    test('Scenario 6: English "Where is my tent?" routes to Navigation (Camp)', () async {
      final res = await IntentPlanner.instance.planAndExecute('Where is my tent in Sector 7?');
      expect(res.type, AgentType.navigation);
      // Honest: no hardcoded "Shakti Camp"; routes to navigation (real place or
      // truthful "location unknown" when the place isn't in the offline data).
    });

    test('Scenario 7: Hindi "Mera tambu kahan hai?" routes to Navigation (Camp)', () async {
      final res = await IntentPlanner.instance.planAndExecute('मेरा तंबू कहाँ है?');
      expect(res.type, AgentType.navigation);
    });

    test('Scenario 8: English "Nearby hotels & accommodations" routes to Camp List', () async {
      final res = await IntentPlanner.instance.planAndExecute('Show nearby hotels and camps');
      expect(res.type, AgentType.accommodation);
      expect(res.rawData.containsKey('camps'), isTrue);
    });

    test('Scenario 9: Hindi "Aaspaas ke shivir dikhao" routes to Camp List', () async {
      final res = await IntentPlanner.instance.planAndExecute('आसपास के शिविर दिखाओ');
      expect(res.type, AgentType.accommodation);
      expect(res.rawData.containsKey('camps'), isTrue);
    });

    test('Scenario 10: Telugu "Sameepamlo unna vasathi" routes to Camp List', () async {
      final res = await IntentPlanner.instance.planAndExecute('సమీపంలో ఉన్న వసతి శిబిరాలు');
      expect(res.type, AgentType.accommodation);
    });

    test('Scenario 11: English "Where is the doctor / hospital?" routes to Navigation (Medical)', () async {
      final res = await IntentPlanner.instance.planAndExecute('Where is the doctor or hospital?');
      expect(res.type, AgentType.navigation);
      // Routes to navigation toward a real resolved hospital place (no hardcoded
      // "Medical Emergency Post" string anymore).
      expect(res.title.toLowerCase(), contains('route to'));
    });

    test('Scenario 12: Hindi "Doctor kahan hai?" routes to Navigation (Medical)', () async {
      final res = await IntentPlanner.instance.planAndExecute('डॉक्टर कहाँ है?');
      expect(res.type, AgentType.navigation);
      expect(res.title.toLowerCase(), contains('route to'));
    });

    test('Scenario 13: Emergency Medical Help (Chest Pain / Ambulance)', () async {
      final res = await IntentPlanner.instance.planAndExecute('Emergency ambulance doctor fast');
      expect(res.type, AgentType.safety);
      expect(res.primaryValue, contains('108'));
    });

    test('Scenario 14: Hindi Emergency "Chakkar aa raha hai ambulance bulo"', () async {
      final res = await IntentPlanner.instance.planAndExecute('चक्कर आ रहा है एंबुलेंस बुलाओ');
      expect(res.type, AgentType.safety);
    });

    test('Scenario 15: Police / Lost person help', () async {
      final res = await IntentPlanner.instance.planAndExecute('Police helpline I am lost');
      expect(res.type, AgentType.safety);
    });

    test('Scenario 16: English "Today schedule & aarti timings"', () async {
      final res = await IntentPlanner.instance.planAndExecute('Today schedule and aarti timings');
      expect(res.type, AgentType.itinerary);
      expect(res.title.toLowerCase(), contains('schedule'));
    });

    test('Scenario 17: Hindi "Aarti kitne baje hogi?"', () async {
      final res = await IntentPlanner.instance.planAndExecute('आरती कितने बजे होगी?');
      expect(res.type, AgentType.itinerary);
    });

    test('Scenario 18: Telugu "Ee roju pranalika"', () async {
      final res = await IntentPlanner.instance.planAndExecute('ఈరోజు ప్రణాళిక మరియు హారతి');
      expect(res.type, AgentType.itinerary);
    });

    test('Scenario 19: Tamil "Indraya thittam"', () async {
      final res = await IntentPlanner.instance.planAndExecute('இன்றைய அட்டவணை மற்றும் பூஜை');
      expect(res.type, AgentType.itinerary);
    });

    test('Scenario 20: Punjabi "Ajj da schedule"', () async {
      final res = await IntentPlanner.instance.planAndExecute('ਅੱਜ ਦਾ ਸ਼ਡਿਊਲ ਕੀ ਹੈ?');
      expect(res.type, AgentType.itinerary);
    });

    test('Scenario 21: Marathi "Aajche velapatrak"', () async {
      final res = await IntentPlanner.instance.planAndExecute('आजचे वेळापत्रक काय आहे?');
      expect(res.type, AgentType.itinerary);
    });

    test('Scenario 22: English "How to reach Sangam Ghat?" routes to Navigation', () async {
      final res = await IntentPlanner.instance.planAndExecute('How to reach Sangam Ghat?');
      expect(res.type, AgentType.navigation);
      expect(res.title.toLowerCase(), contains('sangam'));
    });

    test('Scenario 23: Hindi "Sangam kaise jaun?" routes to Navigation', () async {
      final res = await IntentPlanner.instance.planAndExecute('संगम कैसे पहुंचे?');
      expect(res.type, AgentType.navigation);
    });

    test('Scenario 24: Special train inquiry routes to Transport', () async {
      final res = await IntentPlanner.instance.planAndExecute('Train to Delhi timings platform');
      expect(res.type, AgentType.transport);
    });

    test('Scenario 25: Fallback general query defaults gracefully', () async {
      final res = await IntentPlanner.instance.planAndExecute('Hello PathSaathi help me');
      expect(res.type, isNotNull);
      expect(res.title, isNotEmpty);
    });
  });

  group('🤖 2. Domain Agents Response Integrity Tests', () {
    test('TransportAgent outputs valid spoken multilingual text', () async {
      final res = await TransportAgent.instance.processQuery();
      expect(res.getSpokenText('en'), contains('Bus'));
      expect(res.getSpokenText('hi'), contains('बस'));
      expect(res.getSpokenText('te'), contains('సీట్లు'));
      expect(res.getSpokenText('ta'), contains('புறப்படும்'));
      expect(res.getSpokenText('mr'), contains('निघेल'));
      expect(res.getSpokenText('pa'), contains('ਚੱਲੇਗੀ'));
    });

    test('AccommodationAgent returns valid GPS coordinates and tent info', () async {
      final res = await AccommodationAgent.instance.processQuery(listAll: false);
      expect(res.destinationCoords, isNotNull);
      expect(res.primaryValue, contains('Tent'));
    });

    test('NavigationAgent returns a navigation response for the destination', () async {
      final res = await NavigationAgent.instance.processQuery(destination: 'Sangam Ghat');
      // Honest, GPS-driven agent: it resolves the destination and returns a
      // navigation response. Distance depends on a real GPS fix, so in a test
      // (no fix) it truthfully reports a GPS state instead of a fabricated "850 m".
      expect(res.type, AgentType.navigation);
      expect(res.title.toLowerCase(), contains('sangam'));
      expect(res.primaryValue, isNotEmpty);
    });

    test('ItineraryAgent produces schedule card', () async {
      final res = await ItineraryAgent.instance.processQuery();
      expect(res.badgeText, contains('Schedule'));
    });

    test('SafetyAgent returns emergency phone numbers', () async {
      final res = await SafetyAgent.instance.processQuery();
      expect(res.primaryValue, contains('108'));
    });
  });

  group('🔒 3. Secure Document Agent Data Model Tests', () {
    test('SecureDocument serialization and masking', () {
      const doc = SecureDocument(
        id: 'doc_test',
        title: 'Aadhaar Card',
        docType: 'Identity',
        maskedNumber: 'XXXX-XXXX-1234',
        dateAdded: '30 Aug 2026',
        rawContent: 'UID: 9876 5432 1234',
      );

      final json = doc.toJson();
      expect(json['id'], 'doc_test');
      expect(json['maskedNumber'], 'XXXX-XXXX-1234');

      final reconstructed = SecureDocument.fromJson(json);
      expect(reconstructed.title, doc.title);
      expect(reconstructed.rawContent, doc.rawContent);
    });
  });
}
