// Runs a .sql file against the database configured in .env: `npm run sql -- migrations/001_accounts.sql`
require('dotenv').config();
const fs = require('fs');
const mysql = require('mysql2/promise');

(async () => {
  const file = process.argv[2];
  if (!file) { console.error('Usage: npm run sql -- <file.sql>'); process.exit(1); }
  const connection = await mysql.createConnection({ host: process.env.MYSQL_HOST || 'localhost', port: Number(process.env.MYSQL_PORT || 3306), user: process.env.MYSQL_USER, password: process.env.MYSQL_PASSWORD, database: process.env.MYSQL_DATABASE || 'aeroflow', multipleStatements: true });
  try { await connection.query(fs.readFileSync(file, 'utf8')); console.log(`Applied ${file}`); }
  finally { await connection.end(); }
})().catch((e) => { console.error(e.message); process.exit(1); });
