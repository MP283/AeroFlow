import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;
  @override
  String toString() => message;
}

class ApiFlightRepository {
  ApiFlightRepository({http.Client? client, String? baseUrl}) : _client = client ?? http.Client(), _baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  final http.Client _client;
  final String _baseUrl;
  /// Session token sent as a bearer token on every request once the user logs in.
  String? token;
  Map<String, String> get _headers => {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<List<Airport>> getAirports() async { final response = await _client.get(_uri('/api/airports'), headers: _headers); _ensureSuccess(response); return (jsonDecode(response.body) as List).map(_airport).toList(); }
  Future<List<Flight>> search({Airport? origin, Airport? destination, DateTime? date, TravelClass? travelClass}) async { final query = <String, String>{if (origin != null) 'origin': origin.code, if (destination != null) 'destination': destination.code, if (date != null) 'date': _day(date), if (travelClass != null) 'travelClass': travelClass.name}; final response = await _client.get(_uri('/api/flights').replace(queryParameters: query), headers: _headers); _ensureSuccess(response); return (jsonDecode(response.body) as List).map(_flight).toList(); }
  Future<Flight> createFlight({required String number, required String airline, required Airport origin, required Airport destination, required DateTime departure, required DateTime arrival, required Map<TravelClass, int> counts, required Map<TravelClass, double> prices}) async { final response = await _client.post(_uri('/api/flights'), headers: _headers, body: jsonEncode({'flightNumber': number, 'airline': airline, 'originCode': origin.code, 'destinationCode': destination.code, 'departure': departure.toUtc().toIso8601String(), 'arrival': arrival.toUtc().toIso8601String(), 'seatCounts': {for (final c in TravelClass.values) c.name: counts[c]}, 'prices': {for (final c in TravelClass.values) c.name: prices[c]}})); _ensureSuccess(response); return _flight(jsonDecode(response.body)); }
  Future<Booking> createBooking({required Flight flight, required List<Seat> seats, required String passengerName, required String email, required String phone, required String paymentMethod}) async { final response = await _client.post(_uri('/api/bookings'), headers: _headers, body: jsonEncode({'flightId': flight.id, 'seatNumbers': seats.map((seat) => seat.number).toList(), 'passengerName': passengerName, 'email': email, 'phone': phone, 'paymentMethod': paymentMethod})); _ensureSuccess(response); final data = jsonDecode(response.body); final updatedFlight = _flight(data['flight']); final selected = updatedFlight.seats.where((seat) => seats.any((chosen) => chosen.number == seat.number)).toList(); return Booking(id: data['id'], flight: updatedFlight, seats: selected, passengerName: passengerName, email: email, phone: phone, paymentMethod: paymentMethod, totalAmount: (data['totalAmount'] as num).toDouble(), createdAt: DateTime.now()); }

  Future<(String, AppUser)> signup({required String fullName, required String email, required String phone, required String password}) => _session('/api/auth/signup', {'fullName': fullName, 'email': email, 'phone': phone, 'password': password});
  Future<(String, AppUser)> login({required String email, required String password}) => _session('/api/auth/login', {'email': email, 'password': password});
  Future<void> logout() async { final response = await _client.post(_uri('/api/auth/logout'), headers: _headers); if (response.statusCode != 401) _ensureSuccess(response); }
  Future<AppUser> me() async { final response = await _client.get(_uri('/api/me'), headers: _headers); _ensureSuccess(response); return _user(jsonDecode(response.body)); }
  Future<AppUser> updateMe({required String fullName, required String email, required String phone, String? currentPassword, String? newPassword}) async { final response = await _client.patch(_uri('/api/me'), headers: _headers, body: jsonEncode({'fullName': fullName, 'email': email, 'phone': phone, if (newPassword != null && newPassword.isNotEmpty) ...{'currentPassword': currentPassword, 'newPassword': newPassword}})); _ensureSuccess(response); return _user(jsonDecode(response.body)); }
  Future<List<Booking>> myBookings() async { final response = await _client.get(_uri('/api/me/bookings'), headers: _headers); _ensureSuccess(response); return (jsonDecode(response.body) as List).map((data) { final flight = _flight(data['flight']); final numbers = (data['seats'] as List).cast<String>(); return Booking(id: data['id'], flight: flight, seats: flight.seats.where((s) => numbers.contains(s.number)).toList(), passengerName: data['passengerName'], email: data['email'], phone: data['phone'], paymentMethod: data['paymentMethod'], totalAmount: (data['totalAmount'] as num).toDouble(), createdAt: DateTime.parse(data['createdAt']).toLocal()); }).toList(); }

  Future<SalesReport> salesReport(ReportRange range) async { final data = await _report('sales', range); final t = data['totals']; return SalesReport(revenue: _num(t['revenue']), bookings: t['bookings'], seats: t['seats'], averageBooking: _num(t['averageBooking']),
    byDay: [for (final r in data['byDay']) SalesDay(date: DateTime.parse(r['date']), bookings: r['bookings'], seats: r['seats'], revenue: _num(r['revenue']))],
    byClass: [for (final r in data['byClass']) ClassSales(travelClass: TravelClass.values.byName(r['travelClass']), seats: r['seats'], revenue: _num(r['revenue']))],
    byPaymentMethod: [for (final r in data['byPaymentMethod']) PaymentSales(method: r['method'], bookings: r['bookings'], revenue: _num(r['revenue']))],
    byFlight: [for (final r in data['byFlight']) FlightSales(flightId: r['flightId'], flightNumber: r['flightNumber'], origin: r['origin'], destination: r['destination'], departure: DateTime.parse(r['departure']).toLocal(), seatsSold: r['seatsSold'], capacity: r['capacity'], revenue: _num(r['revenue']))]); }
  Future<UserReport> userReport(ReportRange range) async { final data = await _report('users', range); final t = data['totals']; return UserReport(totalUsers: t['users'], customers: t['customers'], admins: t['admins'], newUsers: t['newUsers'], activeBuyers: t['activeBuyers'],
    users: [for (final u in data['users']) UserSummary(id: u['id'], fullName: u['fullName'], email: u['email'], phone: u['phone'], role: u['role'], createdAt: DateTime.parse(u['createdAt']).toLocal(), bookings: u['bookings'], seats: u['seats'], totalSpent: _num(u['totalSpent']), lastBookingAt: u['lastBookingAt'] == null ? null : DateTime.parse(u['lastBookingAt']).toLocal())]); }
  Future<List<Invoice>> invoices(ReportRange range) async { final data = await _report('invoices', range) as List; return [for (final i in data) Invoice(invoiceNumber: i['invoiceNumber'], bookingId: i['bookingId'], issuedAt: DateTime.parse(i['issuedAt']).toLocal(), accountEmail: i['accountEmail'], passengerName: i['passengerName'], email: i['email'], phone: i['phone'], paymentMethod: i['paymentMethod'], totalAmount: _num(i['totalAmount']),
    flightNumber: i['flight']['flightNumber'], airline: i['flight']['airline'], originCode: i['flight']['originCode'], originCity: i['flight']['originCity'], destinationCode: i['flight']['destinationCode'], destinationCity: i['flight']['destinationCity'], departure: DateTime.parse(i['flight']['departure']).toLocal(),
    lines: [for (final s in i['seats']) InvoiceLine(seat: s['number'], travelClass: TravelClass.values.byName(s['travelClass']), price: _num(s['price']))])]; }

  Future<dynamic> _report(String name, ReportRange range) async { final response = await _client.get(_uri('/api/admin/reports/$name').replace(queryParameters: {'from': _day(range.from), 'to': _day(range.to)}), headers: _headers); _ensureSuccess(response); return jsonDecode(response.body); }
  String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  double _num(dynamic v) => (v as num).toDouble();
  Future<(String, AppUser)> _session(String path, Map<String, String> body) async { final response = await _client.post(_uri(path), headers: _headers, body: jsonEncode(body)); _ensureSuccess(response); final data = jsonDecode(response.body); return (data['token'] as String, _user(data['user'])); }
  void _ensureSuccess(http.Response response) { if (response.statusCode < 200 || response.statusCode >= 300) { dynamic body; try { body = jsonDecode(response.body); } catch (_) {} throw ApiException(body is Map && body['error'] != null ? body['error'] : 'The server could not complete that request.', response.statusCode); } }
  AppUser _user(dynamic data) => AppUser(id: data['id'], fullName: data['fullName'], email: data['email'], phone: data['phone'], role: data['role'] ?? 'customer');
  Airport _airport(dynamic data) => Airport(code: data['code'], city: data['city'], name: data['name']);
  Flight _flight(dynamic data) { final seats = (data['seats'] as List).map((value) => Seat(number: value['number'], travelClass: TravelClass.values.byName(value['travelClass']), price: (value['price'] as num).toDouble(), status: value['status'] == 'booked' ? SeatStatus.booked : SeatStatus.available)).toList(); return Flight(id: data['id'], flightNumber: data['flightNumber'], airline: data['airline'], origin: _airport(data['origin']), destination: _airport(data['destination']), departure: DateTime.parse(data['departure']).toLocal(), arrival: DateTime.parse(data['arrival']).toLocal(), airplane: Airplane(id: data['airplane']['id'], name: data['airplane']['name'], rowsByClass: const {}, seatsPerRowByClass: const {}), seats: seats); }
}
