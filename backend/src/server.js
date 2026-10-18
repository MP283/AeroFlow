require('dotenv').config();
const express = require('express');
const cors = require('cors');
const mysql = require('mysql2/promise');
const crypto = require('crypto');

const app = express();
app.use(cors());
app.use(express.json());
const pool = mysql.createPool({ host: process.env.MYSQL_HOST || 'localhost', port: Number(process.env.MYSQL_PORT || 3306), user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, database: process.env.MYSQL_DATABASE || 'aeroflow', waitForConnections: true, connectionLimit: 10 });
const id = (prefix) => `${prefix}-${crypto.randomUUID()}`;
const error = (res, status, message) => res.status(status).json({ error: message });
const route = (handler) => (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
const auth = require('./auth')({ pool, id, error, route });
// Seat letters per row for each cabin; A/F are windows and the aisle runs between C and D.
const CABIN_LETTERS = { first: ['A','C','D','F'], business: ['A','C','D','F'], economy: ['A','B','C','D','E','F'] };
app.use(auth.authenticate);
auth.register(app);
require('./reports')({ pool, error, route, requireAdmin: auth.requireAdmin }).register(app);

async function flightById(flightId, connection = pool) {
  const [rows] = await connection.query(`SELECT f.*, oo.code origin_code, oo.city origin_city, oo.name origin_name, dd.code destination_code, dd.city destination_city, dd.name destination_name
    FROM flights f JOIN airports oo ON oo.code=f.origin_code JOIN airports dd ON dd.code=f.destination_code WHERE f.id=?`, [flightId]);
  if (!rows.length) return null;
  const flight = rows[0];
  const [seats] = await connection.query('SELECT seat_number, travel_class, price, status FROM seats WHERE flight_id=? ORDER BY id', [flightId]);
  return { id: flight.id, flightNumber: flight.flight_number, airline: flight.airline, origin: { code: flight.origin_code, city: flight.origin_city, name: flight.origin_name }, destination: { code: flight.destination_code, city: flight.destination_city, name: flight.destination_name }, departure: flight.departure_at, arrival: flight.arrival_at, airplane: { id: flight.airplane_id, name: flight.airplane_name }, seats: seats.map(s => ({ number: s.seat_number, travelClass: s.travel_class, price: Number(s.price), status: s.status })) };
}

app.get('/health', route(async (_req, res) => { await pool.query('SELECT 1'); res.json({ ok: true }); }));
app.get('/api/airports', route(async (_req, res) => { const [rows] = await pool.query('SELECT code, city, name FROM airports ORDER BY city'); res.json(rows); }));
app.get('/api/flights', route(async (req, res) => {
  const { origin, destination, date, travelClass } = req.query;
  let sql = 'SELECT DISTINCT f.id, f.departure_at FROM flights f'; const params = []; const where = ['f.departure_at > NOW()']; // departed flights are never bookable
  if (travelClass) { sql += ' JOIN seats s ON s.flight_id=f.id'; where.push("s.travel_class=? AND s.status='available'"); params.push(travelClass); }
  if (origin) { where.push('f.origin_code=?'); params.push(origin); }
  if (destination) { where.push('f.destination_code=?'); params.push(destination); }
  if (date) { where.push('DATE(f.departure_at)=?'); params.push(date); }
  if (where.length) sql += ` WHERE ${where.join(' AND ')}`;
  sql += ' ORDER BY f.departure_at';
  const [rows] = await pool.query(sql, params); res.json(await Promise.all(rows.map(row => flightById(row.id))));
}));
app.post('/api/flights', auth.requireAdmin, async (req, res) => {
  const { flightNumber, airline, originCode, destinationCode, departure, arrival, seatCounts, prices } = req.body;
  if (!flightNumber || !airline || !originCode || !destinationCode || !departure || !arrival || originCode === destinationCode || new Date(arrival) <= new Date(departure)) return error(res, 400, 'Invalid flight details.');
  if (new Date(departure) <= new Date()) return error(res, 400, 'Departure must be in the future.');
  const connection = await pool.getConnection();
  try { await connection.beginTransaction(); const flightId = id('flight');
    const [[originRows], [destinationRows]] = await Promise.all([connection.query('SELECT code FROM airports WHERE code=?', [originCode]), connection.query('SELECT code FROM airports WHERE code=?', [destinationCode])]);
    if (!originRows.length || !destinationRows.length) throw new Error('Unknown airport.');
    await connection.query('INSERT INTO flights (id,flight_number,airline,origin_code,destination_code,departure_at,arrival_at,airplane_id,airplane_name) VALUES (?,?,?,?,?,?,?,?,?)', [flightId, flightNumber, airline, originCode, destinationCode, new Date(departure), new Date(arrival), id('plane'), 'AeroFlow Configured Cabin']);
    let nextRow = 1;
    for (const type of ['first','business','economy']) { const count = Number(seatCounts[type]); const price = Number(prices[type]); if (!Number.isInteger(count) || count < 1 || !Number.isFinite(price) || price <= 0) throw new Error('Seat counts and prices must be positive.'); const letters = CABIN_LETTERS[type]; for (let i=0; i<count; i++) await connection.query('INSERT INTO seats (flight_id,seat_number,travel_class,price) VALUES (?,?,?,?)', [flightId, `${nextRow + Math.floor(i / letters.length)}${letters[i % letters.length]}`, type, price]); nextRow += Math.ceil(count / letters.length); }
    await connection.commit(); res.status(201).json(await flightById(flightId));
  } catch (e) { await connection.rollback(); error(res, 400, e.message); } finally { connection.release(); }
});
app.post('/api/bookings', auth.requireUser, async (req, res) => {
  const { flightId, seatNumbers, passengerName, email, phone, paymentMethod } = req.body;
  if (!flightId || !Array.isArray(seatNumbers) || !seatNumbers.length || !passengerName || !email || !phone || !paymentMethod) return error(res, 400, 'Complete all booking details.');
  const connection = await pool.getConnection();
  try { await connection.beginTransaction(); const [[open]] = await connection.query('SELECT departure_at > NOW() open FROM flights WHERE id=?', [flightId]); if (!open || !open.open) throw new Error('This flight has already departed and can no longer be booked.'); const marks = seatNumbers.map(() => '?').join(','); const [seats] = await connection.query(`SELECT id, seat_number, price FROM seats WHERE flight_id=? AND seat_number IN (${marks}) AND status='available' FOR UPDATE`, [flightId, ...seatNumbers]);
    if (seats.length !== new Set(seatNumbers).size) throw new Error('One or more seats are no longer available.');
    const bookingId = id('booking'); const total = seats.reduce((sum, seat) => sum + Number(seat.price), 0);
    await connection.query('INSERT INTO bookings (id,flight_id,user_id,passenger_name,email,phone,payment_method,total_amount) VALUES (?,?,?,?,?,?,?,?)', [bookingId,flightId,req.user.id,passengerName,email,phone,paymentMethod,total]);
    await connection.query(`UPDATE seats SET status='booked' WHERE id IN (${seats.map(() => '?').join(',')})`, seats.map(s => s.id));
    await connection.query(`INSERT INTO booking_seats (booking_id,seat_id) VALUES ${seats.map(() => '(?,?)').join(',')}`, seats.flatMap(s => [bookingId,s.id]));
    await connection.commit(); res.status(201).json({ id: bookingId, totalAmount: total, flight: await flightById(flightId), seats: seats.map(s => ({ number:s.seat_number, price:Number(s.price) })) });
  } catch (e) { await connection.rollback(); error(res, 409, e.message); } finally { connection.release(); }
});
app.get('/api/me/bookings', auth.requireUser, route(async (req, res) => {
  const [rows] = await pool.query(`SELECT b.id, b.flight_id, b.passenger_name, b.email, b.phone, b.payment_method, b.total_amount, b.created_at, GROUP_CONCAT(s.seat_number ORDER BY s.id) seat_numbers
    FROM bookings b JOIN booking_seats bs ON bs.booking_id=b.id JOIN seats s ON s.id=bs.seat_id WHERE b.user_id=? GROUP BY b.id ORDER BY b.created_at DESC`, [req.user.id]);
  const flights = new Map(await Promise.all([...new Set(rows.map(r => r.flight_id))].map(async (flightId) => [flightId, await flightById(flightId)])));
  res.json(rows.map(r => ({ id: r.id, totalAmount: Number(r.total_amount), paymentMethod: r.payment_method, passengerName: r.passenger_name, email: r.email, phone: r.phone, createdAt: r.created_at, seats: r.seat_numbers.split(','), flight: flights.get(r.flight_id) })));
}));
app.use((err, _req, res, _next) => { console.error(err); error(res, 500, 'Unexpected server error.'); });
auth.bootstrapAdmin().catch((e) => console.error('Admin bootstrap failed:', e.message));
app.listen(Number(process.env.PORT || 3000), () => console.log('AeroFlow API listening on port ' + (process.env.PORT || 3000)));
