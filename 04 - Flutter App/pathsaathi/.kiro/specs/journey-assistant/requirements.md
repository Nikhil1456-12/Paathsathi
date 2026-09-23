# Requirements — PathSaathi Journey Assistant

## Introduction

PathSaathi is an on-device, multilingual, offline-first travel companion for pilgrims and
visitors. A user speaks (or types) where they want to go in their own language; the app
plans the journey while the network is available, pre-caches everything they will need at
the destination, and then keeps working when connectivity is lost — navigation, their
booked/nearby accommodation, nearby help (hospitals, food, water, help centres), their
securely-stored identity documents, and emergency contact.

This feature set is derived from a representative user journey (a visitor travelling to
Dwaraka) but is built **generically**: it must work for ANY supported destination, ANY
supported language, and ANY user — the Dwaraka story is one path through a general system,
not a hardcoded scenario.

### Scope honesty (what is "real" here)

Because this is an on-device prototype for an evaluated project, the following boundaries
apply and are reflected throughout the requirements:

- **Real flows, prototype data.** Transport options, schedules, fares, and accommodation
  listings are drawn from **curated local/offline datasets** (real place/route/station
  names with realistic times and prices), not live paid booking APIs. There is no public,
  free, student-accessible API for live IRCTC/bus/hotel booking, and booking is inherently
  online — so "booking" produces a **real on-device reservation record + confirmation**, a
  genuine prototype booking, with **no real money and no live third-party transaction**.
- **Documents stay on device.** The user adds THEIR OWN documents (photo from gallery, or a
  typed/spoken number). They are encrypted on-device and never transmitted. Real DigiLocker
  / Aadhaar-authority integration requires government OAuth authorization that is out of
  scope; a user-provided document (the legal, safe equivalent) is used instead.
- **Online-prepares → offline-survives** is the core value: anything the app needs offline
  is fetched/cached WHILE ONLINE, so airplane-mode operation uses local data only. When
  offline data is unavailable, the app states this truthfully and never fabricates results.
- **No fabrication.** The app never invents GPS fixes, live schedules, coordinates, or
  results. When it cannot know something offline, it says so.

### Out of scope (explicitly not built)

- Live/paid transport or hotel booking; real payment processing.
- Real DigiLocker / UIDAI Aadhaar retrieval of a real identity.
- Handling other people's personal documents.
- Real-money transactions of any kind.
- Offline peer-to-peer messaging to emergency services beyond initiating a standard phone
  dial (any offline mesh/SOS broadcast is only included if a real, on-device-capable
  mechanism exists; otherwise it is reported as unavailable, not faked).

---

## Requirement 1 — User onboarding and profile

**User story:** As a first-time user, I want to register with my name, phone number, and a
password, and pick my language, so the app is personalised and secured to me.

#### Acceptance criteria
1. WHEN the app is launched for the first time THEN the system SHALL present an onboarding
   flow capturing name, phone number, and a password (or PIN).
2. WHEN the user submits onboarding details THEN the system SHALL store them securely
   on-device (password/PIN hashed or in secure storage; never stored in plain text) and
   SHALL NOT transmit them off-device.
3. WHEN onboarding is complete THEN the system SHALL prompt for the user's preferred
   language from the supported set and SHALL persist it.
4. WHEN a returning user opens the app THEN the system SHALL require the password/PIN (or
   biometric) before granting access to secured areas (profile, documents).
5. IF the user has already onboarded THEN the system SHALL skip onboarding and open the
   main screen.

## Requirement 2 — Secure document capture and storage

**User story:** As a user, I want to add my ID documents (Aadhaar, PAN, passport) by photo,
by number, or by voice, so I can present them later even without internet.

#### Acceptance criteria
1. WHEN the user chooses to add a document THEN the system SHALL allow input via (a) an
   image from the gallery/camera, (b) a typed number, or (c) a spoken number.
2. WHEN a document is added THEN the system SHALL store it in the encrypted on-device vault
   (platform keystore-backed) and SHALL NOT transmit it off-device.
3. WHEN the user requests a stored document THEN the system SHALL require authentication
   (PIN/biometric) before revealing it.
4. WHEN offline THEN the system SHALL still allow viewing stored documents (they are local).
5. IF no PIN has been set THEN the system SHALL require the user to set one before storing
   or revealing documents (no default/hardcoded PIN).
6. WHERE a spoken document number is captured THEN the system SHALL read it back for the
   user to confirm before storing.

## Requirement 3 — Voice/text destination capture and confirmation

**User story:** As a user, I want to say or type my destination in my own language and
confirm the app understood correctly, so I never start a journey to the wrong place.

#### Acceptance criteria
1. WHEN the user speaks or types a destination THEN the system SHALL show the recognised
   text for confirmation before acting.
2. WHEN the recognised destination resolves to a known place THEN the system SHALL show a
   confirmation ("Did you mean X?") and SHALL proceed only after explicit user approval.
3. IF the input does not resolve to a real destination THEN the system SHALL show a truthful
   "could not understand / try again" state and SHALL NOT proceed to any default or
   arbitrary destination (no Prayagraj/Sangam/previous-destination fallback).
4. WHEN offline and the destination is not in local data THEN the system SHALL report it as
   unavailable offline rather than guessing.
5. WHILE a destination is only recognised (not confirmed) THEN the system SHALL NOT treat it
   as the confirmed destination for planning/navigation.

## Requirement 4 — Transport options and selection

**User story:** As a user, after confirming my destination, I want to see available ways to
get there (bus, train, or combinations) with times and prices, so I can choose.

#### Acceptance criteria
1. WHEN a destination is confirmed AND the network is available THEN the system SHALL present
   transport options (e.g. bus, train, bus+train) with departure/arrival times and indicative
   prices drawn from the curated dataset.
