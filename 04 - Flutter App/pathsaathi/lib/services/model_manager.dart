import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_tier_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Model Entry — one downloadable quantized model
// ─────────────────────────────────────────────────────────────────────────────
class ModelEntry {
  final String id;
  final String name;
  final String description;
  final String quantization;   // e.g. "INT8", "INT4 GGUF", "FP16"
  final String framework;      // e.g. "Whisper.cpp", "MediaPipe", "ONNX RT"
  final int sizeMB;
  final String fileName;
  final String sha256;         // real hex sha256, or '' if not yet pinned
  final Set<DeviceTier> tiers; // Which tiers use this model
  final String category;       // 'asr', 'llm', 'nlu', 'embed', 'tts', 'map', 'data'

  /// Real public download URL. If null, this model has no automatic download
  /// source configured and MUST be provided manually — the app will never
  /// fabricate it.
  final String? downloadUrl;

  /// Whether fetching this URL requires user authentication (e.g. a gated
  /// Hugging Face repo). Purely informational for the UI.
  final bool requiresAuth;

  const ModelEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.quantization,
    required this.framework,
    required this.sizeMB,
    required this.fileName,
    required this.sha256,
    required this.tiers,
    required this.category,
    this.downloadUrl,
    this.requiresAuth = false,
  });

  /// A downloaded file is considered plausibly-real only if it is at least this
  /// many bytes. Guards against the old "placeholder text file" masquerading as
  /// a model (those were a few dozen bytes). We use 80% of the advertised size.
  int get minValidBytes => (sizeMB * 1024 * 1024 * 0.8).floor();

  /// True when a real automatic download source is configured.
  bool get isAutoDownloadable => downloadUrl != null && downloadUrl!.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Catalog — all quantized models for PathSaathi
// Infosys-specified tech stack, quantized for on-device inference
// ─────────────────────────────────────────────────────────────────────────────
class ModelCatalog {
  ModelCatalog._();

