---
inclusion: fileMatch
fileMatchPattern: 'lib/services/stt_service.dart|lib/services/tts_service.dart|lib/services/nlu_service.dart|lib/services/whisper_service.dart|lib/services/llm_service.dart|lib/core/voice_strings.dart|lib/providers/language_provider.dart|lib/screens/listening_screen.dart|lib/screens/speech_test_screen.dart|lib/screens/voice_profile_screen.dart'
---

# Voice AI Rules

Applies when working on STT / TTS / NLU / voice-confirmation code. Reuse the
existing services and centralized strings; do not add parallel voice pipelines.

## STT / TTS architecture
- STT tries **on-device (offline) recognition first**, then the system
  recognizer, then en-US (`stt_service.dart`, exposes `lastRanOnDevice` and an
  `onConfidence` callback). Preserve this fallback order.
- TTS uses the Android device engine (`flutter_tts`) for hi/te/ta/pa/mr/en.
- Offline STT/TTS quality depends on the device's installed language packs —
  never assume a pack is present.

## Selected-language propagation
- The selected language (`language_provider.dart`) controls user-facing voice
  and UI output (invariant I8). All spoken/displayed voice strings go through
  `VoiceStrings` in `lib/core/voice_strings.dart`.
- Changing language SHALL NOT change the destination or trip context
  (invariant I3).

## Multilingual + unsupported languages (truthful)
- `VoiceStrings` falls back to English when a language string is missing. This
  fallback is explicit and acceptable — but never silently pretend an
  unsupported language is fully supported.
- Add new-language strings in `VoiceStrings`; do not hardcode user-facing voice
  text inline in screens/services.

## Voice confirmation rules
- Confirmation is confidence-gated: when recognition confidence is low
  (noisy crowd), show the "did I hear you correctly?" prompt instead of acting
  automatically (`listening_screen.dart`). Keep multilingual yes/no detection
  intact — it is covered by the baseline adversarial tests.

## No fabricated AI responses
- On-device LLM/NLU models are currently placeholders (only Whisper has a real
  URL). Do not make placeholder models appear to answer. If a model isn't
  present, report the honest state — never invent an AI answer, destination, or
  confidence. See #[[file:IMPROVEMENTS_AND_VERIFICATION.md]]

## Global voice assistant behavior
- Voice behavior must be consistent across screens (speak button / banner in
  `widgets/speak_button.dart`), always in the selected language, always
  offline-capable, never presenting fabricated or live-only content while
  offline. Invariants: #[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]
