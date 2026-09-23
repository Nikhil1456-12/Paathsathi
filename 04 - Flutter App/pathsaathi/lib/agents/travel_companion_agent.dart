import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../database/app_database.dart';
import '../models/agent_response.dart';
import '../services/accommodation_repository.dart';
import '../services/india_gazetteer.dart';
import '../services/journey_plan_service.dart';
import '../services/location_service.dart';
import '../services/reservation_service.dart';

/// Answers context questions that need the current trip, GPS, or local
/// reservations rather than a fixed phrase-to-screen mapping.
class TravelCompanionAgent {
  TravelCompanionAgent._();
  static final instance = TravelCompanionAgent._();

  Future<AgentResponse?> answer(String rawQuery) async {
    final q = rawQuery.toLowerCase().trim();
    if (_isCurrentLocation(q)) return _whereAmI();
    if (_isBusStatus(q)) return _busStatus(q);
    if (_isHotelQuestion(q)) return _hotelStatus();
    return null;
  }

  bool _isCurrentLocation(String q) => _hasAny(q, [
        'where am i',
        'my current location',
        'my location',
        'location now',
        'मैं कहाँ',
        'मेरा स्थान',
        'నేను ఎక్కడ',
        'నా స్థానం',
        'எங்கே இருக்கிறேன்',
      ]);

  bool _isBusStatus(String q) => _hasAny(q, [
        'where is my bus',
        'where is the bus',
        'when will my bus',
        'what time will my bus',
        'bus arrive',
        'bus arrival',
        'bus timing',
        'बस कहाँ',
        'बस कब',
        'బస్ ఎక్కడ',
        'బస్ ఎప్పుడు',
      ]);

  bool _isHotelQuestion(String q) => _hasAny(q, [
        'where is my hotel',
        'where is the hotel',
        'where am i staying',
        'my stay',
        'hotel location',
        'मेरा होटल',
        'मेरा आवास',
        'నా హోటల్',
        'నా వసతి',
      ]);

  bool _hasAny(String q, List<String> terms) =>
      terms.any((term) => q.contains(term));

  Future<AgentResponse> _whereAmI() async {
    final snapshot = LocationService.instance.last;
    final position = await LocationService.instance.currentOnce();
    if (position == null) {
      return _response(
        title: 'Your location',
        subtitle: snapshot.state.label,
        value: 'GPS needed',
        badge: 'LIVE GPS',
        icon: Icons.my_location,
        english:
            'I cannot see your current location yet. Please enable location and wait for a GPS fix.',
        hindi:
            'मैं अभी आपका वर्तमान स्थान नहीं देख पा रहा हूँ। कृपया लोकेशन चालू करें और GPS सिग्नल का इंतजार करें।',
        telugu:
            'మీ ప్రస్తుత స్థానాన్ని ఇంకా గుర్తించలేకపోతున్నాను. లొకేషన్ ఆన్ చేసి GPS సిగ్నల్ కోసం వేచి ఉండండి.',
        raw: {'gpsState': snapshot.state.name},
        route: '/nav',
      );
    }

    final nearest = _nearestPlace(position);
    final label = nearest == null
        ? 'GPS ${position.latitude.toStringAsFixed(5)}, '
            '${position.longitude.toStringAsFixed(5)}'
        : 'Near ${nearest.name}';
    final spoken = nearest == null
        ? 'Your current GPS location is latitude ${position.latitude.toStringAsFixed(5)} and longitude ${position.longitude.toStringAsFixed(5)}.'
        : 'You are near ${nearest.name}. Your GPS coordinates are ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}.';
    return _response(
      title: 'You are here',
      subtitle:
          '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
      value: label,
      badge: 'LIVE GPS',
      icon: Icons.my_location,
      english: spoken,
      hindi: 'आप ${nearest?.name ?? 'इस GPS स्थान'} के पास हैं।',
      telugu: 'మీరు ${nearest?.name ?? 'ఈ GPS స్థానం'} దగ్గర ఉన్నారు.',
      raw: {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracyM': snapshot.accuracyM,
      },
      route: '/nav',
    );
  }

