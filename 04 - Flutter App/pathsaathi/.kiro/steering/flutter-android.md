---
inclusion: fileMatch
fileMatchPattern: 'lib/**|android/**|pubspec.yaml|analysis_options.yaml'
---

# Flutter / Android Rules

Applies when working in Flutter/Android code. Keep changes minimal and aligned
with the existing patterns already in `lib/`.

## Architecture conventions
- State: Riverpod (`flutter_riverpod`). Providers live in `lib/providers/`.
- Routing: `go_router` via `lib/core/router.dart`.
- Services are singletons under `lib/services/` (e.g. `LocationService.instance`);
  screens stay thin and read from providers/services.
- Agents live under `lib/agents/` (7-agent orchestrator + fog agents). Reuse the
  orchestrator; do not add parallel architectures.
- Reuse existing helpers/services before adding new ones.

## Android lifecycle
- App must survive: clean launch, rapid relaunch, background→foreground,
  force-stop→relaunch, offline launch, and offline restart.
- Persisted travel state and selected language must be restored on restart; only
  the CONFIRMED destination is restored (never a pending guess). See invariants
  I1, I2, I9 in the reliability spec.

## Permissions
- Location via `geolocator` + `permission_handler`; handle granted / denied /
  permanently-denied truthfully (mirror `GpsState` in `location_service.dart`).
- Microphone via `permission_handler` for STT.
- Biometric/secure via `local_auth` + `flutter_secure_storage`; documents use
  FLAG_SECURE (`services/secure_window.dart`). Do not weaken these.

## ADB / device testing
- Voice/in-canvas flows can't be driven by ADB/uiautomator (single Flutter
  canvas). Cover voice/state correctness with logic tests; use the device
  harness for lifecycle/persistence/GPS/network/crash. See reliability
  Requirement 2.

## Build rules
- Release: R8 code + resource shrinking; ABI restricted to `arm64-v8a`
  (`android/app/build.gradle.kts` + `proguard-rules.pro`).
- **Do NOT auto-run `flutter build apk`** — known Gradle/JVM memory limit on this
  machine. Build manually on a machine with ≥8 GB free RAM.
- `flutter analyze` must stay at 0 errors / 0 warnings.

## Performance & memory
- Device-tier detection (`device_tier_service.dart`) sizes models Lite/Standard/
  Full; only offer the model set that fits the detected tier.
- Watch PSS/memory trend on device (soak remains an UNKNOWN until verified).

## Offline-first
- Core features must work fully offline; never present live data as available
  while offline (invariant I7). Details:
  #[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]
  and #[[file:IMPROVEMENTS_AND_VERIFICATION.md]]
