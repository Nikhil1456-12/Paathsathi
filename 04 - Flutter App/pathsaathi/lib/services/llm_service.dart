import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma_interface.dart';
import 'package:path_provider/path_provider.dart';
import 'model_manager.dart';

/// On-device Gemma LLM service for agent routing.
/// Uses flutter_gemma (MediaPipe) with Gemma 1B INT4 — 100% offline.
/// Degrades gracefully: returns 'unknown' when the model is not present, so the
/// planner falls back to its keyword tier. It NEVER fabricates a model.
class LlmService {
  LlmService._();
  static final LlmService instance = LlmService._();

  static const String modelFileName = 'gemma3-1b-it-int4.task';

  bool _isReady = false;
  bool get isModelReady => _isReady;

  final FlutterGemmaPlugin _gemma = FlutterGemmaPlugin.instance;

  /// Locate the Gemma model file that ModelManager verified onto disk.
  /// Returns null if no real, verified model file is present.
  Future<String?> _verifiedModelPath() async {
    // Find the LLM catalog entry and confirm the real file passes verification.
    for (final entry in ModelCatalog.all) {
      if (entry.category != 'llm') continue;
      final ok = await ModelManager.isDownloaded(entry);
      if (!ok) continue;
      final docDir = await getApplicationDocumentsDirectory();
      final path = '${docDir.path}/models/llm/${entry.fileName}';
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<bool> initialize() async {
    try {
      // Already loaded in this process?
      if (await _gemma.isLoaded) {
        _isReady = true;
        return true;
      }
      // Load from the verified on-disk model if one exists.
      final path = await _verifiedModelPath();
      if (path == null) {
        _isReady = false; // no real model → planner uses keyword tier
        return false;
      }
      return await loadFromPath(path);
    } catch (e) {
      debugPrint('[LlmService] Init error: $e');
      _isReady = false;
      return false;
    }
  }

  /// Route query to the correct agent (single-intent convenience wrapper).
  /// Returns one of: 'transport','navigation','accommodation',
  ///                 'itinerary','safety','document','unknown'
  Future<String> routeQuery(String userQuery) async {
    final plan = await planQuery(userQuery);
    return plan.primaryIntent;
  }

  /// Decompose a spoken goal into a STRUCTURED plan: an ordered list of agent
  /// intents (the planner/orchestrator requirement — a goal can map to more
  /// than one agent task) plus any extracted destination/entity.
  ///
  /// When no real model is loaded, returns [QueryPlan.unknown] so the caller
  /// falls back to its keyword tier — this method never fabricates a plan.
  Future<QueryPlan> planQuery(String userQuery, {String dataTier = 'verified'}) async {
    if (!_isReady) return QueryPlan.unknown(userQuery, dataTier: dataTier);
    try {
      final prompt = _planPrompt(userQuery, dataTier: dataTier);
      final response = await _gemma.getResponse(prompt: prompt);
      return QueryPlan.parse(response ?? '', userQuery, dataTier: dataTier);
    } catch (e) {
      debugPrint('[LlmService] plan error: $e');
      return QueryPlan.unknown(userQuery, dataTier: dataTier);
    }
  }

  String _planPrompt(String userQuery, {String dataTier = 'verified'}) =>
      '''You are the planner for a pilgrim assistant at a large gathering (data_tier=$dataTier).
Break the user's request into one or more tasks. Reply with ONLY a comma-separated
list of task labels, in priority order, chosen from:
transport, navigation, accommodation, itinerary, safety, document
Then, if the user named a place, add "place=<name>".
Example: "book a bus and find a tent near the ghat" -> transport, accommodation, place=ghat

User request: "$userQuery"
Answer:''';

  /// Load model from local file path (call after download completes).
  Future<bool> loadFromPath(String modelPath) async {
    try {
      await _gemma.init(
        maxTokens: 256,
        temperature: 0.1,
        topK: 1,
        randomSeed: 1,
      );
      await _gemma.loadAssetModel(fullPath: modelPath);
      _isReady = true;
      return true;
    } catch (e) {
      debugPrint('[LlmService] Load error: $e');
      _isReady = false;
      return false;
    }
  }

  void reset() {
    _isReady = false;
  }
}

/// Structured result of decomposing a spoken goal into agent tasks.
class QueryPlan {
  /// Ordered agent intents (first = primary). Valid labels:
  /// transport, navigation, accommodation, itinerary, safety, document.
  final List<String> intents;

  /// Optional place/entity the user named (lowercased), or null.
  final String? place;

  /// The original query (for debugging / fallback).
  final String query;

  /// Data tier ('verified' | 'template' | 'unknown')
  final String dataTier;

  const QueryPlan({
    required this.intents,
    required this.place,
    required this.query,
    this.dataTier = 'verified',
  });

  factory QueryPlan.unknown(String query, {String dataTier = 'verified'}) =>
      QueryPlan(intents: const ['unknown'], place: null, query: query, dataTier: dataTier);

  String get primaryIntent => intents.isNotEmpty ? intents.first : 'unknown';
  bool get isMultiTask => intents.where((i) => i != 'unknown').length > 1;

  static const _valid = {
    'transport', 'navigation', 'accommodation', 'itinerary', 'safety', 'document',
  };

  /// Parse a (possibly messy) model reply into a structured plan. Only known
  /// labels are kept, de-duplicated, in first-seen order. Extracts place=... if
  /// present. Returns [QueryPlan.unknown] when nothing valid is found.
  factory QueryPlan.parse(String raw, String query, {String dataTier = 'verified'}) {
    final text = raw.toLowerCase();

    // Extract an optional place=... token.
    String? place;
    final placeMatch = RegExp(r'place\s*=\s*([^\n,;]+)').firstMatch(text);
    if (placeMatch != null) {
      final p = placeMatch.group(1)?.trim();
      if (p != null && p.isNotEmpty) place = p;
    }

    // Collect valid intent labels in the order they appear.
    final found = <String>[];
    for (final match in RegExp(r'[a-z]+').allMatches(text)) {
      final w = match.group(0)!;
      // Map a couple of natural synonyms the model might emit.
      final label = switch (w) {
        'map' || 'route' || 'directions' => 'navigation',
        'camp' || 'tent' || 'lodging' || 'hotel' => 'accommodation',
        'schedule' || 'timing' || 'aarti' => 'itinerary',
        'emergency' || 'medical' || 'sos' => 'safety',
        _ => w,
      };
      if (_valid.contains(label) && !found.contains(label)) {
        found.add(label);
      }
    }

    if (found.isEmpty) return QueryPlan.unknown(query, dataTier: dataTier);
    return QueryPlan(intents: found, place: place, query: query, dataTier: dataTier);
  }
}
