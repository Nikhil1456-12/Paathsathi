// lib/agents/agent.dart
//
// The explicit "agent swarm" contract. The Infosys brief asks for "a swarm of
// specialized on-device agents coordinated by a central planner." This file
// makes that architecture LITERAL rather than aspirational:
//
//   • [Intent] is the structured task the planner produces from a spoken goal.
//   • [PathSaathiAgent] is the common interface every specialist implements.
//   • [AgentRegistry] is the dispatch layer the planner routes through.
//
// The planner (IntentPlanner) decides WHICH intent a query maps to (today via
// keywords; tomorrow via a function-calling LLM — a one-line swap at the
// planner's input). Dispatch to the right agent is polymorphic through this
// interface, not a hardcoded switch, so agents can be added/replaced without
// touching the planner.

import '../models/agent_response.dart';

/// A structured task decomposed from the user's spoken goal.
///
/// [kind] is the canonical intent label (transport, navigation, accommodation,
/// itinerary, safety, document). [place] is an optional resolved destination
/// slot. [raw] is the original user query, kept for agents that want it.
class Intent {
  final String kind;
  final String? place;
  final String raw;
  final Map<String, dynamic> slots;

  const Intent(this.kind, {this.place, this.raw = '', this.slots = const {}});

  static const unknown = Intent('unknown');

  Intent copyWith({String? kind, String? place, String? raw}) =>
      Intent(kind ?? this.kind,
          place: place ?? this.place, raw: raw ?? this.raw, slots: slots);
}

/// The contract every specialist agent implements. Coordinated by the planner.
abstract class PathSaathiAgent {
  /// Stable identifier for telemetry / the "which agent answered" indicator.
  String get name;

  /// Whether this agent can serve the given intent.
  bool canHandle(Intent intent);

  /// Produce a response for the intent. Only called when [canHandle] is true.
  Future<AgentResponse> handle(Intent intent);
}

/// The dispatch layer: holds the registered agents and routes an intent to the
/// first one that can handle it. This is the "central coordination" the brief
/// asks for, decoupled from how the intent was parsed.
class AgentRegistry {
  AgentRegistry._();
  static final AgentRegistry instance = AgentRegistry._();

  final List<PathSaathiAgent> _agents = [];

  /// Register the swarm. Order matters only for overlapping canHandle().
  void register(Iterable<PathSaathiAgent> agents) {
    _agents
      ..clear()
      ..addAll(agents);
  }

  List<PathSaathiAgent> get agents => List.unmodifiable(_agents);

  /// Route an intent to the first capable agent, or null if none applies so the
  /// caller can fall through to another tier.
  Future<AgentResponse?> dispatch(Intent intent) async {
    for (final a in _agents) {
      if (a.canHandle(intent)) return a.handle(intent);
    }
    return null;
  }
}
