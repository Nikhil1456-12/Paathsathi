import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../database/app_database.dart';
import '../models/agent_response.dart';
import '../services/journey_plan_service.dart';
import '../services/india_gazetteer.dart';
import '../services/regional_template_service.dart';

class TransportAgent {
  TransportAgent._();
  static final TransportAgent instance = TransportAgent._();

  Future<AgentResponse> processQuery({String? destination}) async {
    final plan = await JourneyPlanService.instance.active();
    final targetDestName = (destination != null && destination.trim().isNotEmpty)
        ? destination.trim()
        : (plan?.destinationName ?? '');
    final targetDestId = (destination != null && destination.trim().isNotEmpty)
        ? IndiaGazetteer.instance.toSlug(destination.trim())
        : (plan?.destinationId ?? '');

    if (targetDestId.isNotEmpty) {
      final dbOptions = await AppDatabase.instance.getTransportOptions(targetDestId);
      if (dbOptions.isNotEmpty) {
        final opt = dbOptions.first;
        final isTrain = opt['mode'] == 'train';
        final operatorName = opt['operator'] ?? 'Transport Service';
        final from = opt['from_name'] ?? 'Origin';
        final to = opt['to_name'] ?? targetDestName;
        final time = opt['dep_time'] ?? '06:00 AM';
        final price = opt['price_inr'] ?? 100;
        final isIndicative = opt['indicative'] == 1;

        return AgentResponse(
          type: AgentType.transport,
          title: '$operatorName • ${isTrain ? 'TRAIN' : 'BUS'}',
          subtitle: '$from → $to',
          primaryValue: time,
          badgeText: isIndicative ? 'ESTIMATED — NOT LIVE DATA' : 'Verified Schedule ✅',
          badgeColor: isIndicative ? const Color(0xFFF97316) : const Color(0xFF16A34A),
          primaryIcon: isTrain ? Icons.train_rounded : Icons.directions_bus_rounded,
          spokenTextEnglish:
              'Bus service: $operatorName from $from to $to departs at $time. Indicative fare is ₹$price.',
          spokenTextHindi:
              'बस सेवा: $operatorName, $from से $to के लिए $time पर रवाना होगी। अनुमानित किराया ₹$price है।',
          spokenTextTelugu:
              'బస్ సేవ: $operatorName, $from నుండి $to కు $time కు బయలుదేరుతుంది. ఈ బస్సులో సీట్లు అందుబాటులో ఉన్నాయి. అంచనా ఛార్జీ ₹$price.',
          spokenTextTamil:
              'பஸ் சேவை: $operatorName, $from இலிருந்து $to வரை $time மணிக்கு புறப்படும். மதிப்பிடப்பட்ட கட்டணம் ₹$price.',
          spokenTextMarathi:
              'बस सेवा: $operatorName, $from ते $to साठी $time वाजता निघेल. अंदाजे शुल्क ₹$price.',
          spokenTextPunjabi:
              'ਬੱਸ ਸੇਵਾ: $operatorName, $from ਤੋਂ $to ਲਈ $time ਵਜੇ ਚੱਲੇਗੀ। ਅੰਦਾਜ਼ਨ ਕੀਤੀ ਕੀਮਤ ₹$price ਹੈ।',
          rawData: opt,
          destinationCoords: plan?.destinationCoords,
          actionButtonText: 'View All Transport',
          actionButtonRoute: '/transport',
        );
      }

      // No SQLite rows -> Evaluate Tier B vs Tier C
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: targetDestId,
        hasVerifiedRows: false,
      );

      if (tier == DestinationTier.tierB_template) {
        final templateOptions = RegionalTemplateService.instance.generateTransportOptions(
          destinationId: targetDestId,
          destinationName: targetDestName,
        );
        if (templateOptions.isNotEmpty) {
          final opt = templateOptions.first;
          final isTrain = opt.mode == 'train';
          final gEntry = IndiaGazetteer.instance.byId(targetDestId) ??
              IndiaGazetteer.instance.resolve(targetDestName);
          final stateName = gEntry?.stateName ?? 'Regional';

          return AgentResponse(
            type: AgentType.transport,
            title: '${opt.operator} • ${isTrain ? 'TRAIN' : 'BUS'}',
            subtitle: '${opt.fromName} → ${opt.toName}',
            primaryValue: opt.depTime,
            badgeText: 'ESTIMATED — NOT LIVE DATA',
            badgeColor: const Color(0xFFF97316),
            primaryIcon: isTrain ? Icons.train_rounded : Icons.directions_bus_rounded,
            spokenTextEnglish: RegionalTemplateService.formatSpokenText(
              baseSpokenText:
                  'Bus service: ${opt.operator} from ${opt.fromName} to ${opt.toName} is scheduled around ${opt.depTime}. Indicative fare is ₹${opt.priceInr}.',
              stateName: stateName,
              langCode: 'en',
              isTemplate: true,
            ),
            spokenTextHindi: RegionalTemplateService.formatSpokenText(
              baseSpokenText:
                  'बस सेवा: ${opt.operator}, ${opt.fromName} से ${opt.toName} के लिए लगभग ${opt.depTime} पर संचालित होती है। अनुमानित किराया ₹${opt.priceInr} है।',
              stateName: stateName,
              langCode: 'hi',
              isTemplate: true,
            ),
            spokenTextTelugu: RegionalTemplateService.formatSpokenText(
              baseSpokenText:
                  'బస్ సేవ: ${opt.operator}, ${opt.fromName} నుండి ${opt.toName} కు సుమారు ${opt.depTime} కు నడుస్తుంది. అంచనా ఛార్జీ ₹${opt.priceInr}.',
              stateName: stateName,
              langCode: 'te',
              isTemplate: true,
            ),
            rawData: opt.toMap(),
            destinationCoords: gEntry?.coords ?? plan?.destinationCoords,
            actionButtonText: 'View Transport',
            actionButtonRoute: '/transport',
          );
        }
      } else {
        // Tier C: Unknown
        return AgentResponse(
          type: AgentType.transport,
          title: 'Transport — $targetDestName',
          subtitle: 'No offline transport data available',
          primaryValue: 'Inquire Locally',
          badgeText: 'No Offline Data ⚠️',
          badgeColor: const Color(0xFF6B7280),
          primaryIcon: Icons.help_outline_rounded,
          spokenTextEnglish:
              'No offline transport data available for $targetDestName. Please inquire at the local bus station or help desk.',
          spokenTextHindi:
              '$targetDestName के लिए कोई ऑफ़लाइन परिवहन डेटा उपलब्ध नहीं है। कृपया स्थानीय बस स्टेशन या पूछताछ केंद्र से संपर्क करें।',
          spokenTextTelugu:
              '$targetDestName కోసం ఆఫ్‌లైన్ రవాణా సమాచారం అందుబాటులో లేదు. దయచేసి స్థానిక బస్ స్టేషన్ లేదా సహాయ కేంద్రాన్ని సంప్రదించండి.',
          rawData: const {},
          actionButtonText: 'View Transport',
          actionButtonRoute: '/transport',
        );
      }
    }

