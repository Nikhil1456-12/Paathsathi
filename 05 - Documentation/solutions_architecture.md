# PathSaathi — Solutions & Mitigations Architecture
### Engineering Solutions for All 16 Identified Drawbacks
*FYP Documentation | Infosys Problem Statement 2*

---

## Solutions Overview Map

| Drawback | Solution Architecture |
|---|---|
| 🔴 Storage (3.1GB) + Battery drain + Slow inference | **Solution 1: Adaptive Device Tier System** |
| 🔴 LLM Hallucination | **Solution 2: Hallucination-Free Data Pipeline** |
| 🟠 Noisy crowd ASR | **Solution 3: Noise-Robust ASR Pipeline** |
| 🟠 Dialect variation | **Solution 4: Dialect-Adaptive NLU Layer** |
| 🟠 Stale offline data | **Solution 5: Smart Data Freshness Engine** |
| 🟠 Phone lost + OAuth expiry | **Solution 6: Device Security & Recovery System** |
| 🔴 Platform channel complexity | **Solution 7: MediaPipe Simplified Integration** |
| 🟠 Testing difficulty | **Solution 8: Offline AI Testing Framework** |
| 🟡 Setup burden + Language switching | **Solution 9: Progressive Setup & Adaptive UX** |

---

## Solution 1 — Adaptive Device Tier System
*Fixes: Storage (3.1GB), Battery Drain, Slow Inference on Budget Phones*

### Core Idea
Instead of one fixed set of models for all devices, detect the device
capability at install time and download the appropriate model tier.

```mermaid
flowchart TD
    INSTALL["📱 App First Launch"]
    DETECT["🔍 Device Capability Detection\nCheck: RAM, Storage, CPU cores\nCheck: Has NPU/GPU?\nCheck: Android version"]

    DETECT --> T1{"Device\nTier?"}

    T1 -->|"RAM ≥ 6GB\nStorage ≥ 64GB\nSnapdragon 7/8 series"| TIER1["🟢 TIER 1: Full Mode\n\nLLM: Phi-3 Mini 3.8B (4-bit)\nASR: Whisper Small (int8)\nTTS: High-quality Coqui\nMaps: Full region tiles\nSize: ~3.1 GB\n\nExpected response: 3-6 sec"]

    T1 -->|"RAM 3-6GB\nStorage 32-64GB\nMid-range SoC"| TIER2["🟡 TIER 2: Standard Mode\n\nLLM: Gemma 2B (4-bit)\nASR: Whisper Tiny (int8)\nTTS: Standard MMS-TTS\nMaps: Event area only\nSize: ~1.6 GB\n\nExpected response: 6-12 sec"]

    T1 -->|"RAM < 3GB\nStorage < 32GB\nBudget SoC"| TIER3["🔴 TIER 3: Lite Mode\n\nLLM: TinyLlama 1.1B (4-bit)\nASR: Whisper Tiny (int8)\nTTS: eSpeak-NG (basic)\nMaps: Core zones only\nSize: ~800 MB\n\nExpected response: 10-20 sec"]

    TIER1 & TIER2 & TIER3 --> CACHE["🗄️ Response Cache Layer\nCache top 100 most common\nqueries per agent\nNo LLM re-run for cached results\nReduces battery use by ~60%"]

    CACHE --> BATTERY["🔋 Battery Awareness Module\n> 50%: Full inference mode\n20-50%: Cached responses priority\n< 20%: Emergency-only mode\nCritical alert shown to user"]
```

### Response Cache Architecture
```mermaid
flowchart LR
    QUERY["User Query\n(embedded vector)"]
    CACHE_DB["📦 Response Cache\nSQLite table:\ncached_responses\n- query_hash\n- response_text\n- tts_audio_file\n- timestamp\n- hit_count"]

    SIMILAR["Similarity Check\nCosineSimilarity > 0.92?\n→ Cache Hit\n→ Skip LLM entirely"]

    LLM_PATH["🧠 LLM Inference\n(only if cache miss)"]
    STORE["Store response\nin cache for\nfuture queries"]

    QUERY --> CACHE_DB
    CACHE_DB --> SIMILAR
    SIMILAR -->|"Cache Hit ✅"| PLAY["▶️ Play cached\nTTS audio directly\nResponse time: <1 sec"]
    SIMILAR -->|"Cache Miss"| LLM_PATH
    LLM_PATH --> STORE --> PLAY
```

