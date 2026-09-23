# Requirements — Reliability Baseline & Device QA Harness

> Scope guard: This spec establishes a **permanent reliability gate** for PathSaathi.
> It does **not** implement any new travel feature (no train/bus/flight APIs, no
> Offline Travel Planning, no UI redesign). No existing application behavior is
> changed by this document. Requirements only — Design and Tasks are deferred
> until this document is approved.

## Introduction

PathSaathi has reached a verified milestone: 124/124 logic/regression tests pass,
two real P1 defects were fixed (Kedarnath/Char Dham destinations missing from the
place index; confirmed destination not persisted across restart), and adversarial
destination/confirmation sequences pass. However, three critical **physical-device**
checks remain **UNKNOWN** because device runs were interrupted:

1. Offline restart persistence on hardware.
2. GPS OFF → truthful "unavailable" state → GPS ON recovery on hardware.
3. Physical-device memory-soak / leak trend.

This feature turns the current QA work into a **repeatable, permanent reliability
gate** that every future PathSaathi feature must pass. It defines: the frozen
regression baseline, a low-cost ADB/Termux device harness, reusable critical
pilgrim journeys (centered on Kedarnath), strict PASS/FAIL/UNKNOWN truthfulness
rules, a failure-handling protocol, and a future-feature gate.

## Definitions

- **Baseline suite**: the current passing set of automated logic/regression tests
  (124 tests across the existing test files).
- **Device harness**: the documented, scripted ADB (+ Termux/SSHD where useful)
  procedure that exercises the app on a real Android phone.
- **PASS**: behavior directly observed and evidenced (test output or device log).
- **FAIL**: failure directly reproduced with evidence.
- **UNKNOWN**: test could not be completed or evidence is insufficient. Never
  promoted to PASS via source inspection or unit tests alone.
- **Critical journey**: a named end-to-end scenario (A–F) that must be verifiable
  on device.
- **Reliability gate**: the combined condition that must hold before any major
  new feature work begins.

---

## Requirement 1 — Permanent Regression Baseline

**User story:** As the project maintainer, I want the existing passing tests
frozen as a mandatory baseline, so future changes cannot silently weaken or
bypass proven behavior.

### Acceptance Criteria
1. WHEN the baseline is defined THEN the system SHALL enumerate every existing
   automated test file and its test count as the frozen baseline (currently
   `test/destination_resolution_test.dart`, `test/qa_adversarial_test.dart`,
   `test/qa_kedarnath_test.dart`, `test/pathsaathi_full_suite_test.dart`,
   `test/widget_test.dart` — 124 tests total).
2. WHEN any future change is proposed THEN the baseline suite SHALL be run and
   SHALL report 100% pass before the change is considered complete.
3. IF a baseline test must change because behavior intentionally changes THEN the
   change SHALL be documented with (a) the reason, (b) the old vs new expected
   behavior, and (c) evidence that equivalent or greater coverage is preserved.
4. The system SHALL NOT delete, skip, weaken assertions in, or comment out a
   baseline test merely to obtain a green result.
5. WHEN the baseline changes for a legitimate reason THEN the new test count and
   rationale SHALL be recorded in the baseline manifest.

### Invariants that the baseline must permanently protect
- I1: An unconfirmed (pending) destination SHALL NEVER become the confirmed
  destination without explicit confirmation.
- I2: A newly confirmed destination SHALL replace the previous confirmed
  destination.
- I3: Changing language SHALL NOT change the destination or trip context.
- I4: Network loss SHALL NOT corrupt persisted travel state.
- I5: GPS failure SHALL NOT create fabricated location data.
- I6: General/knowledge questions SHALL resolve to `null` (never invent a
  destination).
- I7: Offline mode SHALL NEVER present live data as available.
- I8: The selected language SHALL control user-facing voice/UI responses.
- I9: App restart SHALL restore the CONFIRMED destination only, never a stale
  pending guess, and never an obsolete previous destination after a newer one is
  confirmed.

---

## Requirement 2 — Physical-Device QA Harness

