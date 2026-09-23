import '../models/agent_response.dart';
import '../services/llm_service.dart';
import '../services/nlu_service.dart';
import 'agent.dart';
import 'agent_registry_setup.dart';
import 'transport_agent.dart';
import 'travel_companion_agent.dart';

class IntentPlanner {
  IntentPlanner._() {
    // Ensure the specialist swarm is registered before any dispatch. Idempotent.
    if (AgentRegistry.instance.agents.isEmpty) registerPathSaathiAgents();
  }
  static final IntentPlanner instance = IntentPlanner._();

  /// Tracks which routing mode was used last (for UI badge display).
  String lastRoutingMode = 'keyword'; // 'llm' | 'nlu' | 'keyword'

  /// The intents from the last LLM plan (for UI/telemetry). Empty when the LLM
  /// tier was not used.
  List<String> lastPlanIntents = const [];

  /// Execute a single planned intent by dispatching through the AgentRegistry
  /// (polymorphic — no hardcoded switch). Returns null when no agent can handle
  /// the intent (e.g. 'document' is handled elsewhere) so the caller can fall
  /// through to another tier.
  Future<AgentResponse?> _runIntent(String intent, String? place,
      {Map<String, dynamic> slots = const {}}) async {
    return AgentRegistry.instance
        .dispatch(Intent(intent, place: place, slots: slots));
  }

  Future<AgentResponse> planAndExecute(String rawQuery) async {
    final query = rawQuery.toLowerCase().trim();

    final companionResponse =
        await TravelCompanionAgent.instance.answer(rawQuery);
    if (companionResponse != null) {
      lastRoutingMode = 'context';
      lastPlanIntents = const ['travel_context'];
      return companionResponse;
    }

    // ─────────────────────────────────────────────────────────────
    // TIER 1: On-device LLM planner — genuine task decomposition.
    // A spoken goal can produce MULTIPLE agent tasks (e.g. "bus and a tent").
    // We execute the primary task and attach the remaining tasks to rawData so
    // the orchestrator/UI can surface the full plan.
    // ─────────────────────────────────────────────────────────────
    if (LlmService.instance.isModelReady) {
      final plan = await LlmService.instance.planQuery(rawQuery);
      if (plan.primaryIntent != 'unknown') {
        lastRoutingMode = 'llm';
        lastPlanIntents = plan.intents;
        final primary = await _runIntent(plan.primaryIntent, plan.place);
        if (primary != null) {
          // The full decomposed plan (incl. any secondary tasks) is exposed via
          // `lastPlanIntents` for the orchestrator/UI. We do not mutate the
          // response's rawData (may be a const map).
          return primary;
        }
      }
      // LLM produced nothing usable → fall through to NLU/keyword tiers.
    }

    // ─────────────────────────────────────────────────────────────
    // TIER 2: MobileBERT NLU (if model downloaded ~25MB)
    // ─────────────────────────────────────────────────────────────
    if (NluService.instance.isModelReady) {
      final label = await NluService.instance.classify(rawQuery);
      lastRoutingMode = 'nlu';
      // Map the NLU label to a canonical intent, then dispatch via the registry.
      const nluToIntent = {
        'findTransport': 'transport',
        'findNavigation': 'navigation',
        'findAccommodation': 'accommodation',
        'getItinerary': 'itinerary',
        'getEmergency': 'safety',
      };
      final intent = nluToIntent[label];
      if (intent != null) {
        final res = await _runIntent(intent, null);
        if (res != null) return res;
      }
      // Unknown/unhandled → fall through to keyword.
    }

    // ─────────────────────────────────────────────────────────────
    // TIER 3: Multilingual Keyword Matching (always available)
    // ─────────────────────────────────────────────────────────────
    lastRoutingMode = 'keyword';

    // Parse the query into a canonical Intent, then dispatch via the registry.
    // The keyword rules here are the INTENT SOURCE; the AgentRegistry is the
    // single dispatch point (swap this parser for an LLM later, no dispatch
    // changes needed).
    final intent = _parseKeywordIntent(query);
    final res =
        await _runIntent(intent.kind, intent.place, slots: intent.slots);
    // The registry only lacks a handler for 'document' / 'unknown'; the safe
    // pilgrim-default is the next bus to Sangam.
    return res ?? await TransportAgent.instance.processQuery();
  }

  /// Multilingual keyword rules → a canonical [Intent]. Pure and testable.
  Intent _parseKeywordIntent(String query) {
    final isWhere = _isWhereQuery(query);
    final isWhen = _isWhenQuery(query);
    final isList = _isListQuery(query);

    // SCENARIO 1: WHERE IS X → Navigation (with a resolved place slot)
    if (isWhere) {
      if (_hasTransportKeywords(query)) {
        return const Intent('navigation', place: 'Gate 3 Bus Stand');
      } else if (_hasStayKeywords(query)) {
        return const Intent('navigation', place: 'Shakti Camp (Sector 7)');
      } else if (_hasMedicalKeywords(query)) {
        return const Intent('navigation', place: 'Medical Emergency Post 2');
      } else {
        return const Intent('navigation', place: 'Sangam Ghat');
      }
    }

    // SCENARIO 2: NEARBY HOTELS/CAMPS → Accommodation (list)
    if (isList && _hasStayKeywords(query)) {
      return const Intent('accommodation', slots: {'listAll': true});
    }

    // SCENARIO 3: EMERGENCY / DOCTOR / POLICE → Safety
    if (_hasMedicalKeywords(query) || _hasPoliceKeywords(query)) {
      return const Intent('safety');
    }

    // SCENARIO 4: ITINERARY / AARTI / SCHEDULE → Itinerary
    if (_hasItineraryKeywords(query)) {
      return const Intent('itinerary');
    }

    // SCENARIO 5: WHEN IS THE BUS → Transport
    if (isWhen || _hasTransportKeywords(query)) {
      final toSangam = query.contains('sangam') ||
          query.contains('संगम') ||
          query.contains('సంగం');
      return Intent('transport', place: toSangam ? 'Sangam Ghat' : null);
    }

    // SCENARIO 6: STAY / ACCOMMODATION DETAILS → Accommodation
    if (_hasStayKeywords(query)) {
      return const Intent('accommodation');
    }

    // Fallback: next bus to Sangam (default pilgrim intent).
    return const Intent('transport');
  }

