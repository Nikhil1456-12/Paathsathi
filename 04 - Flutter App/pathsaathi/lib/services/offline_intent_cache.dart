// lib/services/offline_intent_cache.dart
//
// TIER 0 — Sub-millisecond Offline Intent Cache for PathSaathi
//
// Intercepts ~30 high-frequency hot query patterns BEFORE any agent,
// network, or ML model is involved. Response latency: <1ms.
//
// Hot patterns cover: SOS, First Aid, Ritual Timings, Static Facility Maps,
// Lost Child protocol, and frequently asked Hindi/Telugu/English questions.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/agent_response.dart';

class OfflineIntentCache {
  OfflineIntentCache._();
  static final OfflineIntentCache instance = OfflineIntentCache._();

  /// Lookup a query. Returns null if no cache hit (fall through to next tier).
  AgentResponse? lookup(String rawQuery) {
    final q = rawQuery.toLowerCase().trim();

    // ── SOS / Emergency hot-patterns ─────────────────────────────
    if (_matchesAny(q, _sosPatterns)) return _sosResponse;

    // ── First Aid hot-patterns ────────────────────────────────────
    if (_matchesAny(q, _firstAidPatterns)) return _firstAidResponse;

    // ── Lost Child / Person ───────────────────────────────────────
    if (_matchesAny(q, _lostChildPatterns)) return _lostChildResponse;

    // ── Ritual Timings (Snan, Aarti) ─────────────────────────────
    if (_matchesAny(q, _ritualPatterns)) return _ritualTimingsResponse;

    // ── Nearest Medical Post ──────────────────────────────────────
    if (_matchesAny(q, _medicalPatterns)) return _medicalResponse;

    // ── Water / Drinking Water ────────────────────────────────────
    if (_matchesAny(q, _waterPatterns)) return _waterResponse;

    // ── Food / Langar / Annakshetra ───────────────────────────────
    if (_matchesAny(q, _foodPatterns)) return _foodResponse;

    // ── Toilet / Sanitation ───────────────────────────────────────
    if (_matchesAny(q, _toiletPatterns)) return _toiletResponse;

    return null; // Cache miss → escalate to Fog / On-Device / Cloud
  }

  bool _matchesAny(String q, List<String> patterns) =>
      patterns.any((p) => q.contains(p));

  // ── Pattern Banks ─────────────────────────────────────────────────────────

  static const _sosPatterns = [
    // English
    'sos', 'help me', 'emergency', 'ambulance', 'dying', 'heart attack',
    'unconscious', 'collapsed', 'chest pain', 'crush', 'stampede',
    // Hindi
    'bachao', 'madad karo', 'ambulance bulao', 'hospital jaldi',
    'dil dard', 'behosh', 'achaanak gir gaya',
    // Telugu
    'sahaayam', 'ambulance palikandi', 'pramadam', 'mottam', 'padipoyadu',
    // Tamil
    'udavi', 'ambulance anuppu', 'apathu',
  ];

  static const _firstAidPatterns = [
    'first aid', 'bleeding', 'wound', 'burn', 'fracture', 'broken bone',
    'snake bite', 'heat stroke', 'dehydration', 'faint', 'dizzy',
    'prathamik upchar', 'khoon aa raha', 'jal gaya', 'haath tuta',
    'modumu poyindi', 'gaayu', 'kaay',
  ];

  static const _lostChildPatterns = [
    'lost child', 'lost my child', 'missing child', 'baccha kho gaya',
    'bacha nahi mila', 'mera bacha', 'pillala', 'pilladu kayam',
    'lost person', 'kho gaya', 'nahi mil raha',
    'lost in crowd', 'separated from family',
  ];

  static const _ritualPatterns = [
    'snan time', 'snan ka time', 'bathing time', 'amrit snan', 'mauni amavasya',
    'basant panchami', 'maha shivratri snan', 'aarti time', 'aarti kab',
    'aarti schedule', 'sangam aarti', 'puja time', 'ritual timing',
    'snanam time', 'snaanam enduku', 'snanam schedule',
    'मौनी अमावस्या', 'बसंत पंचमी', 'महाशिवरात्रि',
    'shahi snan', 'raj snan',
  ];