  static const all = <ModelEntry>[

    // ── ASR: Whisper.cpp (Infosys specified: "compact multilingual ASR model") ──
    // Real public GGML weights from the whisper.cpp repo on Hugging Face.
    // File names match the whisper_flutter_new plugin's expected ggml-*.bin.
    ModelEntry(
      id: 'whisper_small_int8',
      name: 'Whisper Small',
      description: 'High-accuracy multilingual ASR — Hindi, Telugu, Tamil, Punjabi, Marathi',
      quantization: 'GGML FP16',
      framework: 'Whisper.cpp',
      sizeMB: 488,
      fileName: 'ggml-small.bin',
      sha256: '',
      downloadUrl: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin',
      // High-accuracy ASR for powerful devices (much better on Indian languages
      // than tiny). Auto-downloaded on full-tier phones over WiFi.
      tiers: {DeviceTier.full},
      category: 'asr',
    ),
    ModelEntry(
      id: 'whisper_base_int8',
      name: 'Whisper Base',
      description: 'Balanced multilingual ASR — 6 Indian languages',
      quantization: 'GGML FP16',
      framework: 'Whisper.cpp',
      sizeMB: 148,
      fileName: 'ggml-base.bin',
      sha256: '',
      downloadUrl: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin',
      // Balanced accuracy/size ASR — auto-downloaded on standard-tier phones.
      tiers: {DeviceTier.standard},
      category: 'asr',
    ),
    // Compact ASR for low-RAM devices — smallest download, lowest accuracy.
    ModelEntry(
      id: 'whisper_tiny_int8',
      name: 'Offline Voice (Whisper Tiny)',
      description: 'Compact multilingual offline speech recognition. Smallest '
          'download; lower accuracy — used only on low-RAM devices.',
      quantization: 'GGML FP16',
      framework: 'Whisper.cpp',
      sizeMB: 75,
      fileName: 'ggml-tiny.bin',
      sha256: '',
      downloadUrl: 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin',
      tiers: {DeviceTier.lite},
      category: 'asr',
    ),

    // ── Planner LLM (Infosys: "small function-calling capable model") ─────────
    // Gemma 3 1B (.task for MediaPipe / flutter_gemma). Hosted on Hugging Face
    // under a gated Google repo — requires the user to accept the license and
    // supply an HF token, so it is flagged requiresAuth.
    ModelEntry(
      id: 'gemma3_1b_int4',
      name: 'Gemma 3 1B (INT4)',
      description: 'On-device planner LLM — routes queries to agents, works offline',
      quantization: 'INT4 (.task)',
      framework: 'MediaPipe LLM Inference',
      sizeMB: 555,
      fileName: 'gemma3-1b-it-int4.task',
      sha256: '',
      downloadUrl: 'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/gemma3-1b-it-int4.task',
      requiresAuth: true,
      tiers: {DeviceTier.full, DeviceTier.standard},
      category: 'llm',
    ),
    // TinyLlama GGUF — fully public, no auth.
    ModelEntry(
      id: 'tinyllama_int4',
      name: 'TinyLlama 1.1B (INT4)',
      description: 'Ultra-compact planner for Lite mode devices',
      quantization: 'INT4 GGUF (Q4_K_M)',
      framework: 'llama.cpp via FFI',
      sizeMB: 638,
      fileName: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      sha256: '',
      downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      tiers: {DeviceTier.lite},
      category: 'llm',
    ),

    // ── NLU/NER: MobileBERT (Infosys: "BERT-style model for intent + entity") ─
    ModelEntry(
      id: 'mobilebert_int8',
      name: 'MobileBERT NLU (INT8)',
      description: 'Intent classification + Named Entity Recognition — pilgrim domain',
      quantization: 'INT8 ONNX (8-bit)',
      framework: 'ONNX Runtime Mobile',
      sizeMB: 25,
      fileName: 'mobilebert_nlu_pilgrim_int8.onnx',
      sha256: '',
      // Domain-fine-tuned model: no public URL. Must be supplied manually.
      downloadUrl: null,
      tiers: {DeviceTier.full, DeviceTier.standard, DeviceTier.lite},
      category: 'nlu',
    ),

    // ── Embeddings: MiniLM (Infosys: "multilingual sentence-embedding model") ─
    ModelEntry(
      id: 'minilm_fp16',
      name: 'MiniLM-L12 Embeddings (FP16)',
      description: 'Multilingual semantic search — 6 Indian + English languages',
      quantization: 'FP16 ONNX (16-bit)',
      framework: 'ONNX Runtime Mobile',
      sizeMB: 85,
      fileName: 'paraphrase-multilingual-minilm-l12-v2-fp16.onnx',
      sha256: '',
      downloadUrl: null, // no pinned public ONNX export; supply manually
      tiers: {DeviceTier.full},
      category: 'embed',
    ),
    ModelEntry(
      id: 'minilm_int8',
      name: 'MiniLM-L12 Embeddings (INT8)',
      description: 'Quantized multilingual semantic search — compact version',
      quantization: 'INT8 ONNX (8-bit)',
      framework: 'ONNX Runtime Mobile',
      sizeMB: 43,
      fileName: 'paraphrase-multilingual-minilm-l12-v2-int8.onnx',
      sha256: '',
      downloadUrl: null, // no pinned public ONNX export; supply manually
      tiers: {DeviceTier.standard, DeviceTier.lite},
      category: 'embed',
    ),

    // ── TTS: Coqui/MMS (Infosys: "open multilingual TTS for regional languages")
    ModelEntry(
      id: 'mms_tts_hin',
      name: 'MMS-TTS Hindi (optional)',
      description: 'Optional neural Hindi voice. Not active by default — the app '
          'uses the on-device platform TTS engine unless this is supplied.',
      quantization: 'INT8',
      framework: 'Meta MMS-TTS',
      sizeMB: 37,
      fileName: 'mms_tts_hin_int8.onnx',
      sha256: '',
      downloadUrl: null, // optional neural TTS; platform TTS is used by default
      tiers: {DeviceTier.full, DeviceTier.standard, DeviceTier.lite},
      category: 'tts',
    ),
    ModelEntry(
      id: 'mms_tts_tel',
      name: 'MMS-TTS Telugu (optional)',
      description: 'Optional neural Telugu voice. Not active by default — the app '
          'uses the on-device platform TTS engine unless this is supplied.',
      quantization: 'INT8',
      framework: 'Meta MMS-TTS',
      sizeMB: 37,
      fileName: 'mms_tts_tel_int8.onnx',
      sha256: '',
      downloadUrl: null, // optional neural TTS; platform TTS is used by default
      tiers: {DeviceTier.full, DeviceTier.standard, DeviceTier.lite},
      category: 'tts',
    ),

    // ── Offline Maps: MBTiles ────────────────────────────────────────────────
    ModelEntry(
      id: 'mbtiles_full',
      name: 'Kumbh Mela Maps (Full)',
      description: 'Prayagraj region offline maps with all routes — flutter_map tiles',
      quantization: 'Lossless vector',
      framework: 'MBTiles + Valhalla',
      sizeMB: 320,
      fileName: 'kumbh_prayagraj_full.mbtiles',
      sha256: '',
      downloadUrl: null, // generated offline tiles; supply manually
      tiers: {DeviceTier.full, DeviceTier.standard},
      category: 'map',
    ),
    ModelEntry(
      id: 'mbtiles_lite',
      name: 'Kumbh Mela Maps (Lite)',
      description: 'Core event area offline maps — reduced resolution',
      quantization: 'Compressed vector',
      framework: 'MBTiles + Valhalla',
      sizeMB: 180,
      fileName: 'kumbh_prayagraj_lite.mbtiles',
      sha256: '',
      downloadUrl: null, // generated offline tiles; supply manually
      tiers: {DeviceTier.lite},
      category: 'map',
    ),

    // ── Structured Data: SQLite ──────────────────────────────────────────────
    ModelEntry(
      id: 'event_db',
      name: 'Event & Transport DB',
      description: 'Bus schedules, accommodation, advisories — offline SQLite',
      quantization: 'SQLite compressed',
      framework: 'sqflite',
      sizeMB: 42,
      fileName: 'pathsaathi_events.db',
      sha256: '',
      downloadUrl: null, // built + seeded on-device by AppDatabase (sqflite)
      tiers: {DeviceTier.full, DeviceTier.standard, DeviceTier.lite},
      category: 'data',
    ),
  ];

