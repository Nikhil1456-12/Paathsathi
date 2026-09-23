# PathSaathi — Physical-Device QA Procedure

> Operator procedure for the physical-device reliability checks that support the
> automated baseline (`BASELINE.md`). This document is the **procedure only** —
> it does not execute anything and does not claim any phase has passed.

## 1. Purpose

Verify PathSaathi's behavior on real hardware: lifecycle, persistence, GPS,
network/offline, crashes/ANRs, and observable device behavior.

**Automated PASS does NOT equal physical-device PASS.** The automated baseline
(126/126) proves logic/state correctness; it does not prove hardware behavior.
Hardware behavior stays UNKNOWN until device evidence exists.

## 2. Reference Device

| Field | Value |
|---|---|
| Reference device | OnePlus CPH2467 |
| Android | Android 15 |
| Primary method | USB ADB |
| Termux / SSHD | Optional, NOT required (gate must not depend on it) |

No additional device is required for this baseline.

## 3. Evidence Rules

Every device check ends as exactly one of:

- **PASS** — direct device evidence (command output / logcat / observed screen).
- **FAIL** — a reproduced failure with evidence.
- **UNKNOWN** — the check could not be completed or evidence is insufficient.

Rules:
- Never convert UNKNOWN to PASS via source inspection or automated tests.
- Interrupted ADB/device connectivity ⇒ **UNKNOWN**, unless the check can be
  cleanly repeated to completion.
- A device check is never marked PASS without direct evidence.

## 4. Preconditions

- Reference device connected and visible to ADB (USB preferred).
- USB debugging / ADB available.
- PathSaathi app installed (release APK).
- Location permission and location services togglable for GPS phases.
- Sufficient battery and storage for a light soak.
- Reference environment (device model, Android, build) recorded in `qa/REPORT.md`.

Exact command sequences belong to the harness script (Task 6); this document
describes actions at a high level.

## 5. Device QA Phases (P0–P12)

Each phase lists: objective · precondition · operator action · expected evidence
· status rule. These are procedures, not results.

### P0 — Preflight
- Objective: confirm device + app ready.
- Precondition: device connected.
- Action: list devices; confirm reference device; confirm app installed; note
  USB vs wireless.
- Evidence: device id present; package present.
- Status: PASS if device+app confirmed; else UNKNOWN.

### P1 — Clean launch
- Objective: app launches cleanly.
- Precondition: app installed.
- Action: clear logs; launch; wait; confirm process alive.
- Evidence: live PID; no `FATAL EXCEPTION` / `ANR`.
- Status: PASS if alive + no crash/ANR; FAIL if crash/ANR; else UNKNOWN.

### P2 — Rapid relaunch ×5
- Objective: survives quick relaunch cycling.
- Action: start/force-stop ×5; final launch; confirm alive.
- Evidence: survives all cycles; no FATAL/ANR.
- Status: PASS / FAIL / UNKNOWN per evidence.

### P3 — Background / foreground
- Objective: resumes correctly.
- Action: send to background (HOME); return to foreground.
- Evidence: resumes; no crash.
- Status: PASS / FAIL / UNKNOWN.

### P4 — Force-stop / relaunch
- Objective: cold relaunch works.
- Action: force-stop; relaunch; confirm alive.
- Evidence: relaunch succeeds; no crash.
- Status: PASS / FAIL / UNKNOWN.

### P5 — Offline launch
- Objective: launches with no network.
- Precondition: **USB ADB** (disabling WiFi severs wireless ADB).
- Action: enable airplane mode + disable WiFi; force-stop; launch; confirm alive.
- Evidence: launches offline; no infinite-load crash; no FATAL.
- Status: PASS / FAIL / UNKNOWN.

### P6 — Offline restart persistence
- Objective: confirmed destination + language survive an offline restart.
- Precondition: a destination confirmed while usable; device offline; USB ADB.
- Action: force-stop; relaunch offline; inspect persisted prefs.
- Evidence: `selected_language_code` present; `confirmed_destination_id` present
  and equals the last confirmed id; NOT a stale/rejected id.
- Status: PASS only with persisted-pref evidence; else UNKNOWN. **Currently
  UNKNOWN** until executed.

### P7 — GPS OFF
- Objective: truthful "unavailable" state, no fabricated fix.
- Action: turn location OFF; launch; observe status + inspect location request.
- Evidence: app shows a truthful unavailable/searching/permission state (operator
  glance) and does NOT display a fabricated lock or coordinates.
- Status: PASS only with truthful-state evidence; else UNKNOWN. **Currently
  UNKNOWN.**

### P8 — Permission states
- Objective: location permission handling.
- Action: inspect declared/granted permission; exercise denied / permanently
  denied where the ROM allows.
- Evidence: FINE/COARSE declared; grant state recorded; app handles denial
  truthfully.
- Status: PASS / FAIL / UNKNOWN.

