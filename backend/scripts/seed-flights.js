// Seeds 20 sample flights on real airline routes: `npm run seed:flights`.
// Airlines, routes and flight numbers follow real published services; times, durations and aircraft are
// representative, not a live timetable. Safe to re-run: flights are keyed by id and skipped if present.
require('dotenv').config();
const mysql = require('mysql2/promise');

// Must match CABIN_LETTERS in src/server.js: first/business 2-2, economy 3-3.
const CABIN_LETTERS = { first: ['A','C','D','F'], business: ['A','C','D','F'], economy: ['A','B','C','D','E','F'] };
const SHORT = { first: 4, business: 8, economy: 30 }, LONG = { first: 8, business: 16, economy: 48 };

// [flight number, airline, from, to, local departure (ISO with UTC offset), duration in minutes, aircraft, seats, prices in ₹ {first, business, economy}]
const FLIGHTS = [
  ['AI 101', 'Air India', 'DEL', 'JFK', '2026-10-21T14:15:00+05:30', 965, 'Boeing 777-300ER', LONG, [520000, 245000, 68000]],
  ['EK 511', 'Emirates', 'DEL', 'DXB', '2026-10-21T04:25:00+05:30', 225, 'Boeing 777-300ER', LONG, [145000, 62000, 19500]],
  ['6E 2155', 'IndiGo', 'DEL', 'BOM', '2026-10-22T06:00:00+05:30', 130, 'Airbus A321neo', SHORT, [32000, 18500, 6400]],
  ['BA 138', 'British Airways', 'BOM', 'LHR', '2026-10-22T01:55:00+05:30', 595, 'Boeing 787-9', LONG, [480000, 230000, 61000]],
  ['SQ 403', 'Singapore Airlines', 'DEL', 'SIN', '2026-10-23T23:00:00+05:30', 340, 'Airbus A350-900', LONG, [210000, 98000, 27500]],
  ['QR 579', 'Qatar Airways', 'DEL', 'DOH', '2026-10-24T03:50:00+05:30', 245, 'Boeing 787-8', LONG, [135000, 71000, 21000]],
  ['LH 761', 'Lufthansa', 'DEL', 'FRA', '2026-10-24T01:30:00+05:30', 550, 'Airbus A350-900', LONG, [455000, 215000, 57000]],
  ['AF 218', 'Air France', 'BOM', 'CDG', '2026-10-26T01:35:00+05:30', 605, 'Boeing 777-300ER', LONG, [470000, 225000, 59000]],
  ['EK 203', 'Emirates', 'DXB', 'JFK', '2026-10-27T02:30:00+04:00', 850, 'Airbus A380-800', LONG, [610000, 285000, 74000]],
  ['KU 381', 'Kuwait Airways', 'KWI', 'BOM', '2026-10-28T22:00:00+03:00', 240, 'Airbus A330-800', LONG, [118000, 56000, 18500]],
  ['SV 756', 'Saudia', 'JED', 'DEL', '2026-10-29T13:25:00+03:00', 300, 'Boeing 787-10', LONG, [142000, 69000, 23500]],
  ['SV 1020', 'Saudia', 'RUH', 'JED', '2026-10-30T09:00:00+03:00', 115, 'Airbus A320neo', SHORT, [38000, 21000, 8200]],
  ['AC 42', 'Air Canada', 'YYZ', 'DEL', '2026-10-30T20:30:00-04:00', 820, 'Boeing 777-300ER', LONG, [560000, 260000, 79000]],
  ['TK 716', 'Turkish Airlines', 'IST', 'DEL', '2026-10-31T20:00:00+03:00', 375, 'Airbus A350-900', LONG, [185000, 92000, 31000]],
  ['BA 117', 'British Airways', 'LHR', 'JFK', '2026-11-02T08:25:00+00:00', 480, 'Airbus A350-1000', LONG, [395000, 190000, 52000]],
  ['AA 100', 'American Airlines', 'JFK', 'LHR', '2026-11-03T18:15:00-05:00', 415, 'Boeing 777-300ER', LONG, [405000, 195000, 54000]],
  ['UA 1', 'United Airlines', 'SFO', 'SIN', '2026-11-04T22:40:00-08:00', 1030, 'Boeing 787-9', LONG, [590000, 275000, 82000]],
  ['KL 871', 'KLM', 'AMS', 'DEL', '2026-11-05T10:25:00+01:00', 495, 'Boeing 787-10', LONG, [430000, 205000, 55000]],
  ['IB 6251', 'Iberia', 'MAD', 'JFK', '2026-11-06T15:55:00+01:00', 515, 'Airbus A330-200', LONG, [380000, 182000, 49000]],
  ['6E 5317', 'IndiGo', 'BOM', 'GOI', '2026-11-07T13:40:00+05:30', 75, 'Airbus A320neo', SHORT, [21000, 12500, 4300]],
];

(async () => {
  const connection = await mysql.createConnection({ host: process.env.MYSQL_HOST || 'localhost', port: Number(process.env.MYSQL_PORT || 3306), user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, database: process.env.MYSQL_DATABASE || 'aeroflow', charset: 'utf8mb4' });
  let added = 0;
  try {
    await connection.beginTransaction();
    for (const [number, airline, from, to, local, minutes, aircraft, counts, [first, business, economy]] of FLIGHTS) {
      const departure = new Date(local); const arrival = new Date(departure.getTime() + minutes * 60000);
      const id = `${number.replace(' ', '-')}-${local.slice(0, 10).replaceAll('-', '')}`;
      const [result] = await connection.query('INSERT IGNORE INTO flights (id,flight_number,airline,origin_code,destination_code,departure_at,arrival_at,airplane_id,airplane_name) VALUES (?,?,?,?,?,?,?,?,?)', [id, number, airline, from, to, departure, arrival, `${aircraft.split(' ')[1]}-${id}`, aircraft]);
      if (!result.affectedRows) continue;
      added++;
      // Pre-book a deterministic ~15% of seats so seat maps look lived-in.
      let nextRow = 1, n = 0; const prices = { first, business, economy }; const rows = [];
      for (const type of ['first', 'business', 'economy']) { const letters = CABIN_LETTERS[type]; for (let i = 0; i < counts[type]; i++, n++) rows.push([id, `${nextRow + Math.floor(i / letters.length)}${letters[i % letters.length]}`, type, prices[type], (n * 7 + number.length) % 13 < 2 ? 'booked' : 'available']); nextRow += Math.ceil(counts[type] / letters.length); }
      await connection.query('INSERT INTO seats (flight_id,seat_number,travel_class,price,status) VALUES ?', [rows]);
    }
    await connection.commit();
    console.log(`Added ${added} flights (${FLIGHTS.length - added} already present).`);
  } catch (e) { await connection.rollback(); throw e; }
  finally { await connection.end(); }
})().catch((e) => { console.error(e.message); process.exit(1); });
