# PathSaathi — Master System & Solutions Architecture
### Vernacular AI Concierge for Pilgrims at Large Public Gatherings
**Infosys FYP Problem Statement 2 | Domain: Multilingual NLP / Multi-Agent Systems / Offline-First Mobile AI**

> **Current implementation status:** The Flutter prototype implements real GPS
> source positioning, online/offline route selection, shared one-time offline
> map installation, grounded voice answers, source-aware transport options,
> ranked accommodation with local booking confirmation, active-trip itinerary
> filtering, and encrypted document/photo persistence. Curated transport and
> accommodation records are demonstration data, not live inventory. Live bus
> tracking and worldwide street-level offline routing require external provider
> data and are reported as unavailable rather than fabricated.

---

## 1. Executive Summary & Infosys Tech Stack Compliance

This document represents the unified **Master Architecture** for **PathSaathi**, combining the core multi-agent platform design with the 9 mitigation and solution architectures required to solve real-world edge-device constraints (battery, noise, storage, hallucination, dialect variations, and security).

### 📋 Exact Infosys Specified Tech Stack Mapping

Every single item specified in the Infosys problem statement is fully incorporated and mapped to concrete on-device production implementations:

| Infosys Specified Component | Exact Specification Text | Our Production Implementation | Role in Architecture |
|---|---|---|---|
| **Speech / ASR** | *"A compact multilingual ASR model (quantized)"* | **Whisper.cpp / Whisper Tiny & Small (int8 quantized)** | On-device speech recognition & language identification across regional languages |
| **Text-to-Speech (TTS)** | *"An open multilingual text-to-speech model for regional languages"* | **Coqui TTS / Meta MMS-TTS** | Offline voice synthesis for Hindi, Tamil, Telugu, Bhojpuri, etc. |
| **Planner LLM** | *"A small function-calling capable model"* | **Phi-3 Mini 3.8B / Gemma 2B (4-bit quantized via llama.cpp / MediaPipe)** | Central Orchestrator that decomposes voice queries into sub-agent calls |
| **NLU / NER Engine** | *"A regionally appropriate BERT-style model for intent classification and entity extraction"* | **MobileBERT / DistilBERT (ONNX Runtime Mobile, int8)** | Fast intent classification and named entity extraction prior to LLM routing |
| **Semantic Search Engine** | *"A multilingual sentence-embedding model for FAQ/policy document search"* | **paraphrase-multilingual-MiniLM-L12 (ONNX)** + **LanceDB Vector DB** | On-device vector embeddings for RAG retrieval over personal and event knowledge |
| **Secure Storage** | *"Device-native secure storage (e.g., platform keystore/keychain) for cached credentials"* | **flutter_secure_storage + Android Hardware Keystore / iOS Keychain** | Hardware-backed AES-256 vault for personal documents and tokens |
| **Inference Runtime** | *"ONNX Runtime Mobile, llama.cpp, or an equivalent local inference engine"* | **ONNX Runtime Mobile + llama.cpp / MediaPipe GenAI Engine** | Executes BERT, Whisper, MiniLM, and LLM locally with hardware acceleration |

### 🚀 Value-Add Architecture Enhancements
- **Mobile Application Framework**: Flutter 3.x (Cross-platform, offline maps, platform channels)
- **Vector Database**: LanceDB Embedded (Rust-based, native mobile vector search)
- **Offline Maps & Routing**: `flutter_map` + MBTiles + Valhalla Routing Engine
- **On-Device OCR**: Google ML Kit (Offline document text extraction)
- **Local Mesh Broadcast**: Bridgefy SDK / Bluetooth Low Energy (BLE) P2P emergency alert relay
- **Structured Storage**: SQLite (`sqflite`) for deterministic transport and lodging schedules

---

## 2. High-Level Master System Architecture

