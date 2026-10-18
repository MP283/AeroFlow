enum TravelClass { economy, business, first }

extension TravelClassLabel on TravelClass {
  String get label => switch (this) {
        TravelClass.economy => 'Economy',
        TravelClass.business => 'Business Class',
        TravelClass.first => 'First Class',
      };
}

enum SeatStatus { available, selected, booked }

enum SeatPosition { window, middle, aisle }

extension SeatPositionLabel on SeatPosition {
  String get label => switch (this) { SeatPosition.window => 'Window', SeatPosition.middle => 'Middle', SeatPosition.aisle => 'Aisle' };
}

/// Seat letters in each cabin row, left to right. The aisle runs between C and D, and A/F sit at the windows.
const cabinLetters = {TravelClass.first: ['A', 'C', 'D', 'F'], TravelClass.business: ['A', 'C', 'D', 'F'], TravelClass.economy: ['A', 'B', 'C', 'D', 'E', 'F']};

class Airport {
  const Airport({required this.code, required this.city, required this.name});

  final String code;
  final String city;
  final String name;
  String get displayName => '$city ($code)';
}

class Airplane {
  const Airplane({
    required this.id,
    required this.name,
    required this.rowsByClass,
    required this.seatsPerRowByClass,
  });

  final String id;
  final String name;
  final Map<TravelClass, int> rowsByClass;
  final Map<TravelClass, int> seatsPerRowByClass;
}

class Seat {
  const Seat({
    required this.number,
    required this.travelClass,
    required this.price,
    this.status = SeatStatus.available,
  });

  final String number;
  final TravelClass travelClass;
  final double price;
  final SeatStatus status;

  int get row => int.tryParse(number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  String get letter => number.replaceAll(RegExp(r'[0-9]'), '');
  /// Window: A/F. Aisle: C/D (either side of the aisle). Middle: anything else (B/E in economy).
  SeatPosition get position => switch (letter) { 'A' || 'F' => SeatPosition.window, 'C' || 'D' => SeatPosition.aisle, _ => SeatPosition.middle };

  Seat copyWith({SeatStatus? status}) => Seat(
        number: number,
        travelClass: travelClass,
        price: price,
        status: status ?? this.status,
      );
}

class Flight {
  const Flight({
    required this.id,
    required this.flightNumber,
    required this.airline,
    required this.origin,
    required this.destination,
    required this.departure,
    required this.arrival,
    required this.airplane,
    required this.seats,
  });

  final String id;
  final String flightNumber;
  final String airline;
  final Airport origin;
  final Airport destination;
  final DateTime departure;
  final DateTime arrival;
  final Airplane airplane;
  final List<Seat> seats;

  Duration get duration => arrival.difference(departure);
  double basePrice(TravelClass travelClass) => seats
      .where((seat) => seat.travelClass == travelClass)
      .map((seat) => seat.price)
      .fold<double>(0, (lowest, price) => lowest == 0 || price < lowest ? price : lowest);
  int availability(TravelClass travelClass) => seats
      .where((seat) => seat.travelClass == travelClass && seat.status == SeatStatus.available)
      .length;
  Flight copyWith({List<Seat>? seats}) => Flight(
        id: id,
        flightNumber: flightNumber,
        airline: airline,
        origin: origin,
        destination: destination,
        departure: departure,
        arrival: arrival,
        airplane: airplane,
        seats: seats ?? this.seats,
      );
}

class AppUser {
  const AppUser({required this.id, required this.fullName, required this.email, required this.phone, this.role = 'customer'});

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String role;
  bool get isAdmin => role == 'admin';
  String get initials => fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).take(2).map((p) => p[0].toUpperCase()).join();
}

class Booking {
  const Booking({
    required this.id,
    required this.flight,
    required this.seats,
    required this.passengerName,
    required this.email,
    required this.phone,
    required this.paymentMethod,
    required this.totalAmount,
    this.createdAt,
  });

  final String id;
  final Flight flight;
  final List<Seat> seats;
  final String passengerName;
  final String email;
  final String phone;
  final String paymentMethod;
  final double totalAmount;
  final DateTime? createdAt;
  bool get isUpcoming => flight.departure.isAfter(DateTime.now());
}

/// Admin report date range; both ends are inclusive calendar days.
typedef ReportRange = ({DateTime from, DateTime to});

class SalesDay { const SalesDay({required this.date, required this.bookings, required this.seats, required this.revenue}); final DateTime date; final int bookings, seats; final double revenue; }
class ClassSales { const ClassSales({required this.travelClass, required this.seats, required this.revenue}); final TravelClass travelClass; final int seats; final double revenue; }
class PaymentSales { const PaymentSales({required this.method, required this.bookings, required this.revenue}); final String method; final int bookings; final double revenue; }
class FlightSales {
  const FlightSales({required this.flightId, required this.flightNumber, required this.origin, required this.destination, required this.departure, required this.seatsSold, required this.capacity, required this.revenue});
  final String flightId, flightNumber, origin, destination; final DateTime departure; final int seatsSold, capacity; final double revenue;
  double get loadFactor => capacity == 0 ? 0 : seatsSold / capacity;
}
class SalesReport {
  const SalesReport({required this.revenue, required this.bookings, required this.seats, required this.averageBooking, this.byDay = const [], this.byClass = const [], this.byPaymentMethod = const [], this.byFlight = const []});
  final double revenue, averageBooking; final int bookings, seats;
  final List<SalesDay> byDay; final List<ClassSales> byClass; final List<PaymentSales> byPaymentMethod; final List<FlightSales> byFlight;
}

class UserSummary {
  const UserSummary({required this.id, required this.fullName, required this.email, required this.phone, required this.role, required this.createdAt, required this.bookings, required this.seats, required this.totalSpent, this.lastBookingAt});
  final String id, fullName, email, phone, role; final DateTime createdAt; final int bookings, seats; final double totalSpent; final DateTime? lastBookingAt;
  bool get isAdmin => role == 'admin';
}
class UserReport {
  const UserReport({required this.totalUsers, required this.customers, required this.admins, required this.newUsers, required this.activeBuyers, this.users = const []});
  final int totalUsers, customers, admins, newUsers, activeBuyers; final List<UserSummary> users;
}

class InvoiceLine { const InvoiceLine({required this.seat, required this.travelClass, required this.price}); final String seat; final TravelClass travelClass; final double price; }
class Invoice {
  const Invoice({required this.invoiceNumber, required this.bookingId, required this.issuedAt, this.accountEmail, required this.passengerName, required this.email, required this.phone, required this.paymentMethod, required this.totalAmount, required this.flightNumber, required this.airline, required this.originCode, required this.originCity, required this.destinationCode, required this.destinationCity, required this.departure, required this.lines});
  final String invoiceNumber, bookingId, passengerName, email, phone, paymentMethod, flightNumber, airline; final String? accountEmail; final DateTime issuedAt, departure; final double totalAmount;
  final String originCode, originCity, destinationCode, destinationCity;
  /// Airports as shown on the invoice, e.g. `New Delhi (DEL)`.
  String get origin => '$originCity ($originCode)';
  String get destination => '$destinationCity ($destinationCode)';
  final List<InvoiceLine> lines;
}
