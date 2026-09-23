---
inclusion: always
---

# PathSaathi — Project Guardrails

Thin, always-on rules for every session. Detailed rules live in the referenced
documents — this file does not duplicate them.

## Prime directives
1. **Do not destabilize the baseline.** 124/124 logic tests currently PASS. Do
   not delete, skip, weaken, or comment out any baseline test to get a green
   result. See the reliability requirements: #[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]
2. **No fabricated data.** Never invent GPS fixes, coordinates, live schedules,
   or AI answers. Report the honest state instead. GPS truthfulness and offline
   honesty are protected invariants (I5, I6, I7 in the reliability spec).
3. **Truthful status only.** Every verifiable claim is PASS, FAIL, or UNKNOWN.
   UNKNOWN is never upgraded to PASS without direct hardware evidence. Never use
   the word "perfect"; always list remaining risks/UNKNOWNs.
4. **Smallest correct change.** Fix root causes with minimal edits. No unrelated
   refactoring, no UI redesign, no new architecture, no duplicate tooling.
5. **Scope discipline.** Do not start Offline Travel Planning or train/bus/flight
   or live travel APIs unless explicitly instructed.

## Protected physical-device UNKNOWNs (do not falsely mark PASS)
- Offline restart persistence on hardware.
- GPS OFF → truthful "unavailable" → GPS ON recovery on hardware.
- Physical-device memory-soak / leak trend.

## Low-Kiro-credit principle
Optimize for HIGH ACCURACY + LOW CREDIT: one inspection pass, batch shell/tool
calls, reuse existing tests and docs, minimal files/hooks, no duplicate tooling,
no unnecessary rebuilds. (Reliability spec Requirement 6.)

## Reference documents (read, do not restate)
- Reliability gate & invariants: #[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]
- Honest capability status + manual verification: #[[file:IMPROVEMENTS_AND_VERIFICATION.md]]
- Key technical decisions: #[[file:../../05 - Documentation/key_notes_and_decisions.md]]
