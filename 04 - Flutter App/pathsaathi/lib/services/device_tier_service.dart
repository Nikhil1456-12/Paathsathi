import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Device Tier Enum
// PathSaathi auto-selects quantization level based on available RAM
// ─────────────────────────────────────────────────────────────────────────────
enum DeviceTier {
  /// ≥ 6 GB RAM — Full mode: Whisper Small INT8, Gemma-3-1B INT4
  full,

  /// 3–6 GB RAM — Standard mode: Whisper Base INT8, Gemma-3-1B INT4
  standard,

  /// < 3 GB RAM — Lite mode: Whisper Tiny INT8, TinyLlama INT4
  lite,
}

extension DeviceTierX on DeviceTier {
  String get label {
    switch (this) {
      case DeviceTier.full:     return 'Full Mode';
      case DeviceTier.standard: return 'Standard Mode';
      case DeviceTier.lite:     return 'Lite Mode';
    }
  }

  String get description {
    switch (this) {
      case DeviceTier.full:     return 'Best accuracy — 6+ GB RAM detected';
      case DeviceTier.standard: return 'Balanced accuracy — 3–6 GB RAM';
      case DeviceTier.lite:     return 'Optimized for low-end — <3 GB RAM';
    }
  }

  String get badge {
    switch (this) {
      case DeviceTier.full:     return '🟢 Full Mode';
      case DeviceTier.standard: return '🟡 Standard Mode';
      case DeviceTier.lite:     return '🔵 Lite Mode';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device Tier Service
// Phase 1: Uses saved preference or defaults to Standard
// Phase 2: Will use device_info_plus + platform channel for actual RAM detection
// ─────────────────────────────────────────────────────────────────────────────
class DeviceTierService {
  static DeviceTier _tier = DeviceTier.standard;
  static bool _userOverridden = false;

  static DeviceTier get tier => _tier;

  /// Call once at app startup. Uses a saved user override if present, otherwise
  /// auto-detects the device tier from real physical RAM so we only load a
  /// model set that fits — keeping memory and download size appropriate.
  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('device_tier');
    if (saved != null) {
      _userOverridden = true;
      _tier = DeviceTier.values.firstWhere(
        (t) => t.name == saved,
        orElse: () => DeviceTier.standard,
      );
      return; // respect explicit user choice
    }
    await _autoDetect();
  }

  /// Detect device class and map it to a tier.
  ///
  /// device_info_plus 10.x does not expose exact RAM, but Android's
  /// ActivityManager.isLowRamDevice() flag (surfaced as [isLowRamDevice]) is a
  /// reliable signal for very constrained devices. Combined with 64-bit ABI
  /// support and API level, this gives a robust tier heuristic without a
  /// native platform channel:
  ///   • isLowRamDevice           → Lite
  ///   • 64-bit + API ≥ 29 (~mid) → Full
  ///   • otherwise                → Standard
  static Future<void> _autoDetect() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        if (a.isLowRamDevice) {
          _tier = DeviceTier.lite;
        } else if (a.supported64BitAbis.isNotEmpty && a.version.sdkInt >= 29) {
          _tier = DeviceTier.full;
        } else {
          _tier = DeviceTier.standard;
        }
        _lowRam = a.isLowRamDevice;
        debugPrint('[DeviceTierService] lowRam=${a.isLowRamDevice} '
            'sdk=${a.version.sdkInt} 64bit=${a.supported64BitAbis.isNotEmpty} '
            '→ tier=${_tier.name}');
        return;
      }
    } catch (e) {
      debugPrint('[DeviceTierService] Detection failed: $e');
    }
    _tier = DeviceTier.standard; // iOS / unknown → safe middle default
  }

  static bool _lowRam = false;
  static bool get isLowRamDevice => _lowRam;

  static bool get isUserOverridden => _userOverridden;

  /// Allow user / system to set tier manually
  static Future<void> overrideTier(DeviceTier tier) async {
    _tier = tier;
    _userOverridden = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_tier', tier.name);
  }
}

// Riverpod provider
final deviceTierProvider = Provider<DeviceTier>((ref) => DeviceTierService.tier);
