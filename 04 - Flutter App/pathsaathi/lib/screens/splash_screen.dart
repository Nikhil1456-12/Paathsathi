import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/profile_service.dart';

const _green = Color(0xFF1A6B3C);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2600), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    // Route based on real profile state: not logged in → /login; logged in but
    // onboarding unfinished → resume at /language; fully set up → /home.
    final route = await ProfileService.instance.initialRoute();
    if (!mounted) return;
    context.go(route);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF0D4A28), _green, Color(0xFF2E8B57)],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.explore, color: Colors.white, size: 56),
                ),
                const SizedBox(height: 24),
                Text('PathSaathi', style: GoogleFonts.outfit(
                  fontSize: 40, fontWeight: FontWeight.w700, color: Colors.white,
                  letterSpacing: -0.5,
                )),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    'Your AI Companion for a Safe & Blessed Journey',
                    style: GoogleFonts.outfit(fontSize: 15, color: Colors.white70, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(flex: 3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _pill('📴 Offline'),
                    const SizedBox(width: 10),
                    _pill('🔒 Private'),
                    const SizedBox(width: 10),
                    _pill('🙏 Safe'),
                  ],
                ),
                const SizedBox(height: 48),
                Text('Powered by Infosys FYP', style: GoogleFonts.outfit(
                  fontSize: 11, color: Colors.white38,
                )),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white30),
    ),
    child: Text(label, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white)),
  );
}
