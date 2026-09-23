# PathSaathi — Reliability Baseline Manifest

> Authoritative, permanent record of the PathSaathi **automated** reliability
> baseline. This is the automated logic/regression baseline — it is **not**
> physical-device certification. Automated PASS does NOT equal device PASS.

## 1. Purpose

- Serve as the permanent automated reliability gate for PathSaathi.
- Freeze the passing test suite so future changes cannot silently delete, skip,
  weaken, or rewrite proven behavior to make failures disappear.
- This manifest covers **automated logic/regression** coverage only. Physical
  hardware behavior is verified separately (device harness) and tracked as
  UNKNOWN until device evidence exists.

## 2. Baseline Status

| Item | Value |
|---|---|
| Current declared test blocks | **63** |
| Current executed cases | **126** |
| Latest result | **126/126 PASS** |
| State | Current baseline **after** additive I3/I9 coverage |

Counting rule (preserve exactly): "declared test blocks" = number of
`test()` / `testWidgets()` declarations; "executed cases" = the count Flutter
reports after parameterization/loops expand those declarations. 126 is an
executed-case count, never a declared-block count.

## 3. Original Frozen Five-File Baseline

The original baseline (before the additive I3/I9 coverage) — frozen and
unchanged:

| File | Declared blocks |
|---|---|
| `test/destination_resolution_test.dart` | 11 |
| `test/pathsaathi_full_suite_test.dart` | 31 |
| `test/qa_adversarial_test.dart` | 12 |
| `test/qa_kedarnath_test.dart` | 6 |
| `test/widget_test.dart` | 1 |
| **Total** | **61 declared blocks / 124 executed cases** |

These five files must not be modified, deleted, skipped, or weakened.

## 4. Additive I3/I9 Coverage

| Field | Value |
|---|---|
| File | `test/invariants_i3_i9_test.dart` |
| Declared blocks | **2** |
| Test names | `I3: changing selected language does NOT mutate the confirmed destination` <br> `I9: after restart, confirmed destination is restored but a prior pending is NOT` |
| Reason | **Additive I3/I9 coverage** |
| New total | **63 declared blocks / 126 executed cases** |

This test exercises the real implementations (`TravelContextNotifier` including
its actual SharedPreferences persist/rehydrate path, and `LanguageNotifier`);
`SharedPreferences.setMockInitialValues` backs only the platform channel — the
production code under test is unmocked.

## 5. Verification

| Verification | Result |
|---|---|
| New I3/I9 test alone | **2/2 PASS** |
| Full baseline (five frozen files) + I3/I9 file | **126/126 PASS** |
| Existing baseline tests modified/deleted/skipped/weakened | **None** |

(Per task rule, tests were not re-run for this documentation task; the above
reflects the verified Task 3 results.)

## 6. Covered Invariants (I1–I9)

Terminology as established in `requirements.md`:

| ID | Invariant |
|---|---|
| I1 | An unconfirmed (pending) destination SHALL NEVER become the confirmed destination without explicit confirmation. |
| I2 | A newly confirmed destination SHALL replace the previous confirmed destination. |
| I3 | Changing language SHALL NOT change the destination or trip context. |
| I4 | Network loss SHALL NOT corrupt persisted travel state. |
| I5 | GPS failure SHALL NOT create fabricated location data. |
| I6 | General/knowledge questions SHALL resolve to `null` (never invent a destination). |
| I7 | Offline mode SHALL NEVER present live data as available. |
| I8 | The selected language SHALL control user-facing voice/UI responses. |
| I9 | App restart SHALL restore the CONFIRMED destination only, never a stale pending guess, and never an obsolete previous destination after a newer one is confirmed. |

Automated coverage: I1, I2, I6 (destination/confirmation suites); I3, I9
(`invariants_i3_i9_test.dart`); I8 (voice-strings tests). I4, I5, I7 have
partial logic coverage but depend on device verification (see §7, §10).

## 7. Critical Journey Traceability

| Journey | Summary | Automated (logic) | Physical-device |
|---|---|---|---|
| A | Hindi Kedarnath → confirm → offline → restart → Kedarnath remains | Resolve + confirm core covered | Offline-restart persistence — **required, UNKNOWN** |
| B | Kedarnath → confirm → change to Mumbai → confirm → restart → Mumbai (not Kedarnath) | Replacement/chain covered | Restart persistence — **required, UNKNOWN** |
| C | Kedarnath confirmed → propose Mumbai → reject → Kedarnath remains | **Logic/state verified (automated)** | Not a hardware interaction |
| D | Kedarnath → confirm → switch language → restart offline → destination + language remain | Language/destination decoupling + persistence covered | Offline-restart — **required, UNKNOWN** |
| E | GPS OFF → app reports unavailable; no fabricated coords/lock | LocationService design (no default coords) | **required, UNKNOWN** |
| F | GPS ON → location available; app recovers | — | **required, UNKNOWN** |

Distinction preserved: **Journey C is logic/state verification.** The
physical-device portions of A, B, D, E, F still require device evidence.

## 8. Baseline Execution Rule

- Future changes SHALL run the full current baseline (63 declared / 126
  executed) and report 100% pass before being considered complete.
- Tests SHALL NOT be deleted, skipped, weakened, or silently changed to make a
  failure disappear.
- A legitimate baseline change requires a documented reason and before/after
  declared-block and executed-case counts, recorded in the Change Log (§12).

## 9. Truthfulness / Status Rule

- **PASS** = behavior directly verified with evidence (test output or device
  log).
- **FAIL** = failure directly reproduced with evidence.
- **UNKNOWN** = test could not be completed or evidence is insufficient.
- UNKNOWN SHALL NOT be promoted to PASS via source inspection or unit tests for
  a requirement that is a hardware behavior.
- **Automated PASS does NOT equal physical-device PASS.**

## 10. Current Known Hardware UNKNOWNs

The following remain **UNKNOWN** until actual device evidence exists:

1. Offline restart persistence (on hardware).
2. GPS OFF → truthful "unavailable" state → GPS ON recovery (on hardware).
3. Physical-device memory-soak / leak trend.

## 11. Future Feature Gate

- Major future work (e.g. Offline Travel Planning, train/bus/flight search, live
  APIs, Journey Safety Pack) SHALL NOT be treated as READY while any required
  reliability/device gate remains UNKNOWN or FAIL.
- Kiro reports evidence and PASS/FAIL/UNKNOWN only. The **maintainer has final
  READY authority** and never declares READY while a critical hardware item is
  UNKNOWN or FAIL.

## 12. Change Log

| Date | Change | Previous | Current | Reason | Tests weakened/removed |
|---|---|---|---|---|---|
| Task 3 | Added `test/invariants_i3_i9_test.dart` (2 blocks, I3 + I9) | 61 declared / 124 executed | 63 declared / 126 executed | Additive I3/I9 coverage | None |
