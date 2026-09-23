# Design — PathSaathi Journey Assistant

## Overview

This document describes how the Journey Assistant is built as a **100% real, offline-first**
system on top of the existing PathSaathi app. Every capability here is implemented with real,
verifiable technology. Where a capability cannot work offline with practical on-device
technology, this document says so plainly and describes the honest degradation instead of
faking it.

The guiding principle is **online-prepares → offline-survives**: while connected, the app
caches everything needed at the destination (real OSM map tiles for the trip region, nearby
places with coordinates, the plan, and reservations). When the network drops, the app serves
only that cached/local data and never fabricates results.

### What is genuinely real vs. honestly limited (read this first)

| Capability | Offline? | How it's real | Honest limit |
|---|---|---|---|
| Onboarding, profile, PIN | ✅ | Local secure storage | — |
| Secure ID documents (photo/typed/spoken) | ✅ | Encrypted keystore vault, on-device only | Not real DigiLocker (user adds own doc) |
| Voice/text → destination → confirm | ✅ (text always; voice needs on-device model/pack) | STT + resolver + confirm gate | Voice accuracy is model-dependent; fails safe |
| Transport options (times/prices) | ✅ (cached) | Curated local dataset + booking record | Prototype data, not live IRCTC/bus API |
| Reservation | ✅ | Real on-device booking record + reference | No real money / live seat |
| Journey plan + **pre-cache real OSM tiles** for trip region | ✅ (cached while online) | FMTC downloads real OSM tiles for the area | Needs one-time online window to cache |
| Live location + arrival detection | ✅ | GPS is satellite-based (offline) | — |
| Offline **map display** of destination | ✅ | Cached OSM tiles via flutter_map | — |
| Offline **navigate to hotel/help: direction + distance, spoken** (Level A) | ✅ | GPS + haversine/bearing + offline TTS | Straight-line guidance, not street turns |
| Offline **turn-by-turn "turn left onto X"** (Level B) | ⚠️ NOT offline-practical | Requires a routing engine | No on-device Dart engine exists; see §7 |
| Open documents offline | ✅ | Local encrypted vault | — |
| Dial emergency (100/108/112) | ✅ | Platform dialler, no data needed | — |
| Offline SOS/mesh messaging | ❌ | — | No real on-device mechanism; dial only |

**Level B (spoken street turn-by-turn) is the one thing that cannot be done truthfully
offline** with a practical on-device Dart engine. Real OSM routers (GraphHopper, Valhalla) are
heavy Java/C++ servers; Dart routing packages are online clients. So navigation offline is
**Level A (direction + distance + spoken)**, which is real and useful. Level B, if ever added,
would run only when online (calling a routing service) and is explicitly out of the offline
guarantee.

---

## Architecture

### High-level flow

```
Onboarding ─▶ Secure Profile + Documents (encrypted, on-device)
     │
     ▼
Main screen ─▶ Voice/Text ─▶ Destination Resolver ─▶ Confirm gate
     │                                                   │ (approved)
     │                                                   ▼
     │                                         Transport options (cached data)
     │                                                   │ (user selects)
     │                                                   ▼
     │                                   Journey Plan + Reservation (on-device)
     │                                                   │
     │                          ┌── ONLINE window ───────┤
     │                          ▼                        ▼
     │           Pre-cache: real OSM tiles (FMTC)   Pre-cache: nearby places
     │           for the trip region                (hotels/hospitals/food/
     │                          │                    water/help + coords)
     │                          └──────────┬─────────┘
     ▼                                     ▼
Live tracking (GPS) ─▶ Arrival detection ─▶ notify / offer accommodation
     │
     ▼
NETWORK LOST ─▶ Offline Survival Mode:
     • show real cached map of destination
     • navigate to booked hotel (Level A: direction+distance, spoken)
     • or list nearby help from cached places
     • open ID documents (local)
     • dial emergency (100/108/112)
```

### Layers

- **Presentation (Flutter screens/widgets):** onboarding, profile/documents, listening,
  confirmation, transport options, plan/reservations, journey/map, offline-survival panel.
- **State (Riverpod):** existing providers (travel context, connectivity, orchestrator) plus
  new `journeyProvider` (plan + reservations + cache status).
- **Services (on-device):** existing (STT, TTS, Whisper, resolver, location, connectivity,
  secure vault, agents, model manager) plus new/extended:
  - `JourneyPlanService` — builds + persists the plan, drives pre-caching.
  - `PreCacheService` — orchestrates region tile download (FMTC) + nearby-place caching.
  - `ReservationService` — on-device booking records.
  - `NearbyPlacesRepository` — curated + cached places with coordinates.
  - `TileCacheService` — wraps FMTC region download/serve for `flutter_map`.
