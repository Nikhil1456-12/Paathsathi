import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pathsaathi/services/india_gazetteer.dart';
import 'package:pathsaathi/services/regional_template_service.dart';
import 'package:pathsaathi/models/journey_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IndiaGazetteer & Resolution Tests', () {
    test('Exact matching for short names <= 4 characters', () {
      final puri = IndiaGazetteer.instance.resolve('Puri');
      expect(puri, isNotNull);
      expect(puri!.name, 'Puri');
      expect(puri.stateCode, 'OD');

      final pune = IndiaGazetteer.instance.resolve('Pune');
      expect(pune, isNotNull);
      expect(pune!.name, 'Pune');
      expect(pune.stateCode, 'MH');

      // Short names must never cross-match
      expect(puri.id, isNot(equals(pune.id)));
    });

    test('Multilingual alias resolution', () {
      // Visakhapatnam in Telugu & Hindi
      final vizagTe = IndiaGazetteer.instance.resolve('విశాఖపట్నం');
      expect(vizagTe, isNotNull);
      expect(vizagTe!.name, 'Visakhapatnam');

      final vizagHi = IndiaGazetteer.instance.resolve('विशाखापट्टनम');
      expect(vizagHi, isNotNull);
      expect(vizagHi!.name, 'Visakhapatnam');

      // Srikakulam in Telugu
      final sklmTe = IndiaGazetteer.instance.resolve('శ్రీకాకుళం');
      expect(sklmTe, isNotNull);
      expect(sklmTe!.name, 'Srikakulam');

      // Chennai in Tamil
      final chennaiTa = IndiaGazetteer.instance.resolve('சென்னை');
      expect(chennaiTa, isNotNull);
      expect(chennaiTa!.name, 'Chennai');
    });

    test('Length-guarded fuzzy matching for long names', () {
      // "Visakhapatnm" (1 typo in 12-char word) -> Visakhapatnam
      final fuzzyVizag = IndiaGazetteer.instance.resolve('Visakhapatnm');
      expect(fuzzyVizag, isNotNull);
      expect(fuzzyVizag!.name, 'Visakhapatnam');

      // Nonsense place does not resolve
      final unknown = IndiaGazetteer.instance.resolve('xyzqwe999');
      expect(unknown, isNull);
    });

    test('Dynamic slug generation and legacy mappings', () {
      expect(IndiaGazetteer.instance.toSlug('Visakhapatnam'), 'visakhapatnam');
      expect(IndiaGazetteer.instance.toSlug('Dwarka'), 'dwarka');
      expect(IndiaGazetteer.instance.toSlug('Kurnool'), 'kurnool_ap');
    });
  });

  group('RegionalTemplateService & Tier Evaluation Tests', () {
    test('Tier A: hasVerifiedRows == true always yields tierA_verified', () {
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: 'visakhapatnam',
        hasVerifiedRows: true,
      );
      expect(tier, DestinationTier.tierA_verified);
    });

    test('Tier B: 0 SQLite rows + valid Gazetteer yields tierB_template', () {
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: 'kurnool_ap',
        hasVerifiedRows: false,
      );
      expect(tier, DestinationTier.tierB_template);
    });

    test('Tier C: 0 SQLite rows + unknown place yields tierC_unknown', () {
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: 'non_existent_place_123',
        hasVerifiedRows: false,
      );
      expect(tier, DestinationTier.tierC_unknown);
    });

    test('Tier B Transport options carry honest regional metadata', () {
      final options = RegionalTemplateService.instance.generateTransportOptions(
        destinationId: 'kurnool_ap',
        destinationName: 'Kurnool',
      );
      expect(options, isNotEmpty);
      final bus = options.firstWhere((o) => o.mode == 'bus');
      expect(bus.isTemplate, isTrue);
      expect(bus.dataTier, 'template');
      expect(bus.indicative, isTrue);
      expect(bus.operator, contains('APSRTC'));
      expect(bus.operator, contains('Indicative'));
    });

    test('Tier B Accommodation carries template markings', () {
      final accom = RegionalTemplateService.instance.generateAccommodation(
        destinationId: 'kurnool_ap',
        destinationName: 'Kurnool',
      );
      expect(accom.isTemplate, isTrue);
      expect(accom.dataTier, 'template');
      expect(accom.campName, contains('Dharamshala / Lodge'));
      expect(accom.facilities, contains('Drinking Water'));
    });

    test('Tier B Itinerary has 4-stage classical structure', () {
      final items = RegionalTemplateService.instance.generateItinerary(
        destinationId: 'kurnool_ap',
        destinationName: 'Kurnool',
      );
      expect(items.length, 4);
      expect(items[0].isTemplate, isTrue);
      expect(items[0].dataTier, 'template');
      expect(items[0].title, contains('Darshan'));
      expect(items[1].title, contains('Walk'));
      expect(items[2].title, contains('Lunch'));
      expect(items[3].title, contains('Aarti'));
    });

    test('Mandatory Spoken Qualifier enforcement', () {
      // English
      final en = RegionalTemplateService.formatSpokenText(
        baseSpokenText: 'Bus departs at 10 AM.',
        stateName: 'Andhra Pradesh',
        langCode: 'en',
        isTemplate: true,
      );
      expect(en, startsWith('Estimated regional information: Based on typical services in Andhra Pradesh'));

      // Telugu
      final te = RegionalTemplateService.formatSpokenText(
        baseSpokenText: 'బస్సు ఉదయం 10 గంటలకు బయలుదేరుతుంది.',
        stateName: 'Andhra Pradesh',
        langCode: 'te',
        isTemplate: true,
      );
      expect(te, startsWith('అంచనా వేసిన సమాచారం: Andhra Pradesh రాష్ట్రంలోని సాధారణ సేవల ఆధారంగా'));

      // Hindi
      final hi = RegionalTemplateService.formatSpokenText(
        baseSpokenText: 'बस सुबह 10 बजे निकलेगी।',
        stateName: 'Andhra Pradesh',
        langCode: 'hi',
        isTemplate: true,
      );
      expect(hi, startsWith('अनुमानित जानकारी: Andhra Pradesh राज्य की सामान्य सेवाओं के आधार पर'));

      // Verified data passes through unchanged
      final verified = RegionalTemplateService.formatSpokenText(
        baseSpokenText: 'Confirmed schedule.',
        stateName: 'Andhra Pradesh',
        langCode: 'en',
        isTemplate: false,
      );
      expect(verified, 'Confirmed schedule.');
    });
  });

  group('Map Guard Logic Tests', () {
    test('Prayagraj guard rejects distant coordinates or non-Prayagraj IDs', () {
      const sangam = LatLng(25.4358, 81.8814);
      const vizag = LatLng(17.6868, 83.2185);
      const distance = Distance();

      final dVizagToSangam = distance.as(LengthUnit.Meter, vizag, sangam);
      expect(dVizagToSangam, greaterThan(20000));

      // Guard requirement: ID must be 'prayagraj' AND distance < 20km
      bool isNearPrayagraj(String? id, LatLng center) {
        final isId = id?.toLowerCase() == 'prayagraj';
        final d = distance.as(LengthUnit.Meter, center, sangam);
        return isId && d < 20000;
      }

      expect(isNearPrayagraj('prayagraj', sangam), isTrue);
      expect(isNearPrayagraj('visakhapatnam', vizag), isFalse);
      expect(isNearPrayagraj('prayagraj', vizag), isFalse);
      expect(isNearPrayagraj('chennai', const LatLng(13.0827, 80.2707)), isFalse);
    });
  });
}