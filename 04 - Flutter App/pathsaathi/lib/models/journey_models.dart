// lib/models/journey_models.dart
//
// Data models for the Journey Assistant. All map 1:1 to the SQLite rows created
// in AppDatabase v2. Everything here is on-device / offline; transport + nearby
// data is curated prototype data (labelled indicative), reservations are
// on-device prototype bookings (no money, no live seat).

import 'package:latlong2/latlong.dart';

/// A way to reach a destination (bus / train / bus+train). Times/prices are
/// indicative curated data, never claimed as a live reservation.
class TransportOption {
  final int id;
  final String destinationId;
  final String mode; // 'bus' | 'train' | 'bus+train'
  final String fromName;
  final String toName;
  final String depTime;
  final String arrTime;
  final int priceInr;
  final String operator;
  final bool indicative;
  final bool isTemplate;
  final String dataTier; // 'verified' | 'template'

  const TransportOption({
    required this.id,
    required this.destinationId,
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.depTime,
    required this.arrTime,
    required this.priceInr,
    required this.operator,
    this.indicative = true,
    this.isTemplate = false,
    this.dataTier = 'verified',
  });

  factory TransportOption.fromRow(Map<String, dynamic> r) => TransportOption(
        id: (r['id'] as int?) ?? 0,
        destinationId: (r['destination_id'] as String?) ?? '',
        mode: (r['mode'] as String?) ?? 'bus',
        fromName: (r['from_name'] as String?) ?? '',
        toName: (r['to_name'] as String?) ?? '',
        depTime: (r['dep_time'] as String?) ?? '',
        arrTime: (r['arr_time'] as String?) ?? '',
        priceInr: (r['price_inr'] as int?) ?? 0,
        operator: (r['operator'] as String?) ?? '',
        indicative: ((r['indicative'] as int?) ?? 1) == 1,
        isTemplate: ((r['is_template'] as int?) ?? 0) == 1,
        dataTier: (r['data_tier'] as String?) ?? 'verified',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'destination_id': destinationId,
        'mode': mode,
        'from_name': fromName,
        'to_name': toName,
        'dep_time': depTime,
        'arr_time': arrTime,
        'price_inr': priceInr,
        'operator': operator,
        'indicative': indicative ? 1 : 0,
        'is_template': isTemplate ? 1 : 0,
        'data_tier': dataTier,
      };

  TransportOption copyWith({
    String? fromName,
    String? toName,
    bool? indicative,
    String? dataTier,
  }) =>
      TransportOption(
        id: id,
        destinationId: destinationId,
        mode: mode,
        fromName: fromName ?? this.fromName,
        toName: toName ?? this.toName,
        depTime: depTime,
        arrTime: arrTime,
        priceInr: priceInr,
        operator: operator,
        indicative: indicative ?? this.indicative,
        isTemplate: isTemplate,
        dataTier: dataTier ?? this.dataTier,
      );
}

/// A place near the destination used for offline help. Coordinates are real so
/// offline direction+distance guidance works.
class NearbyPlace {
  final int id;
  final String destinationId;
  final String category; // hotel | hospital | food | water | help
  final String name;
  final LatLng coords;
  final String note;
  final String source; // curated | cached

  const NearbyPlace({
    required this.id,
    required this.destinationId,
    required this.category,
    required this.name,
    required this.coords,
    required this.note,
    this.source = 'curated',
  });

  factory NearbyPlace.fromRow(Map<String, dynamic> r) => NearbyPlace(
        id: (r['id'] as int?) ?? 0,
        destinationId: (r['destination_id'] as String?) ?? '',
        category: (r['category'] as String?) ?? 'help',
        name: (r['name'] as String?) ?? '',
        coords: LatLng(
          (r['lat'] as num?)?.toDouble() ?? 0,
          (r['lng'] as num?)?.toDouble() ?? 0,
        ),
        note: (r['note'] as String?) ?? '',
        source: (r['source'] as String?) ?? 'curated',
      );
}

