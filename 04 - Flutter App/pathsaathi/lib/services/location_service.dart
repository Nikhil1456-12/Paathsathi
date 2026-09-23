// lib/services/location_service.dart
//
// Real on-device GNSS/GPS location for PathSaathi. Works fully offline —
// satellite positioning does NOT require internet. This service NEVER
// fabricates a position; if it has no valid fix it reports the honest state.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Truthful location states surfaced to the UI. No fake "GPS Lock".
enum GpsState {
  idle, // not started
  servicesOff, // device location/GPS turned off
  permissionDenied, // user denied (can re-ask)
  permissionForever, // permanently denied (must open settings)
  searching, // permission ok, waiting for first fix
  lowAccuracy, // have a fix but accuracy is poor (> 50 m)
  ready, // good fix (<= 50 m)
  unavailable, // error / no fix after searching
}

extension GpsStateX on GpsState {
  String get label {
    switch (this) {
      case GpsState.idle:
        return 'GPS idle';
      case GpsState.servicesOff:
        return 'Location is OFF';
      case GpsState.permissionDenied:
        return 'Location permission needed';
      case GpsState.permissionForever:
        return 'Enable location in Settings';
      case GpsState.searching:
        return 'Searching for GPS…';
      case GpsState.lowAccuracy:
        return 'GPS weak (low accuracy)';
      case GpsState.ready:
        return 'GPS ready';
      case GpsState.unavailable:
        return 'GPS unavailable';
    }
  }

  bool get hasFix => this == GpsState.ready || this == GpsState.lowAccuracy;
}

class LocationSnapshot {
  final GpsState state;
  final LatLng? position; // null unless state.hasFix
  final double? accuracyM; // metres, null unless fix
  final double? headingDeg; // device heading if available
  final DateTime? at;

  const LocationSnapshot({
    required this.state,
    this.position,
    this.accuracyM,
    this.headingDeg,
    this.at,
  });

  /// True if the fix is older than [maxAge] — caller should treat as stale,
  /// never present a stale position as "current" without saying so.
  bool isStale({Duration maxAge = const Duration(seconds: 15)}) {
    if (at == null) return true;
    return DateTime.now().difference(at!) > maxAge;
  }
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const double _lowAccuracyThresholdM = 50.0;

  final _controller = StreamController<LocationSnapshot>.broadcast();
  StreamSubscription<Position>? _sub;
  LocationSnapshot _last = const LocationSnapshot(state: GpsState.idle);

  Stream<LocationSnapshot> get stream => _controller.stream;
  LocationSnapshot get last => _last;

  void _emit(LocationSnapshot s) {
    _last = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  /// Ensure permission + services, then begin continuous updates.
  /// Safe to call repeatedly; it re-checks and (re)starts the stream.
  Future<GpsState> start() async {
    // 1. Location services (GPS radio) enabled?
    if (!await Geolocator.isLocationServiceEnabled()) {
      _emit(const LocationSnapshot(state: GpsState.servicesOff));
      return GpsState.servicesOff;
    }

    // 2. Permission
    // Runtime permission is requested centrally on the first home page.
    // Feature pages only inspect the result so they never show a second,
    // page-specific permission prompt.
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.deniedForever) {
      _emit(const LocationSnapshot(state: GpsState.permissionForever));
      return GpsState.permissionForever;
    }
    if (perm == LocationPermission.denied) {
      _emit(const LocationSnapshot(state: GpsState.permissionDenied));
      return GpsState.permissionDenied;
    }

    // 3. Begin searching
    _emit(const LocationSnapshot(state: GpsState.searching));

    // Seed with last known position (clearly may be stale) to give the map
    // something immediately — but state stays "searching" until a live fix.
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _emit(LocationSnapshot(
          state: GpsState.searching,
          position: LatLng(lastKnown.latitude, lastKnown.longitude),
          accuracyM: lastKnown.accuracy,
          at: lastKnown.timestamp,
        ));
      }
    } catch (_) {}

    // 4. Continuous stream. distanceFilter keeps it battery-friendly.
    await _sub?.cancel();
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter:
          5, // metres — avoids constant updates while standing still
    );
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        final acc = p.accuracy;
        final state = acc > _lowAccuracyThresholdM
            ? GpsState.lowAccuracy
            : GpsState.ready;
        _emit(LocationSnapshot(
          state: state,
          position: LatLng(p.latitude, p.longitude),
          accuracyM: acc,
          headingDeg: p.heading >= 0 ? p.heading : null,
          at: p.timestamp,
        ));
      },
      onError: (e) {
        debugPrint('[LocationService] stream error: $e');
        _emit(const LocationSnapshot(state: GpsState.unavailable));
      },
      cancelOnError: false,
    );

    return GpsState.searching;
  }

  /// One-shot current position (for "Recenter / Where am I?").
  /// Returns null if no valid fix could be obtained.
  Future<LatLng?> currentOnce() async {
    if (_last.state.hasFix && _last.position != null && !_last.isStale()) {
      return _last.position;
    }
    try {
      final p = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  void stop() {
    _sub?.cancel();
    _sub = null;
    _emit(const LocationSnapshot(state: GpsState.idle));
  }
}

/// Riverpod stream provider — widgets watch this for live, truthful location.
final locationProvider = StreamProvider<LocationSnapshot>((ref) {
  // Kick off updates when first watched; stop when no longer listened.
  LocationService.instance.start();
  ref.onDispose(() => LocationService.instance.stop());
  return LocationService.instance.stream;
});