### Battery Management State
```mermaid
stateDiagram-v2
    [*] --> FullMode: Battery > 50%

    FullMode: ⚡ FULL MODE
    FullMode: All AI models active
    FullMode: Full LLM inference
    FullMode: High-quality TTS
    FullMode: Real-time map rendering

    FullMode --> EcoMode: Battery drops to 20%

    EcoMode: 🟡 ECO MODE
    EcoMode: Cache-first responses
    EcoMode: Reduced TTS quality
    EcoMode: Map tiles pre-loaded only
    EcoMode: Background sync paused

    EcoMode --> EmergencyMode: Battery drops to 10%

    EmergencyMode: 🔴 EMERGENCY MODE
    EmergencyMode: Only Safety Agent active
    EmergencyMode: Only emergency contacts shown
    EmergencyMode: BLE mesh still active
    EmergencyMode: All non-critical AI off

    EmergencyMode --> EcoMode: Charging detected
    EcoMode --> FullMode: Battery > 50%
```

---

## Solution 2 — Hallucination-Free Data Pipeline
*Fixes: LLM Hallucination Risk (most critical safety issue)*

### The Golden Rule
```
❌ WRONG approach:
   User: "What time does the bus to Prayagraj leave?"
   LLM:  Thinks... "I'll say 6 AM" ← HALLUCINATION RISK!

✅ CORRECT approach:
   User: "What time does the bus to Prayagraj leave?"
   System: Query SQLite → Gets "Bus 47: 06:00 AM, Gate 3"
   LLM:  Formats ONLY: "Bus number 47 leaves at 6 AM from Gate 3"
         LLM never invents — only formats retrieved facts
```

### Architecture: Grounded Response System

```mermaid
flowchart TD
    INTENT["🎯 Planner Output\n{intent, entities}"]

    INTENT --> ROUTER{"Data Source\nRouter"}

    ROUTER -->|"transport query"| SQL_T["SQLite Query\nSELECT * FROM transport\nWHERE dest=? AND date=?\nReturns: structured rows"]

    ROUTER -->|"accommodation query"| SQL_A["SQLite Query\nSELECT * FROM lodging\nWHERE user_id=?\nReturns: structured rows"]

    ROUTER -->|"personal info query"| RAG_P["LanceDB RAG Search\nVector similarity search\nReturns: text chunks\n+ confidence score"]

    ROUTER -->|"general FAQ query"| RAG_F["LanceDB RAG Search\nFAQ + policy documents\nReturns: text chunks\n+ confidence score"]

    SQL_T & SQL_A --> GROUNDED["✅ Grounded Context\n100% verified facts\nfrom structured DB"]

    RAG_P & RAG_F --> CONFIDENCE{"Confidence\nScore Check"}

    CONFIDENCE -->|"Score > 0.75\n✅ High confidence"| GROUNDED
    CONFIDENCE -->|"Score 0.5-0.75\n⚠️ Medium confidence"| PARTIAL["Add disclaimer:\n'Based on available info,\nbut please verify'"]
    CONFIDENCE -->|"Score < 0.5\n❌ Low confidence"| FALLBACK["Safe Fallback:\n'I don't have reliable\ninfo on this. Please\nvisit info booth at\nGate 2 or Gate 7'"]

    GROUNDED --> LLM_FORMAT["🧠 Phi-3 Mini\nFORMAT ONLY\n\nSystem Prompt:\n'You are a formatter.\nOnly use the FACTS below.\nNEVER add information\nnot in the context.'\n\nContext: {grounded facts}\nTask: Format as friendly Hindi response"]

    PARTIAL --> LLM_FORMAT
    FALLBACK --> SAFE_RESPONSE["🔒 Safe Response\nNo LLM involved\nPre-written safe message"]

    LLM_FORMAT --> VERIFY["🔍 Post-Generation\nVerification\nCheck: Does response contain\nonly facts from context?\nRemove any hallucinated additions"]

    VERIFY --> TTS["🔊 Speak Response"]
```