```mermaid
graph TB
    subgraph PILGRIM["👤 Pilgrim (End User Interface)"]
        MIC["🎙️ Voice Input (Regional Language)"]
        DISPLAY["📱 UI Screen (Visual Directions & Docs)"]
        SPEAKER["🔊 Audio Response (Native Voice)"]
    end

    subgraph NOISE_PIPE["🔧 Solution 3: Noise & Audio Preprocessing"]
        VAD["Voice Activity Detection (RNNoise)"]
        DENOISE["15dB Noise Suppression Filter"]
        AGC["Automatic Gain Control"]
    end

    subgraph SPEECH_LAYER["🗣️ Speech & NLU Layer (Infosys Stack)"]
        ASR["🎙️ Whisper.cpp ASR\n(int8 Quantized)"]
        DIALECT["🗣️ Solution 4: Dialect Normalizer\n(Bhojpuri/Awadhi → Standard)"]
        NLU["🧠 MobileBERT NLU\n(ONNX Runtime Mobile)"]
    end

    subgraph PLANNER_LAYER["🎯 Central Planner & Orchestrator (Infosys Stack)"]
        CACHE["🗄️ Solution 1: Response Cache\n(Bypasses LLM on Cache Hit)"]
        TIER["⚡ Solution 1: Device Tier Selector\n(Full / Standard / Lite Modes)"]
        LLM["🎯 Phi-3 Mini 3.8B / Gemma 2B\n(4-bit quantized via llama.cpp / MediaPipe)"]
        GROUND["🔒 Solution 2: Grounding & Anti-Hallucination Guard"]
    end

    subgraph AGENT_SWARM["🤖 Specialized Agent Swarm (7 Modules)"]
        A1["🚌 Transport Agent"]
        A2["🏕️ Accommodation Agent"]
        A3["📅 Itinerary Agent"]
        A4["🔐 Secure Document Agent"]
        A5["⚠️ Safety & Alert Agent"]
        A6["🗺️ Navigation Agent"]
        A7["💬 General Query Agent"]
    end

    subgraph DATA_LAYER["💾 On-Device Storage & Ground Truth (Offline)"]
        SQL["🗄️ SQLite Database\nTransport Schedules & Lodging"]
        RAG["🔍 LanceDB Vector DB\nMiniLM Multilingual Embeddings"]
        MAPS["🗺️ MBTiles & Valhalla\nOffline Maps & Routing Engine"]
        VAULT["🔐 Keystore Vault\nAES-256 Encrypted Documents"]
    end

    subgraph RESILIENCE_LAYER["🛡️ Reliability & Security Extensions"]
        FRESH["🔄 Solution 5: Opportunistic Sync & Mesh"]
        SEC_SYS["🔐 Solution 6: Biometric Gate & Auto Wipe"]
        BLE["📡 BLE Mesh Alert Broadcast"]
    end

    MIC --> VAD --> DENOISE --> AGC --> ASR
    ASR --> DIALECT --> NLU
    NLU --> CACHE
    CACHE -->|"Cache Miss"| TIER --> LLM
    CACHE -->|"Cache Hit"| GROUND
    LLM --> GROUND
    GROUND --> A1 & A2 & A3 & A4 & A5 & A6 & A7

    A1 & A2 --> SQL
    A3 & A7 --> RAG
    A4 --> SEC_SYS --> VAULT
    A5 --> RAG & BLE
    A6 --> MAPS

    A1 & A2 & A3 & A4 & A5 & A6 & A7 --> GROUND
    GROUND --> TTS["🔊 Coqui / MMS-TTS Engine"]
    TTS --> SPEAKER
    GROUND --> DISPLAY
    FRESH -.->|"WiFi / 4G Opportunistic"| SQL & RAG
```

---

## 3. Comprehensive Solutions Architecture (All 9 Mitigations Integrated)

---

### Solution 1 — Adaptive Device Tier System
**Fixes: Storage (3.1GB limit), Battery Drain, Slow Inference on Budget Hardware**

To accommodate budget smartphones (2GB–3GB RAM) commonly used by pilgrims alongside flagship devices, PathSaathi dynamically inspects device hardware during initial boot and configures the optimal execution tier.