- **Storage:** SQLite (structured data: transport, places, reservations, plan), secure
  storage (profile secrets + documents), file system (cached OSM tiles via FMTC store).

---

## Components and interfaces

### 1. Onboarding & profile (Req 1)

- `OnboardingScreen` (multi-step): name, phone, PIN/password, language.
- `ProfileService`:
  - `Future<void> saveProfile(name, phone)` → SQLite (non-secret) / secure storage (secret).
  - PIN stored via `flutter_secure_storage` (hashed/secure; no default PIN — reuses the
    hardened vault-PIN logic already added to `DocumentAgent`).
  - `bool get isOnboarded`, gate on app start; returning users authenticate (PIN/biometric
    via existing `local_auth`).

### 2. Secure documents (Req 2)

- Reuses the existing encrypted `DocumentAgent` vault (keystore-backed, on-device only).
- New input paths:
  - Image: `image_picker`/camera → store bytes encrypted.
  - Typed number → store as document record.
  - Spoken number → STT digit capture → **read back + confirm** → store.
- Viewing requires PIN/biometric; works offline (all local).

### 3. Destination capture + confirm (Req 3) — REUSES existing, safety-critical

- `listening_screen` + `DestinationResolutionService` + confirmation gate are **already built
  and hardened**. The P1 safety rule is preserved: unresolved/garbled input → truthful retry,
  **never** a default/arbitrary destination. This design does not weaken that gate.

### 4. Transport options + selection (Req 4)

- `TransportRepository` (SQLite): routes keyed by (origin region → destination), each with
  mode (bus/train/bus+train), times, indicative price, operator/station names — **curated
  offline dataset**, clearly labelled "indicative".
- `TransportOptionsScreen`: lists options for the confirmed destination; user selects.
- Offline: shows cached options for the planned route; live-only fields marked unavailable.
- If no data for a route: truthful "no transport data for this route" (no invented options).

### 5. Reservation (Req 5)

- `ReservationService`:
  - `Reservation create({type, details})` → SQLite record with a generated confirmation
    reference + timestamp + status; **clearly a prototype booking** (no money/live seat).
  - `List<Reservation> all()`, available offline.
- UI shows a confirmation card labelled "Demo reservation".

### 6. Journey plan + pre-caching (Req 6) — THE CORE

- `JourneyPlanService.build({destination, transport})` → persists a `JourneyPlan`
  (destination, transport choice, created time, cache status).
- `PreCacheService.prepare(plan)` runs while online (prefers WiFi via `ConnectivityService`):
  1. **Real OSM tiles for the trip region** using **FMTC (`flutter_map_tile_caching`)**:
     download a bounded region (destination center + radius, zoom range) from the OSM tile
     server into an FMTC store. This is the real replacement for the dead demo CDN.
  2. **Nearby places** for the destination area (hotels, hospitals, food, water, help
     centres) with coordinates → `NearbyPlacesRepository` (curated dataset for supported
     regions; cached to SQLite). *(Optionally enriched from an online OSM/Overpass query when
     available; if not, curated data is used. Never fabricated.)*
  3. **Route path** (list of LatLng) to the booked/likely accommodation for Level A guidance.
  - Emits progress; records exactly what was cached. Partial cache is used as-is offline with
    a truthful "some data missing" indicator.
- Offline: `PreCacheService` performs **no** network calls; serves only cached stores.

### 7. Navigation — Level A (real, offline) and Level B (honest limit)

- **Level A — Offline spoken guidance (BUILT on existing `NavigationAgent` + `NavMath`):**
  - Inputs: live GPS (`LocationService`) + target coords (booked hotel or chosen nearby
    place, from cache).
  - Output: distance (haversine) + 8-point compass bearing + walk-time estimate, **spoken in
    the selected language via offline TTS** ("Your hotel is 300 metres to the North-East"),
    updating as the user moves. Rendered on the **cached OSM map** with a "you are here" dot,
    destination marker, and a straight guide line.
  - Fully offline. This is the guaranteed navigation experience.
