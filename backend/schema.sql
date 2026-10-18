CREATE DATABASE IF NOT EXISTS aeroflow CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE aeroflow;

CREATE TABLE airports (
  code CHAR(3) PRIMARY KEY,
  city VARCHAR(100) NOT NULL,
  name VARCHAR(180) NOT NULL
);

CREATE TABLE flights (
  id VARCHAR(50) PRIMARY KEY,
  flight_number VARCHAR(30) NOT NULL,
  airline VARCHAR(120) NOT NULL,
  origin_code CHAR(3) NOT NULL,
  destination_code CHAR(3) NOT NULL,
  departure_at DATETIME NOT NULL,
  arrival_at DATETIME NOT NULL,
  airplane_id VARCHAR(50) NOT NULL,
  airplane_name VARCHAR(120) NOT NULL,
  CONSTRAINT fk_flight_origin FOREIGN KEY (origin_code) REFERENCES airports(code),
  CONSTRAINT fk_flight_destination FOREIGN KEY (destination_code) REFERENCES airports(code),
  CHECK (origin_code <> destination_code),
  CHECK (arrival_at > departure_at)
);

CREATE TABLE seats (
  id BIGINT AUTO_INCREMENT PRIMARY KEY,
  flight_id VARCHAR(50) NOT NULL,
  seat_number VARCHAR(8) NOT NULL,
  travel_class ENUM('economy','business','first') NOT NULL,
  price DECIMAL(12,2) NOT NULL,
  status ENUM('available','booked') NOT NULL DEFAULT 'available',
  UNIQUE KEY uq_flight_seat (flight_id, seat_number),
  CONSTRAINT fk_seat_flight FOREIGN KEY (flight_id) REFERENCES flights(id) ON DELETE CASCADE
);

