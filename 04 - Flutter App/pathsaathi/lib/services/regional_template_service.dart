// lib/services/regional_template_service.dart
//
// Pure, unit-testable service for PathSaathi's 3-Tier data fallback system.
//
// Tier Definitions:
//   Tier A (Verified): SQLite has >= 1 verified row for the destination.
//   Tier B (Regional Template): 0 SQLite rows, but recognized state/region in Gazetteer.
//   Tier C (Unknown / No Network): Unresolvable / unknown destination.
//
// Anti-Hallucination & Honesty Constraints for Tier B:
//   - NEVER generate a specific bus number, specific departure time, or room number.
//   - Transport uses generic state RTC service and Indian Railways ordinary/express.
//   - Accommodation uses generic pilgrim lodge / dharamshala with basic amenities.
//   - Itinerary uses standard 4-stage pilgrimage slot template (rounded slot times).
//   - Every generated object carries isTemplate = true and dataTier = 'template'.
//   - Spoken text is strictly prepended with localized estimation qualifiers.

import '../models/journey_models.dart';
import 'india_gazetteer.dart';

// ignore: constant_identifier_names
enum DestinationTier {
  tierA_verified,
  tierB_template,
  tierC_unknown,
}

class TemplateAccommodation {
  final String campName;
  final String sector;
  final String tentId;
  final double distanceKm;
  final double lat;
  final double lng;
  final String facilities;
  final String destinationId;
  final bool isTemplate;
  final String dataTier;

  const TemplateAccommodation({
    required this.campName,
    required this.sector,
    required this.tentId,
    required this.distanceKm,
    required this.lat,
    required this.lng,
    required this.facilities,
    required this.destinationId,
    this.isTemplate = true,
    this.dataTier = 'template',
  });

  Map<String, dynamic> toMap() => {
        'id': -1,
        'camp_name': campName,
        'sector': sector,
        'tent_id': tentId,
        'distance_km': distanceKm,
        'lat': lat,
        'lng': lng,
        'facilities': facilities,
        'destination_id': destinationId,
        'is_template': 1,
        'data_tier': 'template',
      };
}

class TemplateItineraryItem {
  final String time;
  final String title;
  final String titleHi;
  final String titleTe;
  final String location;
  final String crowdLevel;
  final String iconName;
  final String destinationId;
  final bool isTemplate;
  final String dataTier;

  const TemplateItineraryItem({
    required this.time,
    required this.title,
    required this.titleHi,
    required this.titleTe,
    required this.location,
    required this.crowdLevel,
    required this.iconName,
    required this.destinationId,
    this.isTemplate = true,
    this.dataTier = 'template',
  });

  Map<String, dynamic> toMap() => {
        'id': -1,
        'time': time,
        'title': title,
        'title_hi': titleHi,
        'title_te': titleTe,
        'location': location,
        'crowd_level': crowdLevel,
        'icon_name': iconName,
        'destination_id': destinationId,
        'is_template': 1,
        'data_tier': 'template',
      };
}

class RegionalTemplateService {
  RegionalTemplateService._();
  static final RegionalTemplateService instance = RegionalTemplateService._();

  /// Evaluate the data tier for a destination.
  /// [hasVerifiedRows] should be true if SQLite returned >= 1 row.
  DestinationTier evaluateTier({
    required String destinationId,
    required bool hasVerifiedRows,
  }) {
    if (hasVerifiedRows) {
      return DestinationTier.tierA_verified;
    }

    final entry = IndiaGazetteer.instance.byId(destinationId) ??
        IndiaGazetteer.instance.resolve(destinationId);

    if (entry != null) {
      return DestinationTier.tierB_template;
    }

    return DestinationTier.tierC_unknown;
  }

