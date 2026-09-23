import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _border = Color(0xFFE5E7EB);

class SetupTypeScreen extends StatelessWidget {
  const SetupTypeScreen({super.key});

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
        title: Text('Setup PathSaathi', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Who is setting up PathSaathi?',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
              const SizedBox(height: 8),
              Text('Choose the right setup for the best experience',
                style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4B5563))),
              const SizedBox(height: 32),
              _card(context,
                icon: Icons.person_outline, title: 'For myself',
                subtitle: 'Fresh start — set up quickly and independently',
              ),
              const SizedBox(height: 16),
              _card(context,
                icon: Icons.people_outline, title: 'For a family member',
                subtitle: 'Parent / Elder — We will make it simple and easy for them',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return GestureDetector(
      onTap: () => context.go('/voice-profile'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: _green, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
                const SizedBox(height: 4),
                Text(subtitle, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
              ],
            )),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
