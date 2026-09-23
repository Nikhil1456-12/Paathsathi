# Implementation Plan — PathSaathi Journey Assistant

Build on the EXISTING app. Reuse current services/screens wherever possible (STT, TTS,
Whisper, resolver, confirmation gate, LocationService, ConnectivityService, DocumentAgent
vault, AppDatabase, SmartOfflineMapWidget, NavigationAgent/NavMath). Do NOT rewrite working
code or weaken the destination-confirmation safety gate. Ship in vertical slices; each task
is verifiable with targeted tests + analyze (no full baseline unless a regression appears).

---

- [ ] 1. Data layer foundation (SQLite tables + models)
  - Extend `AppDatabase` with tables: `reservations`, `nearby_places`, `journey_plan`
    (transport table already/similar exists — reuse or extend, don't duplicate).
  - Add Dart models: `Reservation`, `NearbyPlace`, `JourneyPlan` (+ `cacheStatus`), and
    ensure `TransportOption` model exists/curated.
  - Seed a curated offline dataset (real place/route names) for a few supported destinations
    (e.g. Dwaraka, Kedarnath, Varanasi) — transport options + nearby places with coords.
  - _Requirements: 4, 5, 6_

- [ ] 2. Onboarding + secure profile
  - [ ] 2.1 `OnboardingScreen` (name, phone, PIN/password, language); persist non-secret to
        SQLite, PIN to secure storage (reuse hardened no-default-PIN logic). Add `ProfileService`.
  - [ ] 2.2 App-start gate: first run → onboarding; returning user → PIN/biometric unlock
        (reuse `local_auth`); onboarded → main screen. Wire into router.
  - _Requirements: 1_

- [ ] 3. Secure document capture (extend existing vault)
  - [ ] 3.1 Add document input paths to the existing `DocumentAgent` vault: image (gallery/
        camera via `image_picker`), typed number, spoken number (STT digits → read-back →
        confirm). Store encrypted, on-device only.
  - [ ] 3.2 Documents screen: add/view with PIN/biometric; confirm offline viewing works.
  - _Requirements: 2_

- [ ] 4. Transport options + selection
  - [ ] 4.1 `TransportRepository` reading curated SQLite options for the confirmed
        destination; label indicative/prototype.
  - [ ] 4.2 `TransportOptionsScreen`: list options (bus/train/bus+train, times, prices);
        user selects → stored in journey plan. Truthful empty state if no data.
  - _Requirements: 4_

- [ ] 5. Reservation (on-device prototype booking)
  - `ReservationService.create(...)` → SQLite record + generated confirmation reference,
    labelled demo booking; list/view offline. Reservation confirmation UI.
  - _Requirements: 5_

- [ ] 6. Journey plan + pre-caching (CORE) — real OSM tiles + nearby places
  - [ ] 6.1 Add `flutter_map_tile_caching` (FMTC). `TileCacheService` wrapping FMTC region
        download (destination center + radius, zoom range) from the OSM tile server; and
        serving cached tiles to `flutter_map` / `SmartOfflineMapWidget`. Replace the dead
        demo-CDN path in `MapBundleService` usage with real FMTC region caching.
  - [ ] 6.2 `NearbyPlacesRepository` (curated + cached) with coordinates per destination.
  - [ ] 6.3 `JourneyPlanService.build(...)` + `PreCacheService.prepare(plan)`: on WiFi,
        cache tiles + nearby places + route path; emit progress + honest cacheStatus; partial
        cache usable offline with "missing" indicator; zero network calls when offline.
  - _Requirements: 6_

- [ ] 7. Live tracking + arrival detection
  - `JourneyTrackingService` on `LocationService` stream: compute distance to destination;
    arrival radius → local notification "You have reached X"; offer accommodation if none
    booked, else offer navigation to booked stay. Honest states for no-permission/no-fix.
  - _Requirements: 7_

- [ ] 8. Offline navigation Level A (spoken direction + distance) on cached map
  - Extend existing `NavigationAgent`/`NavMath`: given GPS + target coords (booked hotel or
    chosen nearby place), speak distance + compass bearing + walk-time in the selected
    language (offline TTS), updating on movement; render on `SmartOfflineMapWidget` with
    user dot + destination marker + guide line. (Level B turn-by-turn is out of offline
    scope per design — cleanly absent, never faked.)
  - _Requirements: 8, 9_

- [ ] 9. Offline survival mode panel
  - `OfflineSurvivalPanel` shown when offline during an active journey: navigate to booked
    stay (Level A) OR list nearby help (hospital/food/water/hotel) with Level A guidance;
    "My documents" (local vault); "Emergency" one-tap dial 100/108/112. No network calls.
  - _Requirements: 8_

- [ ] 10. Multilingual strings + spoken responses
  - Add HI/TE/EN strings for transport, reservation, arrival, offline-survival, and guidance
    words (turn/left/right/reached/nearby) to `VoiceStrings`; wire offline TTS for new spoken
    responses; ensure typed input path available throughout.
  - _Requirements: 9_

- [ ] 11. Wire the end-to-end journey flow + honest connectivity UI
  - Connect: main screen → voice/text → confirm → transport → reserve → plan+precache →
    tracking → arrival → offline-survival. Add a global connectivity banner reflecting true
    online/offline. Ensure the confirmation safety gate is untouched.
  - _Requirements: 3, 6, 7, 10_

- [ ] 12. Targeted verification
  - Unit/logic tests: reservation ref, plan cacheStatus transitions, nearby-place distance/
    ranking, arrival threshold, profile PIN rules (reuse NavMath + resolver + confirm tests).
  - Offline simulation: connectivity=offline → services serve cache only, no network calls.
  - `flutter analyze` on changed files. Rerun existing safety/resolution regression suite.
  - _Requirements: all_

- [ ] 13. Device build + guided offline verification (when host RAM permits)
  - Build arm64 release APK (set JAVA_HOME; free RAM; split-per-abi), install to c3780eb2.
  - Pre-cache a trip on WiFi → airplane mode → verify: cached map shows, Level A spoken
    guidance works, nearby help lists, documents open, emergency dial works, honest
    "unavailable/missing" states appear. Record PASS/FAIL/UNKNOWN honestly; stop on any P1
    (wrong/default destination) safety failure.
  - _Requirements: all_
```