```mermaid
flowchart TD
    BOOT["📱 App Initial Boot"]
    INSPECT["🔍 Hardware Inspection\n• Check Available RAM & CPU Cores\n• Check NPU/GPU Acceleration Support\n• Check Available Disk Storage"]

    INSPECT --> SELECT{"Select Hardware\nDevice Tier"}

    SELECT -->|"RAM ≥ 6GB\nStorage ≥ 64GB\nSnapdragon 7/8 Series"| TIER1["🟢 TIER 1: Full Mode\n\n• LLM: Phi-3 Mini 3.8B (4-bit)\n• ASR: Whisper Small (int8)\n• TTS: High-Quality Coqui TTS\n• Maps: Full Regional Map Pack\n• Memory Footprint: ~3.1 GB\n• Inference Time: 2-4 seconds"]

    SELECT -->|"RAM 3GB–5GB\nStorage 32GB–64GB\nMid-Range SoC"| TIER2["🟡 TIER 2: Standard Mode\n\n• LLM: Gemma 2B (4-bit)\n• ASR: Whisper Tiny (int8)\n• TTS: MMS-TTS Standard\n• Maps: Event Perimeter Only\n• Memory Footprint: ~1.6 GB\n• Inference Time: 5-8 seconds"]

    SELECT -->|"RAM < 3GB\nStorage < 32GB\nBudget SoC"| TIER3["🔴 TIER 3: Lite Mode\n\n• LLM: TinyLlama 1.1B (4-bit)\n• ASR: Whisper Tiny (int8)\n• TTS: eSpeak-NG Native\n• Maps: Key Landmark Map Pack\n• Memory Footprint: ~800 MB\n• Inference Time: 8-12 seconds"]

    TIER1 & TIER2 & TIER3 --> CACHE_ENGINE["🗄️ Query Response Cache\nVector similarity lookups against pre-computed responses.\nIf Cosine Similarity > 0.92:\n→ Returns cached answer instantly (<1s)\n→ Bypasses LLM execution, saving ~60% battery"]

    CACHE_ENGINE --> BATTERY_MONITOR["🔋 Battery Awareness State Machine\n• Battery > 50%: Normal Execution\n• Battery 20%-50%: Cache-First Priority\n• Battery < 20%: Emergency Safety Mode Only"]
```

---

### Solution 2 — Hallucination-Free Data Pipeline
**Fixes: LLM Hallucination & Fact Fabrication**

Critical logistics (bus schedules, camp locations, medical alerts) must never be generated by LLM parametric memory. The system enforces strict deterministic grounding.

```mermaid
flowchart TD
    NLU_OUT["📥 NLU Intent & Extracted Entities"]

    NLU_OUT --> ROUTE_QUERY{"Query Type Classification"}

    ROUTE_QUERY -->|"Logistics / Transport / Lodging"| SQL_EXEC["🗄️ SQLite Direct Query\nSELECT * FROM transport_schedule\nWHERE destination=? AND departure_time>=?\n(Deterministic DB Search)"]

    ROUTE_QUERY -->|"FAQ / Guidelines / Medical"| RAG_EXEC["🔍 LanceDB Vector RAG Search\nMultilingual MiniLM Embeddings\nExtract Top-K Document Chunks\n+ Compute Similarity Confidence"]

    SQL_EXEC --> FACT_BUFFER["📋 Verified Fact Buffer\n(100% Ground Truth Data)"]

    RAG_EXEC --> CONF_CHECK{"Similarity Confidence\nScore Evaluation"}

    CONF_CHECK -->|"> 0.75 (High Confidence)"| FACT_BUFFER
    CONF_CHECK -->|"0.50 – 0.75 (Medium)"| FACT_BUFFER_DISCLAIMER["📋 Verified Fact Buffer\n+ Append Verification Disclaimer"]
    CONF_CHECK -->|"< 0.50 (Low Confidence)"| SAFE_FALLBACK["🔒 Safe Fallback Response\n'Information unavailable offline.\nPlease consult Information Booth at Gate 3.'"]

    FACT_BUFFER & FACT_BUFFER_DISCLAIMER --> PROMPT_INJECT["📝 Inject Facts into Strict LLM System Prompt\n'Use ONLY the facts provided in CONTEXT.\nDo NOT add outside information.\nFormat cleanly in regional language.'"]

    PROMPT_INJECT --> LLM_GEN["🧠 Phi-3 Mini / Gemma 2B\n(Formatting & Translation Engine Only)"]

    LLM_GEN --> VERIFIER["🔍 Post-Generation Fact Verifier\nMatches output numbers/locations against Ground Truth Buffer.\nRejects response if ungrounded entities are detected."]

    VERIFIER --> OUTPUT["🔊 Output to TTS & Screen"]
    SAFE_FALLBACK --> OUTPUT
```