  Future<AgentResponse?> _busStatus(String query) async {
    final asksLocation = query.contains('where') ||
        query.contains('कहाँ') ||
        query.contains('ఎక్కడ');
    final plan = await JourneyPlanService.instance.active();
    if (plan == null) return _noTrip('bus');
    final rows =
        await AppDatabase.instance.getTransportOptions(plan.destinationId);
    final matching = rows.where((r) => r['mode'] == 'bus').toList();
    final row = matching.isNotEmpty
        ? matching.first
        : (rows.isNotEmpty ? rows.first : null);
    if (row == null) {
      return _response(
        type: asksLocation ? AgentType.navigation : AgentType.transport,
        title: asksLocation
            ? 'Route to ${plan.destinationName}'
            : 'Bus status unavailable',
        subtitle: 'No offline bus schedule for ${plan.destinationName}',
        value: 'Ask at the local bus station',
        badge: 'NO LIVE DATA',
        icon: Icons.directions_bus_outlined,
        english:
            'I do not have an offline bus schedule for ${plan.destinationName}. I also cannot track a live bus without an operator feed.',
        hindi:
            '${plan.destinationName} के लिए ऑफलाइन बस समय उपलब्ध नहीं है और लाइव बस ट्रैकिंग फीड नहीं मिली।',
        telugu:
            '${plan.destinationName} కోసం ఆఫ్‌లైన్ బస్ సమయం లేదు. లైవ్ బస్ ట్రాకింగ్ సమాచారం కూడా అందుబాటులో లేదు.',
        raw: const {},
        route: '/transport',
        coords: plan.destinationCoords,
      );
    }
    final current = await LocationService.instance.currentOnce();
    final from = current == null
        ? 'your selected origin'
        : 'your current GPS location '
            '(${current.latitude.toStringAsFixed(3)}, '
            '${current.longitude.toStringAsFixed(3)})';
    final to = row['to_name'] ?? plan.destinationName;
    final departure = row['dep_time'] ?? 'not available';
    final arrival = row['arr_time'] ?? 'not available';
    return _response(
      type: asksLocation ? AgentType.navigation : AgentType.transport,
      title: asksLocation
          ? 'Route to ${plan.destinationName}'
          : 'Your bus to ${plan.destinationName}',
      subtitle: '$from → $to',
      value: departure.toString(),
      badge: 'SCHEDULED • NOT LIVE',
      icon: Icons.directions_bus_rounded,
      english:
          'Your scheduled bus is from $from to $to. It departs around $departure and is expected to arrive around $arrival. I cannot see its live position without a real-time operator feed.',
      hindi:
          'आपकी बस $from से $to तक है। यह लगभग $departure बजे रवाना और $arrival बजे पहुंचने की उम्मीद है। लाइव ऑपरेटर फीड के बिना मैं बस की वर्तमान स्थिति नहीं देख सकता।',
      telugu:
          'మీ బస్ $from నుండి $to వరకు ఉంటుంది. ఇది సుమారు $departure కు బయలుదేరి $arrival కు చేరుతుంది. లైవ్ ఆపరేటర్ ఫీడ్ లేకుండా బస్ ప్రస్తుత స్థానాన్ని చూడలేను.',
      raw: {
        'from': from,
        'to': to,
        'departure': departure,
        'arrival': arrival,
        'liveTracking': false,
      },
      route: '/transport',
      coords: plan.destinationCoords,
    );
  }

  Future<AgentResponse?> _hotelStatus() async {
    final reservations = await ReservationService.instance.all();
    final stays = reservations.where((r) => r.type == 'stay').toList();
    final selected = AccommodationRepository.instance.selectedHotel;
    final name =
        selected?.name ?? (stays.isNotEmpty ? stays.first.title : null);
    if (name == null) {
      return _response(
        title: 'No hotel selected',
        subtitle: 'Choose a stay from the accommodation page',
        value: 'Stay not booked',
        badge: 'ACTION NEEDED',
        icon: Icons.hotel_outlined,
        english:
            'You have not selected a hotel yet. Open the stay page to choose and book one.',
        hindi:
            'आपने अभी होटल नहीं चुना है। रहने की जगह चुनने के लिए स्टे पेज खोलें।',
        telugu:
            'మీరు ఇంకా హోటల్ ఎంచుకోలేదు. హోటల్ ఎంచుకోవడానికి స్టే పేజీని తెరవండి.',
        raw: const {},
        route: '/accommodation',
      );
    }
    final area = selected?.area ?? stays.first.details;
    return _response(
      title: 'Your stay: $name',
      subtitle: area,
      value: selected == null
          ? 'Booked locally'
          : '${selected.distanceKm} km away',
      badge: 'STAY DETAILS',
      icon: Icons.hotel_rounded,
      english:
          'Your hotel is $name, in $area. Open the stay page for its map and booking details.',
      hindi:
          'आपका होटल $name है, जो $area में है। नक्शे और बुकिंग विवरण के लिए स्टे पेज खोलें।',
      telugu:
          'మీ హోటల్ $name, $area లో ఉంది. మ్యాప్ మరియు బుకింగ్ వివరాల కోసం స్టే పేజీని తెరవండి.',
      raw: {'hotel': name, 'area': area},
      route: '/accommodation',
    );
  }

  AgentResponse _noTrip(String subject) => _response(
        title: 'No active journey',
        subtitle: 'Select a destination and transport first',
        value: 'Not available',
        badge: 'ACTION NEEDED',
        icon: subject == 'bus' ? Icons.directions_bus : Icons.info_outline,
        english:
            'I need an active journey before I can answer that. Please select your destination and transport first.',
        hindi:
            'इसका उत्तर देने के लिए पहले सक्रिय यात्रा चुनें। कृपया गंतव्य और परिवहन चुनें।',
        telugu:
            'దీనికి సమాధానం ఇవ్వడానికి ముందుగా యాక్టివ్ జర్నీ ఎంచుకోండి. గమ్యం మరియు రవాణాను ఎంచుకోండి.',
        raw: const {},
        route: '/journey',
      );

  AgentResponse _response({
    AgentType type = AgentType.general,
    required String title,
    required String subtitle,
    required String value,
    required String badge,
    required IconData icon,
    required String english,
    required String hindi,
    required String telugu,
    required Map<String, dynamic> raw,
    required String route,
    LatLng? coords,
  }) =>
      AgentResponse(
        type: type,
        title: title,
        subtitle: subtitle,
        primaryValue: value,
        badgeText: badge,
        badgeColor: const Color(0xFF2563EB),
        primaryIcon: icon,
        spokenTextEnglish: english,
        spokenTextHindi: hindi,
        spokenTextTelugu: telugu,
        rawData: raw,
        destinationCoords: coords,
        actionButtonText: 'Open details',
        actionButtonRoute: route,
      );

  GazetteerEntry? _nearestPlace(LatLng position) {
    GazetteerEntry? result;
    var best = double.infinity;
    for (final entry in IndiaGazetteer.entries) {
      final dLat = position.latitude - entry.coords.latitude;
      final dLng = position.longitude - entry.coords.longitude;
      final distance = dLat * dLat + dLng * dLng;
      if (distance < best) {
        best = distance;
        result = entry;
      }
    }
    return result;
  }
}