    // Default fallback to legacy Prayagraj buses
    final buses = await AppDatabase.instance.getBuses();
    final selectedBus = buses.first;
    final busNumber = selectedBus['bus_number'] ?? 'Bus 47';
    final origin = selectedBus['origin'] ?? 'Prayagraj';
    final dest = selectedBus['destination'] ?? 'Sangam Ghat';
    final time = selectedBus['departure_time'] ?? '06:00 AM';
    final gate = selectedBus['gate'] ?? 'Gate 3';
    final seats = selectedBus['seats_available'] ?? 28;

    return AgentResponse(
      type: AgentType.transport,
      title: '$busNumber • $gate',
      subtitle: '$origin → $dest',
      primaryValue: time,
      badgeText: '$seats Seats Available',
      badgeColor: const Color(0xFF16A34A),
      primaryIcon: Icons.directions_bus_rounded,
      spokenTextEnglish:
          'Bus service: $busNumber departs from $origin to $dest at $time from $gate. $seats seats are currently available.',
      spokenTextHindi:
          'बस सेवा: $busNumber, $origin से $dest के लिए सुबह $time पर $gate से रवाना होगी। इसमें $seats सीटें उपलब्ध हैं।',
      spokenTextTelugu:
          'బస్ సేవ: $busNumber, $origin నుండి $dest కు ఉదయం $time కు $gate నుండి బయలుదేరుతుంది. $seats సీట్లు అందుబాటులో ఉన్నాయి.',
      spokenTextTamil:
          'பஸ் சேவை: $busNumber, $origin இலிருந்து $dest வரை காலை $time மணிக்கு $gate இலிருந்து புறப்படும்.',
      spokenTextMarathi:
          'बस सेवा: $busNumber, $origin हून $dest साठी सकाळी $time वाजता $gate वरून निघेल.',
      spokenTextPunjabi:
          'ਬੱਸ ਸੇਵਾ: $busNumber, $origin ਤੋਂ $dest ਲਈ ਸਵੇਰੇ $time ਵਜੇ $gate ਤੋਂ ਚੱਲੇਗੀ।',
      rawData: selectedBus,
      destinationCoords: const LatLng(25.4485, 81.8610), // Gate 3 terminal
      actionButtonText: 'Book this Bus',
      actionButtonRoute: '/transport',
    );
  }
}
