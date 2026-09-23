import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

/// On-device MobileBERT NLU service using ONNX Runtime.
/// Classifies pilgrim queries into intents for agent routing.
/// Falls back to keyword matching when model is not downloaded.
class NluService {
  NluService._();
  static final NluService instance = NluService._();

  static const String modelFileName = 'mobilebert_nlu_pilgrim_int8.onnx';
  static const int modelSizeMB = 25;

  OrtSession? _session;
  bool _isReady = false;
  bool get isModelReady => _isReady;

  static const _intentLabels = [
    'findTransport',
    'findNavigation',
    'findAccommodation',
    'getItinerary',
    'getEmergency',
    'uploadDocument',
    'unknown',
  ];

  Future<String> get _modelPath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/models/nlu/$modelFileName';
  }

  Future<bool> initialize() async {
    try {
      final path = await _modelPath;
      if (!await File(path).exists()) {
        _isReady = false;
        return false;
      }
      OrtEnv.instance.init();
      final opts = OrtSessionOptions();
      _session = OrtSession.fromFile(File(path), opts);
      _isReady = true;
      debugPrint('[NluService] MobileBERT loaded');
      return true;
    } catch (e) {
      debugPrint('[NluService] Init error: $e');
      _isReady = false;
      return false;
    }
  }

  /// Classify intent from user query.
  /// Returns one of the _intentLabels strings.
  Future<String> classify(String query) async {
    if (!_isReady || _session == null) return _keywordFallback(query);
    try {
      // Simple word-level tokenization (replace with full tokenizer in prod)
      final tokens = _tokenize(query);
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        Int64List.fromList(tokens),
        [1, tokens.length],
      );
      final feeds = {'input_ids': inputTensor};
      final outputs = _session!.run(OrtRunOptions(), feeds);
      inputTensor.release();

      // Extract argmax from logits
      final logits = outputs.first?.value;
      int maxIdx = 0;
      if (logits is List && logits.isNotEmpty) {
        final inner = logits[0];
        if (inner is List<double> && inner.isNotEmpty) {
          double maxVal = inner[0];
          for (int i = 1; i < inner.length; i++) {
            if (inner[i] > maxVal) {
              maxVal = inner[i];
              maxIdx = i;
            }
          }
        }
      }
      for (final o in outputs) {
        o?.release();
      }

      return _intentLabels[maxIdx.clamp(0, _intentLabels.length - 1)];
    } catch (e) {
      debugPrint('[NluService] Classify error: $e');
      return _keywordFallback(query);
    }
  }

  /// Simple hash-based tokenizer (stub — use BPE in production)
  List<int> _tokenize(String text) {
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    return words
        .map((w) => w.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) % 30000))
        .toList();
  }

  /// Multilingual keyword fallback (Hindi / Telugu / English)
  String _keywordFallback(String q) {
    final lower = q.toLowerCase();
    // Transport
    if (lower.contains('bus') || lower.contains('train') ||
        lower.contains('बस') || lower.contains('రైలు') ||
        lower.contains('ट्रेन') || lower.contains('schedule') ||
        lower.contains('departure') || lower.contains('gate')) {
      return 'findTransport';
    }
    // Navigation / Where
    if (lower.contains('where') || lower.contains('map') ||
        lower.contains('navigate') || lower.contains('direction') ||
        lower.contains('कहाँ') || lower.contains('ఎక్కడ') ||
        lower.contains('रास్ता') || lower.contains('దారి')) {
      return 'findNavigation';
    }
    // Accommodation
    if (lower.contains('camp') || lower.contains('tent') ||
        lower.contains('stay') || lower.contains('hotel') ||
        lower.contains('तंबू') || lower.contains('క్యాంప్') ||
        lower.contains('शिविर') || lower.contains('accommodation')) {
      return 'findAccommodation';
    }
    // Itinerary / Schedule
    if (lower.contains('aarti') || lower.contains('schedule') ||
        lower.contains('snan') || lower.contains('program') ||
        lower.contains('आरती') || lower.contains('హారతి') ||
        lower.contains('स्नान') || lower.contains('itinerary')) {
      return 'getItinerary';
    }
    // Emergency / Safety
    if (lower.contains('doctor') || lower.contains('emergency') ||
        lower.contains('police') || lower.contains('help') ||
        lower.contains('डॉक्टर') || lower.contains('అత్యవసర') ||
        lower.contains('hospital') || lower.contains('ambulance')) {
      return 'getEmergency';
    }
    // Document
    if (lower.contains('document') || lower.contains('aadhaar') ||
        lower.contains('passport') || lower.contains('दस्तावेज')) {
      return 'uploadDocument';
    }
    return 'unknown';
  }

  void dispose() {
    _session?.release();
    _session = null;
    _isReady = false;
  }
}
