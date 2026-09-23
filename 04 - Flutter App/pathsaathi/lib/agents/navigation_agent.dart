import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/agent_response.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';
import '../services/routing_service.dart';

/// Navigation agent — computes a REAL distance + compass bearing from the
/// user's live GPS position to the destination's real coordinates.
///
/// Honesty rules:
///  • Destination coordinates come from the resolved [Place], never fabricated.
///  • Distance/bearing are computed from the actual GPS fix (haversine).
///  • With no GPS fix, it says so and gives the straight-line info it can
///    (or asks the user to enable location) — it does NOT invent a position.
///  • Turn-by-turn routing needs an offline routing graph that isn't bundled,
///    so it is explicitly marked unavailable rather than faked.
class NavigationAgent {
  NavigationAgent._();
  static final NavigationAgent instance = NavigationAgent._();

  static const Distance _dist = Distance();

  Future<AgentResponse> processQuery(
      {String destination = 'Sangam Ghat'}) async {
    // Resolve the destination to a real Place (for its real coordinates).
    final place = _resolvePlace(destination);
    final destName = place?.name ?? destination;
    final destCoords = place?.coords;

    // Get the current GPS fix (may be null / stale).
    final snap = LocationService.instance.last;
    final here = snap.state.hasFix ? snap.position : null;

    // ── No destination coordinates available ─────────────────────────────
    if (destCoords == null) {
      return _info(
        destName,
        title: 'Location unknown',
        subtitle: 'No stored coordinates for "$destName" offline.',
        primary: '—',
        badge: 'Unavailable offline',
        en: 'I could not find the location of $destName in the offline data. '
            'Please connect to the internet to search for it.',
        hi: '$destName का स्थान ऑफ़लाइन डेटा में नहीं मिला। कृपया इंटरनेट से खोजें।',
        te: '$destName స్థానం ఆఫ్‌లైన్ డేటాలో దొరకలేదు. దయచేసి ఇంటర్నెట్‌లో వెతకండి.',
        coords: null,
      );
    }

    // ── No GPS fix — truthful, no fabricated distance ────────────────────
    if (here == null) {
      return _info(
        destName,
        title: 'Route to $destName',
        subtitle: 'Waiting for GPS — enable location for live distance.',
        primary: snap.state.label,
        badge: 'GPS needed',
        en: 'To show the distance and direction to $destName, please enable '
            'location. Satellite GPS works offline.',
        hi: '$destName की दूरी और दिशा दिखाने के लिए कृपया लोकेशन चालू करें। '
            'सैटेलाइट जीपीएस ऑफ़लाइन काम करता है।',
        te: '$destName కు దూరం, దిశ చూపడానికి దయచేసి లొకేషన్ ఆన్ చేయండి. '
            'ఉపగ్రహ జీపీఎస్ ఆఫ్‌లైన్‌లో పనిచేస్తుంది.',
        coords: destCoords,
      );
    }

    // ── Distance + bearing from live GPS to the destination ──────────────
    // Prefer a REAL along-path route (offline A* over the bundled graph). If no
    // graph covers the user's region, fall back to straight-line but LABEL it
    // approximate — never present straight-line as a real route distance.
    final route = await RoutingService.instance.route(here, destCoords);
    final double metres;
    final bool approx;
    if (route != null) {
      metres = route.distanceMeters;
      approx = false;
    } else {
      metres = _dist.as(LengthUnit.Meter, here, destCoords);
      approx = true;
    }
    final bearing = NavMath.normalizeBearing(_dist.bearing(here, destCoords));
    final compass = NavMath.compass(bearing);
    final distLabel = NavMath.distanceLabel(metres);
    final walkMin = NavMath.walkMinutes(metres);

    final accuracyNote =
        snap.state == GpsState.lowAccuracy ? ' (GPS accuracy is low)' : '';
    final kind = approx ? 'straight-line' : 'along-path';
    final kindEn = approx ? ' (straight-line, approximate)' : ' by path';
    final kindHi = approx ? ' (सीधी दूरी, अनुमानित)' : ' रास्ते से';
    final kindTe = approx ? ' (సరళరేఖ, సుమారు)' : ' దారి ప్రకారం';

    return AgentResponse(
      type: AgentType.navigation,
      title: 'Route to $destName',
      subtitle:
          '$distLabel${approx ? ' (approx)' : ''} • about $walkMin min walk • head $compass$accuracyNote',
      primaryValue: distLabel,
      badgeText: approx ? 'Straight-line 🧭' : 'Along path 🛣️',
      badgeColor: const Color(0xFF2563EB),
      primaryIcon: Icons.navigation_rounded,
      spokenTextEnglish:
          '$destName is $distLabel away$kindEn, roughly $walkMin minutes on foot, towards the $compass.'
          '${approx ? ' Turn-by-turn directions need a downloaded map for this area.' : ' Follow the highlighted path.'}',
      spokenTextHindi:
          '$destName यहाँ से $distLabel दूर है$kindHi, लगभग $walkMin मिनट पैदल, $compass दिशा में।'
          '${approx ? ' इस क्षेत्र के लिए मोड़-दर-मोड़ मार्ग हेतु डाउनलोड किया गया नक्शा चाहिए।' : ' दिखाए गए रास्ते पर चलें।'}',
      spokenTextTelugu:
          '$destName ఇక్కడి నుండి $distLabel దూరంలో ఉంది$kindTe, సుమారు $walkMin నిమిషాల నడక, $compass దిశలో.'
          '${approx ? ' ఈ ప్రాంతానికి మలుపు-వారీ మార్గం కోసం డౌన్‌లోడ్ చేసిన మ్యాప్ అవసరం.' : ' చూపిన దారిలో వెళ్లండి.'}',
      spokenTextTamil:
          '$destName இங்கிருந்து $distLabel தொலைவில், சுமார் $walkMin நிமிட நடை, $compass திசையில் உள்ளது.',
      spokenTextMarathi:
          '$destName येथून $distLabel अंतरावर, सुमारे $walkMin मिनिटे पायी, $compass दिशेला आहे.',
      spokenTextPunjabi:
          '$destName ਇੱਥੋਂ $distLabel ਦੂਰ ਹੈ, ਲਗਭਗ $walkMin ਮਿੰਟ ਪੈਦਲ, $compass ਦਿਸ਼ਾ ਵੱਲ।',
      rawData: {
        'distanceMeters': metres.round(),
        'distanceType': kind,
        'bearingDeg': bearing.round(),
        'compass': compass,
        'walkMinutes': walkMin,
        'destination': destName,
        'turnByTurn': approx ? 'unavailable_offline' : 'available_offline',
        'steps': route?.steps
                .map((s) => {
                      'maneuver': s.maneuver,
                      'meters': s.distanceMeters.round()
                    })
                .toList() ??
            const [],
        'from': {'lat': here.latitude, 'lng': here.longitude},
      },
      destinationCoords: destCoords,
      actionButtonText: 'Open Map',
      actionButtonRoute: '/nav',
    );
  }

