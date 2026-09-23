import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';
import 'register_screen.dart' show hashPassword, kSecureAuth, kPassHashKey;

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _State();
}

class _State extends ConsumerState<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    final savedPhone = prefs.getString('user_phone') ?? '';
    final savedName  = prefs.getString('user_name') ?? '';

    // SECURITY: compare salted SHA-256 hashes, never raw passwords.
    final savedHash = await kSecureAuth.read(key: kPassHashKey) ?? '';
    // Legacy fallback: migrate any old plaintext password to a hash on first login.
    final legacyPlain = prefs.getString('user_password');
    final enteredHash = hashPassword(_passCtrl.text);
    final passOk = savedHash.isNotEmpty
        ? enteredHash == savedHash
        : (legacyPlain != null && _passCtrl.text == legacyPlain);

    if (_phoneCtrl.text.trim() == savedPhone && passOk) {
      if (savedHash.isEmpty) {
        // Migrate legacy plaintext to secure hash, then remove plaintext.
        await kSecureAuth.write(key: kPassHashKey, value: enteredHash);
        await prefs.remove('user_password');
      }
      await prefs.setBool('is_logged_in', true);
      await ref.read(userNameProvider.notifier).setName(savedName);
      if (mounted) context.go('/home');
    } else {
      setState(() {
        _error = 'Incorrect phone number or password.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 48),

            // Logo + brand
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: Text('🛤️', style: TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('PathSaathi', style: GoogleFonts.outfit(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _green)),
                Text('Your travel companion', style: GoogleFonts.outfit(
                  fontSize: 12, color: const Color(0xFF6B7280))),
              ]),
            ]),

            const SizedBox(height: 40),
            Text('Welcome back 👋', style: GoogleFonts.outfit(
              fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            const SizedBox(height: 6),
            Text('Sign in to your account', style: GoogleFonts.outfit(
              fontSize: 14, color: const Color(0xFF6B7280))),

            const SizedBox(height: 36),

            _label('Phone Number'),
            const SizedBox(height: 8),
            _field(
              controller: _phoneCtrl,
              hint: '10-digit mobile number',
              icon: Icons.phone_outlined,
              keyboard: TextInputType.phone,
            ),

            const SizedBox(height: 20),

            _label('Password'),
            const SizedBox(height: 8),
            _field(
              controller: _passCtrl,
              hint: 'Enter your password',
              icon: Icons.lock_outline,
              obscure: _obscure,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF9CA3AF), size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                const SizedBox(width: 6),
                Text(_error!, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFFDC2626))),
              ]),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saffron, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _login,
                child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Login', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 20),

            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text("Don't have an account? ", style: GoogleFonts.outfit(
                fontSize: 14, color: const Color(0xFF6B7280))),
              GestureDetector(
                onTap: () => context.go('/register'),
                child: Text('Register', style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _green)),
              ),
            ]),

            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: GoogleFonts.outfit(
    fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF374151)));

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType? keyboard,
    Widget? suffixIcon,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    style: GoogleFonts.outfit(fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.outfit(color: const Color(0xFF9CA3AF), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
      suffixIcon: suffixIcon,
      filled: true, fillColor: const Color(0xFFF9FAFB),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _green, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
