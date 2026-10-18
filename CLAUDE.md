# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

AeroFlow is a flight booking app with two parts:

- **Flutter web frontend** (repo root: `lib/`, `web/`, `pubspec.yaml`): search flights, pick seats on a cabin map, sign up / log in, check out, view trips on the account page, and (admins only) use the Partner dashboard at `/enlist` to list new flights and view Sales / Users / Invoices reports.
- **Node/Express API** (`backend/`): the only component that talks to MySQL, so DB credentials never reach the browser.

## Commands

Frontend (run from repo root):

```sh
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
flutter analyze          # lints via package:flutter_lints (analysis_options.yaml)
flutter test             # unit tests (models) + widget tests (screens rendered against a MockClient API)
flutter test test/screens_test.dart   # run a single test file
```

`API_BASE_URL` is read with `String.fromEnvironment` in `lib/data/api_flight_repository.dart` and defaults to `http://localhost:3000`.

Backend (run from `backend/`):

```sh
npm install
npm start        # node src/server.js
npm run dev      # node --watch, restarts on change
npm run sql -- migrations/001_accounts.sql   # run a .sql file against the .env database (no mysql CLI needed)
```

Backend setup: create the MySQL DB/user, run `backend/schema.sql` (creates tables and seeds 4 airports + 2 flights with seats), then copy `.env.example` to `.env` and fill in `MYSQL_*` / `PORT`. Databases created before accounts existed need `migrations/001_accounts.sql`. If `ADMIN_EMAIL`/`ADMIN_PASSWORD` are set, that account is created (or promoted) as admin on startup. `GET /health` checks DB connectivity.

## Architecture

**Data flow:** Screens → `FlightController` / `AuthController` (`ChangeNotifier`s provided at the root in `main.dart`, sharing one `ApiFlightRepository`) → HTTP → Express routes in `backend/src/server.js` (auth routes and middleware in `backend/src/auth.js`, admin report routes in `backend/src/reports.js`) → MySQL.

**Auth:** `AuthController` stores the session token in `shared_preferences`, sets `ApiFlightRepository.token` (sent as `Authorization: Bearer`), and restores the session on startup via `GET /api/me`. Searching and seat maps are public; booking requires a user (seat selection pushes `LoginScreen(popOnSuccess: true)` and continues to checkout on success); `/account` and `/enlist` are wrapped in `RequireAuth` (`/enlist` is admin-only, also enforced server-side). Server roles: `customer` / `admin`.

- Screens use `context.watch<FlightController>()` to render and `context.read<FlightController>()` to trigger actions. Controller methods update its in-memory `_flights` list after each API call (e.g. `confirmBooking` swaps in the server's updated flight so booked seats show immediately).
- Errors: the backend always responds `{ "error": "..." }`; `ApiFlightRepository._ensureSuccess` throws an `ApiException(message, statusCode)` (check `statusCode == 401` to detect an expired session).
- Navigation: `onGenerateRoute` in `main.dart` handles `/`, `/login`, `/signup`, `/account`, `/enlist`; seat selection and checkout are pushed with `MaterialPageRoute`, passing the `Flight`/seats as constructor args. Shared chrome (top bar, account menu, booking stepper, `Panel`, `money()`, palette constants) lives in `lib/widgets/app_shell.dart`; ticket-style pieces (`RouteTimeline`, `SeatTag`, `DottedLine`) in `lib/widgets/flight_widgets.dart`.
- Seat positions: rows are 2-2 `A C | D F` for first/business and 3-3 `A B C | D E F` for economy (`cabinLetters` in `models.dart`, `CABIN_LETTERS` in `server.js` — keep them in sync). `Seat.position` derives window (A/F) / aisle (C/D) / middle from the letter.
- All domain models (`Airport`, `Airplane`, `Seat`, `Flight`, `Booking`, enums `TravelClass`, `SeatStatus`) are in `lib/models/models.dart`.
- Controllers depend on the concrete `ApiFlightRepository` (no interface); tests inject a `MockClient` through its `client` constructor arg.

**API contract** (see `backend/README.md` for the auth endpoints; JSON is camelCase; DB columns are snake_case — `flightById()` in `server.js` does the mapping and is the single shape for every flight response, including nested `origin`, `destination`, `airplane`, and `seats[]`):

- `GET /api/airports`
- `GET /api/flights?origin=&destination=&date=YYYY-MM-DD&travelClass=` — `travelClass` filters to flights with an *available* seat in that class.
- `POST /api/flights` (admin) — body `{flightNumber, airline, originCode, destinationCode, departure, arrival, seatCounts:{first,business,economy}, prices:{...}}`. Generates seats server-side (first → business → economy, each class starting a new row) in a transaction.
- `GET /api/admin/reports/{sales,users,invoices}?from=&to=` (admin) — inclusive `YYYY-MM-DD` booking-date range (default last 30 days). Consumed by `ReportsController` (`lib/controllers/reports_controller.dart`, loaded lazily when the Reports tab opens) and rendered in `lib/screens/reports_view.dart`. Invoice numbers are derived (`INV-YYYYMMDD-<8 hex of booking id>`), not stored. CSV download and invoice printing go through `lib/utils/web_export.dart` (conditional import: no-op stub off the web).
- `POST /api/bookings` (logged in; stores `user_id`) — body `{flightId, seatNumbers[], passengerName, email, phone, paymentMethod}`. Uses a transaction with `SELECT ... FOR UPDATE` on available seats to prevent double-booking; returns 409 if any seat is taken. The total is computed server-side from seat prices.

Datetimes are sent as UTC ISO strings from Flutter and converted with `.toLocal()` on parse.

## Conventions

- Dart code in this repo is written in a very dense style (multiple statements and whole widget trees per line). Match the surrounding style when editing.
- When adding a field, update all layers together: `schema.sql`, `flightById()`/route handlers in `server.js`, the parsers in `ApiFlightRepository`, and `models.dart`.
