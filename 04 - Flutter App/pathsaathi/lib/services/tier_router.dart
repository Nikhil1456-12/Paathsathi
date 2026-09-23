// lib/services/tier_router.dart
//
// Central 3-Tier Router for PathSaathi
//
// Dispatches queries through four tiers in priority order:
//
//   Tier 0 — OfflineIntentCache    (<1ms, pattern-match hot queries)
//   Tier 2 — FogService            (<50ms LAN, LangGraph multi-agent)
//   Tier 1 — On-Device Agents      (existing IntentPlanner)
//   Tier 3 — CloudService          (internet-only, Bhashini/Cloud LLM)
//
// Each tier returns null on miss/timeout → next tier is tried automatically.
// Exposes `lastActiveTier` for UI badge rendering.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_response.dart';
import '../agents/intent_planner.dart';
import 'offline_intent_cache.dart';
import 'semantic_search_service.dart';
import 'fog_service.dart';
import 'cloud_service.dart';
import 'connectivity_service.dart';

// ── Tier Enum ─────────────────────────────────────────────────────────────────

enum QueryTier {
  cache,     // Tier 0: OfflineIntentCache
  fog,       // Tier 2: Fog Edge Node (LangGraph)
  onDevice,  // Tier 1: On-Device Agents (IntentPlanner)
  cloud,     // Tier 3: Cloud (Bhashini / Infosys backend)
}

extension QueryTierX on QueryTier {
  String get label {
    switch (this) {
      case QueryTier.cache:    return 'CACHE';
      case QueryTier.fog:      return 'EDGE';
      case QueryTier.onDevice: return 'ON-DEVICE';
      case QueryTier.cloud:    return 'CLOUD';
    }
  }

  String get emoji {
    switch (this) {
      case QueryTier.cache:    return '🟣';
      case QueryTier.fog:      return '🟠';
      case QueryTier.onDevice: return '🟢';
      case QueryTier.cloud:    return '☁️';
    }
  }

  /// Human-readable description for the Fog Dashboard.
  String get description {
    switch (this) {
      case QueryTier.cache:
        return 'Served from on-device hot-pattern cache in <1ms';
      case QueryTier.fog:
        return 'Served by Fog Edge Node (LangGraph multi-agent, Chroma vector DB)';
      case QueryTier.onDevice:
        return 'Served by on-device agents (Gemma LLM / MobileBERT / Keyword)';
      case QueryTier.cloud:
        return 'Served by Cloud backend (Bhashini + Infosys Spring Boot)';
    }
  }
}

// ── Router Singleton ──────────────────────────────────────────────────────────

class TierRouter {
  TierRouter._();
  static final TierRouter instance = TierRouter._();

  QueryTier _lastTier = QueryTier.onDevice;
  int _lastResponseMs = 0;
  int _totalQueries = 0;

  // Tier hit counters (for Fog Dashboard analytics)
  final Map<QueryTier, int> _tierHits = {
    QueryTier.cache:    0,
    QueryTier.fog:      0,
    QueryTier.onDevice: 0,
    QueryTier.cloud:    0,
  };

  QueryTier get lastActiveTier => _lastTier;
  int get lastResponseMs => _lastResponseMs;
  int get totalQueries => _totalQueries;
  Map<QueryTier, int> get tierHits => Map.unmodifiable(_tierHits);

