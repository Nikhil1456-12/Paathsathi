// lib/agents/fog/lost_found_agent.dart
//
// Fog Tier — Lost & Found Agent
//
// On the Fog node, this agent queries the Chroma vector DB
// with phonetic cross-device pilgrim registry lookups.
// On mobile (offline fallback), provides the protocol steps
// and helpline numbers without Chroma access.

import 'package:flutter/foundation.dart';

// ── Lost Person Report Model ──────────────────────────────────────────────────

class LostPersonReport {
  final String id;
  final String name;
  final String? namePhonetic;     // Transliterated for cross-language match
  final int? ageYears;
  final String? clothingDescription;
  final String? lastSeenZone;
  final DateTime reportedAt;
  final String reportedByPhone;
  final String status;            // 'open' | 'found' | 'reunited'

  const LostPersonReport({
    required this.id,
    required this.name,
    this.namePhonetic,
    this.ageYears,
    this.clothingDescription,
    this.lastSeenZone,
    required this.reportedAt,
    required this.reportedByPhone,
    this.status = 'open',
  });
}

// ── Lost & Found Agent ────────────────────────────────────────────────────────

class LostFoundAgent {
  LostFoundAgent._();
  static final LostFoundAgent instance = LostFoundAgent._();

  /// Local in-memory registry (synced from Fog node when connected).
  /// In production, Fog node uses Chroma for semantic + phonetic search.
  final List<LostPersonReport> _localRegistry = [];

  int get openCases => _localRegistry.where((r) => r.status == 'open').length;
  int get resolvedCases => _localRegistry.where((r) => r.status != 'open').length;

  /// Add a new lost person report to local registry.
  void addReport(LostPersonReport report) {
    _localRegistry.add(report);
    debugPrint('[LostFoundAgent] New report: ${report.name} (ID: ${report.id})');
  }

  // NOTE: Lost & Found queries are served by the offline intent cache; the Fog
  // Dashboard consumes `openCases`/`resolvedCases` directly. The prior
  // `buildLostResponse()` AgentResponse builder was unused and has been removed.

  /// Search local registry by name (basic substring / phonetic match).
  /// Returns matching reports (Fog node uses full Chroma vector search).
  List<LostPersonReport> searchLocal(String name) {
    final needle = name.toLowerCase();
    return _localRegistry.where((r) =>
      r.status == 'open' &&
      (r.name.toLowerCase().contains(needle) ||
       (r.namePhonetic?.toLowerCase().contains(needle) ?? false))
    ).toList();
  }
}
