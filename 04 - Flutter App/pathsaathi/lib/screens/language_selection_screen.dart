import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);
const _border = Color(0xFFE5E7EB);

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});
  @override
  ConsumerState<LanguageSelectionScreen> createState() => _State();
}

class _State extends ConsumerState<LanguageSelectionScreen> {
  int _selected = 1; // Hindi selected by default

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('Choose Your Language', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('We will understand you better',
                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4B5563))),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  itemCount: kLanguages.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
                  ),
                  itemBuilder: (ctx, i) {
                    final lang = kLanguages[i];
                    final sel = i == _selected;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: sel ? const Color(0xFFDCFCE7) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: sel ? _green : _border, width: sel ? 2 : 1),
                          boxShadow: sel ? [BoxShadow(color: _green.withValues(alpha: 0.12), blurRadius: 8)] : null,
                        ),
                        child: Stack(
                          children: [
                            Center(child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(lang.script, style: GoogleFonts.outfit(
                                  fontSize: 22, fontWeight: FontWeight.w600,
                                  color: sel ? _green : const Color(0xFF111827),
                                )),
                                const SizedBox(height: 4),
                                Text(lang.name, style: GoogleFonts.outfit(
                                  fontSize: 12, color: const Color(0xFF6B7280),
                                )),
                              ],
                            )),
                            if (sel) Positioned(
                              top: 8, right: 8,
                              child: Container(
                                width: 22, height: 22,
                                decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('You can change later in Settings',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9CA3AF))),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saffron, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    // ✅ Save selected language globally via Riverpod
                    ref.read(languageProvider.notifier).select(kLanguages[_selected]);
                    context.go('/setup');
                  },
                  child: Text('Continue  →', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