**User story:** As a QA engineer, I want a repeatable, low-cost device test
procedure using the existing ADB/Termux/SSHD setup, so hardware behavior is
verified consistently and cheaply.

### Acceptance Criteria
1. WHEN the harness is defined THEN it SHALL document exact ADB command sequences
   (batched to minimize runs) for each device check below.
2. The harness SHALL cover: clean launch; rapid relaunch (≥5×); background →
   foreground; force-stop → relaunch; offline launch; offline restart; GPS OFF;
   GPS ON recovery; location-permission states (granted / denied / permanently
   denied); weak/unavailable GPS; network loss and recovery; language
   persistence; confirmed-destination persistence; crash detection (logcat
   `FATAL EXCEPTION`); ANR detection (logcat `ANR in`); and memory checkpoints
   (`dumpsys meminfo` TOTAL PSS) at ≥3 points for a leak trend.
3. WHEN a device check runs THEN its result SHALL be recorded as PASS / FAIL /
   UNKNOWN with evidence (command output or logcat excerpt).
4. IF a device check cannot be completed (interrupted, no device, WiFi-adb
   dropped) THEN it SHALL be recorded as **UNKNOWN**, never PASS.
5. The harness SHALL explicitly note the known constraint that Flutter renders to
   a single canvas, so ADB/uiautomator cannot read or tap in-canvas widgets and
   cannot drive live STT/TTS; voice-flow correctness is therefore covered by
   logic tests, while the harness covers lifecycle/persistence/GPS/network/crash.
6. The harness SHALL prefer USB adb for tests that disable WiFi (since disabling
   WiFi severs wireless adb), and SHALL state this in the procedure.
7. The harness SHALL restore device connectivity and location settings to a
   normal state at the end of a run.

---

## Requirement 3 — Critical Pilgrim Journeys (Kedarnath-centered)

**User story:** As the maintainer, I want named, reusable end-to-end scenarios so
the most important real-world flows are always checked the same way.

### Acceptance Criteria
1. The system SHALL define these journeys as the critical set:
   - **A (offline persistence):** Hindi → "मुझे केदारनाथ जाना है" → confirmation
     → YES → Kedarnath confirmed → internet OFF → restart → Kedarnath remains.
   - **B (replacement persistence):** Kedarnath → confirm → change to Mumbai →
     confirm → restart → Mumbai remains (NOT Kedarnath).
   - **C (reject keeps prior):** Kedarnath confirmed → propose Mumbai → reject →
     Kedarnath remains confirmed.
   - **D (language + offline restart):** Kedarnath → confirm → switch language →
     restart offline → destination and language both remain correct.
   - **E (GPS truthful):** GPS OFF → app clearly reports location unavailable and
     NEVER fabricates coordinates or a GPS lock.
   - **F (GPS recovery):** GPS ON → location becomes available and app recovers.
2. WHEN a journey has a logic-verifiable core (A, B, C, D destination/state parts)
   THEN it SHALL have a corresponding automated test in the baseline.
3. WHEN a journey requires hardware (offline restart persistence for A/B/D; GPS
   for E/F) THEN it SHALL be executed via the device harness and recorded with
   evidence, and SHALL remain UNKNOWN until so executed.
   - Clarification (approved): Journeys **A, B, D, E, F require physical-device
     verification**. Journey **C is primarily logic/state verification and is
     covered by the automated baseline**; C SHALL NOT be represented as an
     ADB-driven hardware interaction.
4. Journey B SHALL explicitly assert no stale Kedarnath remains after Mumbai is
   confirmed and the app is restarted.
5. Journey E SHALL explicitly assert the GPS status text is one of the truthful
   states (searching / weak / unavailable / permission-required / services-off)
   and that no position marker claims a fabricated fix.

---

## Requirement 4 — Truthfulness & Evidence Rules

**User story:** As the maintainer, I want strict honesty rules so a green report
never hides an unverified or failing behavior.

