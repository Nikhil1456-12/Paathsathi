// lib/services/fog_service.dart
//
// TIER 2 — Fog / Edge Node Client for PathSaathi
//
// Communicates with a Raspberry Pi 5 / Jetson Orin micro-server
// co-located at camp towers. When reachable over LAN/Wi-Fi/BLE-uplink,
// queries are forwarded to the Fog node's LangGraph orchestrator which
// has access to:
//   - Chroma vector DB (2GB zone-wide pilgrim registry)
//   - Real-time crowd density from 1000+ BLE beacons
//   - Lost & Found cross-device registry
//   - Medical SOS dispatch queue
//
// When the Fog node is unreachable, returns null → falls back gracefully
// to on-device Tier 1 (IntentPlanner keyword/NLU/LLM routing).

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/agent_response.dart';

// ── Fog Node Connection Status ────────────────────────────────────────────────

enum FogStatus {
  connected,    // Fog node found and responding
  unreachable,  // Timeout / connection refused
  discovering,  // LAN probe in progress
}

// ── Fog Service Singleton ─────────────────────────────────────────────────────

class FogService {
  FogService._();
  static final FogService instance = FogService._();

  // Configurable — updated from settings screen or auto-discovered via mDNS
  String _fogHost = '192.168.43.1';
  int _fogPort = 8765;
  final Duration _timeout = const Duration(seconds: 3);

  FogStatus _status = FogStatus.unreachable;
  DateTime? _lastSuccessfulPing;

  FogStatus get status => _status;
  bool get isConnected => _status == FogStatus.connected;
  String get fogAddress => '$_fogHost:$_fogPort';

  /// Update Fog node address (called from settings or auto-discovery)
  void configure({required String host, int port = 8765}) {
    _fogHost = host;
    _fogPort = port;
    debugPrint('[FogService] Configured to $_fogHost:$_fogPort');
  }

  /// Probe common LAN addresses for a PathSaathi Fog node.
  /// Tries gateway IPs typically used in mobile hotspot / camp Wi-Fi setups.
  Future<bool> discoverFogNode() async {
    _status = FogStatus.discovering;
    debugPrint('[FogService] Starting LAN discovery probe...');

    // Common mobile hotspot / camp Wi-Fi gateway IPs
    final candidateHosts = [
      '192.168.43.1',   // Android hotspot default gateway
      '192.168.1.1',    // Home router default
      '10.0.0.1',       // Camp network default
      '192.168.0.1',    // Alternate router default
      '172.16.0.1',     // Enterprise network default
    ];

    for (final host in candidateHosts) {
      try {
        final uri = Uri.http('$host:$_fogPort', '/health');
        final resp = await http.get(uri).timeout(const Duration(seconds: 1));
        if (resp.statusCode == 200) {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          if (body['service'] == 'pathsaathi-fog') {
            _fogHost = host;
            _status = FogStatus.connected;
            _lastSuccessfulPing = DateTime.now();
            debugPrint('[FogService] ✅ Fog node discovered at $host:$_fogPort');
            return true;
          }
        }
      } catch (_) {
        // Continue probing next candidate
      }
    }

    _status = FogStatus.unreachable;
    debugPrint('[FogService] No Fog node found on LAN — using on-device fallback');
    return false;
  }