  static const _medicalPatterns = [
    'doctor', 'hospital', 'medical', 'health center', 'clinic', 'nurse',
    'doctor kahan', 'aspatal', 'davakhana',
    'doctor ekkada', 'hospital ekkada', 'arogya',
    'vaiddya', 'marutthuvamanai',
  ];

  static const _waterPatterns = [
    'water', 'drinking water', 'paani', 'jal', 'pani kahan',
    'water atm', 'jal sewa', 'thirst', 'pyaas', 'neer', 'neeru',
    'neera ekkada', 'kudipuneer',
  ];

  static const _foodPatterns = [
    'food', 'langar', 'bhoj', 'bhojan', 'khana', 'annakshetra',
    'prasad', 'free food', 'khana kahan', 'anna', 'annam',
    'unam', 'saapadu', 'bhojanam ekkada',
  ];

  static const _toiletPatterns = [
    'toilet', 'washroom', 'bathroom', 'latrine', 'shauchalaya',
    'sulabh', 'sauchalaya kahan', 'rest room',
    'toilet ekkada', 'kaalatrai',
  ];

  // ── Pre-built Static Responses ────────────────────────────────────────────

  static const _sosResponse = AgentResponse(
    type: AgentType.safety,
    title: '🚨 SOS — Emergency Services',
    subtitle: 'Nearest Medical Post: 200m North • Police: 300m East',
    primaryValue: '📞 112 / 1920',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFFDC2626),
    primaryIcon: Icons.emergency_share_rounded,
    spokenTextEnglish:
        'Emergency! Call 112 immediately. Nearest medical post is 200 metres north. Stay calm, help is coming.',
    spokenTextHindi:
        'आपातकाल! अभी 112 पर कॉल करें। सबसे नज़दीक चिकित्सा केंद्र 200 मीटर उत्तर में है। शांत रहें, मदद आ रही है।',
    spokenTextTelugu:
        'అత్యవసరం! వెంటనే 112 కి కాల్ చేయండి. సమీప వైద్య కేంద్రం 200 మీటర్ల ఉత్తరాన ఉంది. శాంతంగా ఉండండి.',
    spokenTextTamil:
        'அவசரநிலை! உடனே 112 ஐ அழையுங்கள். அருகில் உள்ள மருத்துவ நிலையம் 200 மீட்டர் வடக்கே உள்ளது.',
    destinationCoords: LatLng(25.4420, 81.8750),
    actionButtonText: 'View Map to Medical Post',
    actionButtonRoute: '/nav',
    rawData: {
      'tier': 'CACHE',
      'responseMs': '<1',
      'phone': '112',
      'altPhone': '1920',
      'sosType': 'general_emergency',
    },
  );

  static const _firstAidResponse = AgentResponse(
    type: AgentType.safety,
    title: '🩹 First Aid — Immediate Steps',
    subtitle: 'First Aid Post: 200m North • Medical Post 2: 300m',
    primaryValue: '📞 1920 (Health Helpline)',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFFDC2626),
    primaryIcon: Icons.health_and_safety_rounded,
    spokenTextEnglish:
        'For bleeding: apply firm pressure. For burns: cool with water for 10 minutes. For fractures: do not move the person. Call 1920 for medical helpline.',
    spokenTextHindi:
        'खून बहने पर: कपड़े से दबाव लगाएं। जलने पर: 10 मिनट पानी से ठंडा करें। हड्डी टूटने पर: हिलाएं नहीं। 1920 पर कॉल करें।',
    spokenTextTelugu:
        'రక్తస్రావమైతే: గట్టిగా నొక్కండి. కాలుపు అయితే: 10 నిమిషాలు నీటితో చల్లారించండి. ఎముక విరిగితే: కదిలించవద్దు. 1920 కి కాల్ చేయండి.',
    rawData: {'tier': 'CACHE', 'responseMs': '<1', 'type': 'first_aid'},
  );

  static const _lostChildResponse = AgentResponse(
    type: AgentType.safety,
    title: '🔍 Lost Child — Immediate Protocol',
    subtitle: 'Lost & Found Centre: Sector 7 • Control Room: Sector 1',
    primaryValue: '📞 1090 / Kumbh Helpline',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFFD97706),
    primaryIcon: Icons.child_care_rounded,
    spokenTextEnglish:
        'Lost child! Go immediately to Lost & Found Centre at Sector 7 Gate. Call 1090 Kumbh helpline. Announce via PA system at nearest control point.',
    spokenTextHindi:
        'बच्चा खो गया! सेक्टर 7 गेट पर लॉस्ट एंड फाउंड केंद्र पर जाएं। 1090 कुंभ हेल्पलाइन पर कॉल करें।',
    spokenTextTelugu:
        'పిల్లవాడు తప్పిపోయాడు! సెక్టర్ 7 గేట్ వద్ద లాస్ట్ అండ్ ఫౌండ్ కేంద్రానికి వెళ్ళండి. 1090 కి కాల్ చేయండి.',
    destinationCoords: LatLng(25.4460, 81.8680),
    actionButtonText: 'Navigate to Lost & Found Centre',
    actionButtonRoute: '/nav',
    rawData: {
      'tier': 'CACHE',
      'responseMs': '<1',
      'type': 'lost_child',
      'phone': '1090',
    },
  );

  static const _ritualTimingsResponse = AgentResponse(
    type: AgentType.itinerary,
    title: '🕉️ Kumbh 2025 — Sacred Bath Schedule',
    subtitle: 'Prayagraj Maha Kumbh 2025 Official Snan Timings',
    primaryValue: '5:00 AM – 9:00 AM',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFFD97706),
    primaryIcon: Icons.water_rounded,
    spokenTextEnglish:
        'Amrit Snan timings at Prayagraj 2025: Mauni Amavasya — January 29, Basant Panchami — February 3, Maha Shivratri — February 26. Best bathing time: 5 AM to 9 AM. Ganga Aarti: 6:30 PM daily.',
    spokenTextHindi:
        'प्रयागराज 2025 अमृत स्नान: मौनी अमावस्या — 29 जनवरी, बसंत पंचमी — 3 फरवरी, महाशिवरात्रि — 26 फरवरी। सबसे अच्छा समय: सुबह 5 से 9 बजे। गंगा आरती: शाम 6:30 बजे।',
    spokenTextTelugu:
        'ప్రయాగరాజ్ 2025 అమృత స్నాన: మౌని అమావాస్య — జనవరి 29, బసంత్ పంచమి — ఫిబ్రవరి 3, మహాశివరాత్రి — ఫిబ్రవరి 26. ఉత్తమ సమయం: ఉదయం 5 నుండి 9 గంటలు.',
    spokenTextTamil:
        'குளியல் நேரம்: ஜனவரி 29 — மவுனி அமாவாசை, பிப்ரவரி 3 — வசந்த பஞ்சமி. காலை 5 முதல் 9 மணி வரை சிறந்தது.',
    rawData: {
      'tier': 'CACHE',
      'responseMs': '<1',
      'type': 'ritual_timings',
      'dates': {
        'Mauni Amavasya': 'January 29, 2025',
        'Basant Panchami': 'February 3, 2025',
        'Maha Shivratri': 'February 26, 2025',
      },
    },
  );

  static const _medicalResponse = AgentResponse(
    type: AgentType.navigation,
    title: '🏥 Medical Post 2 — Nearest',
    subtitle: 'Walk 3 minutes North on Triveni Marg',
    primaryValue: '200 m — 3 min walk',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFFDC2626),
    primaryIcon: Icons.local_hospital_rounded,
    spokenTextEnglish:
        'Nearest medical post is 200 metres north. Walk straight on Triveni Marg, look for red cross flag. Open 24 hours. Emergency: call 112.',
    spokenTextHindi:
        'सबसे नज़दीक चिकित्सा केंद्र 200 मीटर उत्तर में है। त्रिवेणी मार्ग पर सीधे जाएं, लाल क्रॉस झंडा देखें।',
    spokenTextTelugu:
        'సమీప వైద్య కేంద్రం 200 మీటర్ల ఉత్తరాన ఉంది. త్రివేణి మార్గంలో నేరుగా వెళ్ళండి.',
    destinationCoords: LatLng(25.4420, 81.8750),
    actionButtonText: 'Navigate to Medical Post',
    actionButtonRoute: '/nav',
    rawData: {'tier': 'CACHE', 'responseMs': '<1', 'type': 'medical'},
  );

  static const _waterResponse = AgentResponse(
    type: AgentType.navigation,
    title: '💧 Jal Sewa Water ATM — 150m',
    subtitle: 'Free drinking water — 24×7 service',
    primaryValue: '150 m — 2 min walk',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFF0284C7),
    primaryIcon: Icons.water_drop_rounded,
    spokenTextEnglish:
        'Free drinking water station is 150 metres away. Jal Sewa ATM at Sector 4 Gate. Carry your bottle. Water is safe and purified.',
    spokenTextHindi:
        'मुफ्त पीने का पानी 150 मीटर दूर है। सेक्टर 4 गेट पर जल सेवा ATM। अपनी बोतल साथ लाएं।',
    spokenTextTelugu:
        'ఉచిత మంచినీళ్ళు 150 మీటర్ల దూరంలో ఉన్నాయి. సెక్టార్ 4 గేటు వద్ద జల సేవా ATM.',
    destinationCoords: LatLng(25.4395, 81.8765),
    actionButtonText: 'Navigate to Water ATM',
    actionButtonRoute: '/nav',
    rawData: {'tier': 'CACHE', 'responseMs': '<1', 'type': 'water'},
  );

  static const _foodResponse = AgentResponse(
    type: AgentType.navigation,
    title: '🍱 Annakshetra (Free Langar) — 400m',
    subtitle: 'Free meals — Breakfast 7-9 AM, Lunch 12-2 PM, Dinner 7-9 PM',
    primaryValue: '400 m — 5 min walk',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFF059669),
    primaryIcon: Icons.restaurant_rounded,
    spokenTextEnglish:
        'Free food at Annakshetra, 400 metres away. Meals served three times daily: breakfast 7-9 AM, lunch 12-2 PM, dinner 7-9 PM. Prasad available at all major ghats.',
    spokenTextHindi:
        'अन्नक्षेत्र में मुफ्त भोजन 400 मीटर दूर। दिन में तीन बार: सुबह 7-9, दोपहर 12-2, शाम 7-9 बजे।',
    spokenTextTelugu:
        'అన్నక్షేత్రంలో ఉచిత భోజనం 400 మీటర్ల దూరంలో ఉంది. రోజుకు మూడు సార్లు: ఉదయం 7-9, మధ్యాహ్నం 12-2, సాయంత్రం 7-9.',
    destinationCoords: LatLng(25.4440, 81.8710),
    actionButtonText: 'Navigate to Annakshetra',
    actionButtonRoute: '/nav',
    rawData: {'tier': 'CACHE', 'responseMs': '<1', 'type': 'food'},
  );

  static const _toiletResponse = AgentResponse(
    type: AgentType.navigation,
    title: '🚻 Sulabh Sauchalaya — 80m',
    subtitle: 'Clean washrooms at every 500m along all Margas',
    primaryValue: '80 m — 1 min walk',
    badgeText: 'CACHE • <1ms',
    badgeColor: Color(0xFF475569),
    primaryIcon: Icons.wc_rounded,
    spokenTextEnglish:
        'Nearest washroom is 80 metres away on Triveni Marg. Sulabh Sauchalaya facilities are available every 500 metres along all major routes. Women-only section available.',
    spokenTextHindi:
        'सबसे नज़दीक शौचालय 80 मीटर दूर त्रिवेणी मार्ग पर है। सुलभ शौचालय हर 500 मीटर पर उपलब्ध हैं।',
    spokenTextTelugu:
        'సమీప మరుగుదొడ్డి 80 మీటర్ల దూరంలో ఉంది. సులభ్ మరుగుదొడ్లు ప్రతి 500 మీటర్లకు అందుబాటులో ఉన్నాయి.',
    destinationCoords: LatLng(25.4418, 81.8742),
    rawData: {'tier': 'CACHE', 'responseMs': '<1', 'type': 'toilet'},
  );
}