### Acceptance Criteria
1. Every reported item SHALL carry exactly one status: PASS, FAIL, or UNKNOWN.
2. A status of PASS SHALL require directly observed evidence (test output or
   device log excerpt) attached or referenced.
3. The system SHALL NOT convert UNKNOWN to PASS on the basis of source inspection
   or unit tests when the requirement is a hardware behavior.
4. The reliability gate SHALL NOT report "READY" while any critical hardware test
   (Requirement 3: A/B/D offline restart, E/F GPS) is UNKNOWN or FAIL.
5. Reports SHALL NOT use the word "perfect" and SHALL always list remaining risks
   and UNKNOWNs.
6. The three currently-open items SHALL be tracked explicitly as UNKNOWN until
   verified: offline-restart persistence, GPS OFF→ON truthful behavior, device
   memory-soak trend.

---

## Requirement 5 — Failure Protocol

**User story:** As the maintainer, I want a disciplined, minimal-change failure
process so fixing one defect never destabilizes the rest.

### Acceptance Criteria
1. WHEN a failure is found THEN it SHALL be recorded with: id, scenario, exact
   input, expected, actual, language, network state, GPS state, screen, evidence,
   reproducibility, and severity (P0/P1/P2/P3).
2. WHEN a fix is applied THEN it SHALL be the smallest correct change addressing
   the root cause, with no unrelated refactoring.
3. WHEN a fix is applied THEN the exact failed test SHALL be re-run, THEN the
   relevant regression subset, THEN the full baseline at the next checkpoint.
4. Severity SHALL follow: P0 = crash/corruption/dangerous navigation/unusable;
   P1 = wrong destination / confirmation bypass / broken offline nav / severe
   language-or-state failure / major GPS failure; P2 = recoverable degradation;
   P3 = minor/cosmetic.
5. A fix SHALL NOT be considered complete until its test passes AND the baseline
   remains 100% green.

---

## Requirement 6 — Low-Kiro-Credit Strategy

**User story:** As the maintainer, I want the QA workflow to consume minimal Kiro
credits while maximizing coverage.

### Acceptance Criteria
1. The workflow SHALL inspect source once and reuse findings rather than
   re-reading the same files.
2. Device and shell commands SHALL be batched into as few executions as
   practical.
3. The workflow SHALL reuse existing tests/helpers and SHALL NOT create duplicate
   test infrastructure.
4. The workflow SHALL avoid unnecessary APK rebuilds (rebuild only when app code
   changed).
5. AFTER a small fix THEN only targeted tests SHALL run; the full baseline SHALL
   run at meaningful checkpoints, not after every trivial change.
6. The workflow SHALL NOT re-run identical passing tests without a specific
   reason.

---

## Requirement 7 — Future-Feature Gate

**User story:** As the maintainer, I want a permanent precondition so no major
feature begins on an unstable base.

### Acceptance Criteria
1. BEFORE any major feature (e.g. Offline Travel Planning, train/bus/flight
   search, live APIs, Journey Safety Pack) begins, ALL of the following SHALL
   hold and be evidenced:
   - a. baseline regression suite is 100% green;
   - b. critical device journeys (Req 3: A, B, C, D, E, F) are PASS (not UNKNOWN);
   - c. no unresolved P0 or P1 defects;
   - d. no unexplained crash or ANR in the device runs;
   - e. confirmed-destination + language persistence verified on device;
   - f. GPS behavior verified truthful on device;
   - g. offline behavior (launch + restart) verified on device.
2. IF any gate item is UNKNOWN or FAIL THEN the gate SHALL report
   "NOT READY — FIX THESE FIRST" with the smallest required fix list.
3. The gate result SHALL be recorded in a durable location (baseline manifest /
   QA report) so it is auditable later.

---

## Requirement 8 — Stable Baseline Documentation

**User story:** As the maintainer, I want the passing baseline and procedures
documented durably so they become the permanent regression suite.

### Acceptance Criteria
1. The system SHALL produce a baseline manifest listing: test files + counts,
   protected invariants (I1–I9), device harness procedure, critical journeys
   (A–F), known limitations, and current build/APK info.