  // ── Helper Intent Matchers ──────────────────────────────────────

  bool _isWhereQuery(String q) {
    const keywords = [
      'where',
      'location',
      'route',
      'navigate',
      'direction',
      'map',
      'way',
      'reach',
      'कहाँ',
      'किधर',
      'रास्ता',
      'मार्ग',
      'नक्शा',
      'पहुंचे',
      'ఎక్కడ',
      'ఎలా వెళ్ళాలి',
      'దారి',
      'మార్గం',
      'எங்கே',
      'வழி',
      'வரைபடம்',
      'ਕਿੱਥੇ',
      'ਰਸਤਾ',
      'कुठे',
      'कसे जायचे',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _isWhenQuery(String q) {
    const keywords = [
      'when',
      'time',
      'timing',
      'schedule',
      'departure',
      'frequency',
      'clock',
      'कब',
      'समय',
      'कितने बजे',
      'छूटेगी',
      'आएगी',
      'ఎప్పుడు',
      'సమయం',
      'ఎన్ని గంటలకు',
      'எப்போது',
      'நேரம்',
      'ਕਦੋਂ',
      'ਸਮਾਂ',
      'केव्हा',
      'वेळ',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _isListQuery(String q) {
    const keywords = [
      'nearby',
      'near',
      'list',
      'hotels',
      'camps',
      'options',
      'all',
      'available',
      'आसपास',
      'पास में',
      'होटल',
      'शिविर',
      'दिखाओ',
      'सूची',
      'సమీపంలో',
      'దగ్గర',
      'హోటళ్ళు',
      'జాబితా',
      'அருகில்',
      'பட்டியல்',
      'ਨੇੜੇ',
      'ਸੂਚੀ',
      'जवळपास',
      'यादी',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _hasTransportKeywords(String q) {
    const keywords = [
      'bus',
      'train',
      'travel',
      'station',
      'shuttle',
      'auto',
      'gate',
      'बस',
      'ट्रेन',
      'गाड़ी',
      'रेल',
      'स्टेशन',
      'किराया',
      'బస్',
      'రైలు',
      'బస్సు',
      'ప్రయాణం',
      'స్టేషన్',
      'பஸ்',
      'ரயில்',
      'பேருந்து',
      'ਬੱਸ',
      'ਰੇਲ',
      'बस',
      'गाडी',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _hasStayKeywords(String q) {
    const keywords = [
      'stay',
      'tent',
      'camp',
      'room',
      'hotel',
      'lodge',
      'sector',
      'accommodation',
      'तंबू',
      'टेंट',
      'शिविर',
      'कैंप',
      'रुकना',
      'ठहरना',
      'कमरा',
      'आवास',
      'వసతి',
      'క్యాంప్',
      'టెంట్',
      'గది',
      'సెక్టార్',
      'బస',
      'தங்குமிடம்',
      'முகாம்',
      'கூடாரம்',
      'ਕੈਂਪ',
      'ਤੰਬੂ',
      'मुक्काम',
      'कॅम्प',
      'निवास',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _hasMedicalKeywords(String q) {
    const keywords = [
      'doctor',
      'hospital',
      'medical',
      'ambulance',
      'sick',
      'hurt',
      'pain',
      'sos',
      'डॉक्टर',
      'अस्पताल',
      'दवा',
      'बीमार',
      'एंबुलेंस',
      'चिकित्सा',
      'డాక్టర్',
      'ఆసుపత్రి',
      'వైద్యం',
      'అంబులెన్స్',
      'மருத்துவர்',
      'மருத்துவமனை',
      'ਡਾਕਟਰ',
      'ਹਸਪਤਾਲ',
      'डॉक्टर',
      'दवाखाना',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _hasPoliceKeywords(String q) {
    const keywords = [
      'police',
      'help',
      'lost',
      'stolen',
      'emergency',
      'khoya paya',
      'पुलिस',
      'मदद',
      'खो गया',
      'चोरी',
      'सहायता',
      'పోలీస్',
      'సహాయం',
      'తప్పిపోయాను',
      'காவல்துறை',
      'உதவி',
      'ਪੁਲਿਸ',
      'ਮਦਦ',
      'पोलीस',
      'मदत',
    ];
    return keywords.any((k) => q.contains(k));
  }

  bool _hasItineraryKeywords(String q) {
    const keywords = [
      'schedule',
      'itinerary',
      'plan',
      'aarti',
      'program',
      'events',
      'routine',
      'snan',
      'योजना',
      'कार्यक्रम',
      'आरती',
      'स्नान',
      'पूजा',
      'ప్రణాళిక',
      'కార్యక్రమం',
      'హారతి',
      'స్నానం',
      'அட்டவணை',
      'திட்டம்',
      'நிகழ்ச்சி',
      'ਸ਼ਡਿਊਲ',
      'ਪ੍ਰੋਗਰਾਮ',
      'वेळापत्रक',
      'नियोजन',
    ];
    return keywords.any((k) => q.contains(k));
  }
}