  /// Returns models for a given tier (no duplicates)
  static List<ModelEntry> forTier(DeviceTier tier) =>
      all.where((m) => m.tiers.contains(tier)).toList();

  /// Total download size for a tier in MB
  static int totalSizeMB(DeviceTier tier) =>
      forTier(tier).fold(0, (sum, m) => sum + m.sizeMB);

  /// Category icons
  static String categoryIcon(String cat) {
    const icons = {
      'asr':  '🎙',
      'llm':  '🧠',
      'nlu':  '🔍',
      'embed':'📐',
      'tts':  '🔊',
      'map':  '🗺',
      'data': '📊',
    };
    return icons[cat] ?? '📦';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Model Manager Service
// Tracks download state, verifies integrity, manages disk space
// ─────────────────────────────────────────────────────────────────────────────
class ModelManager {
  static final Map<String, bool> _downloaded = {};
  static final Map<String, double> _progress = {};

  /// Returns true ONLY if the model file exists AND passes integrity
  /// verification (real size + optional sha256). This is intentionally strict:
  /// a leftover placeholder/partial file must NOT count as "downloaded".
  static Future<bool> isDownloaded(ModelEntry model) async {
    final ok = await verifyIntegrity(model);
    _downloaded[model.id] = ok;
    return ok;
  }

  /// Progress 0.0–1.0 for ongoing downloads
  static double progressOf(String modelId) => _progress[modelId] ?? 0.0;

  /// Get local path for model file
  static Future<File> _modelFile(ModelEntry model) async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models/${model.category}');
    await modelsDir.create(recursive: true);
    return File('${modelsDir.path}/${model.fileName}');
  }

  /// Verify integrity of a downloaded model file — honestly.
  ///
  ///  • File must exist.
  ///  • File must be at least [ModelEntry.minValidBytes] (rejects the old
  ///    placeholder text files and truncated/partial downloads).
  ///  • If a real sha256 is pinned (non-empty), the file's hash must match it.
  ///  • If no sha256 is pinned, the size floor is the best available honest
  ///    check (we do NOT pretend a hash matched).
  static Future<bool> verifyIntegrity(ModelEntry model) async {
    final file = await _modelFile(model);
    if (!await file.exists()) return false;

    final len = await file.length();
    if (len < model.minValidBytes) {
      // Too small to be the real model (e.g. a placeholder token or partial).
      return false;
    }

    final pinned = model.sha256.trim();
    if (pinned.isEmpty) {
      // No pinned hash available; size floor passed → accept as plausibly real.
      return true;
    }
    // Real hash pinned → must match exactly. Never accept 'placeholder'.
    if (pinned.startsWith('placeholder')) return false;
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    return hash == pinned;
  }

  /// Download a model with progress callback
  static Future<void> download(
    ModelEntry model, {
    required void Function(double progress) onProgress,
    required void Function() onDone,
    required void Function(String error) onError,
  }) async {
    final file = await _modelFile(model);

    // No fabricated fallback. If there is no real source, tell the truth.
    if (!model.isAutoDownloadable) {
      _downloaded[model.id] = false;
      onError(model.requiresAuth
          ? '${model.name} requires signing in / accepting the model license, '
              'so it cannot be downloaded automatically. Provide the file manually.'
          : '${model.name} has no automatic download source. '
              'Provide the "${model.fileName}" file manually.');
      return;
    }

    final tmp = File('${file.path}.part');
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 30),
      ));
      // Download to a temp file first so a failed/partial download never
      // masquerades as a finished model.
      await dio.download(
        model.downloadUrl!,
        tmp.path,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final p = received / total;
            _progress[model.id] = p;
            onProgress(p);
          }
        },
      );

      // Atomically move into place, then verify honestly.
      if (await file.exists()) await file.delete();
      await tmp.rename(file.path);

      final ok = await verifyIntegrity(model);
      if (!ok) {
        if (await file.exists()) await file.delete();
        _downloaded[model.id] = false;
        onError('${model.name} downloaded but failed verification '
            '(unexpected size/hash). The file was removed.');
        return;
      }

      _downloaded[model.id] = true;
      _progress[model.id] = 1.0;
      await _saveDownloaded(model.id);
      onDone();
    } catch (e) {
      // Clean up any partial artifacts — never leave a fake "ready" file.
      try { if (await tmp.exists()) await tmp.delete(); } catch (_) {}
      _downloaded[model.id] = false;
      onError('Download failed for ${model.name}. '
          'Check your connection and free storage, then retry.');
    }
  }

  static Future<void> _saveDownloaded(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('downloaded_models') ?? [];
    if (!list.contains(modelId)) {
      list.add(modelId);
      await prefs.setStringList('downloaded_models', list);
    }
  }

  /// Rehydrate the download cache from prefs, but RE-VERIFY each file on disk so
  /// a stale prefs entry (file deleted, or an old placeholder) never reports as
  /// downloaded. Prefs is a hint; the file + integrity check is the truth.
  static Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('downloaded_models') ?? [];
    final stillValid = <String>[];
    for (final id in list) {
      ModelEntry? entry;
      for (final m in ModelCatalog.all) {
        if (m.id == id) { entry = m; break; }
      }
      if (entry == null) continue;
      final ok = await verifyIntegrity(entry);
      _downloaded[id] = ok;
      if (ok) stillValid.add(id);
    }
    // Prune prefs entries whose files no longer verify.
    if (stillValid.length != list.length) {
      await prefs.setStringList('downloaded_models', stillValid);
    }
  }

  /// Total disk used by downloaded models in MB
  static Future<int> diskUsedMB() async {
    final dir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${dir.path}/models');
    if (!await modelsDir.exists()) return 0;
    int total = 0;
    await for (final entity in modelsDir.list(recursive: true)) {
      if (entity is File) {
        final stat = await entity.stat();
        total += stat.size;
      }
    }
    return total ~/ (1024 * 1024);
  }
}

// Riverpod provider — exposes tier for UI
final modelManagerProvider = Provider<ModelManager>((ref) => ModelManager());