CREATE TABLE users (
  id VARCHAR(50) PRIMARY KEY,
  full_name VARCHAR(140) NOT NULL,
  email VARCHAR(254) NOT NULL UNIQUE,
  phone VARCHAR(40) NOT NULL,
  password_hash VARCHAR(200) NOT NULL,
  role ENUM('customer','admin') NOT NULL DEFAULT 'customer',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
  token_hash CHAR(64) PRIMARY KEY,
  user_id VARCHAR(50) NOT NULL,
  expires_at DATETIME NOT NULL,
  CONSTRAINT fk_session_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE bookings (
  id VARCHAR(50) PRIMARY KEY,
  flight_id VARCHAR(50) NOT NULL,
  user_id VARCHAR(50) NULL,
  passenger_name VARCHAR(140) NOT NULL,
  email VARCHAR(254) NOT NULL,
  phone VARCHAR(40) NOT NULL,
  payment_method VARCHAR(40) NOT NULL,
  total_amount DECIMAL(12,2) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_booking_flight FOREIGN KEY (flight_id) REFERENCES flights(id),
  CONSTRAINT fk_booking_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE TABLE booking_seats (
  booking_id VARCHAR(50) NOT NULL,
  seat_id BIGINT NOT NULL,
  PRIMARY KEY (booking_id, seat_id),
  CONSTRAINT fk_booking_seat_booking FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
  CONSTRAINT fk_booking_seat_seat FOREIGN KEY (seat_id) REFERENCES seats(id)
);

INSERT IGNORE INTO airports (code, city, name) VALUES
 ('DEL', 'New Delhi', 'Indira Gandhi International Airport'),
 ('BOM', 'Mumbai', 'Chhatrapati Shivaji Maharaj International Airport'),
 ('BLR', 'Bengaluru', 'Kempegowda International Airport'),
 ('DXB', 'Dubai', 'Dubai International Airport'),
 ('HYD', 'Hyderabad', 'Rajiv Gandhi International Airport'),
 ('MAA', 'Chennai', 'Chennai International Airport'),
 ('CCU', 'Kolkata', 'Netaji Subhas Chandra Bose International Airport'),
 ('AMD', 'Ahmedabad', 'Sardar Vallabhbhai Patel International Airport'),
 ('COK', 'Kochi', 'Cochin International Airport'),
 ('GOI', 'Goa', 'Goa International Airport (Dabolim)'),
 ('PNQ', 'Pune', 'Pune Airport'),
 ('JAI', 'Jaipur', 'Jaipur International Airport'),
 ('LKO', 'Lucknow', 'Chaudhary Charan Singh International Airport'),
 ('ATQ', 'Amritsar', 'Sri Guru Ram Dass Jee International Airport'),
 ('SXR', 'Srinagar', 'Sheikh ul-Alam International Airport'),
 ('TRV', 'Thiruvananthapuram', 'Trivandrum International Airport'),
 ('GAU', 'Guwahati', 'Lokpriya Gopinath Bordoloi International Airport'),
 ('IXC', 'Chandigarh', 'Shaheed Bhagat Singh International Airport'),
 ('NAG', 'Nagpur', 'Dr. Babasaheb Ambedkar International Airport'),
 ('PAT', 'Patna', 'Jay Prakash Narayan International Airport'),
 ('BBI', 'Bhubaneswar', 'Biju Patnaik International Airport'),
 ('VNS', 'Varanasi', 'Lal Bahadur Shastri International Airport'),
 ('SIN', 'Singapore', 'Singapore Changi Airport'),
 ('BKK', 'Bangkok', 'Suvarnabhumi Airport'),
 ('KUL', 'Kuala Lumpur', 'Kuala Lumpur International Airport'),
 ('HKG', 'Hong Kong', 'Hong Kong International Airport'),
 ('NRT', 'Tokyo', 'Narita International Airport'),
 ('SYD', 'Sydney', 'Sydney Airport'),
 ('DOH', 'Doha', 'Hamad International Airport'),
 ('AUH', 'Abu Dhabi', 'Zayed International Airport'),
 ('MCT', 'Muscat', 'Muscat International Airport'),
 ('RUH', 'Riyadh', 'King Khalid International Airport'),
 ('CMB', 'Colombo', 'Bandaranaike International Airport'),
 ('KTM', 'Kathmandu', 'Tribhuvan International Airport'),
 ('MLE', 'Malé', 'Velana International Airport'),
 ('LHR', 'London', 'Heathrow Airport'),
 ('CDG', 'Paris', 'Paris Charles de Gaulle Airport'),
 ('FRA', 'Frankfurt', 'Frankfurt Airport'),
 ('JFK', 'New York', 'John F. Kennedy International Airport'),
 ('AMS', 'Amsterdam', 'Amsterdam Airport Schiphol'),
 ('MAD', 'Madrid', 'Adolfo Suárez Madrid-Barajas Airport'),
 ('BCN', 'Barcelona', 'Josep Tarradellas Barcelona-El Prat Airport'),
 ('FCO', 'Rome', 'Leonardo da Vinci-Fiumicino Airport'),
 ('MUC', 'Munich', 'Munich Airport'),
 ('ZRH', 'Zurich', 'Zurich Airport'),
 ('IST', 'Istanbul', 'Istanbul Airport'),
 ('VIE', 'Vienna', 'Vienna International Airport'),
 ('MAN', 'Manchester', 'Manchester Airport'),
 ('CPH', 'Copenhagen', 'Copenhagen Airport'),
 ('LAX', 'Los Angeles', 'Los Angeles International Airport'),
 ('SFO', 'San Francisco', 'San Francisco International Airport'),
 ('ORD', 'Chicago', 'O''Hare International Airport'),
 ('EWR', 'Newark', 'Newark Liberty International Airport'),
 ('IAD', 'Washington, D.C.', 'Washington Dulles International Airport'),
 ('ATL', 'Atlanta', 'Hartsfield-Jackson Atlanta International Airport'),
 ('MIA', 'Miami', 'Miami International Airport'),
 ('YYZ', 'Toronto', 'Toronto Pearson International Airport'),
 ('YVR', 'Vancouver', 'Vancouver International Airport'),
 ('GRU', 'São Paulo', 'São Paulo/Guarulhos International Airport'),
 ('KWI', 'Kuwait City', 'Kuwait International Airport'),
 ('JED', 'Jeddah', 'King Abdulaziz International Airport'),
 ('DMM', 'Dammam', 'King Fahd International Airport'),
 ('MED', 'Madinah', 'Prince Mohammad bin Abdulaziz International Airport');

INSERT IGNORE INTO flights (id, flight_number, airline, origin_code, destination_code, departure_at, arrival_at, airplane_id, airplane_name) VALUES
 ('AF-101', 'AF 101', 'AeroFlow Airways', 'DEL', 'BOM', '2026-12-10 08:15:00', '2026-12-10 10:25:00', 'A320-1', 'Airbus A320neo'),
 ('AF-203', 'AF 203', 'AeroFlow Airways', 'DEL', 'BLR', '2026-12-10 14:00:00', '2026-12-10 16:45:00', 'A320-1', 'Airbus A320neo');

-- Cabin layouts: first/business 2-2 (A C | D F), economy 3-3 (A B C | D E F). A/F = window, C/D = aisle, B/E = middle.
INSERT IGNORE INTO seats (flight_id, seat_number, travel_class, price, status) VALUES
 ('AF-101','1A','first',24000,'available'), ('AF-101','1C','first',24000,'available'), ('AF-101','1D','first',24000,'available'), ('AF-101','1F','first',24000,'available'),
 ('AF-101','2A','business',12500,'available'), ('AF-101','2C','business',12500,'available'), ('AF-101','2D','business',12500,'available'), ('AF-101','2F','business',12500,'available'),
 ('AF-101','3A','economy',6200,'available'), ('AF-101','3B','economy',6200,'available'), ('AF-101','3C','economy',6200,'available'), ('AF-101','3D','economy',6200,'available'), ('AF-101','3E','economy',6200,'available'), ('AF-101','3F','economy',6200,'available'),
 ('AF-101','4A','economy',6200,'available'), ('AF-101','4B','economy',6200,'available'), ('AF-101','4C','economy',6200,'available'), ('AF-101','4D','economy',6200,'available'), ('AF-101','4E','economy',6200,'available'), ('AF-101','4F','economy',6200,'available'),
 ('AF-203','1A','first',24000,'booked'), ('AF-203','1C','first',24000,'available'), ('AF-203','1D','first',24000,'available'), ('AF-203','1F','first',24000,'available'),
 ('AF-203','2A','business',12500,'available'), ('AF-203','2C','business',12500,'available'), ('AF-203','2D','business',12500,'available'), ('AF-203','2F','business',12500,'available'),
 ('AF-203','3A','economy',6200,'available'), ('AF-203','3B','economy',6200,'booked'), ('AF-203','3C','economy',6200,'available'), ('AF-203','3D','economy',6200,'available'), ('AF-203','3E','economy',6200,'available'), ('AF-203','3F','economy',6200,'available'),
 ('AF-203','4A','economy',6200,'available'), ('AF-203','4B','economy',6200,'available'), ('AF-203','4C','economy',6200,'available'), ('AF-203','4D','economy',6200,'available'), ('AF-203','4E','economy',6200,'available'), ('AF-203','4F','economy',6200,'available');
