import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Requests the runtime permissions needed by the core travel experience.
///
/// This is deliberately called from the first home page rather than from
/// individual feature pages. Android may still display separate system sheets
/// for different permission groups, but they are requested in one batch.
class StartupPermissionService {
  StartupPermissionService._();
  static final StartupPermissionService instance = StartupPermissionService._();

  static const _requestedKey = 'startup_permissions_requested_v1';
  Future<void>? _requestInFlight;

  Future<void> requestOnFirstHome() {
    return _requestInFlight ??= _requestOnce().whenComplete(() {
      _requestInFlight = null;
    });
  }

  Future<void> _requestOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_requestedKey) == true) return;

    final results = await [
      Permission.microphone,
      Permission.locationWhenInUse,
    ].request();

    await prefs.setBool(_requestedKey, true);
    debugPrint(
      '[StartupPermissionService] microphone=${results[Permission.microphone]} '
      'location=${results[Permission.locationWhenInUse]}',
    );
  }
}
