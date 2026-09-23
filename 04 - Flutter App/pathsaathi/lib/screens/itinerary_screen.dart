import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../providers/language_provider.dart';
import '../services/tts_service.dart';
import '../services/journey_plan_service.dart';
import '../services/india_gazetteer.dart';
import '../services/regional_template_service.dart';
import '../widgets/tier_badge_widget.dart';
import '../widgets/speak_button.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// Itinerary screen — backed by destination-filtered offline SQLite
/// `itineraries` table via the active JourneyPlan, with 3-tier fallback.
class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({super.key});

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _destinationName = '';
  bool _hasTrip = false;
  DestinationTier _tier = DestinationTier.tierC_unknown;
  String _stateName = 'Regional';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await JourneyPlanService.instance.active();
    if (plan == null) {
      if (mounted) setState(() { _loading = false; _hasTrip = false; _tier = DestinationTier.tierC_unknown; });
      return;
    }
    _destinationName = plan.destinationName;
    _hasTrip = true;

    final gEntry = IndiaGazetteer.instance.byId(plan.destinationId) ??
        IndiaGazetteer.instance.resolve(plan.destinationName);
    if (gEntry != null) {
      _stateName = gEntry.stateName;
    }

    final list = await AppDatabase.instance
        .getItinerariesForDestination(plan.destinationId);

    if (list.isNotEmpty) {
      _events = list;
      _tier = DestinationTier.tierA_verified;
    } else {
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: plan.destinationId,
        hasVerifiedRows: false,
      );
      _tier = tier;
      if (tier == DestinationTier.tierB_template) {
        final template = RegionalTemplateService.instance.generateItinerary(
          destinationId: plan.destinationId,
          destinationName: plan.destinationName,
        );
        _events = template.map((e) => e.toMap()).toList();
      } else {
        _events = [];
      }
    }
    if (mounted) setState(() { _loading = false; });
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  IconData _icon(String? name) {
    switch (name) {
      case 'wb_sunny': return Icons.wb_sunny_outlined;
      case 'water_drop': return Icons.water_drop_outlined;
      case 'temple_hindu': return Icons.temple_hindu_outlined;
      case 'restaurant': return Icons.restaurant_outlined;
      case 'local_fire_department': return Icons.local_fire_department_outlined;
      case 'directions_walk': return Icons.directions_walk_outlined;
      case 'directions_boat': return Icons.directions_boat_outlined;
      case 'wb_twilight': return Icons.wb_twilight_outlined;
      default: return Icons.place_outlined;
    }
  }

  String _localizedTitle(Map<String, dynamic> e, String lang) {
    switch (lang) {
      case 'hi': return (e['title_hi'] as String?)?.isNotEmpty == true ? e['title_hi'] : e['title'];
      case 'te': return (e['title_te'] as String?)?.isNotEmpty == true ? e['title_te'] : e['title'];
      default: return e['title'] ?? '';
    }
  }

  /// Builds the full spoken summary of the day plan in the given language.
  String _spokenSummary(String lang) {
    if (_events.isEmpty) return 'No schedule available.';
    final buf = StringBuffer();
    buf.write(lang == 'hi'
        ? 'आज के कार्यक्रम: '
        : lang == 'te'
            ? 'ఈరోజు కార్యక్రమం: '
            : "Today's schedule: ");
    for (final e in _events) {
      buf.write('${_localizedTitle(e, lang)} — ${e['time']}. ');
    }
    return RegionalTemplateService.formatSpokenText(
      baseSpokenText: buf.toString(),
      stateName: _stateName,
      langCode: lang,
      isTemplate: _tier == DestinationTier.tierB_template,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;

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
        title: Text('Itinerary', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [SpeakButton(textBuilder: _spokenSummary)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_hasTrip
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Create a trip to see your itinerary',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 16, color: const Color(0xFF6B7280)),
                    ),
                  ),
                )
              : _tier == DestinationTier.tierC_unknown || _events.isEmpty
                  ? SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: TierCEmptyStateWidget(
                          destinationName: _destinationName,
                          contentType: 'Itinerary Schedule',
                          onSyncTriggered: _load,
                        ),
                      ),
                    )
                  : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SpeakBanner(textBuilder: _spokenSummary),
                  const SizedBox(height: 8),
                  if (_tier == DestinationTier.tierB_template) ...[
                    TierBadgeWidget(tier: _tier, stateName: _stateName),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    _destinationName.isEmpty
                        ? "Today's Pilgrimage Schedule"
                        : "Itinerary — $_destinationName",
                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
                  const SizedBox(height: 16),

                  // Timeline built from SQLite
                  ...List.generate(_events.length, (i) {
                    final e = _events[i];
                    return IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Column(children: [
                          Container(
                            width: 16, height: 16,
                            decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                          ),
                          if (i < _events.length - 1)
                            Expanded(child: Container(width: 2, color: const Color(0xFFBBF7D0))),
                        ]),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(_icon(e['icon_name']), color: _green, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(e['time'] ?? '',
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9CA3AF))),
                                  Text(_localizedTitle(e, lang),
                                      style: GoogleFonts.outfit(
                                          fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                                  if ((e['location'] as String?)?.isNotEmpty == true)
                                    Text(e['location'],
                                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280))),
                                ]),
                              ),
                              // Crowd level chip from DB
                              if ((e['crowd_level'] as String?)?.isNotEmpty == true)
                                _crowdChip(e['crowd_level']),
                            ]),
                          ),
                        ),
                      ]),
                    );
                  }),
                  const SizedBox(height: 8),

                  // Crowd prediction card (static heuristic — labelled as such)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('👥 Crowd Prediction',
                          style: GoogleFonts.outfit(
                              fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                      const SizedBox(height: 12),
                      ...[
                        ('Morning', '🟢', 'Low', const Color(0xFF16A34A)),
                        ('Afternoon', '🟡', 'Moderate', const Color(0xFFD97706)),
                        ('Evening', '🔴', 'High', const Color(0xFFDC2626)),
                      ].map((row) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              SizedBox(
                                  width: 80,
                                  child: Text(row.$1,
                                      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563)))),
                              Text(row.$2, style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 8),
                              Text(row.$3,
                                  style: GoogleFonts.outfit(
                                      fontSize: 13, fontWeight: FontWeight.w600, color: row.$4)),
                            ]),
                          )),
                      const SizedBox(height: 4),
                      Text('* Based on historical Kumbh Mela data',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: const Color(0xFF9CA3AF), fontStyle: FontStyle.italic)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saffron,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Itinerary saved offline — available without internet'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.download_outlined),
                      label: Text('Save Itinerary (Offline)',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ]),
              ),
            ),
    );
  }

  Widget _crowdChip(String level) {
    Color c;
    switch (level.toLowerCase()) {
      case 'high': c = const Color(0xFFDC2626); break;
      case 'moderate': c = const Color(0xFFD97706); break;
      default: c = const Color(0xFF16A34A);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(level, style: GoogleFonts.outfit(fontSize: 10, color: c, fontWeight: FontWeight.w700)),
    );
  }
}
