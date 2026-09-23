# PathSaathi — Tech Stack Analysis
## What Infosys Said vs What We Can Add

---

## 1. Exact Tech Stack Infosys Mentioned

> **IMPORTANT**: Infosys uses the word **"Suggested Tech Stack"**  
> This means it is a **RECOMMENDATION, NOT a hard rule.**  
> You are free to use equivalent or better technologies.

### What Infosys Literally Said:

| Category | Infosys Said |
|---|---|
| **Speech/ASR** | "A compact multilingual ASR model (quantized)" |
| **TTS** | "An open multilingual text-to-speech model for regional languages" |
| **Planner LLM** | "A small function-calling capable model" |
| **NLU/NER** | "A regionally appropriate BERT-style model for intent classification and entity extraction" |
| **Semantic Search** | "A multilingual sentence-embedding model for FAQ/policy document search" |
| **Secure Storage** | "Device-native secure storage (e.g., platform keystore/keychain) for cached credentials" |
| **Inference Runtime** | "ONNX Runtime Mobile, llama.cpp, **or an equivalent local inference engine**" |

> **Notice**: They never mentioned Flutter, React Native, Swift, etc.  
> They never specified LanceDB, ChromaDB, or any RAG framework.  
> The mobile framework and RAG choice is **entirely yours to decide.**

---

## 2. What is FIXED vs FLEXIBLE

### 🔴 FIXED — You MUST Implement These (Non-Negotiable)

These are the **Modules, Deliverables, and Objectives** — not tech stack:

```
FIXED MODULES (must build all 7):
  ✅ Speech & Language Agent (ASR + TTS)
  ✅ Planner / Orchestrator (function-calling LLM)
  ✅ Transport Booking Agent
  ✅ Accommodation Agent
  ✅ Itinerary Agent
  ✅ Secure Document Agent
  ✅ Safety & Alert Agent
  ✅ Navigation Agent

FIXED DELIVERABLES (must demonstrate):
  ✅ 2-3 regional languages end-to-end
  ✅ Full functionality in offline/airplane mode
  ✅ Architecture diagram of agent swarm and planner

FIXED EVALUATION CRITERIA (must score well):
  ✅ Language breadth and accuracy
  ✅ Task decomposition and agent coordination quality
  ✅ True offline functionality
  ✅ Security handling of personal documents
  ✅ Usability for non-technical users
```

### 🟢 FLEXIBLE — You CAN Choose/Add These

```
FLEXIBLE (your choice):
  ✅ Mobile framework → Flutter, React Native, Native Android/iOS
  ✅ Specific LLM model → Phi-3, Gemma, Llama, Mistral (any small model)
  ✅ Specific ASR → Whisper, MMS, any multilingual ASR
  ✅ RAG framework → LanceDB, ChromaDB, FAISS (not even mentioned by Infosys!)
  ✅ Offline map library → flutter_map, Mapbox, MapLibre
  ✅ Additional features → Anything extra that ENHANCES the base requirements
  ✅ UI/UX design → Completely your creative choice
  ✅ Additional languages → More than 2-3 is a BONUS
```

---

## 3. New Features We Can SAFELY ADD

### ✅ Feature 1: RAG for Personal Information (Our Idea)
```
Infosys mentioned: "Semantic search for FAQ/policy docs"
Our Addition:      RAG also stores PERSONAL pilgrim data
                   → Medical info, preferences, tickets

Why it's valid:    Infosys said semantic search = vector embeddings
                   We're just extending it to personal context too
                   This DIRECTLY improves usability for non-tech users
                   (Evaluation criterion #5)

Risk Level: ZERO — This only enhances what they asked for
```

### ✅ Feature 2: Bluetooth Mesh for Emergency Alerts
```
Infosys mentioned: "Offline-cached advisories and emergency alerts
                    (e.g., via local mesh broadcast)"

They literally hinted at this! The words "local mesh broadcast" 
appear in their own problem statement.

Our Addition:      Implement it using Bridgefy SDK or BLE custom
                   implementation for peer-to-peer alert relay

Risk Level: ZERO — They explicitly mentioned mesh broadcast
```

### ✅ Feature 3: Flutter as Mobile Framework
```
Infosys mentioned: Nothing about mobile framework

Our Addition:      Flutter with:
                   → flutter_map for offline maps
                   → Platform channels for AI models
                   → flutter_secure_storage for documents

Why it's better:   Flutter gives us cross-platform (Android + iOS)
                   which means more users can access PathSaathi

Risk Level: ZERO — Framework choice is completely ours
```

### ✅ Feature 4: LanceDB On-Device Vector Database
```
Infosys mentioned: "Multilingual sentence-embedding model"
                   (They mentioned embeddings but not the DB to store them!)

Our Addition:      LanceDB — on-device vector DB
                   Designed specifically for mobile/edge devices
                   Runs 100% offline

Why it's better:   Without a vector DB, you can't do semantic search
                   LanceDB is the missing piece Infosys implied but didn't name

Risk Level: ZERO — We're implementing what they described
```

