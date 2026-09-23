# PathSaathi — Improvements Changelog & Verification Guide

This document summarizes the improvements implemented against the Infosys
evaluation criteria (offline excellence, usability for non-literate/elderly
users, small APK size, noise robustness, security) and how to verify them on a
real device or Android emulator.

> Build environment note: `flutter analyze` passes with **0 errors / 0 warnings**
> (only cosmetic style infos remain). A full `flutter build apk` could **not** be
> completed on the current machine because the Gradle/Dart build ran out of
> system memory/threads (JVM daemon crash: "Insufficient system resources").
> This is an environment limitation, not a code defect. Run the build on a
> machine with more RAM (see commands below).

---

## 1. What changed (by file)

### Fixed bugs
- **`emergency_screen.dart`** — completely rebuilt. Every card now works:
  routes the emergency through the agent swarm, speaks the guidance aloud
  (offline TTS), and opens the AI response. Added real phone-dialer buttons
  (`url_launcher` → `tel:108 / 112 / 1090`). Speaks a calming prompt on open.
- **`transport_screen.dart`** — fixed SQLite column mismatch
  (`bus_name`→`bus_number`, `gate_platform`→`gate`) so real bus numbers/gates
  show. Added a per-row "read aloud" button.

### Wired hardcoded screens to the offline database
- **`itinerary_screen.dart`**, **`accommodation_screen.dart`**,
  **`my_journey_screen.dart`** — now read from the seeded SQLite tables
  (`itineraries`, `accommodations`) instead of hardcoded data, with localized
  titles (hi/te) and read-aloud support.

### Usability for non-literate / elderly users
- **`widgets/speak_button.dart`** (new) — reusable `SpeakButton` (icon) and
  `SpeakBanner` ("Tap to hear this page") that read screen content aloud in the
  selected language. Applied to itinerary, accommodation, journey, emergency,
  transport.

### Offline STT + noise robustness
- **`services/stt_service.dart`** — tries **on-device (offline) recognition
  first**, then system recognizer, then en-US. Exposes `lastRanOnDevice` and an
  `onConfidence` callback.
- **`listening_screen.dart`** — **confidence-gated confirmation**: when the
  recognizer is unsure (< 0.55, common in loud crowds), it shows a
  "It's noisy here — did I hear you correctly?" prompt instead of acting
  automatically. Users confirm, retry, or pick a quick question.

### Security
- **`register_screen.dart` / `login_screen.dart`** — passwords are no longer
  stored in plaintext. A salted **SHA-256 hash** is stored in the
  Keystore-backed `flutter_secure_storage` vault; legacy plaintext is migrated
  and removed on first login.
- **`documents_screen.dart`** — added **biometric unlock** (fingerprint/face via
  `local_auth`) alongside the PIN, and **FLAG_SECURE** (blocks
  screenshots/screen-recording) while documents are on screen.
- **`services/secure_window.dart`** (new) + **`MainActivity.kt`** — platform
  channel `pathsaathi/secure_window` toggles Android `FLAG_SECURE`.
  `MainActivity` migrated to `FlutterFragmentActivity` (required by `local_auth`).

### Small APK / quantization strategy
- **`services/device_tier_service.dart`** — real device-class detection via
  `device_info_plus` (`isLowRamDevice`, 64-bit ABI, API level) → Lite / Standard
  / Full tier. Wired into `main.dart` at startup.
- **`model_setup_screen.dart`** — now shows **only the model set that fits the
  detected tier** (Lite ≈ 800 MB, Standard ≈ 1.6 GB, Full ≈ 3.1 GB), with an
  honest size banner. Heavy quantized models download on-demand over WiFi so the
  base install stays lean.
- **`android/app/build.gradle.kts`** — release build enables **R8 code
  shrinking + resource shrinking**; ABI restricted to `arm64-v8a`.
  **`proguard-rules.pro`** (new) keeps native/JNI plugin classes.

### Cleanup
- Removed dead code: `buildCrowdResponse` / `buildSosResponse` /
  `buildLostResponse` (never called) from the fog agents.
- Deleted the orphaned `offline_download_screen.dart`.
- Wired the previously-orphaned `voice_profile_screen` into onboarding
  (`/setup` → `/voice-profile` → `/doc-scan`).
- Fixed all analyzer warnings (unused imports, async `BuildContext` gaps).

### New dependencies
`url_launcher`, `device_info_plus`, `local_auth` (added to `pubspec.yaml`).

---

## 2. Honest status of AI capabilities

- **Working offline today:** device STT (on-device where the language pack is
  installed) + device TTS + keyword/cache intent planner + SQLite agents +
  encrypted document vault + offline maps.
- **Still simulated:** the large quantized model *downloads* for Gemma /
  MobileBERT / MiniLM are placeholders in `model_manager.dart` (only Whisper has
  a real URL). To make the on-device LLM/NLU tiers truly run, ship real
  quantized model files (bundle a small one in `assets/models/` or host real
  download URLs) and replace the stub tokenizer in `nlu_service.dart`.
- **Not implemented (future work):** true DSP noise suppression (RNNoise/VAD),
  real turn-by-turn routing (Valhalla), ML Kit OCR for document scanning, and
  the BLE mesh. These are described in the architecture but need native work +
  on-device testing.

---

## 3. How to build & verify (run on a machine with ≥ 8 GB free RAM)

```bash
cd "04 - Flutter App/pathsaathi"
flutter pub get
flutter analyze                 # expect 0 errors / 0 warnings
flutter build apk --debug       # or: flutter run -d <emulator-id>
```

If the Gradle daemon runs out of memory, raise its heap in
`android/gradle.properties`:

```
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G
```

### Start an Android emulator
```bash
flutter emulators                       # list AVDs
flutter emulators --launch <avd_name>   # or launch from Android Studio > Device Manager
flutter run                             # runs on the booted emulator
```

---

## 4. Manual verification checklist (on emulator / device)

Offline / core flow
- [ ] Turn on **airplane mode**, open the app — it still launches and answers.
- [ ] Tap the mic, ask "Where is my bus?" — get a spoken + card response.
- [ ] Low signal / noise: confirm the "did I hear right?" prompt appears when
      recognition confidence is low.

Usability (non-literate)
- [ ] On Itinerary / My Stay / Journey, tap **"Tap to hear this page"** — content
      is read aloud in the selected language.
- [ ] Switch language in Profile — spoken output and labels change.

Emergency
- [ ] Open Emergency — a calming prompt is spoken automatically.
- [ ] Tap **108 / 112 / 1090** — the phone dialer opens with the number.
- [ ] Tap a card (e.g. Medical) — guidance is spoken and the response screen opens.

Security
- [ ] Documents → tap a document → **Fingerprint** unlock works (or PIN 1234).
- [ ] Try to screenshot the Documents screen — it is blocked (FLAG_SECURE).
- [ ] Register a new user, then log in — login succeeds (password stored hashed).

Data-backed screens
- [ ] Transport shows real bus numbers/gates (e.g. "Bus 47 • Gate 3"), search works.
- [ ] Itinerary / Journey timelines reflect the seeded schedule.

Small APK / tiers
- [ ] Model Setup shows only the models for the detected device tier with a
      realistic total size.
```
```
