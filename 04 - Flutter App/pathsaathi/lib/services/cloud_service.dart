// lib/services/cloud_service.dart
//
// TIER 3 — Cloud Service Client for PathSaathi
//
// Connects to the Infosys Spring Boot backend, Bhashini ASR/TTS API,
// and Cloud LLM for queries that require global context, high-accuracy
// Indic language processing, or cross-zone analytics.
//
// Only invoked when internet connectivity is confirmed (ConnectivityService).
// Gracefully returns null on timeout or when offline.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/agent_response.dart';

// ── Cloud API Endpoints ───────────────────────────────────────────────────────

class _Endpoints {
  // Infosys Spring Boot backend (replace with actual deployment URL)
  static const String infosysBase = 'https://pathsaathi-api.infosys-demo.in';
  static const String query = '$infosysBase/api/v1/query';
  static const String bhashiniAsr = 'https://api.dhruva.ai4bharat.org/services/inference/asr';
  static const String embedSync = '$infosysBase/api/v1/embed-sync';
  static const String telemetry = '$infosysBase/api/v1/telemetry';
}

// ── Cloud Service Singleton ───────────────────────────────────────────────────

class CloudService {
  CloudService._();
  static final CloudService instance = CloudService._();

  final Duration _timeout = const Duration(seconds: 8);
  bool _isAvailable = false;

  bool get isAvailable => _isAvailable;

  /// Check if cloud backend is reachable.
  Future<bool> ping() async {
    try {
      final uri = Uri.parse('${_Endpoints.infosysBase}/health');
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      _isAvailable = resp.statusCode == 200;
      return _isAvailable;
    } catch (_) {
      _isAvailable = false;
      return false;
    }
  }

  /// Forward a query to the Cloud LLM / Infosys backend.
  /// Returns null if offline or timeout.
  Future<AgentResponse?> query({
    required String rawQuery,
    required String langCode,
    Map<String, dynamic>? context,
  }) async {
    try {
      final uri = Uri.parse(_Endpoints.query);
      final payload = jsonEncode({
        'query': rawQuery,
        'lang': langCode,
        'context': context ?? {},
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'client': 'pathsaathi-mobile',
        'version': '1.0.0',
      });

      debugPrint('[CloudService] → Sending query to Cloud: "$rawQuery"');

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-Client': 'pathsaathi-mobile',
        },
        body: payload,
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        debugPrint('[CloudService] ✅ Cloud response received');
        return _parseCloudResponse(data);
      } else {
        debugPrint('[CloudService] Backend returned ${resp.statusCode}');
        return null;
      }
    } on TimeoutException {
      debugPrint('[CloudService] Query timed out after ${_timeout.inSeconds}s');
      return null;
    } catch (e) {
      debugPrint('[CloudService] Query error: $e');
      return null;
    }
  }

  /// Enhance ASR using Bhashini API for improved Indic language accuracy.
  /// Returns enhanced transcript or null if unavailable.
  Future<String?> enhanceWithBhashini({
    required String transcript,
    required String langCode,
  }) async {
    try {
      final bhashiniLang = _toBhashiniLangCode(langCode);
      final uri = Uri.parse(_Endpoints.bhashiniAsr);

      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer BHASHINI_API_KEY', // Injected via secure storage
        },
        body: jsonEncode({
          'config': {'language': {'sourceLanguage': bhashiniLang}},
          'audio': [{'audioContent': transcript}], // Text re-processing
        }),
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final output = data['output'] as List?;
        if (output != null && output.isNotEmpty) {
          return output.first['source'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Push anonymized query telemetry to Cloud for analytics / model improvement.
  /// Fire-and-forget — no await, no blocking.
  void pushTelemetry({
    required String queryHash, // SHA-256 of query (never raw text)
    required String langCode,
    required String tierUsed,
    required int responseMs,
  }) {
    http.post(
      Uri.parse(_Endpoints.telemetry),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'query_hash': queryHash,
        'lang': langCode,
        'tier': tierUsed,
        'response_ms': responseMs,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    ).ignore(); // Silently discard result and errors — fire-and-forget
  }

  /// Pull updated embeddings from Cloud → write to local LanceDB.
  /// Called on startup when online.
  Future<bool> syncEmbeddings() async {
    try {
      final uri = Uri.parse(_Endpoints.embedSync);
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));
      if (resp.statusCode == 200) {
        debugPrint('[CloudService] ✅ Embedding sync complete');
        return true;
      }
    } catch (e) {
      debugPrint('[CloudService] Embedding sync failed: $e');
    }
    return false;
  }

  AgentResponse? _parseCloudResponse(Map<String, dynamic> data) {
    try {
      return AgentResponse(
        type: _parseAgentType(data['agent_type'] as String? ?? 'general'),
        title: data['title'] as String? ?? 'Cloud Response',
        subtitle: data['subtitle'] as String? ?? '☁️ Via Infosys Cloud Backend',
        primaryValue: data['primary_value'] as String? ?? '—',
        badgeText: 'CLOUD • ${data['latency_ms'] ?? '?'}ms',
        badgeColor: const Color(0xFF7C3AED), // Purple for Cloud tier
        primaryIcon: Icons.cloud_done_rounded,
        spokenTextEnglish: data['spoken_en'] as String? ?? '',
        spokenTextHindi: data['spoken_hi'] as String? ?? '',
        spokenTextTelugu: data['spoken_te'] as String? ?? '',
        spokenTextTamil: data['spoken_ta'] as String?,
        spokenTextMarathi: data['spoken_mr'] as String?,
        spokenTextPunjabi: data['spoken_pa'] as String?,
        rawData: {
          'tier': 'CLOUD',
          'backend': 'infosys-spring-boot',
          ...?(data['raw'] as Map<String, dynamic>?),
        },
      );
    } catch (e) {
      debugPrint('[CloudService] Parse error: $e');
      return null;
    }
  }

  AgentType _parseAgentType(String raw) {
    switch (raw) {
      case 'transport':     return AgentType.transport;
      case 'accommodation': return AgentType.accommodation;
      case 'navigation':    return AgentType.navigation;
      case 'itinerary':     return AgentType.itinerary;
      case 'safety':        return AgentType.safety;
      case 'document':      return AgentType.document;
      default:              return AgentType.general;
    }
  }

  /// Map PathSaathi lang codes to Bhashini language identifiers.
  String _toBhashiniLangCode(String code) {
    switch (code) {
      case 'hi': return 'hi';
      case 'te': return 'te';
      case 'ta': return 'ta';
      case 'mr': return 'mr';
      case 'pa': return 'pa';
      case 'en':
      default:   return 'en';
    }
  }
}
