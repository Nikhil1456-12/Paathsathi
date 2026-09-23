# Design — Reliability Baseline & Device QA Harness

> Scope guard: Design only. No implementation, no Tasks, no application-behavior
> changes, no new travel features. This document describes HOW the approved
> requirements will be realized so it can be reviewed before any work begins.

## 1. Overview

The reliability gate is a **documentation + scripting layer around the existing
project** — not new app code. It has four artifacts:

1. A **Baseline Manifest** (`BASELINE.md`) that freezes the current tests,
   invariants, known limitations, and build info.
2. A **Device QA Harness** (`qa/` scripts + `DEVICE_QA.md` runbook) — batched ADB
   command sequences producing evidence.
3. A **QA Report template** (`qa/REPORT.md`) where each run records
   PASS/FAIL/UNKNOWN + evidence.
4. The **existing automated test suite** (unchanged, frozen) as the logic core.

The only thing that may change application code is a *discovered defect* handled
under the Failure Protocol — and only with maintainer-visible justification.

### Design principles
- **Truthful by construction:** the report template forces a status + evidence
  field per item; a blank evidence field cannot be PASS.
- **Cheap by construction:** one batched device script per phase; the full test
  suite runs at checkpoints, not per trivial change.
- **Reproducible:** every device action is a copy-pasteable ADB command with the
  reference device id.
- **No hidden dependencies:** ADB-only required; Termux optional and never on the
  critical path.

---

## 2. Artifact layout

```
04 - Flutter App/pathsaathi/
├─ test/                              # FROZEN baseline (unchanged)
│  ├─ destination_resolution_test.dart   (11 blocks)
│  ├─ qa_adversarial_test.dart           (12 blocks, parameterized)
│  ├─ qa_kedarnath_test.dart             (6 blocks, parameterized)
│  ├─ pathsaathi_full_suite_test.dart    (31 blocks)
│  └─ widget_test.dart                   (1 block)
└─ .kiro/specs/reliability-baseline-device-qa/
   ├─ requirements.md   (approved)
   ├─ design.md         (this file)
   ├─ BASELINE.md       (to be created in Tasks) — the frozen manifest
   ├─ DEVICE_QA.md      (to be created in Tasks) — the device runbook
   └─ qa/
      ├─ run_baseline.(ps1)      # runs flutter test, captures pass/fail
      ├─ device_qa.(ps1)         # batched ADB harness, writes evidence
      └─ REPORT.md               # latest run results (status + evidence)
```

> Note on counts: 61 declared `test(`/`testWidgets(` blocks expand to ~124
> executed cases via loops/matrices. The manifest records BOTH numbers so a
> future reader isn't confused (declared blocks vs executed cases).

---

## 3. Component design

### 3.1 Baseline Manifest (`BASELINE.md`)
A static, version-controlled document. Sections:
- **Frozen test inventory:** the 5 files, declared-block counts, executed-case
  count, and the command to reproduce (`flutter test`).
- **Protected invariants I1–I9** (copied from Requirements) with the test(s) that
  cover each — a traceability table (see §5).
- **Known limitations** (honest): direct-line guidance (not turn-by-turn);
  schematic offline map unless real MBTiles bundled; live travel search not
  implemented; on-device LLM/NLU are placeholders; STT/TTS offline depends on
  device language packs; Flutter-canvas means no adb UI tap / no live STT drive.
- **Build info:** app id `com.pathsaathi.pathsaathi`, release APK ~59.2 MB,
  arm64-v8a, Flutter/Dart versions, reference device CPH2467 / Android 15.
- **Change log:** appended only when the baseline legitimately changes (Req 1.3).

### 3.2 Automated baseline runner (`qa/run_baseline.ps1`)
- Runs `flutter test` from the project root.
- Parses the summary line; emits `BASELINE: PASS (N/N)` or `BASELINE: FAIL`.
- Non-zero exit on any failure so it can gate later steps.
- Does NOT modify tests. Read-only over the suite.

### 3.3 Device QA Harness (`qa/device_qa.ps1` + `DEVICE_QA.md`)
- Single script, **phased**, each phase = one batched ADB invocation writing a
  labelled block to `qa/REPORT.md`.