/// An on-device prototype booking record (transport or stay). Not a real,
/// paid, or live third-party reservation — carries a local confirmation ref.
class Reservation {
  final int id;
  final String refCode;
  final String type; // 'transport' | 'stay'
  final String title;
  final String details;
  final String status; // 'confirmed' (prototype)
  final DateTime createdAt;

  const Reservation({
    required this.id,
    required this.refCode,
    required this.type,
    required this.title,
    required this.details,
    required this.status,
    required this.createdAt,
  });

  factory Reservation.fromRow(Map<String, dynamic> r) => Reservation(
        id: (r['id'] as int?) ?? 0,
        refCode: (r['ref_code'] as String?) ?? '',
        type: (r['type'] as String?) ?? 'transport',
        title: (r['title'] as String?) ?? '',
        details: (r['details'] as String?) ?? '',
        status: (r['status'] as String?) ?? 'confirmed',
        createdAt: DateTime.tryParse((r['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toRow() => {
        'ref_code': refCode,
        'type': type,
        'title': title,
        'details': details,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}

/// Which parts of the destination-area data have been pre-cached for offline.
class CacheStatus {
  final bool tiles; // offline OSM map tiles for the region
  final bool places; // nearby places with coords
  final bool route; // route path to the stay

  const CacheStatus(
      {this.tiles = false, this.places = false, this.route = false});

  bool get isComplete => tiles && places && route;
  bool get isPartial => (tiles || places || route) && !isComplete;

  CacheStatus copyWith({bool? tiles, bool? places, bool? route}) => CacheStatus(
        tiles: tiles ?? this.tiles,
        places: places ?? this.places,
        route: route ?? this.route,
      );
}

/// The persisted plan for the current trip.
class JourneyPlan {
  final int id;
  final String destinationId;
  final String destinationName;
  final LatLng? destinationCoords;
  final int? transportOptionId;
  final int? stayReservationId;
  final CacheStatus cacheStatus;
  final bool active;
  final DateTime createdAt;

  const JourneyPlan({
    required this.id,
    required this.destinationId,
    required this.destinationName,
    this.destinationCoords,
    this.transportOptionId,
    this.stayReservationId,
    this.cacheStatus = const CacheStatus(),
    this.active = true,
    required this.createdAt,
  });

  factory JourneyPlan.fromRow(Map<String, dynamic> r) {
    final lat = (r['dest_lat'] as num?)?.toDouble();
    final lng = (r['dest_lng'] as num?)?.toDouble();
    return JourneyPlan(
      id: (r['id'] as int?) ?? 0,
      destinationId: (r['destination_id'] as String?) ?? '',
      destinationName: (r['destination_name'] as String?) ?? '',
      destinationCoords: (lat != null && lng != null) ? LatLng(lat, lng) : null,
      transportOptionId: r['transport_option_id'] as int?,
      stayReservationId: r['stay_reservation_id'] as int?,
      cacheStatus: CacheStatus(
        tiles: ((r['cache_tiles'] as int?) ?? 0) == 1,
        places: ((r['cache_places'] as int?) ?? 0) == 1,
        route: ((r['cache_route'] as int?) ?? 0) == 1,
      ),
      active: ((r['active'] as int?) ?? 1) == 1,
      createdAt: DateTime.tryParse((r['created_at'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toRow() => {
        'destination_id': destinationId,
        'destination_name': destinationName,
        'dest_lat': destinationCoords?.latitude,
        'dest_lng': destinationCoords?.longitude,
        'transport_option_id': transportOptionId,
        'stay_reservation_id': stayReservationId,
        'cache_tiles': cacheStatus.tiles ? 1 : 0,
        'cache_places': cacheStatus.places ? 1 : 0,
        'cache_route': cacheStatus.route ? 1 : 0,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}
