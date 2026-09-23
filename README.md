# PathSaathi

PathSaathi is an offline-first, multilingual travel companion for pilgrims and
visitors. It combines voice interaction, destination planning, transport
guidance, accommodation discovery, secure document storage, and GPS navigation
in one Flutter application.

## Problem statement

The project addresses the Infosys requirement for a multilingual, multi-agent
assistant that remains useful when connectivity is unreliable. The app is
designed for travellers who may need directions, schedules, a place to stay,
personal documents, and safety information in regional languages.

## Current implementation

- **Voice companion:** natural-language questions are routed to grounded
  offline services. It can answer location, journey transport, and hotel
  questions using the current trip context. Responses do not claim live
  operator tracking when no live feed is available.
- **Navigation:** the map opens at the traveller's latest real GPS position,
  keeps the destination as a target marker, and uses an online road route or
  an available offline route/cache. It never substitutes a straight line for a
  road route without labelling the limitation.
- **Offline maps:** downloaded tiles are stored in a shared app-private cache.
  A single installation marker allows the cache to be reused for later trips;
  the app does not ask the user to download the same offline map again.
- **Transport:** bus and train choices are presented from the current source
  area to the destination transport hub. Curated schedules are marked
  indicative rather than live ticket inventory.
- **Accommodation:** the stay page follows transport selection and shows
  ranked hotels, ratings, vacancy counts, local/temple-area context, and a
  local booking confirmation flow.
- **Journey:** the Journey tab displays the itinerary for the active trip only,
  filtered by the active destination.
- **Secure documents:** document metadata and attached gallery photos are
  encrypted on-device with Android Keystore-backed secure storage. Photos are
  stored in encrypted chunks, restored after unlock, and never uploaded.

## Technology

- Flutter and Dart
- Riverpod and GoRouter
- SQLite (`sqflite`) for journeys and curated travel data
- `flutter_map` with cached tiles and bundled offline map assets
- Geolocator for real GPS fixes
- Android speech recognition/TTS plus optional on-device model services
- `flutter_secure_storage` and `local_auth` for the document vault

## Repository structure

```text
01 - Problem Statement/     Requirements and problem context
02 - Architecture & Design/Architecture diagrams and design decisions
03 - Tech Stack Analysis/  Technology evaluation
04 - Flutter App/pathsaathi/Flutter application source and tests
05 - Documentation/        Project notes, limitations, and decisions
```

## Running locally

```text
cd "04 - Flutter App/pathsaathi"
flutter pub get
flutter analyze
flutter test
flutter run
```

The online routing and transport data are prototype integrations. Production
deployment should use an approved routing provider, authenticated APIs, rate
limits, and a verified live transport inventory source.
