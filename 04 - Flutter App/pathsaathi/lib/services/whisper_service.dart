import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import 'model_manager.dart';
import 'connectivity_service.dart';
import 'device_tier_service.dart';

/// Real on-device ASR using whisper.cpp (via whisper_flutter_new).
///
/// The model file is the one the ModelManager downloads/verifies into
/// `<appDocs>/models/asr/ggml-<size>.bin`. This service picks the whisper size
/// that matches the device tier, and it will ONLY report ready when that real
/// file is present. It never fabricates a model.
///
/// Whisper is batch (record → file → transcribe), so this service also owns a
/// microphone capture path (via `record`) producing a 16 kHz mono WAV that
/// whisper.cpp expects. If no verified model is present, `isModelReady` is
/// false and the caller falls back to the platform recognizer (STTService).
class WhisperService {
  WhisperService._();
  static final WhisperService instance = WhisperService._();

  final AudioRecorder _recorder = AudioRecorder();

  bool _isReady = false;
  bool get isModelReady => _isReady;

  Whisper? _whisper;
  WhisperModel _model = WhisperModel.tiny;

  /// Directory where ModelManager stores ASR models.
  Future<Directory> _asrDir() async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/models/asr');
    await dir.create(recursive: true);
    return dir;
  }

  /// The whisper.cpp ggml file name for a given size.
  static String _fileFor(WhisperModel m) {
    switch (m) {
      case WhisperModel.small:
        return 'ggml-small.bin';
      case WhisperModel.base:
        return 'ggml-base.bin';
      case WhisperModel.tiny:
      default:
        return 'ggml-tiny.bin';
    }
  }

  /// Whisper size matched to the device tier for best accuracy it can handle:
  /// full → small (best on Indian languages), standard → base, lite → tiny.
  /// `initialize()` also falls back to any other size present on disk.
  WhisperModel _modelForTier() {
    switch (DeviceTierService.tier) {
      case DeviceTier.full:
        return WhisperModel.small;
      case DeviceTier.standard:
        return WhisperModel.base;
      case DeviceTier.lite:
        return WhisperModel.tiny;
    }
  }

  /// Path of the currently selected model file (may not exist yet).
  Future<String> modelFilePath() async {
    final dir = await _asrDir();
    return '${dir.path}/${_fileFor(_model)}';
  }

  /// Initialize: only becomes ready if a real verified-size model file exists.
  Future<bool> initialize() async {
    try {
      _model = _modelForTier();
      final dir = await _asrDir();
      final path = '${dir.path}/${_fileFor(_model)}';
      final file = File(path);

      // If the tier model isn't present, try any other downloaded whisper size
      // so the app uses whatever the user actually has.
      if (!await file.exists()) {
        for (final m in [WhisperModel.small, WhisperModel.base, WhisperModel.tiny]) {
          final alt = File('${dir.path}/${_fileFor(m)}');
          if (await alt.exists()) {
            _model = m;
            break;
          }
        }
      }

      final chosen = File('${dir.path}/${_fileFor(_model)}');
      if (!await chosen.exists()) {
        _isReady = false;
        return false;
      }

      _whisper = Whisper(model: _model, modelDir: dir.path);
      _isReady = true;
      debugPrint('[WhisperService] ready with ${_fileFor(_model)}');
      return true;
    } catch (e) {
      debugPrint('[WhisperService] init error: $e');
      _isReady = false;
      return false;
    }
  }

  bool _autoDownloading = false;
  double _downloadProgress = 0.0;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _autoDownloading;

  /// Ensure the offline-voice model is present. If it's already there, just
  /// initialize. Otherwise, when ONLINE, download it once in the background
  /// (resumable, honest) and activate offline voice automatically when done.
  /// When offline it does nothing (text input still works); it will succeed on
  /// a later launch with connectivity. Safe to call repeatedly.
  Future<void> ensureModelAvailable() async {
    if (_isReady) return;
    if (await initialize()) return; // model already on disk → done

    if (_autoDownloading) return; // already in progress

    // Only auto-fetch on WiFi/ethernet (mapped to `online`). Mobile data maps
    // to `degraded`, so a 75MB background download never surprises the user's
    // data plan; they can still trigger it manually on mobile if they want.
    if (ConnectivityService.instance.status != ConnectivityStatus.online) {
      debugPrint('[WhisperService] not on WiFi — deferring voice-model auto-download');
      return;
    }

    // Pick the ASR model configured for THIS device tier (full→small,
    // standard→base, lite→tiny) so each device gets the best accuracy it can
    // handle. Fall back to the smallest auto-downloadable ASR if none matches.
    ModelEntry? asr;
    for (final m in ModelCatalog.forTier(DeviceTierService.tier)) {
      if (m.category == 'asr' && m.isAutoDownloadable) { asr = m; break; }
    }
    if (asr == null) {
      for (final m in ModelCatalog.all) {
        if (m.category == 'asr' && m.isAutoDownloadable) {
          if (asr == null || m.sizeMB < asr.sizeMB) asr = m;
        }
      }
    }
    if (asr == null) return;

    _autoDownloading = true;
    debugPrint('[WhisperService] auto-downloading offline voice model: ${asr.fileName}');
    await ModelManager.download(
      asr,
      onProgress: (p) => _downloadProgress = p,
      onDone: () async {
        _autoDownloading = false;
        _downloadProgress = 1.0;
        await initialize(); // flips isModelReady → offline voice now works
        debugPrint('[WhisperService] offline voice model ready (auto-downloaded)');
      },
      onError: (e) {
        _autoDownloading = false;
        debugPrint('[WhisperService] voice-model auto-download failed: $e');
      },
    );
  }

  /// Transcribe an existing audio file (WAV, 16 kHz mono preferred).
  Future<String> transcribe(String audioPath, {String langCode = 'hi'}) async {
    if (!_isReady || _whisper == null) throw Exception('Whisper not ready');
    try {
      final res = await _whisper!.transcribe(
        transcribeRequest: TranscribeRequest(
          audio: audioPath,
          language: langCode,
        ),
      );
      return res.text.trim();
    } catch (e) {
      debugPrint('[WhisperService] transcribe error: $e');
      return '';
    }
  }

  /// Record from the microphone for up to [maxDuration], then transcribe with
  /// the on-device whisper model. Returns '' if not ready or on failure.
  ///
  /// This is the genuine offline ASR path: mic → WAV → whisper.cpp → text.
  Future<String> transcribeFromMic({
    String langCode = 'hi',
    Duration maxDuration = const Duration(seconds: 8),
  }) async {
    if (!_isReady) {
      final ok = await initialize();
      if (!ok) return '';
    }
    if (!await _recorder.hasPermission()) return '';

    final tmpDir = await getTemporaryDirectory();
    final wavPath = '${tmpDir.path}/asr_${DateTime.now().millisecondsSinceEpoch}.wav';
    try {
      // 16 kHz mono PCM WAV — the format whisper.cpp expects.
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: wavPath,
      );
      await Future.delayed(maxDuration);
      final recordedPath = await _recorder.stop();
      final path = recordedPath ?? wavPath;
      if (!await File(path).exists()) return '';
      final text = await transcribe(path, langCode: langCode);
      // Clean up the temporary recording.
      try { await File(path).delete(); } catch (_) {}
      return text;
    } catch (e) {
      debugPrint('[WhisperService] mic transcribe error: $e');
      try { if (await _recorder.isRecording()) await _recorder.stop(); } catch (_) {}
      return '';
    }
  }

  /// Stop an in-progress recording (e.g. user tapped stop early).
  Future<void> stopRecording() async {
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
  }

  void reset() {
    _isReady = false;
    _whisper = null;
  }
}