- **Level B — Turn-by-turn street directions:**
  - Requires a routing engine over the road graph. **No practical on-device Dart engine
    exists**; real engines (GraphHopper/Valhalla) are heavy native servers, and Dart routers
    are online clients.
  - Decision: Level B is **NOT part of the offline guarantee**. If added later, it runs
    **only when online** (call a routing service to fetch a step list, optionally cache the
    step list for that one route). When offline or no cached steps exist, navigation cleanly
    falls back to Level A and says so. The app never speaks fabricated turns.

### 8. Live tracking + arrival (Req 7)

- `JourneyTrackingService`: subscribes to `LocationService` stream; computes distance to
  destination; when within an arrival radius → sets arrived state, fires a local notification
  ("You have reached X"), and either offers accommodation (if none booked) or navigation to
  the booked accommodation.
- Background behaviour: uses foreground-service/location where the platform permits; degrades
  to foreground-only updates otherwise (documented, not faked).
- Honest states: permission denied / no GPS fix → truthful status, no fabricated arrival.

### 9. Offline survival mode (Req 8)

- `OfflineSurvivalPanel` (surfaces automatically when `ConnectivityService` = offline during
  an active journey):
  - If accommodation booked → "Navigate to your stay" (Level A) on cached map.
  - Else → list nearby help from `NearbyPlacesRepository` (hospital/food/water/hotel), each
    with Level A guidance.
  - "My documents" → opens encrypted vault (local, offline).
  - "Emergency" → one-tap dial 100/108/112 (platform dialler).
- No live calls offline; everything from cache/local.

### 10. Multilingual + spoken (Req 9)

- Reuses `languageProvider`, `VoiceStrings`, offline `TTSService`. New strings (transport,
  reservation, arrival, offline-survival, guidance phrases like "turn"/"left"/"reached") added
  for HI/TE/EN (others best-effort). Typed input always available in the selected language.

---

## Data models

```
Profile        { name, phone, langCode, pinSet:bool }                    (secure + SQLite)
SecureDocument { id, type, maskedNumber, encryptedBytes|number, addedAt } (encrypted vault)
TransportOption{ id, mode, fromName, toName, depTime, arrTime, priceInr,
                 operator, indicative:true }                              (SQLite, curated)
Reservation    { id, type(transport|stay), refCode, details, status,
                 createdAt, prototype:true }                             (SQLite)
NearbyPlace    { id, category(hotel|hospital|food|water|help), name,
                 coords:LatLng, note, source(curated|cached) }           (SQLite)
JourneyPlan    { id, destinationPlaceId, transportOptionId?, stayResId?,
                 cacheStatus{tiles, places, route}, createdAt }          (SQLite)
```

## Storage & offline strategy

- **SQLite** for all structured records (extends existing `AppDatabase` with tables:
  reservations, nearby_places, journey_plan; transport already/similar exists).
- **Secure storage** for profile secret + documents (existing keystore vault).
- **FMTC tile store** on the file system for real cached OSM tiles.
- **Connectivity gating:** all network work checks `ConnectivityService`; pre-cache prefers
  `online` (WiFi). Offline paths make zero network calls.

## Error handling & truthfulness (Req 10, cross-cutting)

- Every service returns an honest state: `available` / `unavailableOffline` /
  `notCachedYet` / `error(reason)`. UI renders these plainly.
- Prototype/curated data is labelled in the UI.
- Connectivity state is always reflected in the UI banner.
- No default/previous/arbitrary destination or booking is ever substituted (safety gate).
- Personal data stays on-device and encrypted; never transmitted without explicit action.

## Testing strategy (targeted, not the full baseline)

- Unit: `NavMath` (already), reservation ref generation, plan cache-status transitions,
  nearby-place ranking/distance, resolver safety (already), profile PIN rules.
- Widget/logic: transport options render from cache; offline-survival lists from cache;
  arrival detection threshold; confirm gate rejects unresolved (already).
- Offline simulation: connectivity=offline → services serve cache only, no network calls.
- Device (human-operated where needed): pre-cache on WiFi → airplane mode → verify map +
  Level A guidance + documents + dial all work; verify honest "missing"/"unavailable" states.
- Reuse existing 97-test regression for safety/resolution; add only targeted new tests.

## Build/rollout notes

- Add `flutter_map_tile_caching` (FMTC) dependency for real OSM region caching.
- Reuse existing `flutter_map`, `latlong2`, `geolocator`, `flutter_tts`, secure storage,
  sqflite, `image_picker` (add if absent) for document photos.
- Build is release APK (arm64) — subject to the known host-RAM constraint; build in slices.
- Ship in vertical slices (see tasks) so each is demoable and the project never stalls.
