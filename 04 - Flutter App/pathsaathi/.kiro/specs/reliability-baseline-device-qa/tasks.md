# Tasks — Reliability Baseline & Device QA Harness

> Scope guard: Tasks only. Nothing here is implemented until the maintainer
> approves this document and explicitly starts a task. No app-behavior changes,
> no new features, no train/bus/flight, no Offline Travel Planning, no MCP, no
> hooks, no unrelated refactors.
>
> Counting rule (always): **declared test blocks** (`test()`/`testWidgets()`) =
> currently **61**; **executed cases** after parameterization/loops = currently
> **~124**. Never call 124 the number of declared blocks.
>
> Authority: the **maintainer** is the final READY authority. Kiro only reports
> PASS / FAIL / UNKNOWN with evidence and never self-declares READY while any
> critical hardware check is UNKNOWN or FAIL.

Artifacts all live under `.kiro/specs/reliability-baseline-device-qa/`:
`BASELINE.md`, `DEVICE_QA.md`, `qa/run_baseline.ps1`, `qa/device_qa.ps1`,
`qa/REPORT.md`.

---

- [ ] 1. Capture the frozen baseline inventory (read-only)
  - Enumerate the 5 existing test files and their declared-block counts:
    destination_resolution_test.dart (11), qa_adversarial_test.dart (12),
    qa_kedarnath_test.dart (6), pathsaathi_full_suite_test.dart (31),
    widget_test.dart (1) = **61 declared blocks**.
  - Run `flutter test` once to record the executed-case total (~124) and confirm
    100% pass as the pre-change baseline snapshot.
  - Do NOT modify any test in this task.
  - _Requirements: 1.1, 6.1_

- [ ] 2. Create `qa/run_baseline.ps1` (automated baseline runner)
  - Runs `flutter test` from project root; parses summary; prints
    `BASELINE: PASS (N/N)` or `BASELINE: FAIL`; non-zero exit on any failure.
  - Read-only over the suite (never edits tests).
  - Verify by running it once; capture output.
  - _Requirements: 1.2, 6.1, 6.5_

- [ ] 3. Add the single approved I3/I9 regression test (ONLY additive change)
  - Add ONE new test file `test/invariants_i3_i9_test.dart` with a small number
    of `test()` blocks asserting:
    - I3: changing the selected language does NOT mutate the confirmed
      destination (travel context unchanged when language changes);
    - I9: after restart/rehydrate, the CONFIRMED destination is restored and a
      prior PENDING/unconfirmed value is NOT restored.
  - Do NOT modify, delete, skip, weaken, or rewrite any existing baseline test.
  - Update `BASELINE.md` change log with: previous declared-block count (61),
    new declared-block count, previous executed-case count (~124), new
    executed-case count, exact reason ("additive I3/I9 coverage"), and the exact
    file/test names added.
  - Verify: run the new test, then run the full suite; both green.
  - _Requirements: 1.3, 1.5, 3.2 (I3/I9), Design §5 gap_

- [ ] 4. Create `BASELINE.md` (frozen manifest)
  - Frozen test inventory (61 declared blocks → executed-case total), reproduce
    command (`flutter test`).
  - Invariants I1–I9 with the traceability table (automated vs device) from
    Design §5.
  - Known limitations (honest): direct-line guidance (not turn-by-turn);
    schematic offline map unless real MBTiles bundled; live travel search not
    implemented; on-device LLM/NLU are placeholders; STT/TTS offline depends on
    device language packs; Flutter-canvas → no adb UI tap / no live STT drive.
  - Build info: app id, ~59.2 MB release APK, arm64-v8a, Flutter/Dart versions,
    reference device CPH2467 / Android 15.
  - Change log section (seeded with the Task 3 addition entry).
  - Future-feature Gate Checklist (Req 7 items a–g) with a status column.
  - _Requirements: 1.1, 1.5, 7.1, 8.1, 8.2, 8.3_

