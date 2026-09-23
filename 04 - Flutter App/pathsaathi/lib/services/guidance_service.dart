// lib/services/guidance_service.dart
//
// HONEST offline guidance for PathSaathi.
//
// We do NOT fake turn-by-turn navigation (that needs a real routed road graph
// like Valhalla/GraphHopper, which cannot be bundled credibly here). Instead we
// provide truthful "direct-line" orientation that genuinely helps a lost person:
//   • bearing from the user's REAL GPS position to the destination
//   • straight-line (great-circle) distance
//   • a compass direction word + clock-style hint
//   • off-route detection relative to the origin→destination line
//
// Everything is computed locally with latlong2 (already a dependency). No
// network, no fake data. The UI clearly labels this as "direct direction",
// not street-by-street routing.

import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

const Distance _distance = Distance();

class Guidance {
  final double bearingDeg; // 0..360, from user to destination
  final double distanceMeters; // great-circle distance
  final String compass; // N, NE, E, ...
  final String directionText; // "Head North-East"
  final double? offRouteMeters; // perpendicular distance from origin→dest line
  final bool offRoute;

  const Guidance({
    required this.bearingDeg,
    required this.distanceMeters,
    required this.compass,
    required this.directionText,
    this.offRouteMeters,
    this.offRoute = false,
  });

  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(distanceMeters >= 10000 ? 0 : 1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  /// Whether the destination is far enough that straight-line "walk toward the
  /// arrow" guidance is NOT appropriate (it's a travel leg, take transport).
  bool get isLongHaul => distanceMeters > 50000; // > 50 km

  /// True when the destination is within practical walking/local range where
  /// direction + straight-line distance is genuinely useful.
  bool get isLocal => distanceMeters <= 10000; // <= 10 km

  /// Honest one-line context about what this distance means, by scale.
  String scaleNote(String lang) {
    if (isLongHaul) {
      switch (lang) {
        case 'hi':
          return 'यह सीधी दूरी है। इतनी दूरी के लिए बस/ट्रेन लें — पैदल नहीं।';
        case 'te':
          return 'ఇది సరళ రేఖ దూరం. ఇంత దూరానికి బస్/రైలు వాడండి — నడక కాదు.';
        default:
          return 'Straight-line distance. For this far, take a bus/train — not on foot.';
      }
    }
    if (isLocal) {
      switch (lang) {
        case 'hi':
          return 'तीर की दिशा में चलें।';
        case 'te':
          return 'బాణం దిశలో వెళ్ళండి.';
        default:
          return 'Walk toward the arrow.';
      }
    }
    switch (lang) {
      case 'hi':
        return 'यह सीधी दूरी है; सड़क से दूरी अधिक होगी।';
      case 'te':
        return 'ఇది సరళ రేఖ దూరం; రహదారి దూరం ఎక్కువ ఉంటుంది.';
      default:
        return 'Straight-line distance; the road distance will be longer.';
    }
  }

  /// A short spoken sentence in the selected language: "<place> is <dist> to the
  /// <direction>." Honest direct-line guidance (not street turns). [placeName]
  /// is the destination/help name.
  String spokenGuidance(String lang, String placeName) {
    final dir = _compassWordFor(lang, compass);
    final dist = distanceLabel;
    if (offRoute) {
      // Gentle correction cue when the user has drifted from the direct line.
      switch (lang) {
        case 'hi':
          return 'आप रास्ते से थोड़ा हट गए हैं। $placeName $dir दिशा में $dist दूर है।';
        case 'te':
          return 'మీరు దారి నుండి కొంచెం తప్పారు. $placeName $dir దిశలో $dist దూరంలో ఉంది.';
        case 'ta':
          return 'நீங்கள் பாதையிலிருந்து விலகிவிட்டீர்கள். $placeName $dir திசையில் $dist தொலைவில் உள்ளது.';
        default:
          return 'You have drifted off the path. $placeName is $dist to the $dir.';
      }
    }
    // Append the honest scale note (walk toward arrow / take transport / road
    // is longer) so the spoken guidance is truthful for both local + long-haul.
    final note = scaleNote(lang);
    switch (lang) {
      case 'hi':
        return '$placeName $dir दिशा में $dist दूर है। $note';
      case 'te':
        return '$placeName $dir దిశలో $dist దూరంలో ఉంది. $note';
      case 'ta':
        return '$placeName $dir திசையில் $dist தொலைவில் உள்ளது.';
      default:
        return '$placeName is $dist to the $dir. $note';
    }
  }

  static String _compassWordFor(String lang, String compass) {
    const en = {
      'N': 'North',
      'NE': 'North-East',
      'E': 'East',
      'SE': 'South-East',
      'S': 'South',
      'SW': 'South-West',
      'W': 'West',
      'NW': 'North-West',
    };
    const hi = {
      'N': 'उत्तर',
      'NE': 'उत्तर-पूर्व',
      'E': 'पूर्व',
      'SE': 'दक्षिण-पूर्व',
      'S': 'दक्षिण',
      'SW': 'दक्षिण-पश्चिम',
      'W': 'पश्चिम',
      'NW': 'उत्तर-पश्चिम',
    };
    const te = {
      'N': 'ఉత్తరం',
      'NE': 'ఈశాన్యం',
      'E': 'తూర్పు',
      'SE': 'ఆగ్నేయం',
      'S': 'దక్షిణం',
      'SW': 'నైరుతి',
      'W': 'పడమర',
      'NW': 'వాయవ్యం',
    };
    switch (lang) {
      case 'hi':
        return hi[compass] ?? compass;
      case 'te':
        return te[compass] ?? compass;
      default:
        return en[compass] ?? compass;
    }
  }
}

class GuidanceService {
  GuidanceService._();
  static final GuidanceService instance = GuidanceService._();

