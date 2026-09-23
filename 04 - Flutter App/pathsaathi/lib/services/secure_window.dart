// lib/services/secure_window.dart
//
// Toggles Android FLAG_SECURE via a platform channel to block screenshots and
// screen recording while sensitive documents are displayed. No-op on platforms
// that don't implement the channel (e.g. iOS, desktop).

import 'package:flutter/services.dart';

class SecureWindow {
  SecureWindow._();
  static const _channel = MethodChannel('pathsaathi/secure_window');

  /// Block screenshots/recording for the current window.
  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } catch (_) {
      // Channel not available on this platform — silently ignore.
    }
  }

  /// Allow screenshots again.
  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } catch (_) {}
  }
}
