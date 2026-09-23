import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/language_provider.dart';
import '../providers/user_provider.dart';
import '../services/device_tier_service.dart';

const _green = Color(0xFF1A6B3C);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ FIX 1: Real name from provider
    final name = ref.watch(userNameProvider);
    final displayName = name.isEmpty ? 'Pilgrim' : name;

    // ✅ FIX 3: Real language from provider
    final lang = ref.watch(languageProvider);
    final tier = DeviceTierService.tier;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
        title: Text('Profile & Settings', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [

            // ── User card ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
              ),
              child: Row(children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ✅ FIX 1: Shows actual entered name
                  Text(displayName,
                    style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFF111827))),
                  Text('Pilgrim Profile',
                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
                  const SizedBox(height: 4),
                  Text('📞 +91 98765 43210',
                    style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9CA3AF))),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(20)),
                  child: Text('🟢 Active',
                    style: GoogleFonts.outfit(fontSize: 11, color: _green, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Settings list ───────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(children: [

                // ✅ FIX 3: Language tile — tapping opens language picker
                _SettingsTile(
                  icon: Icons.language,
                  title: 'Language',
                  // Shows currently selected language
                  value: '${lang.script} (${lang.name})',
                  onTap: () => _showLanguagePicker(context, ref),
                  showDivider: true,
                ),

                _SettingsTile(
                  icon: Icons.phone_android,
                  title: 'Device Mode',
                  value: tier.label,
                  onTap: () {},
                  showDivider: true,
                ),

                _SettingsTile(
                  icon: Icons.sync,
                  title: 'Data & Sync',
                  value: 'Offline  •  2h ago',
                  onTap: () {},
                  showDivider: true,
                ),

                _SettingsTile(
                  icon: Icons.lock_outline,
                  title: 'Documents',
                  value: 'Protected',
                  onTap: () {},
                  showDivider: true,
                ),

                _SettingsTile(
                  icon: Icons.family_restroom,
                  title: 'Family Setup',
                  value: 'Enabled',
                  isGreenBadge: true,
                  onTap: () {},
                  showDivider: true,
                ),

                _SettingsTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  value: '',
                  onTap: () {},
                  showDivider: true,
                ),

                _SettingsTile(
                  icon: Icons.info_outline,
                  title: 'About PathSaathi',
                  value: 'v1.0.0',
                  onTap: () {},
                  showDivider: false,
                ),
              ]),
            ),

            const SizedBox(height: 24),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_logged_in', false);
                if (context.mounted) context.go('/login');
              },
              child: Text('Log Out',
                style: GoogleFonts.outfit(fontSize: 15, color: const Color(0xFFDC2626), fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Text('PathSaathi  •  Infosys FYP 2025-26',
              style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF9CA3AF))),
          ]),
        ),
      ),
    );
  }

  // ✅ FIX 3: Language picker bottom sheet — changes app language everywhere
  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Choose Language', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...kLanguages.map((l) {
            final selected = ref.read(languageProvider).code == l.code;
            return ListTile(
              leading: Text(l.script, style: GoogleFonts.outfit(fontSize: 20)),
              title: Text(l.name, style: GoogleFonts.outfit(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? _green : const Color(0xFF111827),
              )),
              trailing: selected
                ? const Icon(Icons.check_circle, color: _green)
                : null,
              onTap: () {
                // ✅ Updates language globally via Riverpod
                ref.read(languageProvider.notifier).select(l);
                Navigator.pop(context);
              },
            );
          }),
        ]),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool isGreenBadge;
  final bool showDivider;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon, required this.title,
    required this.value, required this.onTap, required this.showDivider,
    this.isGreenBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: _green, size: 18),
        ),
        title: Text(title,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF111827))),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (value.isNotEmpty) ...[
            isGreenBadge
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(8)),
                  child: Text(value, style: GoogleFonts.outfit(fontSize: 11, color: _green, fontWeight: FontWeight.w600)))
              : Text(value, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
            const SizedBox(width: 6),
          ],
          const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF9CA3AF)),
        ]),
        onTap: onTap,
      ),
      if (showDivider) const Divider(height: 1, indent: 56, color: Color(0xFFE5E7EB)),
    ]);
  }
}