  /// Quick health-check ping. Returns true if Fog node responds within timeout.
  Future<bool> ping() async {
    try {
      final uri = Uri.http('$_fogHost:$_fogPort', '/health');
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode == 200) {
        _status = FogStatus.connected;
        _lastSuccessfulPing = DateTime.now();
        return true;
      }
    } catch (_) {}
    _status = FogStatus.unreachable;
    return false;
  }

  /// Send a query to the Fog node's LangGraph orchestrator.
  /// Returns AgentResponse if Fog responds, or null on timeout/error.
  Future<AgentResponse?> query({
    required String rawQuery,
    required String langCode,
    String? zoneId,
  }) async {
    if (_status == FogStatus.unreachable) {
      // Quick re-check (may have reconnected since last attempt)
      final alive = await ping();
      if (!alive) return null;
    }

    try {
      final uri = Uri.http('$_fogHost:$_fogPort', '/query');
      final payload = jsonEncode({
        'query': rawQuery,
        'lang': langCode,
        'zone': zoneId ?? 'auto',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'client': 'pathsaathi-mobile',
      });

      debugPrint('[FogService] → Sending query to Fog: "$rawQuery"');

      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(_timeout);

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        debugPrint('[FogService] ✅ Fog response received (${resp.body.length} bytes)');
        return _parseFogResponse(data);
      } else {
        debugPrint('[FogService] Fog returned ${resp.statusCode}');
        return null;
      }
    } on TimeoutException {
      debugPrint('[FogService] Query timed out after ${_timeout.inSeconds}s');
      _status = FogStatus.unreachable;
      return null;
    } catch (e) {
      debugPrint('[FogService] Query error: $e');
      _status = FogStatus.unreachable;
      return null;
    }
  }

  /// Parses the JSON response from the Fog node's LangGraph orchestrator
  /// into an AgentResponse that the UI can render directly.
  AgentResponse? _parseFogResponse(Map<String, dynamic> data) {
    try {
      final agentType = _parseAgentType(data['agent_type'] as String? ?? 'general');
      final latencyMs = data['latency_ms'] ?? '?';
      final zone = data['zone'] ?? 'Zone ?';

      return AgentResponse(
        type: agentType,
        title: data['title'] as String? ?? 'Fog Agent Response',
        subtitle: data['subtitle'] as String? ?? '📡 Via Edge Node ($zone)',
        primaryValue: data['primary_value'] as String? ?? '—',
        badgeText: 'EDGE • ${latencyMs}ms',
        badgeColor: const Color(0xFFF97316), // Orange for Fog/Edge tier
        primaryIcon: _parseIcon(data['icon'] as String?),
        spokenTextEnglish: data['spoken_en'] as String? ?? data['title'] as String? ?? '',
        spokenTextHindi: data['spoken_hi'] as String? ?? data['title'] as String? ?? '',
        spokenTextTelugu: data['spoken_te'] as String? ?? data['title'] as String? ?? '',
        spokenTextTamil: data['spoken_ta'] as String?,
        spokenTextMarathi: data['spoken_mr'] as String?,
        spokenTextPunjabi: data['spoken_pa'] as String?,
        rawData: {
          'tier': 'FOG',
          'zone': zone,
          'latencyMs': latencyMs,
          'fog_host': fogAddress,
          'fog_agent': data['agent_type'],
          ...?(data['raw'] as Map<String, dynamic>?),
        },
      );
    } catch (e) {
      debugPrint('[FogService] Parse error: $e');
      return null;
    }
  }

  AgentType _parseAgentType(String raw) {
    switch (raw) {
      case 'transport':
        return AgentType.transport;
      case 'accommodation':
        return AgentType.accommodation;
      case 'navigation':
        return AgentType.navigation;
      case 'itinerary':
        return AgentType.itinerary;
      case 'safety':
        return AgentType.safety;
      case 'document':
        return AgentType.document;
      default:
        return AgentType.general;
    }
  }

  IconData _parseIcon(String? raw) {
    switch (raw) {
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'medical':
        return Icons.local_hospital_rounded;
      case 'navigation':
        return Icons.navigation_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'crowd':
        return Icons.people_rounded;
      case 'lost':
        return Icons.search_rounded;
      case 'sos':
        return Icons.emergency_share_rounded;
      default:
        return Icons.hub_rounded;
    }
  }

  /// Returns time since last successful Fog contact (for UI display).
  String get lastContactAgo {
    if (_lastSuccessfulPing == null) return 'Never';
    final diff = DateTime.now().difference(_lastSuccessfulPing!);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
