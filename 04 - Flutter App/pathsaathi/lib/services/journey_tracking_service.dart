// lib/services/journey_tracking_service.dart
//
// Follows the user's live GPS during an active journey and detects arrival at
// the destination. Emits a truthful JourneyStatus stream that the UI watches —
// no notification plugin dependency (an in-app arrival banner is used, which
// also works fully offline). GPS is satellite-based, so tracking continues with
// no network.
//
// Honesty: it never fabricates a position or an arrival. If there is no GPS fix
// or permission is denied, it surfaces that state instead.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/journey_models.dart';
import 'location_service.dart';
import 'journey_plan_service.dart';

/// Phase of the active journey (from the tracker's view).
enum JourneyPhase {
  none,          // no active plan
  awaitingFix,   // active plan but no GPS fix yet
  enRoute,       // moving toward destination
  arrived,       // within arrival radius of destination
}

class JourneyStatus {
  final JourneyPhase phase;
  final double? distanceMeters; // to destination (null if no fix/no plan)
  final String? bearingCompass; // 8-point direction to destination
  final JourneyPlan? plan;
  final String message;

  const JourneyStatus({
    required this.phase,
    this.distanceMeters,
    this.bearingCompass,
    this.plan,
    this.message = '',
  });
}

class JourneyTrackingService {
  JourneyTrackingService._();
  static final JourneyTrackingService instance = JourneyTrackingService._();

  static const Distance _dist = Distance();

  /// Within this many metres of the destination → "arrived".
  static const double arrivalRadiusM = 400;

  final _controller = StreamController<JourneyStatus>.broadcast();
  StreamSubscription<LocationSnapshot>? _sub;
  JourneyPlan? _plan;
  bool _announcedArrival = false;
  JourneyStatus _last = const JourneyStatus(phase: JourneyPhase.none);

  Stream<JourneyStatus> get stream => _controller.stream;
  JourneyStatus get last => _last;

  /// Whether arrival has been reached (for one-shot UI prompts).
  bool get hasArrived => _last.phase == JourneyPhase.arrived;

  void _emit(JourneyStatus s) {
    _last = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  /// Begin tracking the active journey plan. Safe to call repeatedly.
  Future<void> start() async {
    _plan = await JourneyPlanService.instance.active();
    if (_plan == null || _plan!.destinationCoords == null) {
      _emit(const JourneyStatus(
          phase: JourneyPhase.none, message: 'No active journey.'));
      return;
    }
    _announcedArrival = false;

    // Make sure the location stream is running, then subscribe.
    await LocationService.instance.start();
    await _sub?.cancel();
    _sub = LocationService.instance.stream.listen(_onLocation);

    // Seed with the current snapshot if we already have one.
    _onLocation(LocationService.instance.last);
  }

  void _onLocation(LocationSnapshot snap) {
    final dest = _plan?.destinationCoords;
    if (dest == null) return;

    if (!snap.state.hasFix || snap.position == null) {
      _emit(JourneyStatus(
        phase: JourneyPhase.awaitingFix,
        plan: _plan,
        message: snap.state.label, // truthful GPS state, no fabricated position
      ));
      return;
    }

    final here = snap.position!;
    final metres = _dist.as(LengthUnit.Meter, here, dest);
    final bearing = _dist.bearing(here, dest);
    final compass = _compass(bearing);

    if (metres <= arrivalRadiusM) {
      _emit(JourneyStatus(
        phase: JourneyPhase.arrived,
        distanceMeters: metres,
        bearingCompass: compass,
        plan: _plan,
        message: 'You have reached ${_plan!.destinationName}.',
      ));
      _announcedArrival = true;
    } else {
      _emit(JourneyStatus(
        phase: JourneyPhase.enRoute,
        distanceMeters: metres,
        bearingCompass: compass,
        plan: _plan,
        message: '${_fmtDistance(metres)} to ${_plan!.destinationName}, head $compass.',
      ));
    }
  }

  /// One-shot: has arrival just happened and not yet been acknowledged?
  bool consumeArrivalPrompt() {
    if (_announcedArrival) {
      _announcedArrival = false;
      return true;
    }
    return false;
  }

  static String _fmtDistance(double m) =>
      m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  static String _compass(double bearing) {
    const dirs = ['North', 'North-East', 'East', 'South-East',
                  'South', 'South-West', 'West', 'North-West'];
    final b = (bearing % 360 + 360) % 360;
    return dirs[((b + 22.5) ~/ 45) % 8];
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _plan = null;
    _emit(const JourneyStatus(phase: JourneyPhase.none));
  }

  @visibleForTesting
  void dispose() => _controller.close();
}
