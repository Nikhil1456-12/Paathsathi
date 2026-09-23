import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../database/app_database.dart';
import '../providers/language_provider.dart';
import '../services/tts_service.dart';
import '../services/journey_plan_service.dart';
import '../widgets/speak_button.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// My Journey — timeline now built from the offline SQLite `itineraries` table.
/// The day tabs (Today / Tomorrow / Day 3) shift which events are marked done,
/// and every event can be read aloud for non-literate users.
class MyJourneyScreen extends ConsumerStatefulWidget {
  const MyJourneyScreen({super.key});
  @override
  ConsumerState<MyJourneyScreen> createState() => _State();
}

class _State extends ConsumerState<MyJourneyScreen> {
  int _tab = 0;
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final plan = await JourneyPlanService.instance.active();
    final list = plan == null
        ? const <Map<String, dynamic>>[]
        : await AppDatabase.instance
            .getItinerariesForDestination(plan.destinationId);
    if (mounted) {
      setState(() {
        _events = list;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  IconData _icon(String? name) {
    switch (name) {
      case 'wb_sunny':
        return Icons.wb_sunny_outlined;
      case 'water_drop':
        return Icons.water_drop_outlined;
      case 'temple_hindu':
        return Icons.temple_hindu_outlined;
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'local_fire_department':
        return Icons.local_fire_department_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  String _title(Map<String, dynamic> e, String lang) {
    switch (lang) {
      case 'hi':
        return (e['title_hi'] as String?)?.isNotEmpty == true
            ? e['title_hi']
            : e['title'];
      case 'te':
        return (e['title_te'] as String?)?.isNotEmpty == true
            ? e['title_te']
            : e['title'];
      default:
        return e['title'] ?? '';
    }
  }

  String _spoken(String lang) {
    if (_events.isEmpty) return 'No journey planned.';
    final buf = StringBuffer(lang == 'hi'
        ? 'आपकी यात्रा: '
        : lang == 'te'
            ? 'మీ ప్రయాణం: '
            : 'Your journey: ');
    for (final e in _events) {
      buf.write('${e['time']} ${_title(e, lang)}. ');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    // Number of events considered "done" so far shifts per day tab (demo logic).
    final doneCount = _tab == 0
        ? 3
        : _tab == 1
            ? 1
            : 0;

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
        title: Text('My Journey',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [SpeakButton(textBuilder: _spoken)],
      ),
      body: Column(children: [
        // Tab bar
        Container(
          color: _green,
          child: Row(
              children: ['Today', 'Tomorrow', 'Day 3'].asMap().entries.map((e) {
            return GestureDetector(
              onTap: () => setState(() => _tab = e.key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color:
                                _tab == e.key ? _saffron : Colors.transparent,
                            width: 3))),
                child: Text(e.value,
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _tab == e.key ? Colors.white : Colors.white54)),
              ),
            );
          }).toList()),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _events.length,
                  itemBuilder: (ctx, i) {
                    final e = _events[i];
                    final done = i < doneCount;
                    return IntrinsicHeight(
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(children: [
                              Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        done ? _green : const Color(0xFFE5E7EB),
                                    border: Border.all(
                                        color: done
                                            ? _green
                                            : const Color(0xFF9CA3AF),
                                        width: 2),
                                  )),
                              if (i < _events.length - 1)
                                Expanded(
                                    child: Container(
                                        width: 2,
                                        color: done
                                            ? _green.withValues(alpha: 0.3)
                                            : const Color(0xFFE5E7EB))),
                            ]),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: done
                                          ? const Color(0xFFBBF7D0)
                                          : const Color(0xFFE5E7EB)),
                                ),
                                child: Row(children: [
                                  Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                          color: done
                                              ? const Color(0xFFDCFCE7)
                                              : const Color(0xFFF3F4F6),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Icon(_icon(e['icon_name']),
                                          color: done
                                              ? _green
                                              : const Color(0xFF9CA3AF),
                                          size: 20)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(e['time'] ?? '',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  color:
                                                      const Color(0xFF9CA3AF))),
                                          Text(_title(e, lang),
                                              style: GoogleFonts.outfit(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: done
                                                      ? const Color(0xFF111827)
                                                      : const Color(
                                                          0xFF4B5563))),
                                        ]),
                                  ),
                                  IconButton(
                                    tooltip: 'Read aloud',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.volume_up_rounded,
                                        color: _green, size: 20),
                                    onPressed: () => TTSService.instance.speak(
                                        '${e['time']}. ${_title(e, lang)}'),
                                  ),
                                ]),
                              ),
                            ),
                          ]),
                    );
                  },
                ),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _saffron,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/listening'),
        icon: const Icon(Icons.mic),
        label: Text('Ask PathSaathi',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
