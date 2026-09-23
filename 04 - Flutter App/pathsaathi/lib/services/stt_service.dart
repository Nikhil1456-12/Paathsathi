import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'connectivity_service.dart';

/// Multilingual STT Service — wraps Android SpeechRecognizer with
/// robust permission handling, fallback support, error callbacks,
/// and live sound level monitoring.
class STTService {
  STTService._();
  static final STTService instance = STTService._();

  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _lastRanOnDevice = false;
  String _lastError = '';
  String _lastStatus = '';

  /// Whether the last listen ran fully on-device (true offline).
  bool get lastRanOnDevice => _lastRanOnDevice;

  void Function(String errorMsg)? onErrorCallback;
  void Function(String status)? onStatusCallback;
  void Function(double level)? onSoundLevelCallback;

  String get lastError => _lastError;
  String get lastStatus => _lastStatus;
  bool get isListening => _speech.isListening;
  bool get isAvailable => _available;

  // Maps our app language code → BCP-47 locale for Android SpeechRecognizer
  static const Map<String, String> _localeMap = {
    'en': 'en-US',
    'hi': 'hi-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'pa': 'pa-IN',
    'mr': 'mr-IN',
  };

  /// Initialize STT — requests microphone permission, checks availability
  Future<bool> initialize() async {
    try {
      final perm = await Permission.microphone.request();
      if (!perm.isGranted) {
        _lastError = 'Microphone permission denied';
        debugPrint('[STTService] $lastError');
        _available = false;
        onErrorCallback?.call(_lastError);
        return false;
      }

      _available = await _speech.initialize(
        onError: (err) {
          _lastError = err.errorMsg;
          debugPrint('[STTService] Speech error: ${err.errorMsg} (permanent: ${err.permanent})');
          onErrorCallback?.call(err.errorMsg);
        },
        onStatus: (status) {
          _lastStatus = status;
          debugPrint('[STTService] Status changed: $status');
          onStatusCallback?.call(status);
        },
      );
      debugPrint('[STTService] Speech initialized: available = $_available');
      return _available;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('[STTService] Init exception: $e');
      _available = false;
      onErrorCallback?.call(_lastError);
      return false;
    }
  }

  /// Start listening with audio volume level monitoring and error propagation
  Future<bool> startListening({
    required String langCode,
    required void Function(String words, bool isFinal) onResult,
    void Function(double level)? onSoundLevel,
    void Function(String errorMsg)? onError,
    void Function(String status)? onStatus,
    void Function(double confidence)? onConfidence,
  }) async {
    onErrorCallback = onError;
    onStatusCallback = onStatus;
    onSoundLevelCallback = onSoundLevel;

    if (!_available) {
      final ok = await initialize();
      if (!ok) {
        onError?.call(_lastError.isNotEmpty ? _lastError : 'Speech recognition unavailable');
        return false;
      }
    }

    // Resolve the best available locale for this language. If the exact locale
    // (e.g. te-IN) isn't installed on the device we fall back to any locale that
    // starts with the base language, else en-US — otherwise listen() silently
    // recognises nothing.
    final locale = await _resolveLocale(langCode);

    // OFFLINE-FIRST: when the device has no internet, force on-device
    // recognition so it uses the installed offline voice pack instead of
    // silently trying to reach a speech server (which just fails offline). When
    // online, use the default recognizer (server-assisted, more accurate).
    // The caller (listening screen) has a Whisper fallback for when neither the
    // offline pack nor the network is available.
    final offline =
        ConnectivityService.instance.status == ConnectivityStatus.offline;
    final useOnDevice = offline;

    try {
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            onConfidence?.call(result.hasConfidenceRating ? result.confidence : 1.0);
          }
          onResult(result.recognizedWords, result.finalResult);
        },
        onSoundLevelChange: (level) => onSoundLevel?.call(level),
        listenOptions: SpeechListenOptions(
          localeId: locale,
          onDevice: useOnDevice,
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          pauseFor: const Duration(seconds: 4),
        ),
      );
      _lastRanOnDevice = useOnDevice;
      return true;
    } catch (e) {
      debugPrint('[STTService] listen failed for $locale: $e');
      onError?.call(offline
          ? 'Offline voice needs a language pack or the on-device Whisper model. '
              'You can type your request in the box below instead.'
          : 'Could not start voice. You can type your request in the box below, '
              'or install the offline voice pack (Settings → Google → Voice → '
              'Offline speech recognition).');
      return false;
    }
  }

  /// Pick a locale that actually exists on this device for [langCode].
  Future<String> _resolveLocale(String langCode) async {
    final target = _localeMap[langCode] ?? 'en-US';
    try {
      final locales = await _speech.locales();
      final base = target.split('-')[0];
      // Exact match first, then any locale with the same base language.
      final exact = locales.where((l) => l.localeId == target);
      if (exact.isNotEmpty) return exact.first.localeId;
      final baseMatch = locales.where((l) => l.localeId.startsWith(base));
      if (baseMatch.isNotEmpty) return baseMatch.first.localeId;
    } catch (_) {}
    return target;
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }

  /// Check if a specific language is available for STT on this device
  Future<bool> isLocaleAvailable(String langCode) async {
    if (!_available) await initialize();
    final locales = await _speech.locales();
    final targetCode = _localeMap[langCode] ?? 'en-US';
    final baseLang = targetCode.split('-')[0];
    return locales.any((l) =>
      l.localeId == targetCode ||
      l.localeId.startsWith(baseLang));
  }

  /// Returns download instructions if a language pack is missing
  static String downloadInstructions(String langCode) {
    const langNames = {
      'te': 'Telugu (తెలుగు)',
      'ta': 'Tamil (தமிழ்)',
      'pa': 'Punjabi (ਪੰਜਾਬੀ)',
      'mr': 'Marathi (मराठी)',
      'hi': 'Hindi (हिंदी)',
    };
    final name = langNames[langCode] ?? langCode;
    return 'To enable offline $name voice:\n'
        '1. Open Google app on phone\n'
        '2. Settings → Voice → Offline speech recognition\n'
        '3. Search "$name" & download pack\n'
        'Or simply tap any quick question or type below!';
  }

  /// Get list of available locales on this device
  Future<List<LocaleName>> getAvailableLocales() async {
    if (!_available) await initialize();
    return _speech.locales();
  }
}
