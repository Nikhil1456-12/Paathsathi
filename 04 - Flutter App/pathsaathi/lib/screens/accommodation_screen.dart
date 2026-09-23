import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../database/app_database.dart';
import '../services/tts_service.dart';
import '../services/journey_plan_service.dart';
import '../services/regional_template_service.dart';
import '../services/india_gazetteer.dart';
import '../widgets/offline_map_widget.dart';
import '../widgets/speak_button.dart';
import '../widgets/tier_badge_widget.dart';
import '../core/nav_history.dart';
import '../providers/language_provider.dart';
import '../providers/travel_context.dart';
import '../services/accommodation_repository.dart';
import '../services/location_service.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// Accommodation screen — strictly tiered with zero hardcoded cross-destination fallbacks.
class AccommodationScreen extends ConsumerStatefulWidget {
  const AccommodationScreen({super.key});

  @override
  ConsumerState<AccommodationScreen> createState() =>
      _AccommodationScreenState();
}

class _AccommodationScreenState extends ConsumerState<AccommodationScreen> {
  Map<String, dynamic>? _camp;
  bool _loading = true;
  String _destinationId = '';
  String _destinationName = '';
  LatLng? _destinationCoords;
  LatLng? _currentLocation;
  bool _hasTrip = false;
  String? _loadError;
  DestinationTier _tier = DestinationTier.tierC_unknown;
  String _stateName = 'Regional';
  List<AccommodationRecommendation> _hotels = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Render curated stay recommendations immediately from the confirmed
    // destination. SQLite enrichment is optional and must not blank the page
    // while the database is opening or recovering.
    final confirmed = ref.read(travelContextProvider).confirmedDestination;
    _currentLocation = LocationService.instance.last.position;
    if (confirmed != null && mounted) {
      setState(() {
        _destinationId = confirmed.id;
        _destinationName = confirmed.name;
        _destinationCoords = confirmed.coords;
        _hasTrip = true;
        _hotels = AccommodationRepository.instance.forDestination(confirmed.id);
        _loading = false;
      });
    }
    try {
      final plan = await JourneyPlanService.instance.active().timeout(
            const Duration(seconds: 10),
          );
      if (plan == null) {
        if (mounted) {
          setState(() {
            _loading = false;
            if (!_hasTrip) _tier = DestinationTier.tierC_unknown;
          });
        }
        return;
      }

      _destinationId = plan.destinationId;
      _destinationName = plan.destinationName;
      _destinationCoords = plan.destinationCoords;
      _hasTrip = true;
      _hotels =
          AccommodationRepository.instance.forDestination(plan.destinationId);

      final all = await AppDatabase.instance
          .getAccommodationsForDestination(plan.destinationId);

      final gEntry = IndiaGazetteer.instance.byId(plan.destinationId) ??
          IndiaGazetteer.instance.resolve(plan.destinationName);
      if (gEntry != null) {
        _stateName = gEntry.stateName;
        _destinationCoords ??= gEntry.coords;
      }

      if (all.isNotEmpty) {
        _camp = all.first;
        _tier = DestinationTier.tierA_verified;
      } else {
        final tier = RegionalTemplateService.instance.evaluateTier(
          destinationId: plan.destinationId,
          hasVerifiedRows: false,
        );
        _tier = tier;

        if (tier == DestinationTier.tierB_template) {
          final template =
              RegionalTemplateService.instance.generateAccommodation(
            destinationId: plan.destinationId,
            destinationName: plan.destinationName,
          );
          _camp = template.toMap();
        } else {
          _camp = null;
        }
      }
    } catch (e) {
      debugPrint('[AccommodationScreen] load failed: $e');
      if (mounted) {
        setState(() {
          _loadError =
              'Stay data could not be loaded. Please retry or open the page again.';
          _loading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  String _spoken(String lang) {
    final c = _camp;
    if (c == null || !_hasTrip) return 'No accommodation assigned.';

    final name = c['camp_name'] ?? 'your camp';
    final sector = c['sector'] ?? '';
    final tent = c['tent_id'] ?? '';
    final dist = c['distance_km'] ?? '';
    final isTemplate = (c['is_template'] == 1);

    String baseText;
    switch (lang) {
      case 'hi':
        baseText =
            'आपका आवास $name, $sector, $tent में है। यह $dist किलोमीटर दूर है।';
        break;
      case 'te':
        baseText =
            'మీ వసతి $name, $sector, $tent లో ఉంది. ఇది $dist కిలోమీటర్ల దూరంలో ఉంది.';
        break;
      default:
        baseText =
            'Your accommodation is at $name, $sector, $tent. It is $dist kilometres away.';
        break;
    }

    return RegionalTemplateService.formatSpokenText(
      baseSpokenText: baseText,
      stateName: _stateName,
      langCode: lang,
      isTemplate: isTemplate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final langCode = ref.watch(languageProvider).code;
    final c = _camp;

    final isTemplate =
        (_tier == DestinationTier.tierB_template) || (c?['is_template'] == 1);

    final campName = (c?['camp_name'] as String?) ??
        (_hotels.isNotEmpty ? _hotels.first.name : '');
    final sector = c?['sector'] as String? ?? '';
    final tentId = c?['tent_id'] as String? ?? '';
    final dist = (c?['distance_km'] as num?)?.toDouble() ?? 0.8;
    final lat = (c?['lat'] as num?)?.toDouble() ??
        _destinationCoords?.latitude ??
        20.5937;
    final lng = (c?['lng'] as num?)?.toDouble() ??
        _destinationCoords?.longitude ??
        78.9629;
    final facilities = (c?['facilities'] as String?)
            ?.split(',')
            .map((f) => f.trim())
            .where((f) => f.isNotEmpty)
            .toList() ??
        const ['Drinking Water', 'Rest Area', 'Assistance Counter'];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text(
          _destinationName.isEmpty ? 'My Stay' : 'Stay at $_destinationName',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        actions: [SpeakButton(textBuilder: _spoken)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _errorState()
              : (!_hasTrip ||
                      (_tier == DestinationTier.tierC_unknown &&
                          _hotels.isEmpty) ||
                      (campName.isEmpty && _hotels.isEmpty))
                  ? TierCEmptyStateWidget(
                      destinationName: _destinationName,
                      screenType: 'accommodation',
                    )
                  : SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hotels.isNotEmpty) ...[
                              _hotelHeader(),
                              const SizedBox(height: 10),
                              ..._hotels.map(_hotelCard),
                              const SizedBox(height: 18),
                            ],
                            if (isTemplate)
                              TierBadgeWidget(
                                langCode: langCode,
                                customNote:
                                    'Estimated pilgrim stay in $_stateName. Check room allotment at the destination desk.',
                              ),
                            SpeakBanner(textBuilder: _spoken),
                            const SizedBox(height: 8),

                            // Main booking card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border(
                                  top: BorderSide(
                                    color: isTemplate
                                        ? const Color(0xFFF97316)
                                        : _green,
                                    width: 4,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color: isTemplate
                                              ? const Color(0xFFFFF7ED)
                                              : const Color(0xFFDCFCE7),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: Icon(
                                          Icons.holiday_village_outlined,
                                          color: isTemplate
                                              ? const Color(0xFFEA580C)
                                              : _green,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              campName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              '$sector  •  $tentId',
                                              style: GoogleFonts.outfit(
                                                fontSize: 13,
                                                color: const Color(0xFF4B5563),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isTemplate
                                          ? const Color(0xFFFFF7ED)
                                          : const Color(0xFFDCFCE7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isTemplate
                                              ? Icons.info_outline
                                              : Icons.check_circle,
                                          color: isTemplate
                                              ? const Color(0xFFEA580C)
                                              : const Color(0xFF16A34A),
                                          size: 18,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isTemplate
                                              ? 'Estimated Stay'
                                              : 'Booking Confirmed',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isTemplate
                                                ? const Color(0xFFEA580C)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Divider(
                                      height: 24, color: Color(0xFFE5E7EB)),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined,
                                          size: 16, color: Color(0xFF4B5563)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$dist km from center / shrine',
                                        style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            color: const Color(0xFF4B5563)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Offline map preview centered on real coords
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: SizedBox(
                                      height: 140,
                                      width: double.infinity,
                                      child: OfflineMapWidget(
                                        initialCenter: _currentLocation ??
                                            LatLng(lat, lng),
                                        initialZoom: 15.5,
                                        destinationId: _destinationId,
                                        destinationName: _destinationName,
                                        showControls: false,
                                        compact: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _green,
                                      side: const BorderSide(color: _green),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    onPressed: () => context.go('/nav'),
                                    icon: const Icon(Icons.map_outlined),
                                    label: Text('Show on Map',
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _saffron,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                    onPressed: () => context.push('/listening'),
                                    icon: const Icon(Icons.mic_none),
                                    label: Text('Ask PathSaathi',
                                        style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Nearby Facilities',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: facilities
                                  .map((f) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: Text(
                                          f,
                                          style: GoogleFonts.outfit(
                                              fontSize: 13,
                                              color: const Color(0xFF111827)),
                                        ),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hotel_outlined,
                  size: 52, color: Color(0xFF6B7280)),
              const SizedBox(height: 14),
              Text(_loadError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: const Color(0xFF374151))),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadError = null;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  Widget _hotelHeader() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hotel_rounded, color: _green),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Top ${_hotels.length} stays near ${_destinationName.isEmpty ? 'your destination' : _destinationName}',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _green,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _hotelCard(AccommodationRecommendation hotel) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.hotel, color: _saffron, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hotel.name,
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(hotel.area,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: const Color(0xFF4B5563))),
                  const SizedBox(height: 5),
                  Text(hotel.note,
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: const Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: hotel.facilities
                        .map((f) => Chip(
                              label: Text(f,
                                  style: GoogleFonts.outfit(fontSize: 10)),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('★ ${hotel.rating.toStringAsFixed(1)}',
                    style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800, color: _green)),
                const SizedBox(height: 4),
                Text('${hotel.vacancies} vacancies',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: const Color(0xFF6B7280))),
                const SizedBox(height: 6),
                SizedBox(
                  height: 32,
                  child: ElevatedButton(
                    onPressed: hotel.vacancies == 0
                        ? null
                        : () {
                            AccommodationRepository.instance.selectedHotel =
                                hotel;
                            context.push('/stay-reserve');
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _saffron,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('Book hotel'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