  /// Route a query through all tiers. Always returns a valid AgentResponse.
  Future<AgentResponse> route({
    required String rawQuery,
    required String langCode,
    String? zoneId,
  }) async {
    _totalQueries++;
    final sw = Stopwatch()..start();

    debugPrint('[TierRouter] Routing: "$rawQuery" (lang=$langCode)');

    // ── Tier 0: Offline Intent Cache ────────────────────────────
    final cached = OfflineIntentCache.instance.lookup(rawQuery);
    if (cached != null) {
      _record(QueryTier.cache, sw);
      debugPrint('[TierRouter] ✅ Cache hit in ${sw.elapsedMilliseconds}ms');
      return cached;
    }
    debugPrint('[TierRouter] Cache miss → trying semantic search');

    // ── Tier 0.5: Offline semantic search over the advisory/FAQ corpus ─────
    // Catches free-form questions the exact-pattern cache missed but which map
    // to a KNOWN offline answer (no fabrication; null when not confident).
    final semantic = SemanticSearchService.instance.search(rawQuery);
    if (semantic != null) {
      _record(QueryTier.cache, sw); // still an on-device, no-network tier
      debugPrint('[TierRouter] ✅ Semantic (${semantic.method}) '
          'score=${semantic.score.toStringAsFixed(2)} in ${sw.elapsedMilliseconds}ms');
      return semantic.doc.answer;
    }
    debugPrint('[TierRouter] Semantic miss → trying Fog');

    // ── Tier 2: Fog Edge Node (tried before on-device for richer context) ──
    final connectivity = ConnectivityService.instance.status;
    if (connectivity != ConnectivityStatus.offline) {
      // Try Fog even on degraded/mobile — LAN is local, doesn't use internet
      final fogResponse = await FogService.instance.query(
        rawQuery: rawQuery,
        langCode: langCode,
        zoneId: zoneId,
      );
      if (fogResponse != null) {
        _record(QueryTier.fog, sw);
        debugPrint('[TierRouter] ✅ Fog hit in ${sw.elapsedMilliseconds}ms');
        return fogResponse;
      }
    }
    debugPrint('[TierRouter] Fog miss → trying On-Device');

    // ── Tier 1: On-Device IntentPlanner ─────────────────────────
    // This always succeeds (keyword fallback ensures it)
    final onDeviceResponse = await IntentPlanner.instance.planAndExecute(rawQuery);
    _record(QueryTier.onDevice, sw);

    // ── Tier 3: Cloud enhancement (if online and response is generic) ────
    if (connectivity == ConnectivityStatus.online &&
        onDeviceResponse.type == AgentType.general) {
      debugPrint('[TierRouter] On-device returned general → trying Cloud enrichment');
      final cloudResponse = await CloudService.instance.query(
        rawQuery: rawQuery,
        langCode: langCode,
      );
      if (cloudResponse != null) {
        _record(QueryTier.cloud, sw);
        debugPrint('[TierRouter] ✅ Cloud enrichment in ${sw.elapsedMilliseconds}ms');
        return cloudResponse;
      }
    }

    debugPrint('[TierRouter] ✅ On-Device in ${sw.elapsedMilliseconds}ms');
    return onDeviceResponse;
  }

  void _record(QueryTier tier, Stopwatch sw) {
    sw.stop();
    _lastTier = tier;
    _lastResponseMs = sw.elapsedMilliseconds;
    _tierHits[tier] = (_tierHits[tier] ?? 0) + 1;
  }

  /// Percentage of queries served by each tier (for dashboard pie chart).
  double tierHitRate(QueryTier tier) {
    if (_totalQueries == 0) return 0.0;
    return (_tierHits[tier] ?? 0) / _totalQueries;
  }

  /// Reset statistics (e.g., on new session).
  void resetStats() {
    _totalQueries = 0;
    _tierHits.updateAll((_, __) => 0);
  }

  /// Trigger background Fog node discovery and Cloud ping.
  /// Call once on app startup.
  Future<void> initialize() async {
    debugPrint('[TierRouter] Initializing — probing Fog and Cloud...');
    await Future.wait([
      FogService.instance.discoverFogNode(),
      CloudService.instance.ping(),
    ]);
    debugPrint(
      '[TierRouter] Fog: ${FogService.instance.status.name} | '
      'Cloud: ${CloudService.instance.isAvailable}',
    );
  }
}

// ── Riverpod Providers ────────────────────────────────────────────────────────

/// Exposes the last active tier for UI badge rendering.
/// Widgets use [ref.watch(activeTierProvider)] to rebuild on tier changes.
final activeTierProvider = StateProvider<QueryTier>((ref) => QueryTier.onDevice);

/// Exposes Fog connectivity status for the tier indicator.
final fogStatusProvider = StateProvider<FogStatus>((ref) => FogStatus.unreachable);

/// Exposes Cloud availability for the tier indicator.
final cloudAvailableProvider = StateProvider<bool>((ref) => false);
