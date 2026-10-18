import 'package:flutter/foundation.dart';
import '../data/api_flight_repository.dart';
import '../models/models.dart';

class FlightController extends ChangeNotifier {
  FlightController(this._repository);
  final ApiFlightRepository _repository;
  List<Airport> _airports = [];
  List<Flight> _flights = [];
  bool loading = false;
  String? error;
  List<Airport> get airports => List.unmodifiable(_airports);
  /// Only flights that haven't departed yet (the API filters too; this covers a page left open past departure).
  List<Flight> get flights => List.unmodifiable(_flights.where((f) => f.departure.isAfter(DateTime.now())));

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try { _airports = await _repository.getAirports(); _flights = await _repository.search(); }
    catch (e) { error = _message(e); }
    finally { loading = false; notifyListeners(); }
  }

  Future<void> publishFlight({required String number, required String airline, required Airport origin, required Airport destination, required DateTime departure, required DateTime arrival, required Map<TravelClass, int> counts, required Map<TravelClass, double> prices}) async {
    final flight = await _repository.createFlight(number: number, airline: airline, origin: origin, destination: destination, departure: departure, arrival: arrival, counts: counts, prices: prices);
    _flights = [..._flights, flight]..sort((a, b) => a.departure.compareTo(b.departure)); notifyListeners();
  }

  Future<List<Flight>> search({Airport? origin, Airport? destination, DateTime? date, TravelClass? travelClass}) async {
    try { _flights = await _repository.search(origin: origin, destination: destination, date: date, travelClass: travelClass); error = null; }
    catch (e) { error = _message(e); }
    notifyListeners(); return _flights;
  }
  Future<Booking> confirmBooking({required Flight flight, required List<Seat> seats, required String passengerName, required String email, required String phone, required String paymentMethod}) async {
    final booking = await _repository.createBooking(flight: flight, seats: seats, passengerName: passengerName, email: email, phone: phone, paymentMethod: paymentMethod);
    _flights = _flights.map((item) => item.id == flight.id ? booking.flight : item).toList(); notifyListeners(); return booking;
  }
  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