- [ ] 5. Create `DEVICE_QA.md` (device runbook) + `qa/REPORT.md` (evidence template)
  - Runbook documents phases P0–P12 (Design §4) as copy-paste ADB, USB required
    for offline phases (P5–P10), connectivity/location restored at end (P12).
  - Explicitly states the Flutter-canvas constraint and that semantic UI checks
    are a one-glance operator confirmation recorded as evidence.
  - `qa/REPORT.md` template: per-check table (Check | Requirement | Evidence |
    Status | Notes) defaulting to UNKNOWN; a Defects table matching Req 5.1
    columns; a Gate Summary block.
  - No device commands are RUN in this task (authoring only).
  - _Requirements: 2.1, 2.5, 2.6, 2.7, 4.1, 4.2, 5.1_

- [ ] 6. Create `qa/device_qa.ps1` (batched harness script)
  - Phased script (P0–P12) using device id `c3780eb2`, batched per phase.
  - Captures objective signals only (pid, FATAL/ANR scan, persisted-prefs
    contents, `dumpsys location` registration, 3× PSS); leaves `STATUS=UNKNOWN`
    for the operator to set from evidence — never auto-stamps PASS for semantic
    behavior.
  - Restores airplane off / wifi on / location_mode 3 at the end.
  - Authoring + a dry syntax check only; a full device run is Task 8.
  - _Requirements: 2.1–2.7, 4.3, 6.2, 6.4_

- [ ] 7. Full baseline checkpoint (executed-case run)
  - Run `qa/run_baseline.ps1`; confirm the full suite (now including the Task 3
    additive test) is 100% green.
  - Record the new executed-case total in `BASELINE.md` and `qa/REPORT.md`.
  - _Requirements: 1.2, 6.5_

- [ ] 8. Execute the device harness on hardware and record evidence
  - Precondition: USB-connected reference device.
  - Run `qa/device_qa.ps1` phases; for each, attach evidence to `qa/REPORT.md`
    and set PASS / FAIL / UNKNOWN.
  - Journeys A, B, D, E, F: set status ONLY from device evidence (+ one-glance UI
    confirmation where semantic). Journey C stays logic-only (from Task 3/7), not
    represented here as a hardware interaction.
  - The three currently-open items (offline-restart persistence, GPS OFF→ON,
    memory soak) remain UNKNOWN until this task produces evidence.
  - If the device is unavailable or a phase is interrupted → record UNKNOWN (never
    invent PASS).
  - _Requirements: 2.2, 2.3, 2.4, 3.3, 3.4, 3.5, 4.3, 4.4, 4.6_

- [ ] 8.1 Failure handling (only if Task 8 finds a defect)
  - For each failure: record the Req 5.1 row; classify P0–P3; make the smallest
    correct fix (app code only if required, no unrelated refactor); re-run the
    exact failed phase; re-run the targeted regression subset; then the full
    baseline checkpoint.
  - Do not mark a fix complete until its check passes AND `flutter test` is 100%
    green.
  - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [ ] 9. Compile the gate result (report only — maintainer decides READY)
  - Fill the `BASELINE.md` Gate Checklist (a–g) and `qa/REPORT.md` Gate Summary
    from actual evidence.
  - If any critical hardware item (A/B/D offline restart, E/F GPS) is UNKNOWN or
    FAIL → print "NOT READY — FIX THESE FIRST" + smallest fix list.
  - Kiro does NOT declare READY; it presents evidence + status for maintainer
    sign-off.
  - _Requirements: 4.4, 4.5, 7.1, 7.2, 7.3_

---

## Task dependency / review order
1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → (8.1 if needed) → 9.
Each task is independently reviewable. Tasks 1–7 are authoring + logic (no
device); Task 8 is the only task that touches hardware; Task 8.1 is the only task
that may touch application code, and only under the Failure Protocol.

## Credit notes
- Tasks 1 & 7 & the verifies in 3 are the only `flutter test` runs (checkpoints).
- Task 8 is a small number of batched ADB invocations, not dozens.
- No APK rebuild unless Task 8.1 changes app code.
- No duplicate QA infrastructure: one runner, one harness, one report, one
  manifest.
