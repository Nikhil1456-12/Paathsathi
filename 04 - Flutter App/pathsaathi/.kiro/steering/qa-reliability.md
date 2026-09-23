---
inclusion: always
---

# QA & Reliability Rules

Thin pointer to the authoritative reliability spec:
#[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]
Do not duplicate that document — apply these rules in every session.

## Status vocabulary (Requirement 4)
- **PASS** — behavior directly observed with evidence (test output or device log).
- **FAIL** — failure directly reproduced with evidence.
- **UNKNOWN** — could not complete / insufficient evidence. Never promoted to
  PASS via source inspection or unit tests when the requirement is hardware
  behavior.

## Severity (Requirement 5)
- **P0** — crash / data corruption / dangerous navigation / app unusable.
- **P1** — wrong destination / confirmation bypass / broken offline nav / severe
  language-or-state failure / major GPS failure.
- **P2** — recoverable degradation.
- **P3** — minor / cosmetic.

## Regression rules
- The frozen baseline is the 5 existing test files (**124 tests**). Run it and
  require 100% pass before a change is complete.
- Never delete, skip, weaken assertions in, or comment out a baseline test to go
  green. Intentional behavior changes must document reason, old vs new expected
  behavior, and evidence of equal-or-greater coverage (Requirement 1).
- After a small fix: run the targeted test, then the relevant subset, then the
  full baseline at the next checkpoint — not after every trivial change
  (Requirement 6).

## Real-device verification
- Hardware behaviors (offline restart persistence; GPS OFF→ON; memory-soak) must
  be verified on device with evidence, and stay UNKNOWN until then.
- Do not weaken tests to make builds green. Do not auto-run APK builds (the
  current machine has a known Gradle/JVM memory limit — build manually on a
  machine with ≥8 GB free RAM per #[[file:IMPROVEMENTS_AND_VERIFICATION.md]]).