### Strict System Prompt Template
```
SYSTEM PROMPT (sent to Phi-3 Mini for every query):

"You are PathSaathi, a helpful assistant for pilgrims.
 STRICT RULES you must always follow:
 1. Use ONLY the facts provided in [CONTEXT] below.
 2. NEVER add any information not present in [CONTEXT].
 3. If [CONTEXT] is empty or says 'NO DATA', 
    say: 'I don't have that information right now.
    Please visit the information booth.'
 4. Keep response under 3 sentences.
 5. Respond in {user_language} language only.
 
 [CONTEXT]:
 {retrieved_facts_from_sqlite_or_rag}
 
 User asked: {user_query}
 Your response:"
```

---

## Solution 3 — Noise-Robust ASR Pipeline
*Fixes: ASR Accuracy in 100dB+ Crowd Noise*

```mermaid
flowchart TD
    MIC["🎙️ Raw Microphone Input\n(noisy crowd audio)"]

    subgraph PREPROCESSING["🔧 Audio Preprocessing Pipeline (On-Device)"]
        VAD["Voice Activity Detection\nRNNoise (50KB, on-device)\nDetects when user IS speaking\nvs background noise\nOnly processes speech segments"]

        DENOISE["Noise Suppression\nRNNoise ML denoiser\nReduces crowd noise by ~15dB\nRuns in real-time on CPU\nNo internet needed"]

        AGC["Automatic Gain Control\nNormalize volume levels\nBoost quiet speech\nPrevent clipping on loud input"]

        BEAMFORM["Beamforming (if dual-mic)\nFocus on sound from\nphone front direction\nReject side noise"]
    end

    MIC --> VAD --> DENOISE --> AGC --> BEAMFORM

    BEAMFORM --> WHISPER["🎙️ Whisper.cpp ASR\nClean audio now\nWER drops from 35% → 12%"]

    WHISPER --> TRANSCRIPT["📝 Transcribed Text"]

    TRANSCRIPT --> DISPLAY["📱 Show on Screen\nUser sees what was\nunderstood in real-time\nCan correct if wrong"]

    TRANSCRIPT --> CONFIRM{"Whisper Confidence\nScore Check"}

    CONFIRM -->|"Confidence > 80%"| NLU["Proceed to\nNLU Pipeline"]
    CONFIRM -->|"Confidence 60-80%"| DID_YOU_MEAN["💬 'Did you mean:\n[transcribed text]?\nTap Yes or No'"]
    CONFIRM -->|"Confidence < 60%"| RETRY["🔄 'Sorry, I couldn't\nhear clearly. Please\nspeak again closer\nto the phone'"]

    DID_YOU_MEAN -->|"Yes ✅"| NLU
    DID_YOU_MEAN -->|"No ❌"| RETRY
    RETRY --> MIC
```

### Noise-Robust UI Design
```mermaid
flowchart LR
    subgraph UI_FEATURES["📱 Noise-Robust UI Features"]
        B1["🟢 Large HOLD-TO-SPEAK button\n(not press once — hold while speaking)\nReduces accidental triggers"]
        B2["📊 Live waveform display\nShows when voice is detected\nvs background noise"]
        B3["📝 Real-time transcript\nUser reads along as words appear\nCan interrupt and correct"]
        B4["⌨️ Fallback text input\nIf voice fails 3 times\nKeyboard appears automatically"]
        B5["🔁 Confirmation step\nFor critical actions\n'Book bus at 6AM — Confirm?'"]
    end
```

---

## Solution 4 — Dialect-Adaptive NLU Layer
*Fixes: Dialect Variation (Bhojpuri, Awadhi, regional accents)*

