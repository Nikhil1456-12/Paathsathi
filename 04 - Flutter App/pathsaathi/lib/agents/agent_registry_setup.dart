// lib/agents/agent_registry_setup.dart
//
// Adapters that expose each existing specialist singleton through the common
// [PathSaathiAgent] interface, plus the one-call wiring that registers the
// full swarm. Keeping the adapters thin means the planner dispatches
// polymorphically while the agents' own logic is untouched.

import '../models/agent_response.dart';
import 'agent.dart';
import 'transport_agent.dart';
import 'navigation_agent.dart';
import 'accommodation_agent.dart';
import 'itinerary_agent.dart';
import 'safety_agent.dart';

class _TransportAgentAdapter implements PathSaathiAgent {
  @override
  String get name => 'transport';
  @override
  bool canHandle(Intent i) => i.kind == 'transport';
  @override
  Future<AgentResponse> handle(Intent i) =>
      TransportAgent.instance.processQuery(destination: i.place);
}

class _NavigationAgentAdapter implements PathSaathiAgent {
  @override
  String get name => 'navigation';
  @override
  bool canHandle(Intent i) => i.kind == 'navigation';
  @override
  Future<AgentResponse> handle(Intent i) => NavigationAgent.instance
      .processQuery(destination: i.place ?? 'Sangam Ghat');
}

class _AccommodationAgentAdapter implements PathSaathiAgent {
  @override
  String get name => 'accommodation';
  @override
  bool canHandle(Intent i) => i.kind == 'accommodation';
  @override
  Future<AgentResponse> handle(Intent i) => AccommodationAgent.instance
      .processQuery(listAll: i.slots['listAll'] == true, destination: i.place);
}

class _ItineraryAgentAdapter implements PathSaathiAgent {
  @override
  String get name => 'itinerary';
  @override
  bool canHandle(Intent i) => i.kind == 'itinerary';
  @override
  Future<AgentResponse> handle(Intent i) =>
      ItineraryAgent.instance.processQuery(destination: i.place);
}

class _SafetyAgentAdapter implements PathSaathiAgent {
  @override
  String get name => 'safety';
  @override
  bool canHandle(Intent i) => i.kind == 'safety';
  @override
  Future<AgentResponse> handle(Intent i) => SafetyAgent.instance
      .processQuery(emergencyType: i.slots['emergencyType'] ?? 'medical');
}

/// Register the specialist swarm. Call once at startup (idempotent).
void registerPathSaathiAgents() {
  AgentRegistry.instance.register([
    _TransportAgentAdapter(),
    _NavigationAgentAdapter(),
    _AccommodationAgentAdapter(),
    _ItineraryAgentAdapter(),
    _SafetyAgentAdapter(),
  ]);
}
