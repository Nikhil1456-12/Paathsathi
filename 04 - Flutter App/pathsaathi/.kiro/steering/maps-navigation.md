---
inclusion: fileMatch
fileMatchPattern: 'lib/services/location_service.dart|lib/services/place_search_service.dart|lib/services/map_bundle_service.dart|lib/models/city_map_bundle.dart|lib/screens/navigation_screen.dart|lib/screens/city_map_picker_screen.dart|lib/widgets/offline_map_widget.dart|lib/widgets/smart_offline_map_widget.dart'
---

# Maps / Navigation Rules

Applies to GPS, offline maps, routing, and destination resolution. Reuse the
existing services; do not add a second location or map stack.

## GPS truthfulness (highest priority)
- `LocationService` NEVER fabricates a position. It reports one of the truthful
  `GpsState` values: idle / servicesOff / permissionDenied / permissionForever /
  searching / lowAccuracy / ready / unavailable.
- Never show a fake "GPS Lock". `position` is null unless `state.hasFix`.
- A stale fix must not be presented as current without saying so
  (`LocationSnapshot.isStale`). Invariant I5 — GPS failure SHALL NOT create
  fabricated location data.

## Offline maps
- Rendered with `flutter_map` + MBTiles. The offline map may be schematic unless
  real MBTiles are bundled — state this honestly, do not imply full tiles exist.

## Offline routing
- Current guidance is direct-line (bearing/distance), NOT turn-by-turn. Do not
  claim turn-by-turn routing until real offline routing (e.g. Valhalla) is
  actually implemented. See #[[file:IMPROVEMENTS_AND_VERIFICATION.md]]

## Destination resolution & coordinates
- Destinations resolve via the offline `PlaceSearchService` index (real
  OSM-sourced coordinates, multilingual aliases). General/knowledge questions
  resolve to `null` — never invent a destination (invariant I6).
- Keep coordinates real; do not add placeholder/random coordinates.

## Navigation state
- Only the CONFIRMED destination is persisted/restored; a pending guess is never
  persisted (invariants I1, I2, I9). Confirmed replaces previous confirmed.

## Offline / online transitions
- Offline mode SHALL NEVER present live data as available (invariant I7).
- Network loss SHALL NOT corrupt persisted travel state (invariant I4).
- Full invariant list: #[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]