```mermaid
flowchart TD
    RAW_TEXT["📝 ASR Output Text\n(may be in dialect)"]

    subgraph DIALECT_NORM["🗣️ Dialect Normalization Layer"]
        DETECT["Dialect Detection\nFine-tuned classifier\nIdentifies dialect region:\nAwadhi / Bhojpuri / Standard Hindi\nTamil regional / Telugu regional"]

        NORM_MAP["Dialect → Standard Mapping\nPre-built lookup tables:\n'हम जाइब' (Bhojpuri) → 'मैं जाऊंगा' (Hindi)\n'काहे' → 'क्यों' (why)\n'कतना' → 'कितना' (how much)\nStored in SQLite (offline)"]

        NORMALIZE["Normalized Standard Text\nFed to MobileBERT NLU\nfor intent classification"]
    end

    RAW_TEXT --> DETECT --> NORM_MAP --> NORMALIZE

    NORMALIZE --> NLU["🧠 MobileBERT NLU\nIntent + Entity Extraction\nNow works on clean standard text"]

    subgraph DIALECT_RESPONSE["🔊 Dialect-Aware Response"]
        DETECT_RESP["Detect user's dialect\nfrom earlier in session"]
        RESPOND["Generate response in\nuser's DIALECT not standard\n'6 बजे बस मिली' (Bhojpuri style)\nnot 'आपको 6 बजे बस मिलेगी'"]
    end

    NLU --> DETECT_RESP --> RESPOND --> TTS["🔊 TTS in User's Dialect"]
```

### Dialect Coverage Plan
```
PHASE 1 (Weeks 1-12): Standard support
  ✅ Standard Hindi (Delhi/news broadcaster style)
  ✅ Standard Tamil (Chennai)
  ✅ Standard Telugu (Hyderabad)

PHASE 2 (Weeks 13-18): Dialect normalization tables
  ✅ Bhojpuri → Hindi normalization (most common at Kumbh)
  ✅ Awadhi → Hindi normalization (Kumbh region!)
  ✅ Basic Maithili → Hindi

PHASE 3 (Weeks 19-22): Fine-tuning (if time permits)
  ⬜ Fine-tune Whisper tiny on Bhojpuri/Awadhi samples
  ⬜ Use Mozilla Common Voice regional data
```

---

## Solution 5 — Smart Data Freshness Engine
*Fixes: Stale Offline Data, Crowd Prediction Accuracy*

```mermaid
flowchart TD
    subgraph DATA_TYPES["Data Classification by Freshness Need"]
        STATIC["🟢 STATIC (Refresh once)\nMap tiles, base FAQ\nHospital locations\nFixed event venues\nRefresh: Before trip only"]

        SEMI["🟡 SEMI-DYNAMIC (Daily refresh)\nEvent program schedule\nAccommodation allotments\nTransport base schedules\nRefresh: Every 24 hours if online"]

        DYNAMIC["🔴 DYNAMIC (Hourly if possible)\nBus/shuttle delays/cancellations\nCrowd density readings\nNew safety advisories\nGhat open/closed status\nRefresh: Every hour if signal exists"]
    end

    subgraph OPPORTUNISTIC["📶 Opportunistic Sync Strategy"]
        MONITOR["Network Monitor\nContinuously checks for:\n- WiFi (event hotspots)\n- 4G/5G signal\n- Even 2G edge signal"]

        PRIORITY["Priority Queue\nSafety advisories: Priority 1\nTransport changes: Priority 2\nAccommodation updates: Priority 3\nGeneral data: Priority 4"]

        DELTA["Delta Sync Only\nDownload ONLY changed records\nnot full database each time\nMinimizes data usage\nFaster sync on weak signal"]

        PARTIAL["Partial Sync OK\nEven 10 seconds of signal\nupdates highest priority data\nProgress saved if disconnected"]
    end

    STATIC & SEMI & DYNAMIC --> MONITOR
    MONITOR --> PRIORITY --> DELTA --> PARTIAL

    subgraph STALENESS["⚠️ Staleness Warning System"]
        TIMESTAMP["Every data record has:\n- created_at timestamp\n- last_synced_at timestamp\n- expires_at timestamp"]

        BADGE["UI Warning Badges\n🟢 Fresh: < 2 hours old\n🟡 Aging: 2-12 hours old\n🔴 Stale: > 12 hours old\n⚫ Expired: > 24 hours old"]

        SAFE_MSG["Stale data message:\n'This info is from [time] ago.\nPlease verify at info booth\nfor latest updates.'"]
    end

    PARTIAL --> TIMESTAMP --> BADGE --> SAFE_MSG
```

