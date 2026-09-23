// lib/services/connectivity_service.dart
//
// Real-time network connectivity monitoring for PathSaathi.
// Exposes a Riverpod provider so any widget can watch online/offline state.
// Never shows blocking dialogs — offline state is surfaced via OfflineBanner.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Enum ──────────────────────────────────────────────────────────────────────

enum ConnectivityStatus { online, offline, degraded }

extension ConnectivityStatusX on ConnectivityStatus {
  bool get isOnline => this == ConnectivityStatus.online;
  bool get isOffline => this == ConnectivityStatus.offline;
  String get label => switch (this) {
        ConnectivityStatus.online   => 'Online',
        ConnectivityStatus.offline  => 'Offline',
        ConnectivityStatus.degraded => 'Degraded',
      };
}

// ── Service Singleton ─────────────────────────────────────────────────────────

class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  final _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _current = ConnectivityStatus.online;

  /// Current status (synchronous getter).
  ConnectivityStatus get status => _current;
  bool get isOnline => _current.isOnline;

  /// Broadcast stream of connectivity changes.
  Stream<ConnectivityStatus> get onStatusChange => _statusController.stream;

  /// Start listening for connectivity changes.
  Future<void> initialize() async {
    // Read the initial state
    final results = await _connectivity.checkConnectivity();
    _current = _fromResults(results);
    _statusController.add(_current);

    // Listen to changes
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final next = _fromResults(results);
      if (next != _current) {
        _log('Connectivity changed: ${_current.label} → ${next.label}');
        _current = next;
        _statusController.add(_current);
      }
    });
  }

  ConnectivityStatus _fromResults(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      return ConnectivityStatus.online;
    } else if (results.contains(ConnectivityResult.mobile)) {
      return ConnectivityStatus.degraded;
    } else {
      return ConnectivityStatus.offline;
    }
  }

  void _log(String msg) {
    // ignore: avoid_print
    print('[ConnectivityService] $msg');
  }

  void dispose() {
    _subscription?.cancel();
    _statusController.close();
  }
}

// ── Riverpod Provider ─────────────────────────────────────────────────────────

class ConnectivityNotifier extends StateNotifier<ConnectivityStatus> {
  ConnectivityNotifier() : super(ConnectivityStatus.online) {
    _init();
  }

  StreamSubscription<ConnectivityStatus>? _sub;

  Future<void> _init() async {
    await ConnectivityService.instance.initialize();
    // Set initial state
    state = ConnectivityService.instance.status;
    // Subscribe to changes
    _sub = ConnectivityService.instance.onStatusChange.listen((s) {
      state = s;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Watch this provider to get real-time connectivity status.
///
/// Usage in a widget:
/// ```dart
/// final status = ref.watch(connectivityProvider);
/// if (status.isOffline) { ... }
/// ```
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityStatus>(
        (ref) => ConnectivityNotifier());
