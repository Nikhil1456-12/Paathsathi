# PathSaathi — Honest Drawbacks & Limitations Analysis
*For FYP evaluation transparency and professor review*

---

## Severity Legend
| Level | Meaning |
|---|---|
| 🔴 Critical | Could fail the project or demo |
| 🟠 Major | Significant impact, needs careful handling |
| 🟡 Moderate | Noticeable limitation, manageable |
| 🟢 Minor | Small issue, easy to workaround |

---

## Category 1 — Hardware & Device Limitations

### 🔴 Drawback 1: Huge Storage Requirement (~3.1 GB)

```
Problem:
  Whisper ASR:          ~150 MB
  Phi-3 Mini (4-bit):   ~2.0 GB   ← This alone is massive
  MobileBERT NLU:        ~60 MB
  MiniLM Embedding:      ~90 MB
  Coqui TTS (3 langs):  ~200 MB
  Offline Maps:         ~500 MB
  SQLite Event Data:     ~50 MB
  ─────────────────────────────
  TOTAL:               ~3.1 GB

Reality Check:
  ❌ Budget Android phones (2GB RAM): Cannot run Phi-3 Mini at all
  ❌ Old phones with 16GB storage: Nearly 20% of storage used
  ✅ Mid-range phones (4-6 GB RAM, 64GB+ storage): Works fine
  
  But majority of pilgrims at Kumbh Mela use budget phones!
  This is a serious contradiction with the target audience.
```

**Mitigation:**
- Use Gemma 2B (smaller) instead of Phi-3 Mini 3.8B
- Offer "Lite Mode" with smaller models for low-end devices
- Allow selective module download (e.g., skip navigation if not needed)
- Set minimum device requirement clearly: 4GB RAM, 32GB storage

---

### 🔴 Drawback 2: Battery Drain from On-Device AI

```
Problem:
  Running a quantized LLM on a phone CPU is extremely power-intensive.
  
  Estimated battery usage per query:
    Whisper ASR (10s audio):  ~2-3% battery
    MobileBERT NLU:           ~0.5% battery
    Phi-3 Mini inference:     ~3-5% battery
    TTS generation:           ~1% battery
    One complete query:       ~6-9% battery drain
  
  That means:
    ~11-16 queries before 100% battery is consumed
    At a pilgrimage lasting many hours — this is a problem
```

