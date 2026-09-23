import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../agents/agent_orchestrator.dart';
import '../models/agent_response.dart';
import '../providers/language_provider.dart';
import '../services/tts_service.dart';
import '../services/tier_router.dart';
import '../widgets/offline_map_widget.dart';
import '../widgets/tier_status_badge.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class AiResponseScreen extends ConsumerStatefulWidget {
  const AiResponseScreen({super.key});
  @override
  ConsumerState<AiResponseScreen> createState() => _State();
}

class _State extends ConsumerState<AiResponseScreen> {
  bool _isSpeaking = false;
  LatLng? _focusedMapCoords;
  String? _focusedMapTitle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakResponse());
  }

  Future<void> _speakResponse() async {
    final langCode = ref.read(languageProvider).code;
    final orchState = ref.read(orchestratorProvider);
    final response = orchState.latestResponse;

    if (response == null) return;

    final tts = TTSService.instance;
    await tts.initialize(langCode: langCode);

    if (mounted) setState(() => _isSpeaking = true);

    final speechText = response.getSpokenText(langCode);
    await tts.speak(speechText);

    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _toggleSpeak() async {
    final tts = TTSService.instance;
    if (_isSpeaking) {
      await tts.stop();
      if (mounted) setState(() => _isSpeaking = false);
    } else {
      await _speakResponse();
    }
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    final orchState = ref.watch(orchestratorProvider);
    final response = orchState.latestResponse;

    if (response == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _green,
          title: Text('AI Response', style: GoogleFonts.outfit()),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => smartBack(context)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final speechText = response.getSpokenText(lang);
    final isNav = response.type == AgentType.navigation;
    final isStay = response.type == AgentType.accommodation;
    final hasCampsList = response.rawData.containsKey('camps') && response.rawData['camps'] is List;
    final campsList = hasCampsList ? (response.rawData['camps'] as List) : [];

    final mapTargetCoords = _focusedMapCoords ?? response.destinationCoords ?? const LatLng(25.4358, 81.8814);
    final mapTargetTitle = _focusedMapTitle ?? response.title;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () {
            TTSService.instance.stop();
            smartBack(context);
          },
        ),
        title: Text('✨ AI Agent Response', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          if (_isSpeaking)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
                ),
                const SizedBox(width: 6),
                Text('Speaking...', style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
              ]),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // ── Dynamic Agent Response Card ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border(left: BorderSide(color: response.badgeColor, width: 4)),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: response.badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(response.primaryIcon, color: response.badgeColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      response.title,
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TierStatusBadge(
                    tier: ref.watch(activeTierProvider),
                    responseMs: ref.watch(orchestratorProvider).lastResponseMs,
                  ),
                ]),
                const SizedBox(height: 12),
                Text(response.subtitle, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
                const SizedBox(height: 10),
                Text(
                  response.primaryValue,
                  style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w700, color: _saffron),
                ),
                const SizedBox(height: 12),

                // Spoken Translation Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F8F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    speechText,
                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151), height: 1.5),
                  ),
                ),

                // ── If this is a List of Accommodations, render clickable items ──
                if (hasCampsList) ...[
                  const SizedBox(height: 14),
                  Text('Tap any camp to locate on map:',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                  const SizedBox(height: 8),
                  ...campsList.map((camp) {
                    final cName = camp['camp_name'] ?? 'Camp';
                    final cSec = camp['sector'] ?? 'Sector';
                    final cDist = camp['distance_km'] ?? 1.0;
                    final cLat = camp['lat'] as double? ?? 25.4460;
                    final cLng = camp['lng'] as double? ?? 81.8680;
                    final isFocused = _focusedMapCoords?.latitude == cLat;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _focusedMapCoords = LatLng(cLat, cLng);
                            _focusedMapTitle = '$cName ($cSec)';
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isFocused ? const Color(0xFFDCFCE7) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isFocused ? _green : const Color(0xFFE5E7EB)),
                          ),
                          child: Row(children: [
                            Icon(Icons.location_on, color: isFocused ? _green : _saffron, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('$cName ($cSec)', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
                                Text('$cDist km away', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6B7280))),
                              ]),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isFocused ? _green : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isFocused ? _green : const Color(0xFFD1D5DB)),
                              ),
                              child: Text(
                                isFocused ? 'Selected 📍' : 'Locate on Map',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isFocused ? Colors.white : _green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                    );
                  }),
                ],

                // ── Interactive Offline Map Preview ───────────────────────
                if (isNav || isStay || response.destinationCoords != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                      height: isNav ? 200 : 140,
                      width: double.infinity,
                      child: OfflineMapWidget(
                        key: ValueKey('ai_map_${mapTargetCoords.latitude}_${mapTargetCoords.longitude}'),
                        initialCenter: mapTargetCoords,
                        initialZoom: 15.2,
                        destination: mapTargetCoords,
                        destinationName: mapTargetTitle,
                        showControls: isNav,
                        compact: !isNav,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.access_time, size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Text('Processed offline via on-device agent',
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9CA3AF))),
                ]),
              ]),
            ),

            const SizedBox(height: 16),

            // ── Listen / Stop Spoken Response Button ──────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSpeaking ? Colors.red.shade600 : _saffron,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _toggleSpeak,
                icon: Icon(_isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded),
                label: Text(
                  _isSpeaking ? 'Stop Speaking' : '🔊 Listen in ${_langName(lang)}',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            if (response.actionButtonRoute != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go(response.actionButtonRoute!),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(
                    response.actionButtonText ?? 'View Details',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.wifi_off, color: _green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Agent executed locally · 100% Offline with zero internet',
                    style: GoogleFonts.outfit(fontSize: 11, color: _green, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  static String _langName(String code) {
    const names = {
      'en': 'English',
      'hi': 'Hindi (हिंदी)',
      'te': 'Telugu (తెలుగు)',
      'ta': 'Tamil (தமிழ்)',
      'pa': 'Punjabi (ਪੰਜਾਬੀ)',
      'mr': 'Marathi (मराठी)',
    };
    return names[code] ?? 'English';
  }
}
