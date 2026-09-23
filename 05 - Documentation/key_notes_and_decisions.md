# PathSaathi — Key Notes & Decisions
*Quick reference for team members and professors*

## Current implementation decisions

- Destination requests are resolved dynamically; curated destination records
  are used only when verified local data exists.
- Maps open at the traveller's latest real GPS source location. The requested
  destination remains a target marker.
- Offline map tiles use one shared app-private cache and a persistent
  installation marker, so later trips reuse the same downloaded map.
- Online road routing is preferred. Offline route geometry is used only when a
  local graph or cached route is available; a straight line is never presented
  as road navigation without a limitation message.
- Transport schedules and hotel vacancies are clearly indicative prototype data
  unless a trusted live provider is connected.
- The voice companion answers from GPS and active journey data and does not
  invent live vehicle positions or booking availability.
- Secure document photos remain on-device in encrypted secure-storage chunks,
  avoiding value-size limits while allowing the photo to be restored after
  unlock.

## Known limitations

- Live ticket inventory, fares, and bus positions need operator integrations.
- The prototype routing endpoint must be replaced by an approved,
  rate-limited service before production release.
- Detailed offline street routing exists only for packaged or cached regions.
- UI language coverage is broader than the deepest grounded voice-answer
  coverage, which currently has the strongest English, Hindi, and Telugu
  support.

---

## ❓ Why Flutter?
- Infosys did NOT specify a mobile framework — choice is ours
- Flutter gives cross-platform (Android + iOS) from one codebase
- `flutter_map` package provides offline map support with MBTiles
- `flutter_secure_storage` wraps Android Keystore natively
- Platform Channels allow calling native C++ code (llama.cpp, ONNX)

---

## ❓ Why RAG (LanceDB)?
- Infosys mentioned "semantic search" but never specified which vector DB
- RAG solves a key LLM limitation: LLMs don't know personal/current data
- LanceDB runs fully embedded on-device — no server, no internet
- Personal pilgrim data (medical, tickets, contacts) stored as vector chunks
- Event data (schedules, crowd predictions) also stored for fresh retrieval
- This directly improves Evaluation Criterion #5 (usability for non-tech users)

---

## ❓ What is Quantization?
- Shrinking AI models to fit on a phone without significant accuracy loss
- float32 (4 bytes/weight) → int8 (1 byte/weight) = 4x smaller
- float32 → int4 = 8x smaller
- Whisper tiny (int8): ~150MB | Phi-3 Mini (4-bit): ~2GB
- Tools: llama.cpp (for LLMs), ONNX Runtime (for BERT/Whisper)
- Pre-quantized models available on Hugging Face — no need to do it yourself

---

## ❓ How Does Offline Work?
1. Pre-trip: Download all AI models + event data once over WiFi
2. At event: All processing happens on-device (CPU/GPU of phone)
3. No cloud API calls for any core feature
4. Sync happens automatically when internet returns (schedules, advisories)

---

## ❓ Can We Add Features Beyond Infosys Spec?
YES — Infosys says "Suggested Tech Stack" not "Mandatory"
- Keep all 7 agents ✅ (fixed)
- Keep offline-first ✅ (fixed)
- Keep 2-3 languages ✅ (fixed)
- Keep document security ✅ (fixed)
- Framework, RAG, maps, OCR, mesh → our choice 🚀

---

## 🔑 Key Technical Decisions

| Decision | Choice | Alternative Considered |
|---|---|---|
| Mobile Framework | Flutter | React Native, Native Android |
| LLM | Phi-3 Mini 3.8B 4-bit | Gemma 2B, Llama 3.2 3B |
| ASR | Whisper.cpp tiny/small | MMS-ASR, wav2vec2 |
| TTS | Coqui TTS / MMS-TTS | Piper TTS, eSpeak |
| NLU | MobileBERT (ONNX) | DistilBERT, TinyBERT |
| Embedding | MiniLM-L12 multilingual | LaBSE, mUSE |
| Vector DB | LanceDB Embedded | ChromaDB, FAISS |
| Maps | flutter_map + MBTiles | Mapbox, MapLibre |
| OCR | Google ML Kit | Tesseract |
| Mesh | Bridgefy SDK / BLE | WiFi Direct |
| Routing | Valhalla (offline) | OSRM, GraphHopper |

---

## 📱 Supported Languages (Target)
1. Hindi (hi) — Primary
2. Tamil (ta) — Secondary
3. Telugu (te) — Tertiary

Evaluation minimum: 2-3 languages
Bonus: Bengali, Marathi, Kannada

---

## 🏗️ App Size Estimate

| Component | Size |
|---|---|
| Whisper tiny ASR | ~150 MB |
| Phi-3 Mini LLM (4-bit) | ~2.0 GB |
| MobileBERT NLU | ~60 MB |
| MiniLM embedding | ~90 MB |
| Coqui TTS (3 langs) | ~200 MB |
| Offline maps (region) | ~500 MB |
| Event data (SQLite) | ~50 MB |
| **Total** | **~3.1 GB** |

*Note: Typical flagship phone has 128-256GB storage. 3.1GB is acceptable.*

---

## ⚠️ Key Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Phi-3 Mini too slow on low-end phones | Use Gemma 2B or reduce context window |
| Whisper ASR accuracy on noisy crowd | Add noise cancellation preprocessing |
| Map tiles too large to download | Use region-specific tile packs, not full India |
| BLE range limited | Chain via multiple devices (mesh relay) |
| llama.cpp platform channel complexity | Use MediaPipe LLM API (easier Flutter integration) |

---

*Notes maintained by FYP Team | PathSaathi v1.0*