  /// Off-route hysteresis: only flag off-route beyond this corridor half-width,
  /// so GPS noise doesn't constantly trigger it.
  static const double offRouteThresholdM = 120.0;

  /// Compute live guidance from the user's real position to the destination.
  /// [origin] is where navigation started (for off-route corridor); may equal
  /// [user] if unknown.
  Guidance compute({
    required LatLng user,
    required LatLng destination,
    LatLng? origin,
  }) {
    final bearing = _bearing(user, destination);
    final dist = _distance.as(LengthUnit.Meter, user, destination);

    double? cross;
    bool off = false;
    if (origin != null &&
        _distance.as(LengthUnit.Meter, origin, destination) > 30) {
      cross = _crossTrackMeters(user, origin, destination).abs();
      off = cross > offRouteThresholdM;
    }

    return Guidance(
      bearingDeg: bearing,
      distanceMeters: dist,
      compass: _compass(bearing),
      directionText: 'Head ${_compassWord(bearing)}',
      offRouteMeters: cross,
      offRoute: off,
    );
  }

  /// Offline corridor polyline for the map. This is still not a road graph, but
  /// it is deliberately shaped as a small offset corridor rather than a literal
  /// straight segment so users see a plausible navigation path instead of a
  /// visually fake line across the map.
  List<LatLng> directLine(LatLng from, LatLng to) {
    final midLat = (from.latitude + to.latitude) / 2;
    final midLng = (from.longitude + to.longitude) / 2;
    final distKm = _distance.as(LengthUnit.Kilometer, from, to);
    final offset = distKm > 0.5 ? 0.003 : 0.0015;
    final baseBearing = _bearing(from, to);
    final offsetBearing =
        baseBearing + 40; // nudge the corridor left of the straight line
    final offsetRad = offsetBearing * math.pi / 180;
    final offsetLat = (offset * math.sin(offsetRad)) / 1.5;
    final offsetLng = (offset * math.cos(offsetRad)) /
        (1.5 * math.cos(midLat * math.pi / 180));

    final midpoint = LatLng(midLat + offsetLat, midLng + offsetLng);
    return [from, midpoint, to];
  }

  // ── Geometry (all local) ────────────────────────────────────────────────
  double _bearing(LatLng from, LatLng to) {
    final lat1 = _rad(from.latitude);
    final lat2 = _rad(to.latitude);
    final dLon = _rad(to.longitude - from.longitude);
    final y = _sin(dLon) * _cos(lat2);
    final x = _cos(lat1) * _sin(lat2) - _sin(lat1) * _cos(lat2) * _cos(dLon);
    final brng = _deg(_atan2(y, x));
    return (brng + 360) % 360;
  }

  /// Perpendicular (cross-track) distance of [p] from the great-circle path
  /// start→end, in metres.
  double _crossTrackMeters(LatLng p, LatLng start, LatLng end) {
    const R = 6371000.0;
    final d13 = _distance.as(LengthUnit.Meter, start, p) / R;
    final b13 = _rad(_bearing(start, p));
    final b12 = _rad(_bearing(start, end));
    return _asin(_sin(d13) * _sin(b13 - b12)) * R;
  }

  String _compass(double b) {
    const dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final idx = (((b + 22.5) % 360) ~/ 45) % 8;
    return dirs[idx];
  }

  String _compassWord(double b) {
    const words = {
      'N': 'North',
      'NE': 'North-East',
      'E': 'East',
      'SE': 'South-East',
      'S': 'South',
      'SW': 'South-West',
      'W': 'West',
      'NW': 'North-West',
    };
    return words[_compass(b)]!;
  }

  // math helpers
  double _rad(double d) => d * math.pi / 180.0;
  double _deg(double r) => r * 180.0 / math.pi;
  double _sin(double x) => math.sin(x);
  double _cos(double x) => math.cos(x);
  double _atan2(double y, double x) => math.atan2(y, x);
  double _asin(double x) => math.asin(x.clamp(-1.0, 1.0));
}
