import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../core/app_strings.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class VoiceProfileScreen extends ConsumerStatefulWidget {
  const VoiceProfileScreen({super.key});
  @override
  ConsumerState<VoiceProfileScreen> createState() => _State();
}

class _State extends ConsumerState<VoiceProfileScreen> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIX 2: Use selected language from provider
    final lang = ref.watch(languageProvider);
    final langBadge = AppStrings.langBadge(lang.code);
    final langName = lang.name;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('Your Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 20),
            // Step indicator
            Row(children: List.generate(5, (i) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3), height: 6,
                decoration: BoxDecoration(
                  color: i == 1 ? _saffron : (i < 1 ? _green : const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ))),
            const SizedBox(height: 6),
            Text('Step 2 of 5', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9CA3AF))),
            const SizedBox(height: 36),

            Text('What should we call you?',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111827)),
              textAlign: TextAlign.center),
            const SizedBox(height: 8),
            // ✅ FIX 2: Shows the SELECTED language name, not hardcoded Hindi
            Text('Speak your name in $langName',
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4B5563))),

            const Spacer(),

            // Mic button
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFFFF8C00), _saffron]),
                boxShadow: [BoxShadow(color: _saffron.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4)],
              ),
              child: const Icon(Icons.mic, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),

            // Waveform
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: [20.0, 35.0, 55.0, 40.0, 60.0, 45.0, 25.0].map((h) =>
                Container(margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6, height: h,
                  decoration: BoxDecoration(
                    color: _saffron.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(3)))).toList()),
            const SizedBox(height: 16),

            // ✅ FIX 2: Language badge uses selected language
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
              child: Text(langBadge,
                style: GoogleFonts.outfit(fontSize: 13, color: _green, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),

            Text('Or type your name',
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
            const SizedBox(height: 10),

            // ✅ FIX 1: Text field saves name to provider
            TextField(
              controller: _ctrl,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.outfit(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Enter your name...',
                hintStyle: GoogleFonts.outfit(color: const Color(0xFF9CA3AF)),
                filled: true, fillColor: const Color(0xFFF6F8F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.5)),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saffron, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  // ✅ FIX 1: Save name before navigating
                  final name = _ctrl.text.trim();
                  await ref.read(userNameProvider.notifier).setName(
                    name.isEmpty ? 'Pilgrim' : name,
                  );
                  if (context.mounted) context.go('/doc-scan');
                },
                child: Text('Next', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