---

### Solution 3 — Noise-Robust ASR Pipeline
**Fixes: ASR Degradation in 100dB+ Crowd Noise Environments**

Massive events like Kumbh Mela exhibit extreme acoustic interference (chanting, speakers, river sounds). Audio must be sanitized locally before Whisper processing.

```mermaid
flowchart LR
    MIC["🎙️ Raw Mic Input\n(High Noise)"] --> VAD["1. Voice Activity Detection\n(RNNoise VAD)"]
    VAD --> SUPPRESS["2. Noise Suppression\n(-15dB Crowd Noise Filter)"]
    SUPPRESS --> AGC["3. Automatic Gain Control\n(Volume Equalization)"]
    AGC --> WHISPER["4. Whisper.cpp ASR\n(Clean Audio Stream)"]
    WHISPER --> TRANSCRIPT["5. Transcribed Text"]
    TRANSCRIPT --> UI_DISP["📱 Screen Display\n(Live User Verification)"]
    TRANSCRIPT --> EVAL_CONF{"ASR Confidence Score"}
    EVAL_CONF -->|"> 80%"| PROCEED["Proceed to NLU"]
    EVAL_CONF -->|"< 80%"| CONFIRM["💬 Ask User Confirmation:\n'Did you say X?'"]
```

---

### Solution 4 — Dialect-Adaptive NLU Layer
**Fixes: Regional Dialect & Accent Variations (Bhojpuri, Awadhi, Maithili)**

```mermaid
flowchart TD
    RAW_TEXT["📝 Raw ASR Transcript"] --> DETECT_DIALECT["🗣️ Dialect Identification Model"]
    DETECT_DIALECT --> NORM_ENGINE["🔄 SQLite Dialect Normalization Engine\nMaps regional idioms/phrases to standard Hindi/Tamil/Telugu\ne.g., 'हम जाइब' (Bhojpuri) → 'मैं जाऊंगा' (Standard Hindi)"]
    NORM_ENGINE --> NLU_BERT["🧠 MobileBERT Intent & Entity Extractor\n(ONNX Runtime Mobile Engine)"]
    NLU_BERT --> INTENT_OUT["🎯 Structured Intent JSON"]
```

---

### Solution 5 — Smart Data Freshness Engine
**Fixes: Offline Data Staleness & Event Dynamic Updates**

```mermaid
flowchart TD
    subgraph SYNC_STRATEGY["📶 Opportunistic & Mesh Synchronization"]
        MONITOR["Signal Monitor\n(Detects 2G/4G/WiFi Hotspots)"]
        DELTA["Delta Sync Engine\n(Downloads ONLY modified rows/chunks)"]
        MESH_RELAY["📡 BLE Mesh P2P Relay\n(Receives signed emergency updates from nearby phones)"]
    end

    subgraph STALENESS_GUARD["⚠️ Data Staleness Guard"]
        DATA_ITEM["Data Record Request"] --> AGE_CHECK{"Check Record Timestamp"}
        AGE_CHECK -->|"< 6 Hours"| FRESH["🟢 Fresh Data"]
        AGE_CHECK -->|"6 - 24 Hours"| AGING["🟡 Aging Data\n(Appends warning: 'Synced X hours ago')"]
        AGE_CHECK -->|"> 24 Hours"| STALE["🔴 Stale Data\n(Prompts user to verify at venue helpdesk)"]
    end

    MONITOR --> DELTA --> STALENESS_GUARD
    MESH_RELAY --> STALENESS_GUARD
```

---