2. WHEN transport options are shown THEN each option SHALL be clearly labelled as indicative/
   prototype data (no claim of a live/real-time reservation).
3. WHEN the user selects a transport option THEN the system SHALL record the selection as part
   of the journey plan.
4. IF no transport data exists for the route THEN the system SHALL say so truthfully rather
   than inventing options.
5. WHEN offline THEN the system SHALL show any previously-cached transport options for the
   planned route and SHALL mark live details as unavailable.

## Requirement 5 — Reservation (prototype booking record)

**User story:** As a user, I want to "reserve" my chosen transport and accommodation, so I
have a confirmation to rely on during the trip.

#### Acceptance criteria
1. WHEN the user confirms a reservation THEN the system SHALL create a reservation record
   stored on-device with a confirmation reference, and SHALL clearly present it as a
   prototype/demo booking (no real money, no live third-party seat/room).
2. WHEN a reservation exists THEN the system SHALL make it available offline.
3. WHEN the user views reservations THEN the system SHALL list transport and accommodation
   bookings with their details and status.
4. IF a reservation cannot be created THEN the system SHALL report the reason truthfully.

## Requirement 6 — Journey plan and offline pre-caching (core)

**User story:** As a user, once my journey is planned, I want the app to prepare everything
I'll need at my destination while I still have internet, so it keeps helping me if the
network drops.

#### Acceptance criteria
1. WHEN a destination is confirmed AND transport selected AND the network is available THEN
   the system SHALL build a journey plan and pre-cache destination-area data: offline map/
   route data, nearby accommodation, hospitals, food, drinking water, and help centres.
2. WHEN pre-caching runs THEN it SHALL prefer unmetered (WiFi) connectivity and SHALL report
   progress/what was cached.
3. WHEN pre-caching completes THEN the cached data SHALL be usable with no network.
4. IF pre-caching is incomplete when connectivity is lost THEN the system SHALL use whatever
   was cached and SHALL truthfully indicate what is missing.
5. WHILE offline THEN the system SHALL NOT attempt (or appear to attempt) live fetches; it
   SHALL serve only cached/local data.

## Requirement 7 — Live journey tracking and arrival

**User story:** As a user, I want the app to follow my location during the trip and tell me
when I've arrived, and offer accommodation help if I haven't booked yet.

#### Acceptance criteria
1. WHILE a journey is active THEN the system SHALL track the device location (with permission)
   and update journey status in the background where the platform allows.
2. WHEN the user reaches the destination area THEN the system SHALL notify "You have reached
   X" and, IF no accommodation is booked, SHALL offer to book/show nearby accommodation.
3. IF accommodation is already booked THEN the system SHALL NOT show the booking prompt and
   SHALL offer navigation to the booked accommodation instead.
4. WHERE location permission is denied or GPS has no fix THEN the system SHALL report the
   honest location state and SHALL NOT fabricate a position or arrival.
5. WHEN the network is lost during the journey THEN tracking SHALL continue using on-device
   GPS (satellite positioning works offline) and cached map data.

## Requirement 8 — Offline survival mode

**User story:** As a user whose internet dies at the destination, I want to still navigate to
my accommodation or find nearby help entirely offline.

#### Acceptance criteria
1. WHEN offline AND accommodation is booked THEN the system SHALL provide navigation/direction
   to the booked accommodation using cached data.
2. WHEN offline AND no accommodation is booked THEN the system SHALL show nearby accommodation,
   restaurants, hospitals, food, and water from the pre-cached dataset.
3. WHEN offline THEN the system SHALL provide direction and distance to a chosen nearby place
   using on-device GPS and cached coordinates (turn-by-turn only if offline routing data is
   present; otherwise distance+bearing, clearly labelled).
4. WHEN offline THEN the user SHALL be able to open their stored identity documents for
   presentation (e.g. at a police/verification check).
5. WHEN offline THEN one-tap dialling of emergency numbers (e.g. 100, 108, 112) SHALL be
   available (standard phone dialler; works without data).
6. IF a genuine offline emergency communication mechanism (mesh/SOS) is technically feasible
   on-device THEN it MAY be provided; OTHERWISE the system SHALL present only real, working
   options (dial) and SHALL NOT fake offline messaging.

## Requirement 9 — Multilingual, generic, spoken interaction

**User story:** As any user speaking a supported language, I want the whole flow — prompts,
confirmations, and responses — in my language, spoken and shown.

#### Acceptance criteria
1. WHEN the user selects a language THEN prompts, confirmations, and agent responses SHALL be
   presented in that language across the flow (at least Hindi, Telugu, English end-to-end).
2. WHEN the system responds THEN it SHALL be able to speak the response aloud in the selected
   language (offline TTS where the device supports it).
3. WHEN voice recognition is uncertain or offline-limited THEN the system SHALL offer the
   always-available typed-input path in the selected language.
4. WHERE the feature is used THEN it SHALL be destination-agnostic and user-agnostic (no
   hardcoded single city/user); the same flow works for any supported destination.

## Requirement 10 — Offline-first integrity and truthfulness (cross-cutting)

**User story:** As a user relying on this in a crisis, I need the app to be honest about what
it knows and never mislead me.

#### Acceptance criteria
1. WHEN any feature depends on data that is not available offline THEN the system SHALL state
   that clearly rather than fabricating a result.
2. WHEN connectivity changes THEN the system SHALL reflect the true online/offline state in
   the UI.
3. WHEN a destination or booking cannot be confirmed THEN the system SHALL never substitute a
   default, previous, or arbitrary value.
4. WHEN data is prototype/curated rather than live THEN the system SHALL label it as such.
5. WHEN the app stores personal data THEN it SHALL keep it on-device and encrypted, and SHALL
   never transmit it without explicit user action.
