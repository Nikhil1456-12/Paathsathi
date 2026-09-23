// lib/widgets/speak_button.dart
//
// Reusable "read this aloud" control for PathSaathi.
//
// Designed for non-literate and elderly pilgrims: every important screen can
// expose a large, obvious speaker button that reads its content aloud in the
// currently-selected language via the on-device TTS engine (100% offline).
//
// Two forms are provided:
//   • SpeakButton      — a circular icon button (for app bars / cards)
//   • SpeakBanner      — a full-width "Tap to hear this page" banner (for tops of screens)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../services/tts_service.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// A circular speaker button that speaks [text] (or a per-language builder)
/// in the currently selected language. Toggles between speak/stop.
class SpeakButton extends ConsumerStatefulWidget {
  /// Fixed text to speak (same in all languages). Prefer [textBuilder] for
  /// language-specific content.
  final String? text;

  /// Builder that returns the text to speak for a given language code.
  final String Function(String langCode)? textBuilder;

  final Color color;
  final double size;

  const SpeakButton({
    super.key,
    this.text,
    this.textBuilder,
    this.color = Colors.white,
    this.size = 24,
  }) : assert(text != null || textBuilder != null,
            'Provide either text or textBuilder');

  @override
  ConsumerState<SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends ConsumerState<SpeakButton> {
  bool _speaking = false;

  Future<void> _toggle() async {
    final tts = TTSService.instance;
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final lang = ref.read(languageProvider).code;
    final speech = widget.textBuilder?.call(lang) ?? widget.text ?? '';
    if (speech.trim().isEmpty) return;
    await tts.initialize(langCode: lang);
    if (mounted) setState(() => _speaking = true);
    await tts.speak(speech);
    // flutter_tts speak completes when queued (awaitSpeakCompletion=false),
    // so reset the icon after a short delay proportional to text length.
    final ms = (speech.length * 60).clamp(1500, 15000);
    await Future.delayed(Duration(milliseconds: ms));
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _speaking ? 'Stop' : 'Read aloud',
      icon: Icon(
        _speaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
        color: widget.color,
        size: widget.size,
      ),
      onPressed: _toggle,
    );
  }
}

/// A large, full-width banner that reads a screen's content aloud when tapped.
/// Ideal at the top of information screens for non-literate users.
class SpeakBanner extends ConsumerStatefulWidget {
  /// Builder returning the full spoken summary for a language code.
  final String Function(String langCode) textBuilder;
  final String? label;

  const SpeakBanner({super.key, required this.textBuilder, this.label});

  @override
  ConsumerState<SpeakBanner> createState() => _SpeakBannerState();
}

class _SpeakBannerState extends ConsumerState<SpeakBanner> {
  bool _speaking = false;

  static const Map<String, String> _tapLabel = {
    'en': 'Tap to hear this page',
    'hi': 'यह पृष्ठ सुनने के लिए टैप करें',
    'te': 'ఈ పేజీని వినడానికి నొక్కండి',
    'ta': 'இந்தப் பக்கத்தைக் கேட்க தட்டவும்',
    'pa': 'ਇਹ ਪੰਨਾ ਸੁਣਨ ਲਈ ਟੈਪ ਕਰੋ',
    'mr': 'हे पृष्ठ ऐकण्यासाठी टॅप करा',
  };

  Future<void> _toggle() async {
    final tts = TTSService.instance;
    final lang = ref.read(languageProvider).code;
    if (_speaking) {
      await tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    final speech = widget.textBuilder(lang);
    if (speech.trim().isEmpty) return;
    await tts.initialize(langCode: lang);
    if (mounted) setState(() => _speaking = true);
    await tts.speak(speech);
    final ms = (speech.length * 60).clamp(1500, 20000);
    await Future.delayed(Duration(milliseconds: ms));
    if (mounted) setState(() => _speaking = false);
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    final label = widget.label ?? (_tapLabel[lang] ?? _tapLabel['en']!);
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _speaking ? _saffron.withValues(alpha: 0.12) : const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _speaking ? _saffron : _green.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _speaking ? _saffron : _green,
              shape: BoxShape.circle,
            ),
            child: Icon(_speaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _speaking ? 'Speaking… tap to stop' : label,
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w600, color: _green),
            ),
          ),
        ]),
      ),
    );
  }
}
