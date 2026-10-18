import 'dart:convert';
import 'package:aeroflow/controllers/auth_controller.dart';
import 'package:aeroflow/controllers/flight_controller.dart';
import 'package:aeroflow/controllers/reports_controller.dart';
import 'package:aeroflow/data/api_flight_repository.dart';
import 'package:aeroflow/main.dart';
import 'package:aeroflow/models/models.dart';
import 'package:aeroflow/screens/checkout_screen.dart';
import 'package:aeroflow/screens/seat_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _airports = [{'code': 'DEL', 'city': 'New Delhi', 'name': 'Indira Gandhi'}, {'code': 'BOM', 'city': 'Mumbai', 'name': 'CSMIA'}, {'code': 'MAA', 'city': 'Chennai', 'name': 'Chennai International Airport'}];
Map<String, dynamic> _flight(DateTime departure, [String number = 'AF 101']) => {'id': number.replaceAll(' ', '-'), 'flightNumber': number, 'airline': 'AeroFlow Airways', 'origin': _airports[0], 'destination': _airports[1], 'departure': departure.toUtc().toIso8601String(), 'arrival': departure.add(const Duration(hours: 2)).toUtc().toIso8601String(), 'airplane': {'id': 'A320', 'name': 'Airbus A320neo'},
  'seats': [for (final (row, cls, letters) in [(1, 'first', 'ACDF'), (2, 'business', 'ACDF'), (3, 'economy', 'ABCDEF'), (4, 'economy', 'ABCDEF')]) for (final l in letters.split('')) {'number': '$row$l', 'travelClass': cls, 'price': 6200, 'status': row == 3 && l == 'B' ? 'booked' : 'available'}]};
const _user = {'id': 'u1', 'fullName': 'Asha Rao', 'email': 'asha@example.com', 'phone': '9876543210', 'role': 'admin'};

ApiFlightRepository _repo() => ApiFlightRepository(baseUrl: 'http://api', client: MockClient((request) async {
  final body = switch (request.url.path) {
    '/api/airports' => _airports,
    '/api/flights' => [_flight(DateTime.now().add(const Duration(days: 3))), _flight(DateTime.now().subtract(const Duration(hours: 1)), 'AF 999')],
    '/api/me' => _user,
    '/api/admin/reports/sales' => {'totals': {'revenue': 12400, 'bookings': 1, 'seats': 2, 'averageBooking': 12400}, 'byDay': [{'date': _today(), 'bookings': 1, 'seats': 2, 'revenue': 12400}], 'byClass': [{'travelClass': 'economy', 'seats': 2, 'revenue': 12400}], 'byPaymentMethod': [{'method': 'UPI', 'bookings': 1, 'revenue': 12400}],
      'byFlight': [{'flightId': 'AF-101', 'flightNumber': 'AF 101', 'origin': 'DEL', 'destination': 'BOM', 'departure': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(), 'seatsSold': 2, 'capacity': 20, 'revenue': 12400}]},
    '/api/admin/reports/users' => {'totals': {'users': 1, 'customers': 0, 'admins': 1, 'newUsers': 1, 'activeBuyers': 1}, 'users': [{..._user, 'createdAt': DateTime.now().toUtc().toIso8601String(), 'bookings': 1, 'seats': 2, 'totalSpent': 12400, 'lastBookingAt': null}]},
    '/api/admin/reports/invoices' => [{'invoiceNumber': 'INV-20261012-ABC12345', 'bookingId': 'booking-abc12345', 'issuedAt': DateTime.now().toUtc().toIso8601String(), 'accountEmail': 'asha@example.com', 'passengerName': 'Asha Rao', 'email': 'asha@example.com', 'phone': '9876543210', 'paymentMethod': 'UPI', 'totalAmount': 12400,
      'flight': {'flightNumber': 'AF 101', 'airline': 'AeroFlow Airways', 'originCode': 'DEL', 'originCity': 'New Delhi', 'destinationCode': 'BOM', 'destinationCity': 'Mumbai', 'departure': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String()}, 'seats': [{'number': '3A', 'travelClass': 'economy', 'price': 6200}, {'number': '3C', 'travelClass': 'economy', 'price': 6200}]}],
    '/api/me/bookings' => [for (final d in [3, -3]) {'id': 'booking-abc$d', 'totalAmount': 12400, 'paymentMethod': 'UPI', 'passengerName': 'Asha Rao', 'email': 'asha@example.com', 'phone': '9876543210', 'createdAt': DateTime.now().toUtc().toIso8601String(), 'seats': ['3A', '3C'], 'flight': _flight(DateTime.now().add(Duration(days: d)))}],
    _ => {'error': 'not found'},
  };
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
}));

