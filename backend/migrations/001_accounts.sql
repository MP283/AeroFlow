-- Adds customer accounts to a database created from the original schema.sql.
CREATE TABLE IF NOT EXISTS users (
  id VARCHAR(50) PRIMARY KEY,
  full_name VARCHAR(140) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  phone VARCHAR(40) NOT NULL,
  password_hash VARCHAR(200) NOT NULL,
  role ENUM('customer','admin') NOT NULL DEFAULT 'customer',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash CHAR(64) PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  expires_at DATETIME NOT NULL,
  CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

ALTER TABLE bookings ADD COLUMN user_id VARCHAR(50) NULL AFTER flight_id,
  ADD CONSTRAINT fk_booking_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;

-- Move the sample flights into the future and give them the new cabin layout
-- (first/business A C | D F, economy A B C | D E F). Booked seats are kept.
UPDATE flights SET departure_at = departure_at + INTERVAL 2 MONTH, arrival_at = arrival_at + INTERVAL 2 MONTH
  WHERE id IN ('AF-101','AF-203') AND departure_at < '2026-12-01';
DELETE s FROM seats s LEFT JOIN booking_seats bs ON bs.seat_id = s.id
  WHERE s.flight_id IN ('AF-101','AF-203') AND bs.seat_id IS NULL AND s.travel_class IN ('first','business') AND RIGHT(s.seat_number, 1) IN ('B','E');
INSERT IGNORE INTO seats (flight_id, seat_number, travel_class, price) VALUES
 ('AF-101','1C','first',24000), ('AF-101','1D','first',24000), ('AF-101','1F','first',24000),
 ('AF-101','2C','business',12500), ('AF-101','2D','business',12500), ('AF-101','2F','business',12500),
 ('AF-101','3E','economy',6200), ('AF-101','3F','economy',6200),
 ('AF-101','4A','economy',6200), ('AF-101','4B','economy',6200), ('AF-101','4C','economy',6200), ('AF-101','4D','economy',6200), ('AF-101','4E','economy',6200), ('AF-101','4F','economy',6200),
 ('AF-203','1C','first',24000), ('AF-203','1D','first',24000), ('AF-203','1F','first',24000),
 ('AF-203','2C','business',12500), ('AF-203','2D','business',12500), ('AF-203','2F','business',12500),
 ('AF-203','3E','economy',6200), ('AF-203','3F','economy',6200),
 ('AF-203','4A','economy',6200), ('AF-203','4B','economy',6200), ('AF-203','4C','economy',6200), ('AF-203','4D','economy',6200), ('AF-203','4E','economy',6200), ('AF-203','4F','economy',6200);
