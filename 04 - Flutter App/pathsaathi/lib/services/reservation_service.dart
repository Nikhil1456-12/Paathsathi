// lib/services/reservation_service.dart
//
// On-device prototype reservations. A reservation is a REAL record stored in
// the local SQLite DB with a generated confirmation reference — but it is a
// prototype booking only: no money is charged and no live third-party seat/room
// is reserved. This is clearly labelled in the UI. Works fully offline.

import 'dart:math';
import '../database/app_database.dart';
import '../models/journey_models.dart';

class ReservationService {
  ReservationService._();
  static final ReservationService instance = ReservationService._();

  static final _rand = Random();

  /// Generate a human-readable confirmation reference, e.g. "PS-7F3K9Q".
  String _generateRef() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I
    final code = List.generate(6, (_) => chars[_rand.nextInt(chars.length)]).join();
    return 'PS-$code';
  }

  /// Create a reservation record and return it (with its DB id + ref code).
  Future<Reservation> create({
    required String type, // 'transport' | 'stay'
    required String title,
    required String details,
  }) async {
    final res = Reservation(
      id: 0,
      refCode: _generateRef(),
      type: type,
      title: title,
      details: details,
      status: 'confirmed',
      createdAt: DateTime.now(),
    );
    final id = await AppDatabase.instance.insertReservation(res.toRow());
    return Reservation(
      id: id,
      refCode: res.refCode,
      type: res.type,
      title: res.title,
      details: res.details,
      status: res.status,
      createdAt: res.createdAt,
    );
  }

  /// All reservations, newest first (available offline).
  Future<List<Reservation>> all() async {
    final rows = await AppDatabase.instance.getReservations();
    return rows.map(Reservation.fromRow).toList();
  }
}
