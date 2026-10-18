# AeroFlow API

This service is the only component that connects to MySQL. The Flutter web app calls its REST endpoints, so database credentials never reach the browser.

## Start locally

1. Create a MySQL database and app user, then run `schema.sql` with a MySQL client.
   - Upgrading a database created before accounts existed? Run `npm run sql -- migrations/001_accounts.sql` instead (no MySQL client needed).
2. Copy `.env.example` to `.env` and fill in the database credentials. Set `ADMIN_EMAIL` / `ADMIN_PASSWORD` to have an admin (partner) account created on startup.
3. Run `npm install` and `npm start` from this directory.
4. Start Flutter with `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000`.

## Accounts

Passwords are hashed with Node's built-in `crypto.scrypt`. Logging in returns a random session token; only its SHA-256 hash is stored in `sessions` (30-day expiry). Clients send it as `Authorization: Bearer <token>`.

| Endpoint | Auth | Notes |
| --- | --- | --- |
| `POST /api/auth/signup` | – | `{fullName, email, phone, password}` → `{token, user}` |
| `POST /api/auth/login` | – | `{email, password}` → `{token, user}` |
| `POST /api/auth/logout` | user | Deletes the session |
| `GET /api/me`, `PATCH /api/me` | user | Changing the password needs `currentPassword` + `newPassword` |
| `GET /api/me/bookings` | user | The user's bookings, each with the full flight |
| `POST /api/bookings` | user | Locks seats in a transaction so two customers can't buy the same seat |
| `POST /api/flights` | admin | Generates seats using the cabin layouts below |
| `GET /api/airports`, `GET /api/flights` | – | Public search |
| `GET /api/admin/reports/sales` | admin | `?from=&to=` (YYYY-MM-DD, inclusive, default last 30 days) → `{totals, byDay[], byClass[], byPaymentMethod[], byFlight[]}` |
| `GET /api/admin/reports/users` | admin | Same range → `{totals, users[]}`; each user's bookings/seats/spend are counted within the range |
| `GET /api/admin/reports/invoices` | admin | Same range → one invoice per booking (`invoiceNumber` = `INV-YYYYMMDD-<8 hex of booking id>`) with seat line items |

## Cabin layouts

First and Business rows are 2-2 (`A C | D F`) and Economy rows are 3-3 (`A B C | D E F`). A/F are window seats, C/D are aisle seats and B/E are middle seats. The Flutter seat map derives each seat's position from its letter.
