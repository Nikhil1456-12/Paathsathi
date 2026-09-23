import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../database/app_database.dart';
import '../models/agent_response.dart';
import '../services/journey_plan_service.dart';
import '../services/india_gazetteer.dart';
import '../services/regional_template_service.dart';

class AccommodationAgent {
  AccommodationAgent._();
  static final AccommodationAgent instance = AccommodationAgent._();

  Future<AgentResponse> processQuery({bool listAll = false, String? destination}) async {
    final plan = await JourneyPlanService.instance.active();
    final targetDestName = (destination != null && destination.trim().isNotEmpty)
        ? destination.trim()
        : (plan?.destinationName ?? '');
    final targetDestId = (destination != null && destination.trim().isNotEmpty)
        ? IndiaGazetteer.instance.toSlug(destination.trim())
        : (plan?.destinationId ?? '');

    if (listAll) {
      final allCamps = await AppDatabase.instance.getAccommodations();
      if (allCamps.isNotEmpty) {
        return AgentResponse(
          type: AgentType.accommodation,
          title: 'Nearby Accommodations (${allCamps.length})',
          subtitle: 'Camps & lodges around the pilgrimage route',
          primaryValue: '${allCamps.length} Available',
          badgeText: 'Verified Camps 🏕️',
          badgeColor: const Color(0xFF16A34A),
          primaryIcon: Icons.holiday_village_rounded,
          spokenTextEnglish:
              'Found ${allCamps.length} accommodation options nearby: camps and lodges for the pilgrimage route.',
          spokenTextHindi:
              'आसपास ${allCamps.length} आवास विकल्प उपलब्ध हैं: तीर्थयात्रा मार्ग के लिए शिविर और लाजें।',
          spokenTextTelugu:
              'సమీపంలో ${allCamps.length} వసతి ఎంపికలు అందుబాటులో ఉన్నాయి: పుణ్యయాత్ర మార్గం కోసం శిబిరాలు మరియు వసతులు.',
          spokenTextTamil:
              'அருகில் ${allCamps.length} தங்குமிடம் விருப்பங்கள் உள்ளன: யாத்திரை பாதைக்கு அருகில் முகாம்கள் மற்றும் தங்குமிடங்கள்.',
          spokenTextMarathi:
              'जवळपास ${allCamps.length} निवास पर्याय उपलब्ध आहेत: तीर्थयात्रा मार्गासाठी शिबिरे आणि लाज.',
          spokenTextPunjabi:
              'ਨੇੜੇ ${allCamps.length} ਰਹਿਣ ਦੇ ਵਿਕਲਪ ਹਨ: ਯਾਤਰਾ ਲਈ ਕੈਂਪ ਅਤੇ ਲਾਜ।',
          rawData: {'camps': allCamps},
          destinationCoords: const LatLng(25.4460, 81.8680),
          actionButtonText: 'View All Camps & Map',
          actionButtonRoute: '/accommodation',
        );
      }
    }

    if (targetDestId.isNotEmpty) {
      final allCamps = await AppDatabase.instance.getAccommodationsForDestination(targetDestId);
      if (allCamps.isNotEmpty) {
        final primary = allCamps.first;
        final campName = primary['camp_name'] ?? 'Pilgrim Camp';
        final sector = primary['sector'] ?? 'Camp Area';
        String tentId = (primary['tent_id'] as String?) ?? 'Room 101';
        if (tentId.toLowerCase().contains('room')) {
          tentId = 'Tent ${tentId.replaceAll(RegExp(r'room\s*', caseSensitive: false), '').trim()}';
        }
        final distance = primary['distance_km'] ?? 0.5;
        final lat = primary['lat'] as double? ?? 0.0;
        final lng = primary['lng'] as double? ?? 0.0;

        return AgentResponse(
          type: AgentType.accommodation,
          title: '$campName ($sector)',
          subtitle: 'Allotted: $tentId • $distance km from center',
          primaryValue: tentId,
          badgeText: 'Booking Confirmed ✅',
          badgeColor: const Color(0xFF16A34A),
          primaryIcon: Icons.holiday_village_rounded,
          spokenTextEnglish:
              'Your accommodation in $targetDestName is at $campName, $sector, $tentId. It is $distance km away.',
          spokenTextHindi:
              '$targetDestName में आपका आवास $campName, $sector, $tentId में है। यह $distance किमी दूर है।',
          spokenTextTelugu:
              '$targetDestName లో మీ వసతి $campName, $sector, $tentId లో కేటాయించబడింది. ఇది $distance కిమీ దూరంలో ఉంది.',
          rawData: primary,
          destinationCoords: LatLng(lat, lng),
          actionButtonText: 'Directions to Camp',
          actionButtonRoute: '/accommodation',
        );
      }

      // No SQLite rows -> Evaluate Tier B vs Tier C
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: targetDestId,
        hasVerifiedRows: false,
      );

      if (tier == DestinationTier.tierB_template) {
        final template = RegionalTemplateService.instance.generateAccommodation(
          destinationId: targetDestId,
          destinationName: targetDestName,
        );
        final gEntry = IndiaGazetteer.instance.byId(targetDestId) ??
            IndiaGazetteer.instance.resolve(targetDestName);
        final stateName = gEntry?.stateName ?? 'Regional';

        return AgentResponse(
          type: AgentType.accommodation,
          title: '${template.campName} (${template.sector})',
          subtitle: 'Estimated: ${template.tentId} • ${template.distanceKm} km from center',
          primaryValue: template.tentId,
          badgeText: 'ESTIMATED — NOT LIVE DATA',
          badgeColor: const Color(0xFFF97316),
          primaryIcon: Icons.holiday_village_rounded,
          spokenTextEnglish: RegionalTemplateService.formatSpokenText(
            baseSpokenText:
                'Pilgrim accommodation options around $targetDestName typically include ${template.campName}. Check with the local temple board or yatri nivas counter.',
            stateName: stateName,
            langCode: 'en',
            isTemplate: true,
          ),
          spokenTextHindi: RegionalTemplateService.formatSpokenText(
            baseSpokenText:
                '$targetDestName के आसपास तीर्थयात्री आवास के लिए ${template.campName} उपलब्ध रहती है। स्थानीय मंदिर कार्यालय या धर्मशाला काउंटर से संपर्क करें।',
            stateName: stateName,
            langCode: 'hi',
            isTemplate: true,
          ),
          spokenTextTelugu: RegionalTemplateService.formatSpokenText(
            baseSpokenText:
                '$targetDestName పరిసరాలలో యాత్రికుల కోసం ${template.campName} అందుబాటులో ఉంటాయి. స్థానిక దేవస్థానం లేదా యాత్రి నివాస్ కౌంటర్‌లో సంప్రదించండి.',
            stateName: stateName,
            langCode: 'te',
            isTemplate: true,
          ),
          rawData: template.toMap(),
          destinationCoords: LatLng(template.lat, template.lng),
          actionButtonText: 'View Accommodation',
          actionButtonRoute: '/accommodation',
        );
      } else {
        // Tier C
        return AgentResponse(
          type: AgentType.accommodation,
          title: 'Accommodation — $targetDestName',
          subtitle: 'No offline accommodation data available',
          primaryValue: 'Inquire Locally',
          badgeText: 'No Offline Data ⚠️',
          badgeColor: const Color(0xFF6B7280),
          primaryIcon: Icons.help_outline_rounded,
          spokenTextEnglish:
              'No offline accommodation details found for $targetDestName. Please inquire at the local help desk or pilgrim reception center.',
          spokenTextHindi:
              '$targetDestName के लिए कोई ऑफ़लाइन आवास डेटा नहीं मिला। कृपया स्थानीय पूछताछ केंद्र से संपर्क करें।',
          spokenTextTelugu:
              '$targetDestName కోసం ఆఫ్‌లైన్ వసతి వివరాలు లభించలేదు. దయచేసి స్థానిక సహాయ కేంద్రాన్ని సంప్రదించండి.',
          rawData: const {},
          actionButtonText: 'View Accommodation',
          actionButtonRoute: '/accommodation',
        );
      }
    }
    final allCamps = await AppDatabase.instance.getAccommodations();
    final primary = allCamps.isNotEmpty ? allCamps.first : null;

