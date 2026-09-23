// lib/agents/fog/crowd_agent.dart
//
// Fog Tier — Crowd Density Agent
//
// This agent runs on the Fog node (Raspberry Pi 5 / Jetson Orin)
// and is invoked by the LangGraph orchestrator. On the mobile side,
// this file contains the DATA MODEL that parses Fog responses
// and the fallback on-device crowd density estimate.

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// ── Zone Density Data ─────────────────────────────────────────────────────────

enum DensityLevel { low, moderate, high, critical }

class ZoneDensity {
  final String zoneId;
  final String zoneName;
  final DensityLevel level;
  final int estimatedPilgrims;
  final int maxCapacity;
  final String safeAlternativeRoute;
  final LatLng center;

  const ZoneDensity({
    required this.zoneId,
    required this.zoneName,
    required this.level,
    required this.estimatedPilgrims,
    required this.maxCapacity,
    required this.safeAlternativeRoute,
    required this.center,
  });

  double get occupancyRatio => estimatedPilgrims / maxCapacity;

  Color get levelColor {
    switch (level) {
      case DensityLevel.low:      return const Color(0xFF16A34A);
      case DensityLevel.moderate: return const Color(0xFFF59E0B);
      case DensityLevel.high:     return const Color(0xFFF97316);
      case DensityLevel.critical: return const Color(0xFFDC2626);
    }
  }

  String get levelLabel {
    switch (level) {
      case DensityLevel.low:      return 'Low';
      case DensityLevel.moderate: return 'Moderate';
      case DensityLevel.high:     return 'High';
      case DensityLevel.critical: return '⚠️ Critical';
    }
  }
}

// ── Static Fallback Zone Data (used when Fog node is unreachable) ─────────────

class CrowdAgent {
  CrowdAgent._();
  static final CrowdAgent instance = CrowdAgent._();

  /// Static zone layout of Prayagraj Kumbh Mela 2025.
  /// In production, this is replaced with live BLE beacon data from Fog node.
  static const List<ZoneDensity> staticZones = [
    ZoneDensity(
      zoneId: 'Z1',
      zoneName: 'Sangam Ghat (Triveni)',
      level: DensityLevel.high,
      estimatedPilgrims: 85000,
      maxCapacity: 100000,
      safeAlternativeRoute: 'Use Naini Bridge approach via Bandha Marg',
      center: LatLng(25.4358, 81.8853),
    ),
    ZoneDensity(
      zoneId: 'Z2',
      zoneName: 'Sector 4 Camp Zone',
      level: DensityLevel.moderate,
      estimatedPilgrims: 32000,
      maxCapacity: 60000,
      safeAlternativeRoute: 'Direct — no congestion currently',
      center: LatLng(25.4420, 81.8780),
    ),
    ZoneDensity(
      zoneId: 'Z3',
      zoneName: 'Sector 7 Camp Zone',
      level: DensityLevel.low,
      estimatedPilgrims: 11000,
      maxCapacity: 50000,
      safeAlternativeRoute: 'Direct — open access',
      center: LatLng(25.4490, 81.8740),
    ),
    ZoneDensity(
      zoneId: 'Z4',
      zoneName: 'Naini Bridge Entry',
      level: DensityLevel.moderate,
      estimatedPilgrims: 20000,
      maxCapacity: 40000,
      safeAlternativeRoute: 'Phaphamau Bridge if Naini is congested',
      center: LatLng(25.4380, 81.8700),
    ),
  ];

  // NOTE: The Fog Dashboard consumes `staticZones` directly for its heatmap.
  // A prior `buildCrowdResponse()` AgentResponse builder was unused (the crowd
  // query is served by the offline intent cache) and has been removed.
}
