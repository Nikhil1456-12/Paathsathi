import 'package:flutter_tts/flutter_tts.dart';

/// 100% Offline TTS Service — uses device-native local speech synthesis
/// Supports: hi-IN, te-IN, ta-IN, pa-IN, mr-IN, en-US
class TTSService {
  TTSService._();
  static final TTSService instance = TTSService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  String _currentLocale = 'en-US';

  // Maps our app language code → BCP-47 locale tag
  static const Map<String, String> _localeMap = {
    'en': 'en-US',
    'hi': 'hi-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'pa': 'pa-IN',
    'mr': 'mr-IN',
  };

  Future<void> initialize({String langCode = 'en'}) async {
    _currentLocale = _localeMap[langCode] ?? 'en-US';

    try {
      await _tts.setLanguage(_currentLocale);
      await _tts.setSpeechRate(0.45);   // Slightly slower — clearer for elderly pilgrims
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(false);
      _initialized = true;
    } catch (_) {
      // Fallback to English if regional language engine initialization fails offline
      try {
        await _tts.setLanguage('en-US');
        _initialized = true;
      } catch (_) {}
    }
  }

  /// Change language at runtime (when user switches in Profile)
  Future<void> setLanguage(String langCode) async {
    _currentLocale = _localeMap[langCode] ?? 'en-US';
    try {
      await _tts.setLanguage(_currentLocale);
    } catch (_) {
      await _tts.setLanguage('en-US');
    }
  }

  /// Speak text aloud in the selected language offline (fire-and-forget).
  Future<void> speak(String text) async {
    if (!_initialized) await initialize();
    try {
      await _tts.awaitSpeakCompletion(false);
      await _tts.stop();       // Cancel any ongoing speech
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Speak and RESOLVE ONLY WHEN THE SPEECH ACTUALLY FINISHES.
  /// Use this before starting speech recognition so TTS audio and the mic never
  /// run at the same time (which otherwise cuts STT off the instant it starts).
  Future<void> speakAndWait(String text) async {
    if (!_initialized) await initialize();
    try {
      await _tts.stop();
      await _tts.awaitSpeakCompletion(true); // make speak() await completion
      await _tts.speak(text);
    } catch (_) {
      // Fallback: rough wait proportional to text length if the engine can't
      // report completion, so the caller still gets a sensible gap.
      await Future.delayed(Duration(milliseconds: (text.length * 70).clamp(1200, 8000)));
    }
  }

  /// Speak bilingual: first in English, then in native language
  Future<void> speakBilingual(String english, String native) async {
    if (_currentLocale == 'en-US') {
      await speak(english);
    } else {
      await speak(native);
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _tts.pause();
    } catch (_) {}
  }

  bool get isInitialized => _initialized;
  String get currentLocale => _currentLocale;

  Future<bool> isLanguageAvailable(String langCode) async {
    final locale = _localeMap[langCode] ?? 'en-US';
    try {
      final result = await _tts.isLanguageAvailable(locale);
      return result == 1;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getAvailableLanguages() async {
    try {
      final langs = await _tts.getLanguages;
      return (langs as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  void dispose() => _tts.stop();
}
