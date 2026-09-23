// lib/agents/fog/medical_sos_agent.dart
//
// Fog Tier — Medical SOS Dispatch Agent
//
// On the Fog node, this agent:
//   - Queries the nearest medical volunteer / ambulance roster in Chroma
//   - Logs the SOS case to Fog DB (batched to Cloud on reconnect)
//   - Dispatches the nearest responder via BLE broadcast
//
// On mobile (offline fallback), provides immediate first-aid protocol
// and emergency contact numbers without Chroma / Fog access.

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

// ── Medical Post Data ─────────────────────────────────────────────────────────

class MedicalPost {
  final String id;
  final String name;
  final LatLng location;
  final String zone;
  final bool has24HrDoctor;
  final bool hasAmbulance;
  final String phone;

  const MedicalPost({
    required this.id,
    required this.name,
    required this.location,
    required this.zone,
    this.has24HrDoctor = true,
    this.hasAmbulance = false,
    required this.phone,
  });
}

// ── SOS Case Model ────────────────────────────────────────────────────────────

class SosCase {
  final String id;
  final String type; // 'medical' | 'missing' | 'violence' | 'accident'
  final String reportedBy;
  final LatLng? location;
  final DateTime reportedAt;
  String status; // 'open' | 'dispatched' | 'resolved'
  String? assignedResponder;

  SosCase({
    required this.id,
    required this.type,
    required this.reportedBy,
    this.location,
    required this.reportedAt,
    this.status = 'open',
    this.assignedResponder,
  });
}

// ── Medical SOS Agent ─────────────────────────────────────────────────────────

class MedicalSosAgent {
  MedicalSosAgent._();
  static final MedicalSosAgent instance = MedicalSosAgent._();

  final List<SosCase> _activeCases = [];

  int get activeCaseCount => _activeCases.where((c) => c.status == 'open').length;

  /// Static medical posts (live data from Fog Chroma in production).
  static const List<MedicalPost> kumbhMedicalPosts = [
    MedicalPost(
      id: 'MP1',
      name: 'Medical Post 1 — Sangam Nose',
      location: LatLng(25.4365, 81.8840),
      zone: 'Z1',
      has24HrDoctor: true,
      hasAmbulance: true,
      phone: '0532-1234567',
    ),
    MedicalPost(
      id: 'MP2',
      name: 'Medical Post 2 — Sector 4',
      location: LatLng(25.4420, 81.8750),
      zone: 'Z2',
      has24HrDoctor: true,
      hasAmbulance: false,
      phone: '0532-2345678',
    ),
    MedicalPost(
      id: 'MP3',
      name: 'Medical Post 3 — Naini Bridge',
      location: LatLng(25.4380, 81.8700),
      zone: 'Z4',
      has24HrDoctor: false,
      hasAmbulance: false,
      phone: '0532-3456789',
    ),
    MedicalPost(
      id: 'MP4',
      name: 'Central Hospital — Sector 7',
      location: LatLng(25.4490, 81.8740),
      zone: 'Z3',
      has24HrDoctor: true,
      hasAmbulance: true,
      phone: '0532-4567890',
    ),
  ];

  /// Log a new SOS case to local memory.
  /// When Fog is connected, this is forwarded to the Fog node's Chroma DB
  /// and an ambulance/volunteer is dispatched via BLE broadcast.
  SosCase logCase({
    required String type,
    required String reportedBy,
    LatLng? location,
  }) {
    final id = 'SOS-${DateTime.now().millisecondsSinceEpoch}';
    final c = SosCase(
      id: id,
      type: type,
      reportedBy: reportedBy,
      location: location,
      reportedAt: DateTime.now(),
    );
    _activeCases.add(c);
    debugPrint('[MedicalSOSAgent] New case logged: $id ($type)');
    return c;
  }

  // NOTE: The Fog Dashboard consumes `kumbhMedicalPosts` and `activeCaseCount`
  // directly. Medical SOS queries are served by the offline intent cache, so
  // the prior `buildSosResponse()` AgentResponse builder was unused and removed.
}