### Local Mesh Data Update (No Internet!)
```mermaid
flowchart LR
    CONTROL["📡 Event Control Room\nHas internet + PathSaathi\nOrganizer app"]

    CONTROL -->|"WiFi Direct broadcast"| VOLUNTEER["👷 Volunteer Phones\nReceive updates\nRelay via BLE mesh"]

    VOLUNTEER -->|"BLE Mesh relay"| P1["📱 Pilgrim Phone 1"]
    P1 -->|"BLE relay"| P2["📱 Pilgrim Phone 2"]
    P2 -->|"BLE relay"| P3["📱 Pilgrim Phone 3"]

    subgraph UPDATE["Update Packet Structure"]
        PKT["{\n  type: 'DATA_UPDATE',\n  category: 'TRANSPORT',\n  update: 'Bus 47 cancelled',\n  effective: '2025-01-15 08:00',\n  signed_by: 'EVENT_AUTHORITY_KEY'\n}"]
    end
```

---

## Solution 6 — Device Security & Recovery System
*Fixes: Phone Loss, OAuth Token Expiry*

```mermaid
flowchart TD
    subgraph PREVENTION["🛡️ Prevention Layer"]
        LOCK["Auto-Lock Rules\n• Lock after 60s idle\n• Lock after 3 biometric failures\n• Lock on SIM removal\n• Lock on wrong PIN × 3"]

        SCREENSHOT["Screen Security\nFLAG_SECURE on document screens\nScreenshots blocked by OS\nScreen recording blocked\nAirDrop/Share disabled for docs"]

        ENCRYPT["Document Encryption\nAES-256-GCM per file\nKey in Android Keystore\nKey cannot be exported\nKey bound to device hardware"]
    end

    subgraph RECOVERY["🔄 Recovery Layer (When Online)"]
        REMOTE_WIPE["Remote Wipe\nUser flags 'phone lost'\nfrom family member's phone\nNext time lost phone\ncomes online:\n→ All encrypted keys destroyed\n→ Documents inaccessible\n→ RAG DB cleared"]

        RE_DOWNLOAD["Re-download Flow\nUser gets new phone:\n1. Login via OAuth\n2. Verify identity\n3. Re-download documents\n4. Re-setup profile\n(Profile backed up\nto encrypted cloud store)"]
    end

    subgraph OAUTH_FIX["🔑 OAuth Token Expiry Fix"]
        LONG_TOKEN["Request Long-Lived Tokens\nDuring pre-trip setup:\nRequest offline_access scope\nRefresh tokens valid 30 days\nStore encrypted in Keystore"]

        CACHE_DOCS["Cache Documents at Setup\nDon't rely on token for viewing\nDocuments downloaded + encrypted\nToken only needed for SYNC\nnot for viewing cached docs"]

        GRACEFUL["Graceful Degradation\nToken expired?\n→ Show cached document ✅\n→ Disable 'Sync new docs' ⚠️\n→ Show 'Re-authenticate\n   when online' message"]
    end

    subgraph BACKUP["📋 Physical Backup Prompt"]
        REMIND["Pre-Trip Checklist\nApp reminds user:\n'Print or photograph these\ndocuments as physical backup:\n□ Aadhar card\n□ Train ticket\n□ Camp allotment letter\nIn case phone is lost or\nbattery dies at the event'"]
    end

    PREVENTION --> RECOVERY
    OAUTH_FIX --> GRACEFUL
    BACKUP --> REMIND
```

---

## Solution 7 — MediaPipe Simplified Integration
*Fixes: Platform Channel Complexity (most critical dev risk)*

### The Problem vs Solution

