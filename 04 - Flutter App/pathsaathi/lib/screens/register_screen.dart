import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/user_provider.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// Salted SHA-256 hash of a password — never store the raw password.
String hashPassword(String password) {
  const salt = 'pathsaathi_v1_salt'; // static app salt; per-user salt is a future enhancement
  return sha256.convert(utf8.encode('$salt::$password')).toString();
}

/// Secure store for the credential hash (Android Keystore-backed).
const kSecureAuth = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
const kPassHashKey = 'pathsaathi_pass_hash';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _State();
}

class _State extends ConsumerState<RegisterScreen> {
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _confCtrl  = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConf = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass  = _passCtrl.text;
    final conf  = _confCtrl.text;

    // Validation
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name.'); return;
    }
    if (phone.length < 10) {
      setState(() => _error = 'Enter a valid 10-digit phone number.'); return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.'); return;
    }
    if (pass != conf) {
      setState(() => _error = 'Passwords do not match.'); return;
    }

    setState(() { _loading = true; _error = null; });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name',     name);
    await prefs.setString('user_phone',    phone);
    // SECURITY: store only a salted SHA-256 hash in the Keystore-backed vault,
    // never the raw password.
    await kSecureAuth.write(key: kPassHashKey, value: hashPassword(pass));
    await prefs.remove('user_password'); // clean up any legacy plaintext
    await prefs.setBool('is_logged_in',    true);
    await prefs.setBool('onboarding_done', false); // still need language/setup

    await ref.read(userNameProvider.notifier).setName(name);

    if (mounted) context.go('/language');
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

            // Back to login
            GestureDetector(
              onTap: () => context.go('/login'),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.arrow_back_ios_new, size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text('Back to Login', style: GoogleFonts.outfit(
                  fontSize: 14, color: const Color(0xFF6B7280))),
              ]),
            ),
            const SizedBox(height: 28),

            Text('Create Account 🛤️', style: GoogleFonts.outfit(
              fontSize: 26, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
            const SizedBox(height: 6),
            Text('Join PathSaathi — your journey awaits', style: GoogleFonts.outfit(
              fontSize: 14, color: const Color(0xFF6B7280))),

            const SizedBox(height: 32),

            _label('Full Name'),
            const SizedBox(height: 8),
            _field(controller: _nameCtrl, hint: 'e.g. Nikhil Kumar', icon: Icons.person_outline,
              capitalize: TextCapitalization.words),

            const SizedBox(height: 18),
            _label('Phone Number'),
            const SizedBox(height: 8),
            _field(controller: _phoneCtrl, hint: '10-digit mobile number',
              icon: Icons.phone_outlined, keyboard: TextInputType.phone),

            const SizedBox(height: 18),
            _label('Password'),
            const SizedBox(height: 8),
            _field(
              controller: _passCtrl, hint: 'Min. 6 characters',
              icon: Icons.lock_outline, obscure: _obscurePass,
              suffixIcon: IconButton(
                icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF9CA3AF), size: 20),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ),

            const SizedBox(height: 18),
            _label('Confirm Password'),
            const SizedBox(height: 8),
            _field(
              controller: _confCtrl, hint: 'Re-enter password',
              icon: Icons.lock_outline, obscure: _obscureConf,
              suffixIcon: IconButton(
                icon: Icon(_obscureConf ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF9CA3AF), size: 20),
                onPressed: () => setState(() => _obscureConf = !_obscureConf),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text(_error!, style: GoogleFonts.outfit(
                  fontSize: 13, color: const Color(0xFFDC2626)))),
              ]),
            ],

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _loading ? null : _register,
                child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text('Create Account', style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Already have an account? ', style: GoogleFonts.outfit(
                fontSize: 14, color: const Color(0xFF6B7280))),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text('Login', style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _saffron)),
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
    TextCapitalization capitalize = TextCapitalization.none,
    Widget? suffixIcon,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboard,
    textCapitalization: capitalize,
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
