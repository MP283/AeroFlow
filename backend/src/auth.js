const crypto = require('crypto');
const { promisify } = require('util');

const scrypt = promisify(crypto.scrypt);
const SESSION_DAYS = 30;
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

async function hashPassword(password) { const salt = crypto.randomBytes(16).toString('hex'); const hash = await scrypt(password, salt, 64); return `${salt}:${hash.toString('hex')}`; }
async function verifyPassword(password, stored) { const [salt, hex] = String(stored).split(':'); if (!salt || !hex) return false; const expected = Buffer.from(hex, 'hex'); const actual = await scrypt(password, salt, expected.length); return crypto.timingSafeEqual(actual, expected); }
const hashToken = (token) => crypto.createHash('sha256').update(token).digest('hex');
const publicUser = (u) => ({ id: u.id, fullName: u.full_name, email: u.email, phone: u.phone, role: u.role });

module.exports = function createAuth({ pool, id, error, route }) {
  async function createSession(userId) { const token = crypto.randomBytes(32).toString('hex'); await pool.query('INSERT INTO sessions (token_hash,user_id,expires_at) VALUES (?,?,?)', [hashToken(token), userId, new Date(Date.now() + SESSION_DAYS * 864e5)]); return token; }

  // Sets req.user when a valid bearer token is present; never rejects on its own.
  const authenticate = route(async (req, _res, next) => {
    const token = (req.get('authorization') || '').replace(/^Bearer\s+/i, '');
    if (token) { const [rows] = await pool.query('SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at > NOW()', [hashToken(token)]); if (rows.length) { req.user = rows[0]; req.tokenHash = hashToken(token); } }
    next();
  });
  const requireUser = (req, res, next) => req.user ? next() : error(res, 401, 'Please log in to continue.');
  const requireAdmin = (req, res, next) => !req.user ? error(res, 401, 'Please log in to continue.') : req.user.role === 'admin' ? next() : error(res, 403, 'Only partner administrators can do that.');

  function validateProfile({ fullName, email, phone }) {
    if (!fullName || !String(fullName).trim()) return 'Enter your full name.';
    if (!email || !EMAIL.test(String(email).trim())) return 'Enter a valid email address.';
    if (!phone || String(phone).trim().length < 6) return 'Enter a valid phone number.';
    return null;
  }

  function register(app) {
    app.post('/api/auth/signup', route(async (req, res) => {
      const { fullName, email, phone, password } = req.body; const invalid = validateProfile(req.body);
      if (invalid) return error(res, 400, invalid);
      if (!password || String(password).length < 8) return error(res, 400, 'Password must be at least 8 characters.');
      const normalized = String(email).trim().toLowerCase(); const [existing] = await pool.query('SELECT id FROM users WHERE email=?', [normalized]);
      if (existing.length) return error(res, 409, 'An account with this email already exists.');
      const userId = id('user');
      await pool.query('INSERT INTO users (id,full_name,email,phone,password_hash) VALUES (?,?,?,?,?)', [userId, String(fullName).trim(), normalized, String(phone).trim(), await hashPassword(String(password))]);
      const [[user]] = await pool.query('SELECT * FROM users WHERE id=?', [userId]);
      res.status(201).json({ token: await createSession(userId), user: publicUser(user) });
    }));
    app.post('/api/auth/login', route(async (req, res) => {
      const { email, password } = req.body; const [rows] = await pool.query('SELECT * FROM users WHERE email=?', [String(email || '').trim().toLowerCase()]);
      if (!rows.length || !password || !(await verifyPassword(String(password), rows[0].password_hash))) return error(res, 401, 'Incorrect email or password.');
      res.json({ token: await createSession(rows[0].id), user: publicUser(rows[0]) });
    }));
    app.post('/api/auth/logout', requireUser, route(async (req, res) => { await pool.query('DELETE FROM sessions WHERE token_hash=?', [req.tokenHash]); res.status(204).end(); }));
    app.get('/api/me', requireUser, (req, res) => res.json(publicUser(req.user)));
    app.patch('/api/me', requireUser, route(async (req, res) => {
      const { fullName, email, phone, currentPassword, newPassword } = req.body; const invalid = validateProfile(req.body);
      if (invalid) return error(res, 400, invalid);
      const normalized = String(email).trim().toLowerCase(); const [taken] = await pool.query('SELECT id FROM users WHERE email=? AND id<>?', [normalized, req.user.id]);
      if (taken.length) return error(res, 409, 'Another account already uses this email.');
      let passwordHash = req.user.password_hash;
      if (newPassword) {
        if (String(newPassword).length < 8) return error(res, 400, 'New password must be at least 8 characters.');
        if (!currentPassword || !(await verifyPassword(String(currentPassword), req.user.password_hash))) return error(res, 400, 'Your current password is incorrect.');
        passwordHash = await hashPassword(String(newPassword));
      }
      await pool.query('UPDATE users SET full_name=?, email=?, phone=?, password_hash=? WHERE id=?', [String(fullName).trim(), normalized, String(phone).trim(), passwordHash, req.user.id]);
      const [[user]] = await pool.query('SELECT * FROM users WHERE id=?', [req.user.id]); res.json(publicUser(user));
    }));
  }

  // Creates (or promotes) the admin account named in ADMIN_EMAIL / ADMIN_PASSWORD.
  async function bootstrapAdmin() {
    const email = (process.env.ADMIN_EMAIL || '').trim().toLowerCase(); const password = process.env.ADMIN_PASSWORD;
    if (!email || !password) return;
    const [rows] = await pool.query('SELECT id, role FROM users WHERE email=?', [email]);
    if (!rows.length) { await pool.query("INSERT INTO users (id,full_name,email,phone,password_hash,role) VALUES (?,?,?,?,?,'admin')", [id('user'), 'AeroFlow Admin', email, '0000000000', await hashPassword(password)]); console.log(`Created admin account ${email}`); }
    else if (rows[0].role !== 'admin') { await pool.query("UPDATE users SET role='admin' WHERE id=?", [rows[0].id]); console.log(`Promoted ${email} to admin`); }
  }

  return { authenticate, requireUser, requireAdmin, register, bootstrapAdmin };
};