### Solution 6 — Device Security & Recovery System
**Fixes: Phone Loss, Document Tampering, and OAuth Token Expiry**

```mermaid
flowchart LR
    subgraph PRE_TRIP["1. Pre-Trip Auth"]
        OAUTH["OAuth 2.0 + PKCE\n(DigiLocker Integration)"]
        SCOPE["Request 30-Day\nOffline Access Token"]
    end

    subgraph ENCRYPTION_VAULT["2. On-Device Vault"]
        AES["AES-256-GCM\nEncryption"]
        KEYSTORE["Android Hardware Keystore /\niOS Secure Enclave"]
    end

    subgraph ACCESS_GATE["3. Document Access Gate"]
        BIO["Biometric Verification\n(Fingerprint / Face ID)"]
        RAM_ONLY["Decrypt to RAM Only\n(Auto-wipe after 30s)"]
        FLAG_SECURE["FLAG_SECURE\n(Blocks Screenshots & Recording)"]
    end

    OAUTH --> SCOPE --> AES --> KEYSTORE
    KEYSTORE --> BIO --> RAM_ONLY --> FLAG_SECURE
```

---

### Solution 7 — MediaPipe & Native Integration Architecture
**Fixes: Platform Channel Complexity & JNI Overhead**

To avoid fragile custom C++/JNI bindings, the runtime leverages **Google MediaPipe GenAI & Text Tasks** for Flutter, establishing a clean Dart-native interface.

```mermaid
flowchart TD
    subgraph FLUTTER_DART["📱 Flutter App Layer (Dart Code)"]
        UI_MAIN["App UI & Navigation"]
        AGENT_ORCH["Agent Swarm Controller (Dart)"]
    end

    subgraph MEDIAPIPE_PLUGINS["📦 Google MediaPipe Flutter Plugins"]
        MP_GENAI["google_mediapipe_genai\n(Runs Gemma 2B / Phi-3 Mini locally)"]
        MP_TEXT["google_mediapipe_text\n(Runs MiniLM Vector Embeddings)"]
        WHISPER_KIT["flutter_whisper_kit / speech_to_text\n(Runs Whisper ASR)"]
    end

    subgraph NATIVE_RUNTIMES["⚡ Native Execution Runtimes"]
        ONNX_RT["ONNX Runtime Mobile\n(Runs MobileBERT NLU)"]
        LLAMA_CPP["llama.cpp FFI (Fallback)\n(GGUF Inference)"]
    end

    UI_MAIN --> AGENT_ORCH
    AGENT_ORCH --> MP_GENAI & MP_TEXT & WHISPER_KIT
    AGENT_ORCH --> ONNX_RT & LLAMA_CPP
```

---

### Solution 8 — Offline AI Testing & Evaluation Framework
**Fixes: Non-Deterministic Testing Difficulties**

```mermaid
flowchart TD
    TEST_SUITE["🧪 Automated Offline Test Suite"]

    TEST_SUITE --> MOCK_LAYER["Abstract Agent Interfaces\n(Injects Mock ASR, Mock Vector DB, and Preset Audio)"]
    TEST_SUITE --> BENCHMARK["Evaluation Metrics Execution"]

    BENCHMARK --> METRIC1["1. ASR Word Error Rate (WER) < 15%"]
    BENCHMARK --> METRIC2["2. NLU Intent Classification F1-Score > 0.90"]
    BENCHMARK --> METRIC3["3. RAG Retrieval Precision@K (K=3) > 0.85"]
    BENCHMARK --> METRIC4["4. Grounding & Fact Accuracy = 100%"]
```

---

### Solution 9 — Progressive Setup & Adaptive UX
**Fixes: Onboarding Burden for Non-Technical & Elderly Users**

```mermaid
flowchart LR
    START["1. One-Tap Language Selection\n(Hindi / Tamil / Telugu Icons)"] --> VOICE_PROFILE["2. Voice-Guided Profile\n('Say your name and emergency contact')"]
    VOICE_PROFILE --> DOC_OCR["3. Auto Camera Document OCR\n(ML Kit extracts ID data automatically)"]
    DOC_OCR --> FAMILY_SHARE["4. Family Setup Mode\n(Family member pre-loads data on elder's phone)"]
```