### ✅ Feature 5: Crowd Prediction Model
```
Infosys mentioned: "Crowd/congestion predictions" in Itinerary Agent

Our Addition:      Pre-download a small trained ML model
                   that predicts crowd levels by:
                   → Time of day
                   → Day of event
                   → Historical Kumbh Mela data

Why it's better:   This directly satisfies the Itinerary Agent requirement
                   Makes the app genuinely useful for pilgrims

Risk Level: ZERO — They asked for it in the module table
```

### ✅ Feature 6: Multilingual OCR for Document Upload
```
Infosys mentioned: "Secure document retrieval" 
                   (They didn't specify HOW documents are read)

Our Addition:      On-device OCR (ML Kit by Google)
                   → User takes photo of ID card
                   → Text extracted from image
                   → Stored in RAG for smart retrieval

Why it's better:   Many pilgrims only have physical documents
                   This makes document ingestion much easier

Risk Level: ZERO — Enhances the document agent significantly
```

### ✅ Feature 7: Offline Voice-First UI (No Typing at All)
```
Infosys mentioned: "Usability for non-technical user" as evaluation criteria

Our Addition:      100% voice-driven interface
                   → No keyboard needed
                   → Large buttons, icon-based navigation
                   → Every response spoken aloud
                   → Works for illiterate users too

Why it's better:   Directly addresses evaluation criterion #5
                   Most pilgrims at Kumbh Mela are elderly/rural

Risk Level: ZERO — They evaluate on this criterion!
```

---

## 4. Features You Should NOT Add (Risk Areas)

### ❌ Don't Add: Full Cloud Backend
```
Infosys requirement: "Offline-first, airplane-mode parity"
If you add: Cloud API calls for core features

Problem: Directly violates their core requirement
         Will FAIL evaluation criterion #3 (True offline)
```

### ❌ Don't Add: Heavy Social Features (Chat, Forums)
```
Risk: Out of scope, wastes development time
      Evaluators will question relevance
      Better to perfect the 7 agents than add unrelated features
```

### ❌ Don't Add: Real Payment Gateway
```
Risk: Security compliance nightmare
      Out of scope for a student FYP
      Mock/simulated booking is perfectly acceptable
      (Infosys even says "or mock APIs" for transport)
```

---

## 5. Final Recommended Tech Stack (Enhanced)

| Category | Infosys Said | Our Choice | Enhancement |
|---|---|---|---|
| **Mobile Framework** | *(not specified)* | Flutter 3.x | Cross-platform, offline maps built-in |
| **ASR** | Compact multilingual ASR (quantized) | Whisper.cpp (tiny/small) | Best multilingual, 150MB, proven |
| **TTS** | Open multilingual TTS | Coqui TTS / MMS-TTS | Free, supports Hindi/Tamil/Telugu |
| **Planner LLM** | Small function-calling model | Phi-3 Mini 3.8B (4-bit) | Runs on mid-range Android phones |
| **NLU/NER** | BERT-style model | MobileBERT / DistilBERT (ONNX) | 60MB, fast, accurate |
| **Semantic Search** | Multilingual sentence embedding | LanceDB + paraphrase-multilingual | On-device vector DB (our addition!) |
| **RAG** | *(not mentioned)* | LanceDB + personal data | NEW — smart personal context |
| **Secure Storage** | Platform keystore/keychain | flutter_secure_storage | Implements exactly what they asked |
| **Inference Runtime** | ONNX Runtime / llama.cpp | Both (ONNX for BERT, llama.cpp for LLM) | Best of both worlds |
| **Offline Maps** | *(not specified)* | flutter_map + MBTiles + Valhalla | Our addition — navigation agent |
| **OCR** | *(not mentioned)* | Google ML Kit (offline) | Our addition — document upload |
| **Mesh Network** | "local mesh broadcast" (hinted) | Bridgefy SDK / BLE | Implements their own hint |
| **Agent Framework** | *(not specified)* | LangGraph pattern in Dart | Our addition — better coordination |

---

## 6. Summary: Answer to Your Question

```
Q: "Can we add new features or must we do exactly as Infosys said?"

A: YES, you can and SHOULD add new features.

Here is why:

1. Infosys uses "Suggested" tech stack → it's a recommendation
2. They say "or an equivalent" → they expect you to find alternatives
3. Evaluation rewards QUALITY → basic implementation won't score high
4. RAG, Flutter, LanceDB, OCR are all ENHANCEMENTS to their spec
5. None of our additions violate any of their fixed requirements

The RULE is:
  → Keep all 7 agents ✅
  → Keep offline-first ✅  
  → Keep 2-3 languages ✅
  → Keep document security ✅
  → Everything else → INNOVATE FREELY 🚀

Our additions (RAG, OCR, Mesh, Flutter) actually make the project
STRONGER on all 5 evaluation criteria.
```

---

*Analysis based on PathSaathi Problem Statement 2 — Infosys FYP*
