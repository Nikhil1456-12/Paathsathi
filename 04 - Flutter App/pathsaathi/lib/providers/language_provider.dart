import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Language Model ────────────────────────────────────────────────────────────
class AppLanguage {
  final String code;
  final String name;
  final String script;

  const AppLanguage({required this.code, required this.name, required this.script});
}

const kLanguages = [
  AppLanguage(code: 'te', name: 'Telugu',  script: 'తెలుగు'),
  AppLanguage(code: 'hi', name: 'Hindi',   script: 'हिंदी'),
  AppLanguage(code: 'en', name: 'English', script: 'English'),
  AppLanguage(code: 'ta', name: 'Tamil',   script: 'தமிழ்'),
  AppLanguage(code: 'pa', name: 'Punjabi', script: 'ਪੰਜਾਬੀ'),
  AppLanguage(code: 'mr', name: 'Marathi', script: 'मराठी'),
];

AppLanguage languageByCode(String code) =>
    kLanguages.firstWhere((l) => l.code == code,
        orElse: () => const AppLanguage(code: 'hi', name: 'Hindi', script: 'हिंदी'));

// ── Provider ──────────────────────────────────────────────────────────────────
class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(const AppLanguage(code: 'hi', name: 'Hindi', script: 'हिंदी')) {
    _load();
  }

  static const _prefKey = 'selected_language_code';

  /// Load the persisted language so the selection survives app/device restart
  /// and works offline.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null) state = languageByCode(code);
    } catch (_) {}
  }

  void select(AppLanguage lang) {
    state = lang;
    _persist(lang.code);
  }

  Future<void> _persist(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, code);
    } catch (_) {}
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) => LanguageNotifier());