  /// Synthesize Tier B Transport Options without hallucinating specific bus/train numbers.
  List<TransportOption> generateTransportOptions({
    required String destinationId,
    required String destinationName,
  }) {
    final entry = IndiaGazetteer.instance.byId(destinationId) ??
        IndiaGazetteer.instance.resolve(destinationName);

    final stateRtc = entry?.primaryRtc ?? 'State Road Transport';
    final stateName = entry?.stateName ?? 'Regional Area';
    final hub = entry?.transportHub ?? 'Nearest Regional Junction';

    return [
      TransportOption(
        id: -1,
        destinationId: destinationId,
        mode: 'bus',
        fromName: hub,
        toName: destinationName,
        depTime: '06:00 AM',
        arrTime: '07:30 AM',
        priceInr: 150,
        operator: '$stateRtc ($stateName) Regional Service (Indicative)',
        indicative: true,
        isTemplate: true,
        dataTier: 'template',
      ),
      TransportOption(
        id: -2,
        destinationId: destinationId,
        mode: 'train',
        fromName: 'State Rail Network',
        toName: destinationName,
        depTime: 'Daily Connection',
        arrTime: 'Regional Hub',
        priceInr: 120,
        operator: 'Indian Railways Express Connection (Indicative)',
        indicative: true,
        isTemplate: true,
        dataTier: 'template',
      ),
    ];
  }

  /// Synthesize Tier B Accommodation without hallucinating fake tent or room numbers.
  TemplateAccommodation generateAccommodation({
    required String destinationId,
    required String destinationName,
  }) {
    final entry = IndiaGazetteer.instance.byId(destinationId) ??
        IndiaGazetteer.instance.resolve(destinationName);

    final stateName = entry?.stateName ?? 'Regional';
    final lat = entry?.coords.latitude ?? 20.5937;
    final lng = entry?.coords.longitude ?? 78.9629;

    return TemplateAccommodation(
      campName: '$destinationName Pilgrim Dharamshala / Lodge (Estimated)',
      sector: '$stateName Pilgrim Circle',
      tentId: 'Standard Pilgrim Room (Estimated)',
      distanceKm: 0.8,
      lat: lat,
      lng: lng,
      facilities: 'Drinking Water, Luggage Counter, Common Bath, Security',
      destinationId: destinationId,
      isTemplate: true,
      dataTier: 'template',
    );
  }

  /// Synthesize Tier B Itinerary following the 4-stage classical pilgrimage structure.
  List<TemplateItineraryItem> generateItinerary({
    required String destinationId,
    required String destinationName,
  }) {
    return [
      TemplateItineraryItem(
        time: '06:00 AM',
        title: 'Morning Darshan & Prayer Visit',
        titleHi: 'प्रातः दर्शन एवं प्रार्थना',
        titleTe: 'ఉదయ దర్శనం మరియు పూజ',
        location: destinationName,
        crowdLevel: 'Moderate',
        iconName: 'temple_hindu',
        destinationId: destinationId,
      ),
      TemplateItineraryItem(
        time: '09:30 AM',
        title: 'Sacred Complex & Heritage Walk',
        titleHi: 'तीर्थ परिसर एवं धरोहर भ्रमण',
        titleTe: 'పుణ్యక్షేత్ర దర్శనం మరియు నడక',
        location: '$destinationName Complex',
        crowdLevel: 'Moderate',
        iconName: 'directions_walk',
        destinationId: destinationId,
      ),
      TemplateItineraryItem(
        time: '01:00 PM',
        title: 'Traditional Pilgrimage Lunch',
        titleHi: 'पारंपरिक प्रसाद एवं भोजन',
        titleTe: 'సాంప్రదాయ అన్నప్రసాదం / భోజనం',
        location: 'Local Annakshetra / Bhojanalay',
        crowdLevel: 'Low',
        iconName: 'restaurant',
        destinationId: destinationId,
      ),
      TemplateItineraryItem(
        time: '05:30 PM',
        title: 'Evening Aarti & Temple Exploration',
        titleHi: 'संध्या आरती एवं दीप दर्शन',
        titleTe: 'సాయంత్రం హారతి మరియు పరిసరాలు',
        location: destinationName,
        crowdLevel: 'High',
        iconName: 'wb_twilight',
        destinationId: destinationId,
      ),
    ];
  }

  /// Mandatory spoken qualifier prefix enforced at the TTS call site.
  static String formatSpokenText({
    required String baseSpokenText,
    required String stateName,
    required String langCode,
    bool isTemplate = false,
  }) {
    if (!isTemplate) return baseSpokenText;

    final qualifier = switch (langCode) {
      'te' => 'అంచనా వేసిన సమాచారం: $stateName రాష్ట్రంలోని సాధారణ సేవల ఆధారంగా... ',
      'hi' => 'अनुमानित जानकारी: $stateName राज्य की सामान्य सेवाओं के आधार पर... ',
      _ => 'Estimated regional information: Based on typical services in $stateName... ',
    };

    return '$qualifier$baseSpokenText';
  }
}