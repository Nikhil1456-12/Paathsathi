import 'package:flutter/material.dart';
import '../database/app_database.dart';
import '../models/agent_response.dart';
import '../services/journey_plan_service.dart';
import '../services/india_gazetteer.dart';
import '../services/regional_template_service.dart';

class ItineraryAgent {
  ItineraryAgent._();
  static final ItineraryAgent instance = ItineraryAgent._();

  Future<AgentResponse> processQuery({String? destination}) async {
    final plan = await JourneyPlanService.instance.active();
    final targetDestName = (destination != null && destination.trim().isNotEmpty)
        ? destination.trim()
        : (plan?.destinationName ?? '');
    final targetDestId = (destination != null && destination.trim().isNotEmpty)
        ? IndiaGazetteer.instance.toSlug(destination.trim())
        : (plan?.destinationId ?? '');

    if (targetDestId.isNotEmpty) {
      final list = await AppDatabase.instance.getItinerariesForDestination(targetDestId);
      if (list.isNotEmpty) {
        final count = list.length;
        final nextEvent = list.first;

        return AgentResponse(
          type: AgentType.itinerary,
          title: "Today's Schedule — $targetDestName",
          subtitle: '$count planned activities • Next: ${nextEvent['title']}',
          primaryValue: nextEvent['time'] ?? '06:00 AM',
          badgeText: 'Schedule Ready 📅',
          badgeColor: const Color(0xFFFF6B00),
          primaryIcon: Icons.calendar_today_rounded,
          spokenTextEnglish:
              'Your day plan for $targetDestName has $count activities. Next event is ${nextEvent['title']} at ${nextEvent['time']}.',
          spokenTextHindi:
              '$targetDestName के लिए आज $count कार्यक्रम निर्धारित हैं। अगला कार्यक्रम ${nextEvent['title_hi'] ?? nextEvent['title']} सुबह ${nextEvent['time']} पर है।',
          spokenTextTelugu:
              '$targetDestName కోసం ఈరోజు మీ ప్రణాళికలో $count కార్యక్రమాలు ఉన్నాయి. తదుపరి కార్యక్రమం ఉదయం ${nextEvent['time']} కు ప్రారంభమవుతుంది.',
          rawData: {'itineraries': list},
          actionButtonText: 'View Full Timeline',
          actionButtonRoute: '/itinerary',
        );
      }

      // No SQLite rows -> Evaluate Tier B vs Tier C
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: targetDestId,
        hasVerifiedRows: false,
      );

      if (tier == DestinationTier.tierB_template) {
        final template = RegionalTemplateService.instance.generateItinerary(
          destinationId: targetDestId,
          destinationName: targetDestName,
        );
        final gEntry = IndiaGazetteer.instance.byId(targetDestId) ??
            IndiaGazetteer.instance.resolve(targetDestName);
        final stateName = gEntry?.stateName ?? 'Regional';
        final count = template.length;
        final nextEvent = template.first;

        return AgentResponse(
          type: AgentType.itinerary,
          title: "Estimated Schedule — $targetDestName",
          subtitle: '$count typical pilgrimage stages • Next: ${nextEvent.title}',
          primaryValue: nextEvent.time,
          badgeText: 'ESTIMATED — NOT LIVE DATA',
          badgeColor: const Color(0xFFF97316),
          primaryIcon: Icons.calendar_today_rounded,
          spokenTextEnglish: RegionalTemplateService.formatSpokenText(
            baseSpokenText:
                'Typical pilgrimage schedule for $targetDestName has $count stages starting with ${nextEvent.title} at ${nextEvent.time}.',
            stateName: stateName,
            langCode: 'en',
            isTemplate: true,
          ),
          spokenTextHindi: RegionalTemplateService.formatSpokenText(
            baseSpokenText:
                '$targetDestName के लिए सामान्य तीर्थयात्रा क्रम में $count चरण हैं, जिसकी शुरुआत ${nextEvent.titleHi} से सुबह ${nextEvent.time} पर होती है।',
            stateName: stateName,
            langCode: 'hi',
            isTemplate: true,
          ),
          spokenTextTelugu: RegionalTemplateService.formatSpokenText(
            baseSpokenText:
                '$targetDestName కోసం సాధారణ పుణ్యక్షేత్ర దర్శన క్రమంలో $count దశలు ఉన్నాయి. ఉదయం ${nextEvent.time} కు ${nextEvent.titleTe} తో మొదలవుతుంది.',
            stateName: stateName,
            langCode: 'te',
            isTemplate: true,
          ),
          rawData: {'itineraries': template.map((e) => e.toMap()).toList()},
          actionButtonText: 'View Timeline',
          actionButtonRoute: '/itinerary',
        );
      } else {
        // Tier C
        return AgentResponse(
          type: AgentType.itinerary,
          title: "Itinerary — $targetDestName",
          subtitle: 'No offline itinerary schedule available',
          primaryValue: 'Inquire Locally',
          badgeText: 'No Offline Data ⚠️',
          badgeColor: const Color(0xFF6B7280),
          primaryIcon: Icons.help_outline_rounded,
          spokenTextEnglish:
              'No offline itinerary details available for $targetDestName. Please inquire at the temple reception or information desk.',
          spokenTextHindi:
              '$targetDestName के लिए कोई ऑफ़लाइन यात्रा कार्यक्रम उपलब्ध नहीं है। कृपया मंदिर सूचना केंद्र से संपर्क करें।',
          spokenTextTelugu:
              '$targetDestName కోసం ఆఫ్‌లైన్ దర్శన ప్రణాళిక అందుబాటులో లేదు. దయచేసి దేవస్థానం సహాయ కేంద్రాన్ని సంప్రదించండి.',
          rawData: const {},
          actionButtonText: 'View Itinerary',
          actionButtonRoute: '/itinerary',
        );
      }
    }
    final list = await AppDatabase.instance.getItineraries();

