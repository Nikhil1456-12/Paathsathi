---
inclusion: fileMatch
fileMatchPattern: 'lib/agents/transport_agent.dart|lib/agents/itinerary_agent.dart|lib/agents/accommodation_agent.dart|lib/screens/transport_screen.dart|lib/screens/itinerary_screen.dart|lib/screens/accommodation_screen.dart|lib/screens/my_journey_screen.dart|lib/database/app_database.dart|lib/providers/travel_context.dart'
---

# Travel Data Rules

Rules for how travel/transport/itinerary data is sourced and labeled. These
document the standards to apply IF travel data code is touched. They do NOT
authorize starting Offline Travel Planning or any train/bus/flight/live API —
that work begins only when explicitly instructed and only after the reliability
gate is met (#[[file:.kiro/specs/reliability-baseline-device-qa/requirements.md]]).

## Destination confirmation
- Travel actions act on the CONFIRMED destination only. A pending/proposed
  destination never drives bookings, schedules, or navigation until confirmed
  (invariants I1, I2, I9).

## Train / bus / flight data
- Transport data is read from the seeded offline SQLite tables
  (`app_database.dart`; e.g. transport uses `bus_number` / `gate`). Keep column
  names aligned with the schema; do not hardcode fake rows in screens.
- No live train/bus/flight API is implemented today. Do not add one here.

## Live vs cached vs estimated
- Every piece of travel info must be honestly labeled as **live**, **cached**,
  or **estimated**. Never present cached or estimated data as live.
- While offline, never show data as live (invariant I7).

## Offline travel package
- The offline travel package (schedules/itineraries/accommodations) is
  pre-seeded data for offline use. Treat it as cached/estimated, refreshed only
  when online via the existing sync path — not as real-time truth.

## Schedule integration
- Itinerary / journey / accommodation screens read from the seeded SQLite tables
  with localized titles and read-aloud support. Reuse those tables and the
  existing agents; do not duplicate schedule storage.
- Honest capability status: #[[file:IMPROVEMENTS_AND_VERIFICATION.md]]
