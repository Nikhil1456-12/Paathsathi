// lib/agents/agent_orchestrator.dart
//
// Central Orchestrator for PathSaathi
//
// Routes all user queries through the 3-Tier TierRouter:
//   Tier 0: OfflineIntentCache (<1ms hot patterns)
//   Tier 2: Fog Edge Node (LangGraph + Chroma, LAN-only)
//   Tier 1: On-Device Agents (Gemma LLM / MobileBERT / Keyword)
//   Tier 3: Cloud (Bhashini + Infosys backend, internet-only)
//
// After routing, updates activeTierProvider so the UI badge reacts instantly.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent_response.dart';
import 'transport_agent.dart';
import '../services/tier_router.dart';
import '../providers/language_provider.dart';

class OrchestratorState {
  final String currentQuery;
  final bool isProcessing;
  final AgentResponse? latestResponse;
  final QueryTier? lastTier;
  final int? lastResponseMs;

  const OrchestratorState({
    this.currentQuery = '',
    this.isProcessing = false,
    this.latestResponse,
    this.lastTier,
    this.lastResponseMs,
  });

  OrchestratorState copyWith({
    String? currentQuery,
    bool? isProcessing,
    AgentResponse? latestResponse,
    QueryTier? lastTier,
    int? lastResponseMs,
  }) {
    return OrchestratorState(
      currentQuery: currentQuery ?? this.currentQuery,
      isProcessing: isProcessing ?? this.isProcessing,
      latestResponse: latestResponse ?? this.latestResponse,
      lastTier: lastTier ?? this.lastTier,
      lastResponseMs: lastResponseMs ?? this.lastResponseMs,
    );
  }
}

class OrchestratorNotifier extends StateNotifier<OrchestratorState> {
  OrchestratorNotifier(this._ref) : super(const OrchestratorState());

  final Ref _ref;

  Future<AgentResponse> processUserQuery(String query) async {
    state = state.copyWith(currentQuery: query, isProcessing: true);

    // ── Get the selected language code for tier routing ────────────
    final langCode = _ref.read(languageProvider).code;

    // ── Route through 3-Tier system ────────────────────────────────
    final response = await TierRouter.instance.route(
      rawQuery: query,
      langCode: langCode,
    );

    // ── Update tier badge provider for UI ──────────────────────────
    final activeTier = TierRouter.instance.lastActiveTier;
    _ref.read(activeTierProvider.notifier).state = activeTier;

    state = state.copyWith(
      isProcessing: false,
      latestResponse: response,
      lastTier: activeTier,
      lastResponseMs: TierRouter.instance.lastResponseMs,
    );

    return response;
  }

  Future<void> setDefaultResponse() async {
    final defaultResp = await TransportAgent.instance.processQuery();
    state = state.copyWith(
      currentQuery: 'Bus to Sangam',
      latestResponse: defaultResp,
      lastTier: QueryTier.onDevice,
    );
  }
}

final orchestratorProvider =
    StateNotifierProvider<OrchestratorNotifier, OrchestratorState>((ref) {
  return OrchestratorNotifier(ref);
});