2. The manifest SHALL record the current known limitations honestly, including:
   direct-line guidance (not turn-by-turn); offline map is schematic unless real
   MBTiles are bundled; live travel search not implemented; on-device LLM/NLU
   models are placeholders; STT/TTS offline depends on device language packs.
3. The manifest SHALL be updated whenever the baseline legitimately changes.

---

## Resolved Decisions (maintainer-approved)

1. **Reference device:** OnePlus CPH2467 / Android 15 is the primary reference
   device; no additional device required for this baseline.
2. **Termux/SSHD:** OPTIONAL. ADB-only is the primary required method. Termux may
   be used only when it adds value. The gate MUST NOT depend on Termux.
3. **Memory soak:** Light/medium soak — repeated lifecycle/relaunch/offline
   cycles with ≥3 PSS checkpoints. No multi-hour endurance requirement.
4. **CI:** Manual/on-demand only. No CI infrastructure in this spec.
5. **Weak GPS:** Deterministically test GPS OFF, permission denied/permanently
   denied, unavailable state, and GPS ON recovery. Genuine weak/low-accuracy GPS
   cannot be reliably forced via ADB → observe-only; record UNKNOWN if not
   reproducible (never invent a PASS).
6. **Baseline:** Freeze the current 5 test files / 124 tests exactly. Do not add
   tests to the frozen baseline before approval.
7. **READY authority:** The maintainer is the final authority for READY. Kiro
   reports evidence + PASS/FAIL/UNKNOWN and MUST NOT declare READY while any
   critical hardware check is UNKNOWN or FAIL.
8. **Journey C:** Logic/state-verified via the automated baseline; not
   represented as an ADB hardware interaction (see Requirement 3 clarification).

## Open Questions / Assumptions (original — now superseded by Resolved Decisions above)

1. **Device availability:** Assumes the OnePlus CPH2467 (Android 15) remains the
   reference device, reachable via USB (preferred) or wireless adb. Is any other
   device required for the gate?
2. **Termux/SSHD role:** ADB alone covers all listed checks. Assumption: Termux/
   SSHD is optional and only used if a device-side shell adds value (e.g. running
   a loop on-device). Confirm whether Termux usage is required or nice-to-have.
3. **Memory-soak depth:** Assumption is a "light soak" — repeated
   launch/background/foreground/offline-toggle cycles with ≥3 PSS checkpoints,
   not a multi-hour endurance run (to respect the credit budget). Is a longer
   soak wanted?
4. **CI vs manual:** Assumption is the gate runs manually (invoked on demand),
   not wired into a CI pipeline. Confirm no CI integration is expected in this
   spec.
5. **GPS "weak/low accuracy" simulation:** True weak-signal can't be forced
   deterministically via adb. Assumption: we test GPS OFF, permission states, and
   ON-recovery deterministically, and treat "weak accuracy" as observe-only
   (recorded UNKNOWN if not reproducible). Acceptable?
6. **Baseline scope:** Assumption is the baseline = the 5 existing test files
   (124 tests) exactly as they stand now. Confirm nothing should be added to the
   frozen baseline before approval.
7. **"READY" authority:** Assumption is that only you (the maintainer) can accept
   a gate as READY; Kiro reports status but does not self-declare READY while any
   critical hardware item is UNKNOWN.

---

## Proposed Overall Acceptance Criteria (for the whole spec)

- The frozen baseline (124 tests) is documented and runs 100% green on demand.
- A batched, documented device harness exists covering all Req 2 checks.
- Critical journeys A–F are defined, with logic cores automated and hardware
  parts executed on device with evidence.
- Every result is PASS/FAIL/UNKNOWN with evidence; UNKNOWN is never upgraded
  without hardware evidence.
- The three currently-open hardware items are either moved to PASS with evidence
  or remain explicitly UNKNOWN.
- A durable baseline manifest + future-feature gate rule exists.
- No new application feature is implemented; no existing behavior changed except
  where a discovered defect requires the smallest correct fix.