---

## 4. End-to-End Execution Sequence Workflow

Here is the exact lifecycle of a user request processed 100% offline:

```mermaid
sequenceDiagram
    autonumber
    actor Pilgrim as 👤 Pilgrim
    participant Mic as 🎙️ Hardware Mic
    participant Denoise as 🔧 RNNoise Denoise
    participant ASR as 🗣️ Whisper.cpp
    participant NLU as 🧠 MobileBERT (ONNX)
    participant Cache as 🗄️ Response Cache
    participant Planner as 🎯 Phi-3 / Gemma LLM
    participant Agent as 🤖 Target Agent (e.g. Transport)
    participant DB as 🗄️ Local SQLite / LanceDB
    participant TTS as 🔊 Coqui / MMS-TTS

    Pilgrim->>Mic: Speaks: "कल सुबह इलाहाबाद जाने के लिए बस कब मिलेगी?"
    Mic->>Denoise: Raw noisy audio stream
    Denoise->>ASR: Filtered audio stream (-15dB noise reduction)
    ASR->>ASR: Speech-to-Text transcription & language detection
    ASR->>NLU: Text: "कल सुबह इलाहाबाद जाने के लिए बस कब मिलेगी?" (Hindi)
    NLU->>NLU: Classify Intent: book_transport | Extract Entities: {dest: "Allahabad", time: "tomorrow_morning"}
    NLU->>Cache: Check Query Vector in Cache
    alt Cache Hit (Similarity > 0.92)
        Cache-->>Pilgrim: Play cached audio response immediately (<1s)
    else Cache Miss
        Cache->>Planner: Pass Intent JSON & Entities
        Planner->>Agent: Invoke Transport Booking Agent
        Agent->>DB: Query SQLite transport_schedule table
        DB-->>Agent: Returns: Bus #47, Departs 06:00 AM, Gate 3
        Agent->>Planner: Grounded Truth Facts
        Planner->>Planner: Format facts into natural Hindi response (No Hallucinations)
        Planner->>TTS: Text: "कल सुबह 6 बजे गेट 3 से बस नंबर 47 उपलब्ध है।"
        TTS-->>Pilgrim: Spoken audio response + Screen card display
    end
```

---

## 5. Infosys Evaluation Criteria Compliance Matrix

| Infosys Evaluation Criteria | Architectural Safeguards & Solutions Implemented | Verification Method |
|---|---|---|
| **Breadth & accuracy of language support** | • Whisper.cpp int8 quantized for regional ASR<br>• MMS-TTS / Coqui for voice synthesis<br>• Solution 4: Dialect Normalization tables for Bhojpuri/Awadhi | Test against 100 regional audio samples; WER target < 15% |
| **Quality of task decomposition & agent coordination** | • Phi-3 Mini / Gemma 2B function-calling Planner<br>• 7 specialized sub-agents with clear interfaces<br>• Solution 2: Grounded Fact Buffer prevents hallucination | Multi-intent test suite evaluating function payload accuracy |
| **True offline functionality** | • All models (ASR, NLU, LLM, TTS, Vector DB) on-device<br>• Solution 1: 3-tier device scaling for budget hardware<br>• Solution 5: Opportunistic delta sync & BLE mesh | Airplane-mode execution of all 7 agent modules |
| **Security handling of personal documents** | • Solution 6: Hardware Keystore AES-256 vault<br>• Biometric authentication gate prior to document display<br>• Screen capture blocking (`FLAG_SECURE`) & RAM-only decryption | Security audit verifying zero unencrypted disk storage or network leaks |
| **Overall usability for non-technical user** | • Solution 9: 100% voice-first UI with large visual cards<br>• Guided voice onboarding & Family Setup Mode<br>• Solution 3: Noise-robust VAD and manual transcript confirmation | Usability trial with elderly non-tech users evaluating completion rates |

---

*Master System & Solutions Architecture Document v3.0 | PathSaathi FYP*
*Fully aligned with Infosys Problem Statement 2 Requirements*
