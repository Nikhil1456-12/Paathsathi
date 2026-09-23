// lib/providers/travel_context.dart
//
// Global, language-INDEPENDENT travel state for PathSaathi.
//
// Critical invariant that fixes the "Delhi → Prayagraj" bug:
//   • A destination the user SPEAKS becomes `pendingDestination` only.
//   • The map / routing / navigation read ONLY `confirmedDestination`.
//   • pendingDestination is promoted to confirmedDestination ONLY after the
//     user confirms (by voice or tap). No default is ever substituted.
//
// Destinations are stored as canonical `Place` objects (id + real coords), so
// the same place is identical regardless of the language it was spoken in.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/place_search_service.dart';
import '../services/journey_pack_service.dart';

class TravelState {
  final Place? pendingDestination;   // awaiting user confirmation
  final Place? confirmedDestination; // drives map/routing
  final Place? origin;

  const TravelState({
    this.pendingDestination,
    this.confirmedDestination,
    this.origin,
  });

  TravelState copyWith({
    Place? pendingDestination,
    Place? confirmedDestination,
    Place? origin,
    bool clearPending = false,
  }) {
    return TravelState(
      pendingDestination: clearPending ? null : (pendingDestination ?? this.pendingDestination),
      confirmedDestination: confirmedDestination ?? this.confirmedDestination,
      origin: origin ?? this.origin,
    );
  }
}

class TravelContextNotifier extends StateNotifier<TravelState> {
  TravelContextNotifier() : super(const TravelState()) {
    _restore();
  }

  static const _kConfirmedId = 'confirmed_destination_id';

  /// Rehydrate the CONFIRMED destination (only) by its language-independent id,
  /// so a trip survives app/device restart and offline relaunch. Pending is
  /// intentionally NOT persisted (an unconfirmed guess must never resurface).
  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_kConfirmedId);
      if (id != null) {
        final p = PlaceSearchService.instance.byId(id);
        if (p != null) state = state.copyWith(confirmedDestination: p);
      }
    } catch (_) {}
  }

  Future<void> _persistConfirmed(String? id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (id == null) {
        await prefs.remove(_kConfirmedId);
      } else {
        await prefs.setString(_kConfirmedId, id);
      }
    } catch (_) {}
  }

  /// User spoke a destination — hold it as pending (do NOT drive the map yet).
  void proposeDestination(Place p) {
    state = state.copyWith(pendingDestination: p);
  }

  /// User confirmed — promote pending to confirmed. Language does not matter;
  /// the same Place id is used everywhere.
  void confirmPending() {
    final p = state.pendingDestination;
    if (p == null) return;
    state = state.copyWith(confirmedDestination: p, clearPending: true);
    _persistConfirmed(p.id);
    _prepareJourneyPack(p);
  }

  /// Prepare + persist the destination-agnostic offline Journey Pack for the
  /// confirmed destination. Fire-and-forget; built purely from the Place, no
  /// hardcoded city logic, no network required, no fabricated data.
  void _prepareJourneyPack(Place p) {
    JourneyPackService.instance.prepareAndSave(p);
  }

  /// User rejected the pending destination.
  void rejectPending() {
    state = state.copyWith(clearPending: true);
  }

  /// Directly set a confirmed destination (e.g. tapped a search result).
  void setConfirmed(Place p) {
    state = state.copyWith(confirmedDestination: p, clearPending: true);
    _persistConfirmed(p.id);
    _prepareJourneyPack(p);
  }

  void setOrigin(Place p) => state = state.copyWith(origin: p);
}

final travelContextProvider =
    StateNotifierProvider<TravelContextNotifier, TravelState>(
        (ref) => TravelContextNotifier());
