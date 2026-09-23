import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../core/app_strings.dart';
import '../services/tier_router.dart';
import '../services/journey_plan_service.dart';
import '../services/startup_permission_service.dart';
import '../models/journey_models.dart';
import '../widgets/tier_status_badge.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);
const _border = Color(0xFFE5E7EB);
const _bg = Color(0xFFF6F8F7);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        StartupPermissionService.instance.requestOnFirstHome();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    // ✅ FIX 1: Real name from provider
    final name = ref.watch(userNameProvider);
    final displayName = name.isEmpty ? 'Pilgrim' : name;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Bar ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // ✅ FIX 3: Shorter greeting — name only, no long translation inline
                        Text('Namaste, $displayName 🙏',
                            style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF111827))),
                        const SizedBox(height: 2),
                        Row(children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: Color(0xFF16A34A),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(AppStrings.offlineReady(lang),
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF16A34A),
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ])),
                  // Fog Dashboard shortcut button for operators
                  IconButton(
                    onPressed: () => context.push('/fog-dashboard'),
                    icon:
                        const Icon(Icons.hub_rounded, color: Color(0xFFF97316)),
                    tooltip: 'Fog Dashboard',
                  ),
                  IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.notifications_outlined,
                          color: Color(0xFF4B5563))),
                ]),
              ),

              // ── 3-Tier Intelligence Indicator ─────────────────────────────
              TierConnectivityIndicator(
                fogStatus: ref.watch(fogStatusProvider),
                cloudAvailable: ref.watch(cloudAvailableProvider),
              ),

              // ── Active trip card (if a journey plan exists) ────────────────
              FutureBuilder<JourneyPlan?>(
                future: JourneyPlanService.instance.active(),
                builder: (context, snap) {
                  final plan = snap.data;
                  if (plan == null) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => context.push('/active-journey'),
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _saffron),
                      ),
                      child: Row(children: [
                        const Icon(Icons.luggage_rounded, color: _saffron),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Your trip to ${plan.destinationName}',
                                    style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  plan.cacheStatus.isComplete
                                      ? 'Ready for offline • tap to continue'
                                      : 'Tap to continue your journey',
                                  style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280)),
                                ),
                              ]),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF9CA3AF)),
                      ]),
                    ),
                  );
                },
              ),

              // ── Voice Card ─────────────────────────────────────────────────
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D4A28), _green],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(children: [
                  // ✅ FIX 3: Two short lines instead of one long wrapping bilingual line
                  Text('How can I help you today?',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.white70),
                      textAlign: TextAlign.center),
                  if (lang != 'en')
                    Text(_helpTranslation(lang),
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: Colors.white54),
                        textAlign: TextAlign.center),
                  const SizedBox(height: 20),

                  // ── Hero Mic Button (for voice transition animation) ──────
                  Hero(
                    tag: 'mic_button',
                    child: GestureDetector(
                      onTap: () => context.push('/listening'),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _saffron,
                          boxShadow: [
                            BoxShadow(
                                color: _saffron.withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.mic,
                            color: Colors.white, size: 44),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Text(AppStrings.tapToSpeak(lang),
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 1.0)),
                  const SizedBox(height: 4),
                  Text(AppStrings.speakInYourLang(lang),
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 10),

                  // ── Example voice hint in selected language ───────────────
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(AppStrings.voiceHint(lang),
                        style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.white,
                            fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.wifi_off,
                          color: Colors.white70, size: 13),
                      const SizedBox(width: 5),
                      Text(AppStrings.offlineMode(lang),
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: Colors.white70)),
                    ]),
                  ),
                ]),
              ),

              // ── Quick Chips ─────────────────────────────────────────────────
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _chip(AppStrings.whereDoIGo(lang), () {}),
                    const SizedBox(width: 8),
                    _chip(AppStrings.myJourney(lang),
                        () => context.go('/journey')),
                    const SizedBox(width: 8),
                    _chip(AppStrings.emergency(lang),
                        () => context.push('/emergency')),
                  ]),
                ),
              ),

              // ── Quick Access Grid ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text('Quick Access',
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827))),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.55,
                  children: [
                    _gridCard(context, Icons.directions_bus_outlined,
                        AppStrings.transport(lang), '/transport'),
                    _gridCard(context, Icons.map_outlined,
                        AppStrings.navigate(lang), '/nav'),
                    _gridCard(context, Icons.holiday_village_outlined,
                        AppStrings.myStay(lang), '/accommodation'),
                    _gridCard(context, Icons.calendar_today_outlined,
                        AppStrings.itinerary(lang), '/itinerary'),
                    _gridCard(context, Icons.download_for_offline_rounded,
                        'Offline City Maps 🗺', '/city-map-picker'),
                    _gridCard(context, Icons.emergency_rounded,
                        AppStrings.emergency(lang), '/emergency'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Dev: Speech Test Lab ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () => context.push('/speech-test'),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA))),
                    child: Row(children: [
                      const Icon(Icons.biotech_outlined,
                          color: _saffron, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('🧪 STT + TTS Test Lab',
                                style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _saffron)),
                            Text('Test 20 speech phrases across all languages',
                                style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: const Color(0xFF92400E))),
                          ])),
                      const Icon(Icons.arrow_forward_ios,
                          size: 14, color: _saffron),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
          ),
          child: Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFF111827))),
        ),
      );

  Widget _gridCard(
          BuildContext ctx, IconData icon, String label, String route) =>
      GestureDetector(
        onTap: () => ctx.push(route),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: _green, size: 24)),
            const SizedBox(height: 8),
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF111827)),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      );

  // Translation-only (no English prefix) for the subtitle line
  static String _helpTranslation(String lang) {
    const t = {
      'hi': 'आज मैं आपकी कैसे मदद करूं?',
      'te': 'నేను మీకు ఎలా సహాయం చేయాలి?',
      'ta': 'நான் உங்களுக்கு எப்படி உதவலாம்?',
      'pa': 'ਮੈਂ ਤੁਹਾਡੀ ਕਿਵੇਂ ਮਦਦ ਕਰਾਂ?',
      'mr': 'मी तुम्हाला कशी मदत करू?',
    };
    return t[lang] ?? '';
  }
}