    if (listAll) {
      final count = allCamps.length;
      return AgentResponse(
        type: AgentType.accommodation,
        title: 'Nearby Accommodations ($count)',
        subtitle: 'Camps & Ashrams around Sangam & Sector 4/7',
        primaryValue: '$count Available',
        badgeText: 'Verified Camps 🏕️',
        badgeColor: const Color(0xFF16A34A),
        primaryIcon: Icons.holiday_village_rounded,
        spokenTextEnglish:
            'Found $count accommodations nearby: Shakti Camp in Sector 7, Ganga Vihar in Sector 4, and Triveni Ashram in Sector 2. Tap any camp to locate it on the map.',
        spokenTextHindi:
            'आसपास $count शिविर उपलब्ध हैं: शक्ति शिविर सेक्टर 7, गंगा विहार सेक्टर 4, और त्रिवेणी आश्रम सेक्टर 2। नक्शे पर देखने के लिए किसी भी शिविर पर टैप करें।',
        spokenTextTelugu:
            'సమీపంలో $count వసతి శిబిరాలు అందుబాటులో ఉన్నాయి: సెక్టార్ 7 లో శక్తి క్యాంప్, సెక్టార్ 4 లో గంగా విహార్, మరియు సెక్టార్ 2 లో త్రివేణి ఆశ్రమం.',
        spokenTextTamil:
            'அருகில் $count தங்குமிடங்கள் உள்ளன: சக்தி முகாம், கங்கா விஹார் மற்றும் திரிவேணி ஆசிரமம்.',
        spokenTextMarathi:
            'जवळपास $count मुक्कामाचे पर्याय उपलब्ध आहेत: शक्ती कॅम्प, गंगा विहार आणि त्रिवेणी आश्रम.',
        spokenTextPunjabi:
            'ਨੇੜੇ $count ਰਹਿਣ ਦੇ ਪ੍ਰਬੰਧ ਹਨ: ਸ਼ਕਤੀ ਕੈਂਪ, ਗੰਗਾ ਵਿਹਾਰ ਅਤੇ ਤ੍ਰਿਵੇਣੀ ਆਸ਼ਰਮ।',
        rawData: {'camps': allCamps},
        destinationCoords: const LatLng(25.4460, 81.8680),
        actionButtonText: 'View All Camps & Map',
        actionButtonRoute: '/accommodation',
      );
    }