```
❌ COMPLEX WAY (what we originally planned):
   Flutter (Dart)
       ↓ Platform Channel
   Kotlin Android Code
       ↓ JNI Bridge
   llama.cpp (C++)
       ↓
   Model inference
   
   Requires: Dart + Kotlin + C++ + JNI knowledge
   Time to implement: 8-12 weeks
   Risk: Very high — one JNI error = crash

✅ SIMPLE WAY (MediaPipe Solution):
   Flutter (Dart)
       ↓ google_mediapipe_genai plugin
   MediaPipe Inference Engine
       ↓
   Model inference
   
   Requires: Dart only + plugin config
   Time to implement: 1-2 weeks
   Risk: Very low — Google-maintained plugin
```

### Revised Integration Architecture
```mermaid
flowchart TD
    subgraph FLUTTER_LAYER["Flutter / Dart Layer (All in Dart — no native code needed)"]
        UI["Flutter UI Screens"]
        VOICE_UI["Voice Input Widget"]
        RESPONSE_UI["Response Display"]
    end

    subgraph MEDIAPIPE["MediaPipe Flutter Plugins (Google-official, maintained)"]
        MP_LLM["google_mediapipe_genai\nGemma 2B / Phi-3 on-device\nFunction calling supported\nFlutter-native API"]

        MP_ASR["speech_to_text plugin\n+ Whisper via\nflutter_whisper_kit\nOR MediaPipe Audio"]

        MP_EMBED["google_mediapipe_text\nText embedding on-device\nfor RAG vector generation"]

        FLUTTER_TTS["flutter_tts\nPlatform TTS (built-in)\n+ Coqui for regional langs\nSimple Dart API"]
    end

    subgraph STORAGE["Storage (All Dart packages)"]
        SQFLITE["sqflite\nSQLite on Android/iOS\nPure Dart API"]
        LANCE["lancedb Dart binding\nOn-device vector DB"]
        FSS["flutter_secure_storage\nKeystore access\nPure Dart API"]
        FMAP["flutter_map\nOffline MBTiles\nPure Dart API"]
    end

    UI --> MP_LLM & MP_ASR & MP_EMBED & FLUTTER_TTS
    MP_LLM & MP_ASR --> SQFLITE & LANCE & FSS & FMAP

    subgraph TEAM_SPLIT["👥 Team Responsibility Split"]
        DEV1["Developer 1\nFlutter UI +\nAgent logic in Dart"]
        DEV2["Developer 2\nMediaPipe integration +\nModel download pipeline"]
        DEV3["Developer 3\nRAG + SQLite +\nData ingestion pipeline"]
        DEV4["Developer 4\nSecurity + OAuth +\nBLE Mesh alerts"]
    end
```

### Model Availability via MediaPipe
```
Models pre-optimized for MediaPipe (ready to use):
  ✅ Gemma 2B (2-bit, 4-bit) — Google's own, best MediaPipe support
  ✅ Phi-3.5 Mini — Microsoft, MediaPipe compatible
  ✅ Falcon 1B — Lightweight option for Tier 3 devices
  
ASR via flutter packages:
  ✅ flutter_whisper_kit — Whisper for iOS (Apple optimized)
  ✅ whisper_ane — Whisper on Android Neural Engine
  ✅ speech_to_text — OS-native ASR (fallback, always works)
```

---

## Solution 8 — Offline AI Testing Framework
*Fixes: Non-deterministic AI making testing difficult*