- Uses the reference device id (`c3780eb2`) with a `-s` selector; prefers USB.
- **Restores** connectivity + `location_mode` at the end (Req 2.7).
- Phases map 1:1 to Requirement 2 checks (see §4).
- Every phase writes: timestamp, command(s) run, captured output excerpt, and a
  human-set status placeholder (`STATUS: PASS|FAIL|UNKNOWN`) that the operator
  fills based on evidence — the script never auto-stamps PASS for hardware
  behaviors it cannot semantically judge (e.g. "map shows correct place"); it
  captures the objective signals (pid alive, no FATAL, PSS value, persisted-pref
  contents, location request registration) that justify the status.

### 3.4 QA Report (`qa/REPORT.md`)
- One table per run: Check | Requirement | Evidence ref | Status | Notes.
- UNKNOWN is the default until evidence is attached.
- A trailing "Gate summary" block computes READY/NOT-READY per Req 7 — but only
  the maintainer sets the final READY (script prints "NOT READY" if any critical
  item ≠ PASS, never the reverse-with-authority).

---

## 4. Device harness phase design (maps to Requirement 2 & 3)

Each phase is a batched command. Objective signals captured are listed; the
operator sets status from them.

| Phase | Checks (Req) | Batched ADB actions | Objective signals captured |
|---|---|---|---|
| P0 Preflight | 2.1, 2.6 | `adb devices`; confirm USB `c3780eb2`; `pidof`; app installed | device present; usb vs wifi noted |
| P1 Clean launch | 2.2 | logcat -c; `am start`; sleep; `pidof`; logcat scan | pid alive; no FATAL/ANR |
| P2 Rapid relaunch ×5 | 2.2 | loop start/force-stop ×5; final start; `pidof` | survives cycles; no FATAL |
| P3 Background/foreground | 2.2 | `input keyevent HOME`; sleep; `am start`; `pidof` | resumes; no crash |
| P4 Force-stop→relaunch | 2.2 | `force-stop`; `am start`; `pidof` | relaunch ok |
| P5 Offline launch | 2.2 | airplane on + wifi off (USB adb); `force-stop`; `am start`; `pidof`; logcat | launches offline; no infinite-load crash; no FATAL |
| P6 Offline restart persistence (Journeys A/B/D hardware part) | 2.2, 3 | while offline: `force-stop`; `am start`; read `shared_prefs/FlutterSharedPreferences.xml` | `selected_language_code` present; `confirmed_destination_id` present + equals last confirmed; NOT a stale/rejected id |
| P7 GPS OFF (Journey E) | 2.2, 3 | `settings put secure location_mode 0`; `am start`; `dumpsys location \| grep pathsaathi` | app requests location / handles absence; no fabricated fix (operator confirms UI shows unavailable/searching, not a fake lock) |
| P8 Permission states | 2.2 | inspect `dumpsys package … permission`; (revoke where ROM allows) | FINE/COARSE declared; grant state recorded |
| P9 GPS ON recovery (Journey F) | 2.2, 3 | `settings put secure location_mode 3`; `am start`; `dumpsys location` last fix | live GPS registration; real fix appears (satellites>0) offline |
| P10 Network loss/recovery | 2.2 | toggle airplane/wifi ON→OFF→ON; `pidof`; logcat | survives toggles; no FATAL; no stuck state |
| P11 Memory soak (light) | 2.2 | 3× (launch/bg/fg/offline-toggle) with `dumpsys meminfo` TOTAL PSS at start/mid/end | 3 PSS values → trend (flag if monotonic large growth) |
| P12 Restore + crash/ANR summary | 2.7, 2.2 | restore airplane off/wifi on/location 3; full logcat scan | connectivity restored; crash/ANR count |

Constraint honored: Flutter canvas cannot be tapped via adb, so phases capture
**process/prefs/location/log** signals; the semantic UI parts of Journeys A/B/D/E
(that the correct place/text is shown) are operator-confirmed by glancing at the
device once, and that confirmation is recorded as the evidence note. Journey C is
NOT in this table — it is logic-only (see §5).

---

## 5. Requirements → coverage traceability

