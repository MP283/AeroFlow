// Admin-only reporting endpoints: sales, users and invoices for a booking-date range (?from=&to=, inclusive YYYY-MM-DD).
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const pad = (n) => String(n).padStart(2, '0');
const ymd = (d, sep = '-') => `${d.getFullYear()}${sep}${pad(d.getMonth() + 1)}${sep}${pad(d.getDate())}`;
const IN_RANGE = 'b.created_at >= ? AND b.created_at < DATE_ADD(?, INTERVAL 1 DAY)';
// Per-booking seat counts, joined so SUM()s stay one row per booking.
const SEAT_COUNTS = '(SELECT booking_id, COUNT(*) n FROM booking_seats GROUP BY booking_id)';

function parseRange(query) {
  const today = new Date(); const to = query.to || ymd(today); const from = query.from || ymd(new Date(today.getTime() - 29 * 864e5));
  if (!DAY.test(from) || !DAY.test(to) || Number.isNaN(Date.parse(from)) || Number.isNaN(Date.parse(to)) || from > to) return null;
  return { from, to };
}
const invoiceNumber = (booking) => `INV-${ymd(new Date(booking.created_at), '')}-${String(booking.id).replace(/^booking-/, '').replace(/-/g, '').slice(0, 8).toUpperCase()}`;