```mermaid
flowchart TD
    subgraph ARCH["Testable Architecture — Dependency Injection"]
        INTERFACE["Abstract Interfaces\n\nAbstract class ASREngine\nAbstract class LLMPlanner  \nAbstract class RAGStore\nAbstract class AgentSwarm\n\n(All agents coded against\ninterface, not concrete impl)"]

        REAL["Production Implementations\nWhisperASREngine\nPhi3LLMPlanner\nLanceDBRAGStore\nRealAgentSwarm"]

        MOCK["Test Mock Implementations\nMockASREngine (returns preset text)\nMockLLMPlanner (returns preset JSON)\nMockRAGStore (returns preset chunks)\nMockAgentSwarm (returns preset results)"]
    end

    INTERFACE --> REAL
    INTERFACE --> MOCK

    subgraph TEST_TYPES["Test Levels"]
        UNIT["Unit Tests (automated)\nTest each agent in isolation\nMock all dependencies\nDeterministic — same output every run\nRun in CI/CD pipeline"]

        INTEGRATION["Integration Tests (semi-auto)\nTest agent swarm with real models\nPre-recorded audio inputs\nKnown expected outputs\nAcceptable WER threshold defined"]

        E2E["End-to-End Tests (manual)\nFull voice → response flow\nDone with real users\nIn noisy environments\nVideo recorded for evidence"]

        EVAL["AI Evaluation Scripts\nASR: Compute WER on test set\nNLU: F1 score on intent classification\nRAG: Precision@K for retrieval\nLLM: Factual accuracy on grounded queries"]
    end

    MOCK --> UNIT
    REAL --> INTEGRATION & E2E & EVAL

    subgraph TEST_DATA["Test Dataset"]
        DATASET["Curated Test Cases:\n50 Hindi queries + expected responses\n30 Tamil queries + expected responses\n20 Telugu queries + expected responses\n20 emergency scenarios\n10 document retrieval cases\n10 multi-agent complex queries"]
    end
```

### Sample Test Case Format
```json
{
  "test_id": "TRANSPORT_HINDI_001",
  "input_audio": "tests/audio/hindi_bus_query.wav",
  "expected_asr": "मुझे कल सुबह प्रयागराज जाने की बस चाहिए",
  "expected_intent": "book_transport",
  "expected_entities": {
    "destination": "Prayagraj",
    "time": "tomorrow_morning",
    "mode": "bus"
  },
  "expected_agent": "TransportAgent",
  "db_fixture": "tests/fixtures/transport_jan15.sqlite",
  "expected_response_contains": ["6:00", "Bus 47", "Gate 3"],
  "must_not_contain": ["hallucinated_value"]
}
```

---

## Solution 9 — Progressive Setup & Adaptive UX
*Fixes: Setup Burden, Language Switching, Non-Technical Users*

```mermaid
flowchart TD
    subgraph SETUP_WIZARD["🧙 Guided Setup Wizard (Voice-Driven)"]
        S1["Step 1: Language Selection\nLarge flag buttons\nApp speaks 'नमस्ते! कृपया अपनी\nभाषा चुनें'\nUser taps language icon"]

        S2["Step 2: Basic Profile\nVoice-prompted:\n'अपना नाम बोलें' (Say your name)\nApp fills form from speech\nNo typing needed"]

        S3["Step 3: Health Info (Optional)\n'क्या आपको कोई बीमारी है?'\nSimple Yes/No buttons\nIf yes: common conditions list"]

        S4["Step 4: Emergency Contact\n'घर पर किसका नंबर है?'\nSpeech → auto-fills number\nVerifies with call/SMS"]

        S5["Step 5: Document Upload\n'अपना आधार कार्ड की फोटो लें'\nCamera opens automatically\nOCR runs immediately\nConfirm data extracted"]

        S6["Step 6: Download Pack\nShows progress bar\n'आपका डेटा तैयार हो रहा है'\nEstimated time shown\nCan continue in background"]
    end

    S1 --> S2 --> S3 --> S4 --> S5 --> S6

    subgraph FAMILY_MODE["👨‍👩‍👧 Family Setup Mode"]
        FM["'मेरी तरफ से सेट करें'\n(Setup on my behalf)\n\nFamily member enters:\n- Elder's language preference\n- Medical conditions\n- Emergency contacts\n- Uploads documents\n\nElder only needs to verify\nwith fingerprint at the end"]
    end

    subgraph ADAPTIVE_UI["📱 Adaptive UI for Non-Tech Users"]
        LARGE["Large text (18sp minimum)\nHigh contrast colors\nNo small icons without labels"]
        VOICE_FIRST["Voice-first navigation\nEvery screen has mic button\nAll options readable aloud\nNo mandatory text input"]
        SIMPLE["Maximum 3 options per screen\nNo hamburger menus\nNo settings complexity\nSingle primary action per screen"]
        TUTORIAL["First-use tutorial\nAnimated walkthrough\nSpoken in user's language\nCan replay anytime"]
    end

    subgraph LANG_SWITCH["🌐 Language Switching Mid-Session"]
        DETECT_SWITCH["Detect language switch\nIf user speaks in different\nlanguage mid-query:\n→ Detect language change\n→ Ask: 'क्या आप Tamil में\n   बात करना चाहते हैं?'"]
        LOCK["Session Language Lock\nOnce confirmed: switch\nall TTS + UI to new language\nRemember for rest of session"]
    end
```