Future<(AuthController, FlightController)> _pump(WidgetTester tester, {bool loggedIn = true, Widget? home, Size size = const Size(1440, 1000)}) async {
  tester.view.physicalSize = size; tester.view.devicePixelRatio = 1; addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues(loggedIn ? {'aeroflow.session': 'token'} : {});
  final repo = _repo(); final auth = AuthController(repo); final flights = FlightController(repo);
  await tester.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: auth), ChangeNotifierProvider.value(value: flights), ChangeNotifierProvider(create: (_) => ReportsController(repo))], child: home == null ? const AeroFlowApp() : MaterialApp(home: home)));
  await auth.restore(); await flights.load(); await tester.pumpAndSettle();
  return (auth, flights);
}

void main() {
  testWidgets('search page renders hero, popular routes and results', (tester) async {
    await _pump(tester, loggedIn: false);
    expect(find.text('Where to next?'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('New Delhi → Mumbai'), findsOneWidget);
    expect(find.text('Select seats'), findsOneWidget);
    expect(find.textContaining('AF 999'), findsNothing, reason: 'departed flights are hidden');
  });

  testWidgets('airport fields suggest matches as you type', (tester) async {
    await _pump(tester, loggedIn: false);
    final from = find.widgetWithText(TextFormField, 'From');
    await tester.enterText(from, 'mum'); await tester.pumpAndSettle();
    expect(find.text('CSMIA'), findsOneWidget);
    expect(find.text('Chennai'), findsNothing);
    await tester.tap(find.text('CSMIA')); await tester.pumpAndSettle();
    expect(find.text('Mumbai (BOM)'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'To'), 'chen'); await tester.pumpAndSettle();
    expect(find.text('Chennai International Airport'), findsOneWidget);
    await tester.tap(find.byTooltip('Swap')); await tester.pumpAndSettle();
    expect(find.text('Mumbai (BOM)'), findsOneWidget);
  });

  testWidgets('phone width: search, seat map and account render without overflow', (tester) async {
    final (_, flights) = await _pump(tester, size: const Size(400, 860));
    expect(find.text('Where to next?'), findsOneWidget);
    final nav = Navigator.of(tester.element(find.text('Where to next?')));
    nav.push(MaterialPageRoute(builder: (_) => SeatSelectionScreen(flight: flights.flights.first))); await tester.pumpAndSettle();
    expect(find.text('FRONT OF AIRCRAFT'), findsOneWidget);
    nav.pushNamed('/account'); await tester.pumpAndSettle();
    expect(find.text('Upcoming flights (1)'), findsOneWidget);
    nav.pushNamed('/enlist'); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Reports')); await tester.pumpAndSettle();
    expect(find.text('Avg. booking'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Invoices')); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('INV-20261012-ABC12345')); await tester.pumpAndSettle();
    await tester.tap(find.text('INV-20261012-ABC12345')); await tester.pumpAndSettle();
    expect(find.text('Print / Save PDF'), findsOneWidget);
  });

  testWidgets('seat map fits flights published with the old 6-across first/business rows', (tester) async {
    final (_, flights) = await _pump(tester, home: const SizedBox());
    final old = flights.flights.first.copyWith(seats: [for (final (row, cls) in [(1, TravelClass.first), (2, TravelClass.business), (3, TravelClass.economy)]) for (final l in 'ABCDEF'.split('')) Seat(number: '$row$l', travelClass: cls, price: 100)]);
    await tester.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: AuthController(_repo())..restoring = false), ChangeNotifierProvider.value(value: flights)], child: MaterialApp(home: SeatSelectionScreen(flight: old))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('1B · Middle · First Class · ₹100'), findsOneWidget);
  });

  testWidgets('selecting many seats on a laptop screen keeps the summary inside the page', (tester) async {
    final (_, flights) = await _pump(tester, home: const SizedBox(), size: const Size(1366, 768));
    final f = flights.flights.first;
    await tester.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: AuthController(_repo())..restoring = false), ChangeNotifierProvider.value(value: flights)], child: MaterialApp(home: SeatSelectionScreen(flight: f))));
    await tester.pumpAndSettle();
    final free = f.seats.where((s) => s.status == SeatStatus.available).toList();
    for (final seat in free) { await tester.ensureVisible(find.byTooltip('${seat.number} · ${seat.position.label} · ${seat.travelClass.label} · ₹6,200')); await tester.tap(find.byTooltip('${seat.number} · ${seat.position.label} · ${seat.travelClass.label} · ₹6,200')); await tester.pump(); }
    expect(find.text('Your seats (${free.length})'), findsOneWidget);
    expect(find.text('Continue to checkout'), findsOneWidget);
  });

  testWidgets('seat map shows aisle layout and position labels', (tester) async {
    final (_, flights) = await _pump(tester, home: const SizedBox());
    await tester.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: AuthController(_repo())..restoring = false), ChangeNotifierProvider.value(value: flights)], child: MaterialApp(home: SeatSelectionScreen(flight: flights.flights.first))));
    await tester.pumpAndSettle();
    expect(find.text('FRONT OF AIRCRAFT'), findsOneWidget);
    await tester.tap(find.byTooltip('3A · Window · Economy · ₹6,200'));
    await tester.tap(find.byTooltip('3C · Aisle · Economy · ₹6,200'));
    await tester.pump();
    expect(find.text('3A · Window'), findsOneWidget);
    expect(find.text('3C · Aisle'), findsOneWidget);
    expect(find.byTooltip('3B · Middle · Economy · Booked'), findsOneWidget);
  });

  testWidgets('account page lists upcoming and past trips', (tester) async {
    final (auth, _) = await _pump(tester);
    expect(auth.loggedIn, isTrue);
    Navigator.of(tester.element(find.text('Where to next?'))).pushNamed('/account');
    await tester.pumpAndSettle();
    expect(find.text('Upcoming flights (1)'), findsOneWidget);
    expect(find.text('Past bookings (1)'), findsOneWidget);
    expect(find.byType(ETicket), findsOneWidget);
    await tester.tap(find.text('Profile & security')); await tester.pumpAndSettle();
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('admin reports show sales, users and invoices', (tester) async {
    await _pump(tester);
    Navigator.of(tester.element(find.text('Where to next?'))).pushNamed('/enlist'); await tester.pumpAndSettle();
    expect(find.text('Publish a new journey'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Reports')); await tester.pumpAndSettle();
    expect(find.text('Avg. booking'), findsOneWidget);
    expect(find.text('Revenue by day'), findsOneWidget);
    expect(find.text('Economy'), findsOneWidget);
    expect(find.text('2 / 20'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Users')); await tester.pumpAndSettle();
    expect(find.text('All users'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    await tester.tap(find.widgetWithText(Tab, 'Invoices')); await tester.pumpAndSettle();
    expect(find.text('Total billed'), findsOneWidget);
    await tester.tap(find.text('INV-20261012-ABC12345')); await tester.pumpAndSettle();
    expect(find.text('TAX INVOICE'), findsOneWidget);
    expect(find.text('New Delhi (DEL)'), findsOneWidget);
    expect(find.text('3C'), findsOneWidget);
    await tester.tap(find.text('Close')); await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(Tab, 'Publish journey')); await tester.pumpAndSettle();
    expect(find.text('Publish a new journey'), findsOneWidget);
  });

  testWidgets('checkout is prefilled from the account', (tester) async {
    final (_, flights) = await _pump(tester, home: const SizedBox());
    final f = flights.flights.first;
    await tester.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: (await _loggedIn())), ChangeNotifierProvider.value(value: flights)], child: MaterialApp(home: CheckoutScreen(flight: f, selectedSeats: f.seats.take(2).toList(), allSeats: f.seats))));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Asha Rao'), findsOneWidget);
    expect(find.text('Pay ₹12,400'), findsOneWidget);
  });
}

String _today() { final d = DateTime.now(); return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'; }
Future<AuthController> _loggedIn() async { SharedPreferences.setMockInitialValues({'aeroflow.session': 'token'}); final auth = AuthController(_repo()); await auth.restore(); return auth; }