  /// Resolve a destination name/query to a real Place (or null).
  Place? _resolvePlace(String destination) {
    // Exact/alias match through the local index (offline cache).
    final results = PlaceSearchService.instance.search(destination);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  AgentResponse _info(
    String destName, {
    required String title,
    required String subtitle,
    required String primary,
    required String badge,
    required String en,
    required String hi,
    required String te,
    required LatLng? coords,
  }) {
    return AgentResponse(
      type: AgentType.navigation,
      title: title,
      subtitle: subtitle,
      primaryValue: primary,
      badgeText: badge,
      badgeColor: const Color(0xFF6B7280),
      primaryIcon: Icons.location_searching_rounded,
      spokenTextEnglish: en,
      spokenTextHindi: hi,
      spokenTextTelugu: te,
      rawData: {'destination': destName, 'turnByTurn': 'unavailable_offline'},
      destinationCoords: coords,
      actionButtonText: coords != null ? 'Open Map' : null,
      actionButtonRoute: coords != null ? '/nav' : null,
    );
  }
}

/// Pure navigation math — no GPS/plugins, so it is unit-testable.
class NavMath {
  NavMath._();

  /// Average walking pace ~1.35 m/s ≈ 4.86 km/h.
  static const double walkMetresPerMin = 1.35 * 60;

  /// Normalize any bearing (e.g. atan2 output of -180..180) to 0–360°.
  static double normalizeBearing(double bearing) => (bearing % 360 + 360) % 360;

  /// Human-friendly distance: metres under 1 km, else km with one decimal.
  static String distanceLabel(double metres) {
    if (metres < 1000) return '${metres.round()} m';
    return '${(metres / 1000).toStringAsFixed(1)} km';
  }

  /// Estimated walking minutes (at least 1).
  static int walkMinutes(double metres) =>
      (metres / walkMetresPerMin).round().clamp(1, 100000);

  /// 8-point compass direction for a 0–360° bearing (0 = North).
  static String compass(double bearing) {
    const dirs = [
      'North',
      'North-East',
      'East',
      'South-East',
      'South',
      'South-West',
      'West',
      'North-West'
    ];
    final idx = ((normalizeBearing(bearing) + 22.5) ~/ 45) % 8;
    return dirs[idx];
  }
}
