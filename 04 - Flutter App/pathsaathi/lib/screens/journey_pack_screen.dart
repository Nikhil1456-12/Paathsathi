// lib/screens/journey_pack_screen.dart
//
// Smallest useful UI over the existing JourneyPackService. Shows the offline
// Journey Pack for the CONFIRMED destination: overall status + every category
// with honest AVAILABLE / UNAVAILABLE / LIVE_ONLY labelling. Destination-agnostic
// (reads whatever pack was persisted for the confirmed Place). No new data/pack
// system, no fabricated data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../providers/travel_context.dart';
import '../core/nav_history.dart';
import '../services/journey_pack_service.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class JourneyPackScreen extends ConsumerStatefulWidget {
  const JourneyPackScreen({super.key});

  @override
  ConsumerState<JourneyPackScreen> createState() => _JourneyPackScreenState();
}

class _JourneyPackScreenState extends ConsumerState<JourneyPackScreen> {
  JourneyPack? _pack;
  bool _loading = true;
  bool _noDestination = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dest = ref.read(travelContextProvider).confirmedDestination;
    if (dest == null) {
      if (mounted) setState(() { _noDestination = true; _loading = false; });
      return;
    }
    final pack = await JourneyPackService.instance.load(dest.id);
    if (mounted) setState(() { _pack = pack; _loading = false; });
  }

  // ── Localized labels (reuse the app's bi() helper pattern via a small map) ──
  String _t(String lang, Map<String, String> m, String en) =>
      lang == 'en' ? en : (m[lang]?.isNotEmpty == true ? m[lang]! : en);

  String _categoryTitle(String lang, String category) {
    const titles = {
      'destination_info': {'en': 'Destination', 'hi': 'गंतव्य', 'te': 'గమ్యం', 'ta': 'சேருமிடம்'},
      'landmarks': {'en': 'Landmarks', 'hi': 'स्थल', 'te': 'ప్రదేశాలు', 'ta': 'இடங்கள்'},
      'hospitals': {'en': 'Hospitals', 'hi': 'अस्पताल', 'te': 'ఆసుపత్రులు', 'ta': 'மருத்துவமனைகள்'},
      'railway_stations': {'en': 'Railway Stations', 'hi': 'रेलवे स्टेशन', 'te': 'రైల్వే స్టేషన్లు', 'ta': 'ரயில் நிலையங்கள்'},
      'transport': {'en': 'Transport', 'hi': 'परिवहन', 'te': 'రవాణా', 'ta': 'போக்குவரத்து'},
      'pharmacies': {'en': 'Pharmacies', 'hi': 'दवा की दुकान', 'te': 'ఔషధశాలలు', 'ta': 'மருந்தகங்கள்'},
      'hotels': {'en': 'Hotels', 'hi': 'होटल', 'te': 'హోటళ్ళు', 'ta': 'ஹோட்டல்கள்'},
      'airports': {'en': 'Airports', 'hi': 'हवाई अड्डे', 'te': 'విమానాశ్రయాలు', 'ta': 'விமான நிலையங்கள்'},
      'offline_map': {'en': 'Offline Map', 'hi': 'ऑफ़लाइन नक्शा', 'te': 'ఆఫ్‌లైన్ మ్యాప్', 'ta': 'ஆஃப்லைன் வரைபடம்'},
      'live_transport': {'en': 'Live Transport', 'hi': 'लाइव परिवहन', 'te': 'లైవ్ రవాణా', 'ta': 'நேரடி போக்குவரத்து'},
      'emergency_live': {'en': 'Live Emergency Info', 'hi': 'लाइव आपात जानकारी', 'te': 'లైవ్ అత్యవసర సమాచారం', 'ta': 'நேரடி அவசர தகவல்'},
    };
    return _t(lang, titles[category] ?? const {}, _prettify(category));
  }

  String _prettify(String c) =>
      c.split('_').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  ({Color color, IconData icon, String text}) _statusChip(String lang, PackDataStatus s) {
    switch (s) {
      case PackDataStatus.available:
        return (color: const Color(0xFF16A34A), icon: Icons.offline_bolt_rounded,
            text: _t(lang, {'hi': 'उपलब्ध (ऑफ़लाइन)', 'te': 'అందుబాటులో (ఆఫ్‌లైన్)', 'ta': 'கிடைக்கும் (ஆஃப்லைன்)'}, 'Available offline'));
      case PackDataStatus.unavailable:
        return (color: const Color(0xFF9CA3AF), icon: Icons.cloud_off_rounded,
            text: _t(lang, {'hi': 'ऑफ़लाइन अनुपलब्ध', 'te': 'ఆఫ్‌లైన్‌లో అందుబాటులో లేదు', 'ta': 'ஆஃப்லைனில் இல்லை'}, 'Unavailable offline'));
      case PackDataStatus.liveOnly:
        return (color: const Color(0xFF2563EB), icon: Icons.wifi_rounded,
            text: _t(lang, {'hi': 'इंटरनेट आवश्यक', 'te': 'ఇంటర్నెట్ అవసరం', 'ta': 'இணையம் தேவை'}, 'Requires internet'));
    }
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
        title: Text(_t(lang, {'hi': 'ऑफ़लाइन जर्नी पैक', 'te': 'ఆఫ్‌లైన్ జర్నీ ప్యాక్', 'ta': 'ஆஃப்லைன் பயண தொகுப்பு'}, 'Offline Journey Pack'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(key: Key('jp_loading'), child: CircularProgressIndicator())
          : _noDestination
              ? _emptyState(lang,
                  key: const Key('jp_no_destination'),
                  icon: Icons.flag_outlined,
                  msg: _t(lang, {'hi': 'पहले कोई गंतव्य पुष्टि करें।', 'te': 'ముందుగా గమ్యాన్ని నిర్ధారించండి.', 'ta': 'முதலில் ஒரு இடத்தை உறுதிப்படுத்தவும்.'}, 'Confirm a destination first.'))
              : _pack == null
                  ? _emptyState(lang,
                      key: const Key('jp_not_prepared'),
                      icon: Icons.download_for_offline_outlined,
                      msg: _t(lang, {'hi': 'ऑफ़लाइन पैक तैयार नहीं है।', 'te': 'ఆఫ్‌లైన్ ప్యాక్ సిద్ధం కాలేదు.', 'ta': 'ஆஃப்லைன் தொகுப்பு தயாராகவில்லை.'}, 'Offline pack not prepared.'))
                  : _packView(lang, _pack!),
    );
  }

  Widget _emptyState(String lang, {required Key key, required IconData icon, required String msg}) {
    return Center(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF6B7280))),
        ]),
      ),
    );
  }

  Widget _packView(String lang, JourneyPack pack) {
    // Overall availability = count of AVAILABLE categories.
    final availableCount = pack.sections.values.where((s) => s.status == PackDataStatus.available).length;
    final total = pack.sections.length;
    // Preserve a stable category order for the UI.
    const order = [
      'destination_info', 'landmarks', 'hospitals', 'railway_stations', 'transport',
      'pharmacies', 'hotels', 'airports', 'offline_map', 'live_transport', 'emergency_live',
    ];
    final ordered = order.where((k) => pack.sections.containsKey(k)).toList();

    return ListView(
      key: const Key('jp_list'),
      padding: const EdgeInsets.all(16),
      children: [
        // Header: destination + overall status
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: const Border(left: BorderSide(color: _saffron, width: 4)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pack.destinationName,
                key: const Key('jp_destination_name'),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: _green)),
            const SizedBox(height: 4),
            Text(
              _t(lang, {'hi': '$availableCount/$total श्रेणियाँ ऑफ़लाइन उपलब्ध', 'te': '$availableCount/$total విభాగాలు ఆఫ్‌లైన్‌లో అందుబాటులో'}, '$availableCount of $total categories available offline'),
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF4B5563)),
            ),
            const SizedBox(height: 2),
            Text(
              _t(lang, {'hi': 'तैयार: ${_shortDate(pack.preparedAtIso)}', 'te': 'సిద్ధం: ${_shortDate(pack.preparedAtIso)}'}, 'Prepared: ${_shortDate(pack.preparedAtIso)}'),
              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9CA3AF)),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        ...ordered.map((cat) => _sectionCard(lang, cat, pack.sections[cat]!)),
      ],
    );
  }

  Widget _sectionCard(String lang, String category, PackSection section) {
    final chip = _statusChip(lang, section.status);
    return Container(
      key: Key('jp_section_$category'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(_categoryTitle(lang, category),
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: chip.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(chip.icon, size: 13, color: chip.color),
              const SizedBox(width: 4),
              Text(chip.text, style: GoogleFonts.outfit(fontSize: 11, color: chip.color, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        // Only AVAILABLE sections show stored items; others show nothing more
        // (the honest status chip already says why).
        if (section.status == PackDataStatus.available && section.items.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...section.items.map((item) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.place_outlined, size: 14, color: _green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _itemLabel(item),
                      style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151)),
                    ),
                  ),
                ]),
              )),
        ],
      ]),
    );
  }

  String _itemLabel(Map<String, dynamic> item) {
    final name = item['name']?.toString() ?? item['id']?.toString() ?? '—';
    final dist = item['distance_km'];
    return dist != null ? '$name  •  $dist km' : name;
  }

  String _shortDate(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