**Mitigation:**
- Cache frequent query responses (don't re-run LLM for same question)
- Show battery warning in app if below 20%
- Recommend portable power bank as part of pre-trip checklist
- Use NPU/GPU acceleration where available (reduces power by ~40%)

---

### 🟠 Drawback 3: Inference Speed on Budget Phones

```
Problem:
  Phi-3 Mini 4-bit on Snapdragon 680 (budget phone):
    First token latency:  ~8-15 seconds
    Full response:        ~25-40 seconds
  
  Phi-3 Mini 4-bit on Snapdragon 8 Gen 2 (flagship):
    First token latency:  ~1-2 seconds
    Full response:        ~5-8 seconds
  
  A 40-second wait for a lost elderly pilgrim is unacceptable.
```

**Mitigation:**
- Pre-compute answers for common queries (FAQ caching)
- Show "thinking..." animation with partial streaming output
- Use smaller models (TinyLlama 1.1B) for simple intents
- Reserve Phi-3 Mini only for complex multi-agent tasks

---

## Category 2 — AI & Model Limitations

### 🔴 Drawback 4: LLM Hallucination Risk

```
Problem:
  Even with RAG, the Phi-3 Mini LLM can "hallucinate" — 
  generate confident but completely wrong information.
  
  Dangerous scenarios:
  ❌ "Bus 47 departs at 6 AM" — but actual time is 8 AM
  ❌ "The hospital is at Gate 5" — but it's at Gate 12
  ❌ "Your camp is in Sector 7" — but it's actually Sector 12
  
  For a pilgrim in an unfamiliar location, wrong directions
  or wrong medical info can be genuinely dangerous.
```

**Mitigation:**
- Never let LLM generate transport/location data from memory
- ALWAYS retrieve from SQLite database directly — LLM only formats the response
- Add "Verify at information booth" disclaimer for critical info
- Use confidence scoring — if RAG retrieval confidence is low, say "I'm not sure, please verify"

---

### 🟠 Drawback 5: ASR Accuracy in Noisy Crowds

```
Problem:
  Kumbh Mela environment:
    ✗ 100+ dB crowd noise
    ✗ Religious chanting in background
    ✗ PA announcements overlapping
    ✗ River/water sounds near ghats
  
  Whisper tiny ASR was trained on clean speech.
  Word Error Rate (WER) jumps from ~10% (quiet) to ~35-40% (crowd noise)
```

**Mitigation:**
- Add noise suppression preprocessing (RNNoise — runs on device)
- Use directional microphone mode (phone held close to mouth)
- Show transcribed text on screen so user can correct if wrong
- Add "Did you mean...?" confirmation before executing actions
- Provide text input as fallback option

---

### 🟠 Drawback 6: Dialect & Regional Variation

```
Problem:
  "Hindi" is not one language. It has major regional dialects:
    • Bhojpuri (Bihar/UP)       — Very different from standard Hindi
    • Awadhi (Lucknow/Ayodhya) — Kumbh Mela region dialect!
    • Maithili (Mithila)        — Different vocabulary entirely
  
  Whisper tiny is trained on "standard" Hindi (Delhi dialect).
  A Bhojpuri-speaking pilgrim from Bihar may not be understood.
  Same problem exists for Tamil and Telugu regional accents.
```

**Mitigation:**
- Test with native speakers from different regions during development
- Use Whisper Small (better accuracy) if storage allows
- Train fine-tuned adapters on Bhojpuri/Awadhi data (open datasets exist)
- Provide manual correction UI as fallback

---

## Category 3 — Data & Content Limitations

### 🟠 Drawback 7: Pre-Downloaded Data Becomes Stale

```
Problem:
  Pre-trip download happens 7 days before travel.
  But during the event:
    ❌ Bus route 47 gets cancelled — app still shows it
    ❌ Camp allotment changes — app has old assignment
    ❌ New flood advisory issued — app doesn't know
    ❌ A ghat is closed — app still navigates there
  
  Without internet, the app cannot know about these changes.
  Stale data can actively mislead pilgrims.
```

**Mitigation:**
- Add "Data last updated: [timestamp]" warning on every screen
- Design sync to run opportunistically (any WiFi hotspot, even 30 seconds)
- Mark time-sensitive data (schedules) with expiry flags
- Safety Agent always defaults to "go to nearest information booth"

---

### 🟡 Drawback 8: Crowd Prediction Accuracy

```
Problem:
  Pre-downloaded crowd predictions are based on historical data.
  Actual crowd patterns may differ due to:
    • Unexpected weather changes
    • Celebrity/religious leader visits causing surges
    • Stampede-related re-routing
    • Last-minute schedule changes by authorities
```

**Mitigation:**
- Mark crowd predictions as "estimates based on historical data"
- Never use crowd prediction alone — combine with Safety Agent advisory
- Allow volunteers to push real-time updates via local WiFi mesh

---

## Category 4 — Security Limitations

### 🟠 Drawback 9: What Happens if Phone is Lost?

```
Problem:
  If the phone is lost at Kumbh Mela:
    ❌ Pilgrim loses access to their ID, tickets, certificates
    ❌ Thief may attempt to access documents (brute force biometric)
    ❌ No remote wipe capability (we're offline-first!)
  
  Many pilgrims may carry documents ONLY in digital form.
```

**Mitigation:**
- Implement remote wipe trigger that executes when internet returns
- Auto-lock after 3 failed biometric attempts
- Advise users to keep physical document copies as backup
- Store emergency contact info in non-encrypted quick-access area

---

### 🟡 Drawback 10: OAuth Token Expiry Offline

```
Problem:
  OAuth 2.0 tokens expire (typically 1-24 hours).
  If the pilgrim is offline for 3+ days:
    → Access tokens expire
    → Refresh tokens may also expire
    → Cannot re-authenticate offline
    → Document Agent sync breaks
```

**Mitigation:**
- Cache documents locally at setup time — not dependent on token for viewing
- Use long-lived refresh tokens (request extended scope from DigiLocker)
- Warn user before trip: "Your document access valid for 30 days offline"

---

## Category 5 — Development Complexity

### 🔴 Drawback 11: Flutter Platform Channels are Very Complex

```
Problem:
  Running llama.cpp (C++) and ONNX Runtime from Flutter (Dart)
  requires writing Platform Channels in:
    • Kotlin/Java for Android
    • Swift/Objective-C for iOS
  
  This requires knowledge of:
    → Flutter + Dart
    → Android native (Kotlin)
    → C++ FFI / JNI bindings
    → AI model integration
  
  For a student team in 22 weeks — extremely risky.
  One integration failure can block the entire project.
```

**Mitigation:**
- Use MediaPipe LLM Inference API (official Google Flutter plugin — much simpler!)
- Use flutter_whisper package (community wrapper already exists)
- Start with Chaquopy (Python in Android) for prototype — migrate to native later

---

### 🟠 Drawback 12: On-Device Model Compatibility Issues

```
Problem:
  Not all quantized models work on all Android devices.
  
  Issues in practice:
    ❌ ONNX Runtime version conflicts between models
    ❌ llama.cpp needs recompilation for specific CPU architectures
       (ARM v7 vs ARM v8 vs x86 emulator)
    ❌ Some quantization formats not supported on older Android
    ❌ iOS has different requirements than Android
```

**Mitigation:**
- Lock all library versions in pubspec.yaml / build.gradle
- Test on minimum 3 physical devices (low/mid/high end)
- Use pre-tested model bundles from MediaPipe model card page

---

### 🟠 Drawback 13: Testing is Extremely Difficult

```
Problem:
  How do you test an offline multilingual voice AI app?
    ❌ Cannot use standard Flutter tests for AI responses
    ❌ ASR output varies each run — non-deterministic
    ❌ LLM responses are non-deterministic
    ❌ BLE Mesh testing requires multiple physical devices
    ❌ Offline scenario testing is hard to automate
```

**Mitigation:**
- Mock all AI components behind interfaces during unit testing
- Create a "test mode" with pre-recorded audio inputs
- Use fixed random seeds for LLM during testing
- Build evaluation scripts to measure ASR WER and NLU accuracy separately

---

## Category 6 — User Experience Limitations

### 🟡 Drawback 14: First-Time Setup is Burdensome

```
Problem:
  The pre-trip setup requires:
    → 3.1 GB download (needs good WiFi + significant time)
    → Uploading personal documents (privacy concern for some)
    → Creating a profile (non-tech users struggle)
  
  Many elderly pilgrims will need family assistance for setup.
  This contradicts the "non-technical user" evaluation criterion.
```

**Mitigation:**
- Create a guided setup wizard with voice instructions
- Offer "family setup mode" — family member sets up on behalf of pilgrim
- Reduce download size by offering "Essential Pack" (smaller models)
- Partner with event organizers to pre-install at registration counters

---

### 🟡 Drawback 15: Multi-Language / Dialect Switching Mid-Conversation

```
Problem:
  What happens if a pilgrim mixes languages mid-query?
  "मुझे bus station जाना है, nearest wala" (Hindi + English mix)
  
  Language detection may fail or flip, causing TTS to behave
  inconsistently — speaking in the wrong language.
```

**Mitigation:**
- Set language preference once in profile — lock it for the session
- Add explicit language toggle button on main screen
- Train NLU on code-mixed Hindi-English data (very common)

---

## Category 7 — Scope & Demo Risks

### 🟠 Drawback 16: Demo Environment vs Real Environment Gap

```
Problem:
  FYP demos happen in a controlled classroom:
    ✅ Quiet room, clear microphone input
    ✅ Known test queries prepared in advance
    ✅ Fast phone used for demo
  
  Real Kumbh Mela environment:
    ❌ 100dB+ noise
    ❌ Unknown queries from real users
    ❌ Budget phones with 2GB RAM
    ❌ Battery draining fast
  
  There is a large gap between demo success and real-world success.
```

**Mitigation:**
- Test in genuinely noisy environments (market, crowded canteen)
- Show video evidence of testing in real conditions to evaluators
- Prepare honest "limitations" slide in presentation

---

## Final Risk Summary Table

| # | Drawback | Severity | Fixable? |
|---|---|---|---|
| 1 | 3.1 GB storage / low-end phone | 🔴 Critical | Partially |
| 2 | Battery drain from on-device AI | 🔴 Critical | Partially |
| 3 | Slow inference on budget phones | 🟠 Major | Yes |
| 4 | LLM hallucination risk | 🔴 Critical | Yes |
| 5 | ASR accuracy in noisy crowd | 🟠 Major | Yes |
| 6 | Dialect and regional variation | 🟠 Major | Partially |
| 7 | Pre-downloaded data becomes stale | 🟠 Major | Partially |
| 8 | Crowd prediction accuracy | 🟡 Moderate | Partially |
| 9 | Phone loss / security | 🟠 Major | Yes |
| 10 | OAuth token expiry offline | 🟡 Moderate | Yes |
| 11 | Platform channel complexity | 🔴 Critical | Yes (MediaPipe) |
| 12 | Model compatibility issues | 🟠 Major | Yes |
| 13 | Testing difficulty | 🟠 Major | Yes |
| 14 | Setup burden for non-tech users | 🟡 Moderate | Yes |
| 15 | Language switching mid-query | 🟡 Moderate | Yes |
| 16 | Demo vs real environment gap | 🟠 Major | Partially |

---

## The 3 Most Critical Issues to Solve First

```
PRIORITY 1 — Hallucination Prevention
  Rule: LLM never invents factual data (transport, locations)
  Rule: LLM only formats data from SQLite/RAG — never generates it
  Rule: Low-confidence answers always say "please verify"

PRIORITY 2 — Low-End Phone Support  
  Use Gemma 2B or TinyLlama for budget devices
  Test on ₹8,000-₹12,000 phones (real target audience phones)
  Offer "Lite Mode" with smaller models

PRIORITY 3 — Platform Channel Complexity
  Use MediaPipe Flutter plugin instead of raw llama.cpp
  Reduces 3 months of native Android work to 2 weeks
  Community has working Flutter + MediaPipe LLM demos
```

---

*Drawbacks Analysis v1.0 | PathSaathi FYP*
*Being honest about limitations is a sign of engineering maturity*