    final count = list.length;
    final nextEvent = list.isNotEmpty ? list.first : {'title': 'Morning Snan', 'time': '06:30 AM'};

    return AgentResponse(
      type: AgentType.itinerary,
      title: "Today's Pilgrimage Schedule",
      subtitle: '$count planned activities • Next: ${nextEvent['title']}',
      primaryValue: nextEvent['time'] ?? '06:00 AM',
      badgeText: 'Schedule Ready 📅',
      badgeColor: const Color(0xFFFF6B00),
      primaryIcon: Icons.calendar_today_rounded,
      spokenTextEnglish:
          'Your day plan has $count activities. Next event is ${nextEvent['title']} at ${nextEvent['time']}. Morning crowd density is low to moderate.',
      spokenTextHindi:
          'आज के लिए आपके $count कार्यक्रम निर्धारित हैं। अगला कार्यक्रम ${nextEvent['title_hi'] ?? nextEvent['title']} सुबह ${nextEvent['time']} पर है।',
      spokenTextTelugu:
          'ఈరోజు మీ ప్రణాళికలో $count కార్యక్రమాలు ఉన్నాయి. తదుపరి కార్యక్రమం ఉదయం ${nextEvent['time']} కు ప్రారంభమవుతుంది.',
      spokenTextTamil:
          'இன்றைய பயண அட்டவணையில் $count நிகழ்வுகள் உள்ளன. அடுத்த நிகழ்வு காலை ${nextEvent['time']} மணிக்கு.',
      spokenTextMarathi:
          'आजच्या वेळापत्रकात $count कार्यक्रम आहेत. पुढील कार्यक्रम सकाळी ${nextEvent['time']} वाजता आहे.',
      spokenTextPunjabi:
          'ਅੱਜ ਲਈ ਤੁਹਾਡੇ $count ਪ੍ਰੋਗਰਾਮ ਹਨ। ਅਗਲਾ ਪ੍ਰੋਗਰਾਮ ਸਵੇਰੇ ${nextEvent['time']} ਵਜੇ ਹੈ।',
      rawData: {'itineraries': list},
      actionButtonText: 'View Full Timeline',
      actionButtonRoute: '/itinerary',
    );
  }
}