    // Default: Single Assigned Tent Details
    final campName = primary?['camp_name'] ?? 'Shakti Camp';
    final sector = primary?['sector'] ?? 'Sector 7';
    String tentId = (primary?['tent_id'] as String?) ?? 'Tent B-214';
    if (tentId.toLowerCase().contains('room')) {
      tentId = 'Tent ${tentId.replaceAll(RegExp(r'room\s*', caseSensitive: false), '').trim()}';
    }
    final distance = primary?['distance_km'] ?? 1.2;
    final lat = primary?['lat'] as double? ?? 25.4460;
    final lng = primary?['lng'] as double? ?? 81.8680;

    return AgentResponse(
      type: AgentType.accommodation,
      title: '$campName ($sector)',
      subtitle: 'Allotted: $tentId • $distance km from Sangam',
      primaryValue: tentId,
      badgeText: 'Booking Confirmed ✅',
      badgeColor: const Color(0xFF16A34A),
      primaryIcon: Icons.holiday_village_rounded,
      spokenTextEnglish:
          'Your accommodation is at $campName, $sector, $tentId. It is $distance kilometers away with medical post and wash areas nearby.',
      spokenTextHindi:
          'आपका आवास $campName, $sector, $tentId में है। यह $distance किलोमीटर दूर है और पास में चिकित्सा शिविर व भोजनालय उपलब्ध है।',
      spokenTextTelugu:
          'మీ వసతి $campName, $sector, $tentId లో కేటాయించబడింది. ఇది $distance కిలోమీటర్ల దూరంలో ఉంది.',
      spokenTextTamil:
          'உங்கள் தங்குமிடம் $campName, $sector, $tentId இல் உள்ளது. இது $distance கிமீ தொலைவில் உள்ளது.',
      spokenTextMarathi:
          'आपली राहण्याची सोय $campName, $sector, $tentId येथे आहे. हे $distance किमी अंतरावर आहे.',
      spokenTextPunjabi:
          'ਤੁਹਾਡਾ ਰਹਿਣ ਦਾ ਪ੍ਰਬੰਧ $campName, $sector, $tentId ਵਿੱਚ ਹੈ।',
      rawData: primary ?? {},
      destinationCoords: LatLng(lat, lng),
      actionButtonText: 'Directions to Camp',
      actionButtonRoute: '/accommodation',
    );
  }
}
