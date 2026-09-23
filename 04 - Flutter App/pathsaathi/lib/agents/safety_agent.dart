import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/agent_response.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import 'fog/medical_sos_agent.dart';
import 'navigation_agent.dart' show NavMath;

/// Safety & Alert Agent — finds the NEAREST emergency facility to the user's
/// live GPS position and reports a REAL computed distance + direction.
///
/// Honesty rules (same as NavigationAgent):
///  • Facility coordinates are real (MedicalSosAgent.kumbhMedicalPosts).
///  • Distance/bearing are computed from the actual GPS fix (haversine).
///  • With no GPS fix it does NOT invent "200m away" — it reports the posts it
///    knows about and asks the user to enable location for exact distance.
///  • Emergency numbers (108 medical / 112 police) are always shown.
class SafetyAgent {
  SafetyAgent._();
  static final SafetyAgent instance = SafetyAgent._();

  static const Distance _dist = Distance();

  Future<AgentResponse> processQuery({String emergencyType = 'medical'}) async {
    const posts = MedicalSosAgent.kumbhMedicalPosts;
    final snap = LocationService.instance.last;
    final here = snap.state.hasFix ? snap.position : null;

    // ── No GPS fix — truthful: name a known post, no fabricated distance ──
    if (here == null || posts.isEmpty) {
      final fallback = posts.isNotEmpty ? posts.first : null;
      final name = fallback?.name ?? 'the nearest medical post';
      return AgentResponse(
        type: AgentType.safety,
        title: '🚨 Emergency Help',
        subtitle: posts.isEmpty
            ? 'Call 108 (medical) or 112 (police) now.'
            : 'Enable location for exact distance to $name.',
        primaryValue: 'Call: 108 / 112',
        badgeText: 'GPS needed',
        badgeColor: const Color(0xFFDC2626),
        primaryIcon: Icons.local_hospital_rounded,
        spokenTextEnglish:
            'Emergency help is available. Dial 108 for medical or 112 for police. '
            'Turn on location to guide you to the nearest medical post.',
        spokenTextHindi:
            'आपातकालीन मदद उपलब्ध है। चिकित्सा के लिए 108 या पुलिस के लिए 112 डायल करें। '
            'निकटतम मेडिकल पोस्ट तक पहुँचाने के लिए लोकेशन चालू करें।',
        spokenTextTelugu:
            'అత్యవసర సహాయం అందుబాటులో ఉంది. వైద్యానికి 108 లేదా పోలీసుకు 112 డయల్ చేయండి. '
            'దగ్గరి మెడికల్ పోస్ట్‌కు దారి చూపడానికి లొకేషన్ ఆన్ చేయండి.',
        spokenTextTamil:
            'அவசர உதவி உள்ளது. மருத்துவத்திற்கு 108 அல்லது காவல்துறைக்கு 112 அழைக்கவும்.',
        spokenTextMarathi:
            'आपत्कालीन मदत उपलब्ध आहे. वैद्यकीयसाठी 108 किंवा पोलिसांसाठी 112 डायल करा.',
        spokenTextPunjabi:
            'ਐਮਰਜੈਂਸੀ ਮਦਦ ਉਪਲਬਧ ਹੈ। ਮੈਡੀਕਲ ਲਈ 108 ਜਾਂ ਪੁਲਿਸ ਲਈ 112 ਡਾਇਲ ਕਰੋ।',
        rawData: const {
          'helpline': '108',
          'police': '112',
          'gps': 'unavailable'
        },
        destinationCoords: fallback?.location,
        actionButtonText: 'Open Emergency Center',
        actionButtonRoute: '/emergency',
      );
    }

    // ── Find the nearest facility, preferring one that fits the need ──────
    // For medical emergencies prefer posts with a 24h doctor / ambulance; for
    // any other type just take the geographically nearest post.
    final wantMedical = emergencyType == 'medical';
    MedicalPost? best;
    double bestMetres = double.infinity;
    for (final p in posts) {
      final m = _dist.as(LengthUnit.Meter, here, p.location);
      // Small preference bump for capable posts on medical calls: treat a
      // fully-equipped post as slightly "closer" so ties favour real capacity.
      final effective =
          wantMedical && (p.has24HrDoctor && p.hasAmbulance) ? m * 0.85 : m;
      if (effective < bestMetres) {
        bestMetres = effective;
        best = p;
      }
    }
    best ??= posts.first;

    // Try a REAL along-path route (offline A* over the bundled graph). If no
    // graph covers the user's region, fall back to straight-line but LABEL it
    // approximate — never present a straight-line number as a real route.
    final route = await RoutingService.instance.route(here, best.location);
    final double metres;
    final bool approx;
    if (route != null) {
      metres = route.distanceMeters;
      approx = false;
    } else {
      metres = _dist.as(LengthUnit.Meter, here, best.location);
      approx = true;
    }

    final bearing =
        NavMath.normalizeBearing(_dist.bearing(here, best.location));
    final compass = NavMath.compass(bearing);
    final distLabel = NavMath.distanceLabel(metres);
    final walkMin = NavMath.walkMinutes(metres);
    final accuracyNote =
        snap.state == GpsState.lowAccuracy ? ' (GPS accuracy is low)' : '';
    final ambulance = best.hasAmbulance ? ' Ambulance available.' : '';
    // Honest qualifier appended to distance phrasing.
    final approxEn = approx ? ' (straight-line, approximate)' : ' by path';
    final approxHi = approx ? ' (सीधी दूरी, अनुमानित)' : ' रास्ते से';
    final approxTe = approx ? ' (సరళరేఖ, సుమారు)' : ' దారి ప్రకారం';

    return AgentResponse(
      type: AgentType.safety,
      title: '🚨 Nearest Emergency Help',
      subtitle:
          '${best.name} • $distLabel${approx ? ' (approx)' : ''} • head $compass$accuracyNote',
      primaryValue: 'Call: 108 / 112',
      badgeText: 'Nearest post 🚑',
      badgeColor: const Color(0xFFDC2626),
      primaryIcon: Icons.local_hospital_rounded,
      spokenTextEnglish:
          'The nearest medical help is ${best.name}, $distLabel away$approxEn towards the $compass, '
          'about $walkMin minutes on foot.$ambulance For emergencies dial 108 for medical or 112 for police.',
      spokenTextHindi:
          'सबसे नज़दीकी चिकित्सा सहायता ${best.name} है, $compass दिशा में $distLabel दूर$approxHi, '
          'लगभग $walkMin मिनट पैदल। आपातकाल में 108 (चिकित्सा) या 112 (पुलिस) डायल करें।',
      spokenTextTelugu:
          'దగ్గరి వైద్య సహాయం ${best.name}, $compass దిశలో $distLabel దూరంలో$approxTe, '
          'సుమారు $walkMin నిమిషాల నడక. అత్యవసరంలో 108 (వైద్యం) లేదా 112 (పోలీసు) డయల్ చేయండి.',
      spokenTextTamil:
          'அருகிலுள்ள மருத்துவ உதவி ${best.name}, $compass திசையில் $distLabel தொலைவில், '
          'சுமார் $walkMin நிமிட நடை. அவசரத்தில் 108 அல்லது 112 அழைக்கவும்.',
      spokenTextMarathi:
          'सर्वात जवळची वैद्यकीय मदत ${best.name} आहे, $compass दिशेला $distLabel अंतरावर, '
          'सुमारे $walkMin मिनिटे पायी. आपत्कालात 108 किंवा 112 डायल करा.',
      spokenTextPunjabi:
          'ਸਭ ਤੋਂ ਨੇੜੇ ਮੈਡੀਕਲ ਮਦਦ ${best.name} ਹੈ, $compass ਦਿਸ਼ਾ ਵਿੱਚ $distLabel ਦੂਰ, '
          'ਲਗਭਗ $walkMin ਮਿੰਟ ਪੈਦਲ। ਐਮਰਜੈਂਸੀ ਵਿੱਚ 108 ਜਾਂ 112 ਡਾਇਲ ਕਰੋ।',
      rawData: {
        'helpline': '108',
        'police': '112',
        'postId': best.id,
        'postName': best.name,
        'postPhone': best.phone,
        'distanceMeters': metres.round(),
        'distanceType': approx ? 'straight-line-approx' : 'path',
        'bearingDeg': bearing.round(),
        'compass': compass,
        'walkMinutes': walkMin,
        'hasAmbulance': best.hasAmbulance,
        'from': {'lat': here.latitude, 'lng': here.longitude},
      },
      destinationCoords: best.location,
      actionButtonText: 'Open Emergency Center',
      actionButtonRoute: '/emergency',
    );
  }
}