module.exports = function createReports({ pool, error, route, requireAdmin }) {
  // Wraps a handler so it receives the validated range, or answers 400.
  const ranged = (handler) => [requireAdmin, route(async (req, res) => { const range = parseRange(req.query); if (!range) return error(res, 400, 'Use a valid date range (YYYY-MM-DD, from on or before to).'); await handler(req, res, range); })];

  function register(app) {
    app.get('/api/admin/reports/sales', ...ranged(async (_req, res, { from, to }) => {
      const p = [from, to];
      const [[[totals]], [[seatTotals]], [byDay], [byClass], [byPayment], [byFlight]] = await Promise.all([
        pool.query(`SELECT COUNT(*) bookings, COALESCE(SUM(b.total_amount),0) revenue FROM bookings b WHERE ${IN_RANGE}`, p),
        pool.query(`SELECT COUNT(*) seats FROM booking_seats bs JOIN bookings b ON b.id=bs.booking_id WHERE ${IN_RANGE}`, p),
        pool.query(`SELECT DATE_FORMAT(b.created_at,'%Y-%m-%d') day, COUNT(*) bookings, SUM(sc.n) seats, SUM(b.total_amount) revenue FROM bookings b JOIN ${SEAT_COUNTS} sc ON sc.booking_id=b.id WHERE ${IN_RANGE} GROUP BY day ORDER BY day`, p),
        pool.query(`SELECT s.travel_class, COUNT(*) seats, SUM(s.price) revenue FROM bookings b JOIN booking_seats bs ON bs.booking_id=b.id JOIN seats s ON s.id=bs.seat_id WHERE ${IN_RANGE} GROUP BY s.travel_class ORDER BY revenue DESC`, p),
        pool.query(`SELECT b.payment_method, COUNT(*) bookings, SUM(b.total_amount) revenue FROM bookings b WHERE ${IN_RANGE} GROUP BY b.payment_method ORDER BY revenue DESC`, p),
        pool.query(`SELECT f.id, f.flight_number, f.origin_code, f.destination_code, f.departure_at, COUNT(*) seats_sold, SUM(s.price) revenue, (SELECT COUNT(*) FROM seats x WHERE x.flight_id=f.id) capacity
          FROM bookings b JOIN flights f ON f.id=b.flight_id JOIN booking_seats bs ON bs.booking_id=b.id JOIN seats s ON s.id=bs.seat_id WHERE ${IN_RANGE} GROUP BY f.id ORDER BY revenue DESC`, p),
      ]);
      const bookings = Number(totals.bookings), revenue = Number(totals.revenue);
      res.json({ from, to, totals: { revenue, bookings, seats: Number(seatTotals.seats), averageBooking: bookings ? revenue / bookings : 0 },
        byDay: byDay.map(r => ({ date: r.day, bookings: Number(r.bookings), seats: Number(r.seats), revenue: Number(r.revenue) })),
        byClass: byClass.map(r => ({ travelClass: r.travel_class, seats: Number(r.seats), revenue: Number(r.revenue) })),
        byPaymentMethod: byPayment.map(r => ({ method: r.payment_method, bookings: Number(r.bookings), revenue: Number(r.revenue) })),
        byFlight: byFlight.map(r => ({ flightId: r.id, flightNumber: r.flight_number, origin: r.origin_code, destination: r.destination_code, departure: r.departure_at, seatsSold: Number(r.seats_sold), capacity: Number(r.capacity), revenue: Number(r.revenue) })) });
    }));

    app.get('/api/admin/reports/users', ...ranged(async (_req, res, { from, to }) => {
      const [rows] = await pool.query(`SELECT u.id, u.full_name, u.email, u.phone, u.role, u.created_at, (u.created_at >= ? AND u.created_at < DATE_ADD(?, INTERVAL 1 DAY)) is_new,
          COUNT(b.id) bookings, COALESCE(SUM(sc.n),0) seats, COALESCE(SUM(b.total_amount),0) total_spent, MAX(b.created_at) last_booking_at
        FROM users u LEFT JOIN bookings b ON b.user_id=u.id AND ${IN_RANGE} LEFT JOIN ${SEAT_COUNTS} sc ON sc.booking_id=b.id
        GROUP BY u.id ORDER BY total_spent DESC, u.created_at DESC`, [from, to, from, to]);
      const users = rows.map(r => ({ id: r.id, fullName: r.full_name, email: r.email, phone: r.phone, role: r.role, createdAt: r.created_at, bookings: Number(r.bookings), seats: Number(r.seats), totalSpent: Number(r.total_spent), lastBookingAt: r.last_booking_at }));
      res.json({ from, to, totals: { users: users.length, customers: users.filter(u => u.role === 'customer').length, admins: users.filter(u => u.role === 'admin').length, newUsers: rows.filter(r => Number(r.is_new)).length, activeBuyers: users.filter(u => u.bookings > 0).length }, users });
    }));

    app.get('/api/admin/reports/invoices', ...ranged(async (_req, res, { from, to }) => {
      const [rows] = await pool.query(`SELECT b.*, u.email account_email, f.flight_number, f.airline, f.departure_at, f.origin_code, oo.city origin_city, f.destination_code, dd.city destination_city
        FROM bookings b JOIN flights f ON f.id=b.flight_id JOIN airports oo ON oo.code=f.origin_code JOIN airports dd ON dd.code=f.destination_code LEFT JOIN users u ON u.id=b.user_id
        WHERE ${IN_RANGE} ORDER BY b.created_at DESC`, [from, to]);
      const seats = new Map(rows.map(r => [r.id, []]));
      if (rows.length) { const [seatRows] = await pool.query('SELECT bs.booking_id, s.seat_number, s.travel_class, s.price FROM booking_seats bs JOIN seats s ON s.id=bs.seat_id WHERE bs.booking_id IN (?) ORDER BY s.id', [rows.map(r => r.id)]); for (const s of seatRows) seats.get(s.booking_id).push({ number: s.seat_number, travelClass: s.travel_class, price: Number(s.price) }); }
      res.json(rows.map(r => ({ invoiceNumber: invoiceNumber(r), bookingId: r.id, issuedAt: r.created_at, accountEmail: r.account_email, passengerName: r.passenger_name, email: r.email, phone: r.phone, paymentMethod: r.payment_method, totalAmount: Number(r.total_amount),
        flight: { flightNumber: r.flight_number, airline: r.airline, originCode: r.origin_code, originCity: r.origin_city, destinationCode: r.destination_code, destinationCity: r.destination_city, departure: r.departure_at }, seats: seats.get(r.id) })));
    }));
  }

  return { register };
};