### P9 — GPS ON recovery
- Objective: genuine location recovery when GPS returns.
- Action: turn location ON; relaunch; observe location request + a real fix.
- Evidence: live location registration; a genuine fix (satellites > 0) — even
  offline (GNSS needs no internet).
- Status: PASS only with a genuine fix as evidence; else UNKNOWN. **Currently
  UNKNOWN.**

### P10 — Network loss / recovery
- Objective: survives online↔offline toggling; no stuck/fake state.
- Action: toggle airplane/WiFi ON→OFF→ON; confirm alive between toggles.
- Evidence: survives toggles; no FATAL; no stuck loading; no fabricated live
  data presented.
- Status: PASS / FAIL / UNKNOWN.

### P11 — Light memory soak (3 PSS checkpoints)
- Objective: no obvious progressive memory growth (light/medium, not multi-hour).
- Action: 3 cycles of launch/background/foreground/offline-toggle, capturing
  TOTAL PSS at start / mid / end.
- Evidence: 3 PSS values → trend.
- Status: PASS if no large monotonic growth across the 3 points; FAIL if clear
  runaway growth; else UNKNOWN. Do not claim a leak from one noisy measurement.

### P12 — Restore state + crash/ANR summary
- Objective: leave device normal; summarize stability.
- Action: restore airplane OFF / WiFi ON / location ON; full logcat scan.
- Evidence: connectivity + location restored; crash/ANR count for the run.
- Status: PASS / FAIL / UNKNOWN.

## 6. Critical Pilgrim Journeys (A–F)

| Journey | Steps | Coverage |
|---|---|---|
| **A** | Hindi → "मुझे केदारनाथ जाना है" → confirmation → confirm → internet OFF → restart → Kedarnath remains | Resolve+confirm = automated; offline-restart = **device (P6)** |
| **B** | Kedarnath → confirm → change to Mumbai → confirm → restart → **Mumbai remains, not stale Kedarnath** | Replacement = automated; restart persistence = **device (P6)** |
| **C** | Kedarnath confirmed → propose Mumbai → reject → Kedarnath remains | **Automated logic/state verification — NOT an ADB hardware interaction** |
| **D** | Kedarnath → confirm → switch language → restart offline → destination + language remain | Decoupling = automated; offline-restart = **device (P6)** |
| **E** | GPS OFF → truthful unavailable state → no fabricated coordinates/lock | **device (P7)** |
| **F** | GPS ON → location available / recovery | **device (P9)** |

Journey C is explicitly automated logic/state verification and is not performed
as an ADB hardware interaction. The physical-device portions of A, B, D, E, F
require device evidence and are currently UNKNOWN.

## 7. Flutter Canvas Limitation

ADB/uiautomator cannot reliably semantically inspect or tap Flutter
canvas-rendered widgets, and ADB cannot directly validate live STT/TTS
semantics. Therefore:
- logic/semantic behavior is covered by automated tests where applicable;
- device QA validates lifecycle, persistence, GPS, network, crashes/ANRs, and
  observable device behavior;
- operator confirmation (a glance at the device) is required where canvas or
  live-voice semantics cannot be mechanically asserted, and that observation is
  recorded as the evidence.

ADB does not prove semantic voice correctness — do not claim that it does.

## 8. GPS Truthfulness

- GPS OFF must produce a truthful unavailable state.
- No fabricated coordinates. No fabricated GPS lock.
- GPS ON must allow genuine recovery when the device provides a location.
- Genuine weak/low-accuracy GPS cannot be reliably forced via ADB → observe-only;
  if it cannot be reproduced deterministically, record **UNKNOWN** rather than
  fabricating or guessing a result.

## 9. Network / Offline Rules

- Offline behavior must not present live data as available.
- Network loss must not corrupt persisted travel state.
- Connectivity recovery should be observable.
- Do not fabricate live train/bus/flight data.

## 10. Memory / Crash / ANR

- Memory soak is **light/medium**, not multi-hour endurance.
- Collect at least **3 PSS checkpoints** and assess the trend.
- Do not claim a leak from a single noisy measurement.
- Record crashes/ANRs objectively (logcat `FATAL EXCEPTION`, `ANR in
  com.pathsaathi`).

## 11. Restoration / Cleanup

- After testing, restore any changed connectivity/location/device settings
  (airplane OFF, WiFi ON, location ON).
- Prefer **USB ADB** whenever network settings are disabled.
- Do not leave the reference device intentionally offline or with altered
  location settings.

## 12. Failure Protocol

Sequence: **find → record → classify → smallest fix → rerun exact failed check →
targeted regression → full baseline checkpoint.**

Severity:
- **P0** — crash / corruption / dangerous navigation / unusable app.
- **P1** — wrong destination, confirmation bypass, broken offline navigation,
  severe language/state/GPS failure.
- **P2** — recoverable degradation.
- **P3** — cosmetic.

A fix is complete only when its check passes AND the full baseline is green. No
fixes are performed as part of authoring this procedure.
