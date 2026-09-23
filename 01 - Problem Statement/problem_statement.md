# Problem Statement 2: PathSaathi
## Vernacular AI Concierge for Pilgrims and Visitors at Large Public Gatherings

**Domain:** Multilingual NLP / Multi-Agent Systems / Offline-First Mobile AI

**Given By:** Infosys

---

## Background

Large-scale public gatherings and pilgrimages — some attracting hundreds of millions of visitors over several weeks — bring together people speaking dozens of regional languages, with patchy connectivity and varying digital literacy. Existing event/travel apps typically assume English fluency, stable connectivity, and comfort filling out forms — none of which reliably holds at such events. A better solution is an on-device AI concierge that understands spoken regional languages, works fully offline, and syncs gracefully whenever connectivity returns.

---

## Problem Statement

Build a swarm of specialized on-device agents coordinated by a central planner that lets a visitor speak in their own language and get help booking transport, finding accommodation, viewing local advisories, and retrieving personal documents — with every feature available offline as well as online (airplane-mode parity is the bar).

---

## Objectives

- Support intent understanding and response generation in multiple regional languages via on-device speech and language models.
- Decompose a spoken request into sub-tasks handled by specialized agents (transport, accommodation, itinerary, safety, navigation, document retrieval).
- Ensure the system is offline-first, with all core features usable with no network connection.
- Handle secure, on-demand retrieval of personal documents (e.g., ID or certificate lookups) without those documents leaving the device.

---

## Key Modules

| Module | Responsibility |
|---|---|
| **Speech & Language Agent** | ASR, language identification, and text-to-speech across multiple regional languages |
| **Planner / Orchestrator** | Decomposes a user's spoken goal into structured agent tasks (function-calling capable LLM) |
| **Transport Booking Agent** | Queries transport APIs (or mock APIs) for trains, buses, or shuttle services |
| **Accommodation Agent** | Searches available lodging/camp allotments |
| **Itinerary Agent** | Generates a day-wise schedule, local timings, and crowd/congestion predictions |
| **Secure Document Agent** | OAuth-based (or mocked) integration for retrieving ID and certificate documents from a secure digital locker |
| **Safety & Alert Agent** | Offline-cached advisories and emergency alerts (e.g., via local mesh broadcast) |
| **Navigation Agent** | On-device offline maps; indoor routing; lost-and-found support |

---

## Suggested Tech Stack

- **Speech/ASR:** A compact multilingual ASR model (quantized)
- **TTS:** An open multilingual text-to-speech model for regional languages
- **Planner LLM:** A small function-calling capable model
- **NLU/NER:** A regionally appropriate BERT-style model for intent classification and entity extraction
- **Semantic search:** A multilingual sentence-embedding model for FAQ/policy document search
- **Secure storage:** Device-native secure storage (e.g., platform keystore/keychain) for cached credentials
- **On-device inference runtime:** ONNX Runtime Mobile, llama.cpp, or an equivalent local inference engine

---

## Document Integration Notes

For a live integration, an OAuth 2.0 with PKCE flow against a sandbox digital-locker service can be used. For offline demos, a mocked local JSON store mirroring the expected document responses (ID, certificates, vaccination record, etc.) is an acceptable substitute. The owning agent should manage the full credential lifecycle — token refresh, encrypted local caching, and on-demand presentation — with documents never leaving the device.

---

## Deliverables

- A working prototype supporting at least 2–3 regional languages end-to-end (speech in → agent action → spoken response).
- Demonstration of full functionality in offline (airplane) mode.
- Architecture diagram of the agent swarm and planner.

---

## Evaluation Criteria

- Breadth and accuracy of language support
- Quality of task decomposition and agent coordination
- True offline functionality
- Security handling of personal documents
- Overall usability for a non-technical user

---

*Problem Statement issued by Infosys | Final Year Project 2025-26*
