import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../agents/agent_orchestrator.dart';
import '../providers/language_provider.dart';
import '../providers/travel_context.dart';
import '../core/voice_strings.dart';
import '../services/tts_service.dart';
import '../services/stt_service.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);

/// Multilingual destination confirmation gate.
///
/// If a destination is PENDING (spoken by the user), this screen:
///   • shows + speaks "You said X. Is that correct?" in the selected language,
///   • listens for a yes/no answer by voice (also tappable),
///   • on YES → promotes pending → confirmed and opens navigation with THAT
///     destination (never a default),
///   • on NO  → returns to listening.
///
/// If there is no pending destination, it falls back to the old agent-response
/// confirmation (for non-destination queries).
class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakAndListen());
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    STTService.instance.stop();
    super.dispose();
  }

  Future<void> _speakAndListen() async {
    final lang = ref.read(languageProvider).code;
    final pending = ref.read(travelContextProvider).pendingDestination;
    if (pending == null) return; // agent-response fallback path, no voice loop

    await TTSService.instance.initialize(langCode: lang);
    // Speak the question and WAIT until it finishes — TTS and the mic must not
    // run at the same time, otherwise recognition is cut off the instant the
    // question starts playing (the "STT stops when it speaks" bug).
    await TTSService.instance.speakAndWait(VoiceStrings.confirmDestination(lang, pending.name));
    await TTSService.instance.stop();
    // Small gap so the audio route fully releases before the mic opens.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || _handled) return;

    // Now listen for a spoken yes/no in the selected language.
    await STTService.instance.startListening(
      langCode: lang,
      onResult: (words, isFinal) {
        if (!isFinal || _handled || words.trim().isEmpty) return;
        if (VoiceStrings.isYes(words)) {
          _confirm();
        } else if (VoiceStrings.isNo(words)) {
          _reject();
        }
      },
      onError: (_) {}, // silent — user can still tap the buttons
    );
  }

  void _confirm() {
    if (_handled || !mounted) return;
    _handled = true;
    STTService.instance.stop();
    final lang = ref.read(languageProvider).code;
    final dest = ref.read(travelContextProvider).pendingDestination;
    ref.read(travelContextProvider.notifier).confirmPending();
    if (dest != null) {
      TTSService.instance.speak(VoiceStrings.confirmedGoing(lang, dest.name));
    }
    // Route the CONFIRMED destination into the journey flow: choose transport,
    // reserve, prepare-for-offline, then track. (Was '/nav'; the journey flow
    // reaches navigation later via the active plan.)
    context.go('/transport-options');
  }

  void _reject() {
    if (_handled || !mounted) return;
    _handled = true;
    STTService.instance.stop();
    ref.read(travelContextProvider.notifier).rejectPending();
    context.go('/listening');
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    final pending = ref.watch(travelContextProvider).pendingDestination;

    // ── Destination confirmation (voice-first, multilingual) ───────────────
    if (pending != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => smartBack(context),
          ),
          title: Text('Confirm destination', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
                ),
                child: Column(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.place_rounded, color: _green, size: 30),
                  ),
                  const SizedBox(height: 16),
                  // Confirmation question in the selected language
                  Text(VoiceStrings.confirmDestination(lang, pending.name),
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(pending.name,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: _green)),
                  if (pending.note != null)
                    Text(pending.note!, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280))),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _BlinkDot(),
                    const SizedBox(width: 6),
                    Text('🎙 ${_answerHint(lang)}',
                        style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9CA3AF))),
                  ]),
                ]),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _confirm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(VoiceStrings.yesLabel(lang),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 56,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _reject,
                  icon: const Icon(Icons.close),
                  label: Text(VoiceStrings.noLabel(lang),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    // ── Fallback: agent-response confirmation (non-destination queries) ────
    final orchState = ref.watch(orchestratorProvider);
    final response = orchState.latestResponse;

    // SAFETY GATE: if there is neither a pending destination NOR a genuine agent
    // response, there is nothing legitimate to confirm. Never allow confirming
    // an empty/unresolved state into /ai-response (that path used to fabricate a
    // default Prayagraj/Sangam transport reply). Send the user back to retry.
    if (response == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            onPressed: () => smartBack(context),
          ),
          title: Text("Couldn't understand", style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const SizedBox(height: 24),
              const Icon(Icons.help_outline, color: Color(0xFFDC2626), size: 48),
              const SizedBox(height: 16),
              Text(
                "We couldn't recognise a destination or request. Please try again and say the place name clearly.",
                style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFF374151)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go('/listening'),
                  icon: const Icon(Icons.mic),
                  label: Text('Try again', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    final queryText = orchState.currentQuery.isNotEmpty ? orchState.currentQuery : 'your request';
    final title = response.title;
    final subtitle = response.subtitle;
    final icon = response.primaryIcon;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('Did you mean?', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 4))],
              ),
              child: Column(children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: _green, size: 30),
                ),
                const SizedBox(height: 16),
                Text('"$queryText"',
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: _green)),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
              ]),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => context.go('/ai-response'),
                icon: const Icon(Icons.check_circle_outline),
                label: Text("Yes, that's right", style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => context.go('/listening'),
                icon: const Icon(Icons.close),
                label: Text('No, try again', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  static String _answerHint(String lang) => switch (lang) {
        'hi' => 'हाँ या नहीं बोलें',
        'te' => 'అవును లేదా కాదు అని చెప్పండి',
        'ta' => 'ஆம் அல்லது இல்லை என்று சொல்லுங்கள்',
        _ => 'Say yes or no',
      };
}

class _BlinkDot extends StatefulWidget {
  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.2, end: 1.0).animate(_c),
        child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
      );
}