---

## Revised Architecture: All Solutions Combined

```mermaid
graph TB
    subgraph DEVICE["📱 PathSaathi — Mitigated Architecture"]

        subgraph INPUT["Input (Solution 3: Noise-Robust)"]
            RNN["RNNoise\nDenoiser"]
            VAD["Voice Activity\nDetection"]
            ASR["Whisper.cpp\n(Tier-appropriate size)"]
        end

        subgraph UNDERSTANDING["Understanding (Solution 4: Dialect-Adaptive)"]
            DIAL["Dialect\nNormalizer"]
            NLU["MobileBERT\nNLU"]
        end

        subgraph GROUNDING["Grounding (Solution 2: Hallucination-Free)"]
            ROUTER["Data Source\nRouter"]
            SQL["SQLite\n(Ground Truth)"]
            RAG["LanceDB RAG\n(Personal Data)"]
            CONF["Confidence\nChecker"]
        end

        subgraph PLANNING["Planning (Solution 7: MediaPipe)"]
            MP["MediaPipe\nGemma 2B"]
            CACHE["Response\nCache Layer"]
        end

        subgraph AGENTS["7 Agents"]
            A1["Transport"] & A2["Accommodation"] & A3["Itinerary"]
            A4["Document"] & A5["Safety"] & A6["Navigation"] & A7["General"]
        end

        subgraph RESILIENCE["Resilience Layer"]
            TIER["Device Tier\nSelector"]
            BATTERY["Battery\nAwareness"]
            STALE["Freshness\nChecker"]
            SECURITY["Security +\nRemote Wipe"]
            MESH["BLE Mesh\nAlerts"]
        end

    end

    RNN --> VAD --> ASR --> DIAL --> NLU
    NLU --> ROUTER --> SQL & RAG --> CONF --> MP
    MP --> CACHE --> A1 & A2 & A3 & A4 & A5 & A6 & A7
    TIER --> MP
    BATTERY --> CACHE
    STALE --> SQL & RAG
    SECURITY --> A4
    A5 --> MESH
```

---

## Implementation Priority Order

```
WEEK 1-2:   Solution 7 (MediaPipe setup)     ← Unblocks everything else
WEEK 3-4:   Solution 2 (Grounded pipeline)   ← Safety-critical, do early
WEEK 5-6:   Solution 3 (Noise-robust ASR)    ← Core user experience
WEEK 7-8:   Solution 1 (Device tier system)  ← Enables budget phone support
WEEK 9-10:  Solution 5 (Data freshness)      ← Data reliability
WEEK 11-12: Solution 4 (Dialect NLU)         ← Language coverage
WEEK 13-14: Solution 6 (Security + Recovery) ← Document security evaluation
WEEK 15-16: Solution 8 (Testing framework)   ← Quality assurance
WEEK 17-18: Solution 9 (Progressive UX)      ← Non-tech usability evaluation
WEEK 19-22: Integration, polish, demo prep
```

---

## How Solutions Map to Infosys Evaluation Criteria

| Infosys Criterion | Solutions Addressing It |
|---|---|
| **Language breadth & accuracy** | Solution 3 (noise-robust ASR) + Solution 4 (dialect adaptive) |
| **Agent task decomposition quality** | Solution 2 (grounded pipeline) + Solution 7 (MediaPipe LLM) |
| **True offline functionality** | Solution 5 (freshness engine) + Solution 1 (tiered models) |
| **Document security** | Solution 6 (security + recovery) |
| **Usability for non-technical users** | Solution 1 (battery mgmt) + Solution 9 (progressive UX) |

---

*Solutions Architecture v1.0 | PathSaathi FYP*
*Every critical drawback has a concrete engineering solution*