| Invariant / Journey | Covered by (automated) | Covered by (device) |
|---|---|---|
| I1 pending≠confirmed | qa_adversarial, qa_kedarnath | P6 (persisted id is confirmed only) |
| I2 new confirmed replaces old | qa_adversarial, qa_kedarnath (Seq2, chain) | P6 (Journey B) |
| I3 language change ≠ destination change | (add note: covered by state tests; travel state has no language field) | P6 (Journey D) |
| I4 network loss ≠ state corruption | — (logic has no network coupling) | P5, P6, P10 |
| I5 no fabricated GPS | LocationService design (no default coords) | P7 (Journey E) |
| I6 general Q → null | destination_resolution, qa_adversarial, qa_kedarnath | n/a |
| I7 offline ≠ fake live | — | P5, P10 (observe) |
| I8 selected language controls voice | voice_strings tests | operator glance (P6/P7) |
| I9 restart restores confirmed only | travel_context persistence (design) | P6 (Journeys A/B/D) |
| Journey A | logic core (Kedarnath resolve + confirm) | P6 |
| Journey B | qa_kedarnath Seq2/chain | P6 |
| Journey C | qa_kedarnath Seq (reject keeps prior) — **logic only** | — |
| Journey D | logic (lang + confirmed independent) | P6 |
| Journey E | — | P7 |
| Journey F | — | P9 |

Gaps this table reveals (to be addressed in Tasks, NOT now):
- I3 and I9 have strong logic coverage in `travel_context` behavior but no single
  explicitly-named test asserting "change language does not mutate confirmed
  destination". Design decision: add ONE small automated test for I3/I9 to the
  suite during Tasks (this is an *addition*, not a weakening; baseline count
  updates with rationale per Req 1.5). Flagged here for your visibility.

---

## 6. Failure protocol design (Req 5)

A lightweight `qa/REPORT.md` "Defects" table with columns exactly matching Req
5.1 (id, scenario, input, expected, actual, language, network, GPS, screen,
evidence, reproducible, severity). Workflow encoded in `DEVICE_QA.md`:

```
find → record row → classify P0–P3 → smallest fix (app code only if required)
→ re-run exact failed check → re-run targeted regression subset
→ re-run full baseline at next checkpoint → update row status
```

No fix is “done” until its check passes AND `flutter test` is 100% green.

## 7. Low-credit execution model (Req 6)

- `run_baseline.ps1` = 1 command for all logic tests.
- `device_qa.ps1` = phased; a full pass is a handful of batched commands, not
  dozens. Re-runs target only the affected phase after a fix.
- No APK rebuild unless app code changed (rebuild only in the Failure Protocol).
- Source inspection reuses the architecture map already established; the design
  does not re-read unrelated files.

## 8. Future-feature gate design (Req 7)

`BASELINE.md` ends with a **Gate Checklist** (a–g from Req 7.1) rendered as a
checkbox list with a status column. A helper note in the runbook states: the gate
prints "NOT READY — FIX THESE FIRST" (+ smallest fix list) whenever any item is
UNKNOWN/FAIL; only the maintainer flips items to READY, and never while a critical
hardware item is UNKNOWN.

## 9. Explicit non-goals

- No CI, no cloud, no Termux dependency.
- No new app feature; no train/bus/flight; no Offline Travel Planning.
- No UI redesign; no localization expansion.
- No change to the frozen tests except the single flagged I3/I9 addition (with
  documented rationale) and any Failure-Protocol-driven fix.

## 10. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Wireless adb drops when WiFi disabled | Harness mandates USB for offline phases (P5–P10). |
| Operator marks PASS without evidence | Report template requires an evidence ref; script leaves STATUS=UNKNOWN by default. |
| Device unavailable at run time | Phases record UNKNOWN; gate stays NOT READY. |
| Baseline drift over time | Manifest change log + Req 1 rules; count changes require rationale. |
| Memory trend noisy | Light soak reports 3 PSS points as a trend, not a single number; flags only large monotonic growth. |

## 11. Design decisions needing your confirmation (before Tasks)

- **D1:** Scripts as PowerShell (`.ps1`) since the environment is Windows/pwsh.
  OK, or prefer plain `.md` runbook with copy-paste commands and no script files?
- **D2:** Add ONE new automated test for I3/I9 ("language change never mutates
  confirmed destination; restart restores confirmed not pending") during Tasks —
  approved as an addition (not a baseline weakening)? This is the only proposed
  test-suite change.
- **D3:** Artifacts live under `.kiro/specs/reliability-baseline-device-qa/`
  (BASELINE.md, DEVICE_QA.md, qa/). OK, or do you want BASELINE.md at project
  root for visibility?
