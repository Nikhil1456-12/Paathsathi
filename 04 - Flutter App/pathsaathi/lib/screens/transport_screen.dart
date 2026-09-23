import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../services/tts_service.dart';
import '../services/journey_plan_service.dart';
import '../services/regional_template_service.dart';
import '../services/india_gazetteer.dart';
import '../widgets/tier_badge_widget.dart';
import '../core/nav_history.dart';
import '../providers/language_provider.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class TransportScreen extends ConsumerStatefulWidget {
  const TransportScreen({super.key});

  @override
  ConsumerState<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends ConsumerState<TransportScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _options = [];
  bool _loading = true;
  String _destinationName = '';
  String _destinationId = '';
  DestinationTier _tier = DestinationTier.tierC_unknown;
  String _stateName = 'Regional';
  bool _isTemplate = false;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    final plan = await JourneyPlanService.instance.active();
    if (plan == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _tier = DestinationTier.tierC_unknown;
        });
      }
      return;
    }
    _destinationId = plan.destinationId;
    _destinationName = plan.destinationName;

    final gEntry = IndiaGazetteer.instance.byId(plan.destinationId) ??
        IndiaGazetteer.instance.resolve(plan.destinationName);
    if (gEntry != null) {
      _stateName = gEntry.stateName;
    }

    await _loadOptions('');
  }

  Future<void> _loadOptions(String query) async {
    setState(() => _loading = true);
    final results = await AppDatabase.instance.getTransportOptions(_destinationId);

    if (results.isNotEmpty) {
      _tier = DestinationTier.tierA_verified;
      _isTemplate = false;
      final filtered = query.isEmpty
          ? results
          : results.where((r) {
              final s = '${r['from_name']} ${r['to_name']} ${r['operator']} ${r['mode']}'.toLowerCase();
              return s.contains(query.toLowerCase());
            }).toList();
      if (mounted) {
        setState(() {
          _options = filtered;
          _loading = false;
        });
      }
    } else {
      // 0 SQLite rows -> Evaluate Tier B vs Tier C
      final tier = RegionalTemplateService.instance.evaluateTier(
        destinationId: _destinationId,
        hasVerifiedRows: false,
      );
      _tier = tier;

      if (tier == DestinationTier.tierB_template) {
        _isTemplate = true;
        final templates = RegionalTemplateService.instance.generateTransportOptions(
          destinationId: _destinationId,
          destinationName: _destinationName,
        );
        final mapped = templates.map((t) => {
          'id': t.id,
          'destination_id': t.destinationId,
          'mode': t.mode,
          'from_name': t.fromName,
          'to_name': t.toName,
          'dep_time': t.depTime,
          'arr_time': t.arrTime,
          'price_inr': t.priceInr,
          'operator': t.operator,
          'indicative': 1,
          'is_template': 1,
          'data_tier': 'template',
        }).toList();

        final filtered = query.isEmpty
            ? mapped
            : mapped.where((r) {
                final s = '${r['from_name']} ${r['to_name']} ${r['operator']} ${r['mode']}'.toLowerCase();
                return s.contains(query.toLowerCase());
              }).toList();

        if (mounted) {
          setState(() {
            _options = filtered;
            _loading = false;
          });
        }
      } else {
        _isTemplate = false;
        if (mounted) {
          setState(() {
            _options = [];
            _loading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    TTSService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          _destinationName.isEmpty
              ? 'Available Transport'
              : 'Transport to $_destinationName',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_destinationId.isEmpty || (_tier == DestinationTier.tierC_unknown && _options.isEmpty))
              ? TierCEmptyStateWidget(
                  destinationName: _destinationName,
                  screenType: 'transport',
                )
              : SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_isTemplate)
                  TierBadgeWidget(
                    langCode: ref.watch(languageProvider).code,
                    customNote:
                        'Estimated regional transport for $_stateName. Fares and operators are indicative.',
                  ),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => _loadOptions(val),
                  decoration: InputDecoration(
                    hintText: 'Search destination (e.g. Sangam, Delhi, Gate 3)',
                    hintStyle: GoogleFonts.outfit(color: const Color(0xFF9CA3AF), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF9CA3AF)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF)),
                            onPressed: () {
                              _searchCtrl.clear();
                              _loadOptions('');
                            },
                          )
                        : const Icon(Icons.directions_bus, color: _green),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: 'Available Schedules ${_options.length} found',
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Text('Available Schedules', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
                  child: Text('${_options.length} found', style: GoogleFonts.outfit(fontSize: 11, color: _green, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _options.isEmpty
                    ? Center(
                        child: Text(
                          'No transport options found${_searchCtrl.text.isNotEmpty ? ' for "${_searchCtrl.text}"' : ''}.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF6B7280), height: 1.5),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _options.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final b = _options[i];
                          final name = b['operator'] ?? b['mode'] ?? 'Transport';
                          final from = b['from_name'] ?? '';
                          final to = b['to_name'] ?? '';
                          final time = b['dep_time'] ?? '';
                          final mode = b['mode'] ?? 'bus';
                          final price = b['price_inr'] ?? 0;
                          final isTemplateRow = (b['is_template'] == 1);

                          return Semantics(
                            label: '$name from $from to $to at $time $mode ₹$price',
                            child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: Row(children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isTemplateRow ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  mode == 'train' ? Icons.train_rounded : Icons.directions_bus_rounded,
                                  color: isTemplateRow ? const Color(0xFFEA580C) : _green, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                                  Text('$from → $to',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4B5563))),
                                  const SizedBox(height: 4),
                                  Row(children: [
                                    Flexible(
                                      child: Text('$time  •  ${mode[0].toUpperCase()}${mode.substring(1)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _saffron)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isTemplateRow ? const Color(0xFFFFF7ED) : const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isTemplateRow ? 'Indicative' : '₹$price',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: isTemplateRow ? const Color(0xFFEA580C) : _green,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ]),
                              ),
                              // Compact trailing controls: speaker + Route
                              IconButton(
                                tooltip: 'Read aloud',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                                icon: const Icon(Icons.volume_up_rounded, color: _green, size: 20),
                                onPressed: () async {
                                  final baseSpoken = '$name from $from to $to departs at $time by $mode. Indicative fare ₹$price.';
                                  final spoken = RegionalTemplateService.formatSpokenText(
                                    baseSpokenText: baseSpoken,
                                    stateName: _stateName,
                                    langCode: ref.read(languageProvider).code,
                                    isTemplate: isTemplateRow,
                                  );
                                  await TTSService.instance.speak(spoken);
                                },
                              ),
                              SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _saffron,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 0,
                                  ),
                                  onPressed: () => context.go('/nav'),
                                  child: Text('Route', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ]),
                            ),
                          );
                        },
                      ),
          ),
          Semantics(
            label: '100% Offline SQLite database Zero internet required',
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, size: 14, color: _green),
                const SizedBox(width: 6),
                Text('100% Offline SQLite database  •  Zero internet required',
                    style: GoogleFonts.outfit(fontSize: 11, color: _green, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
