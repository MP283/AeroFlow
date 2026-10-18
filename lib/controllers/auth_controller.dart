import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/api_flight_repository.dart';
import '../models/models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);
  static const _tokenKey = 'aeroflow.session';
  final ApiFlightRepository _repository;
  AppUser? _user;
  List<Booking> _bookings = [];
  bool restoring = true;
  bool loadingBookings = false;
  String? bookingsError;
  AppUser? get user => _user;
  bool get loggedIn => _user != null;
  List<Booking> get upcoming => _bookings.where((b) => b.isUpcoming).toList()..sort((a, b) => a.flight.departure.compareTo(b.flight.departure));
  List<Booking> get past => _bookings.where((b) => !b.isUpcoming).toList()..sort((a, b) => b.flight.departure.compareTo(a.flight.departure));

  /// Restores a saved session on startup; a token the server no longer accepts is discarded.
  Future<void> restore() async {
    try { final prefs = await SharedPreferences.getInstance(); final token = prefs.getString(_tokenKey); if (token != null) { _repository.token = token; try { _user = await _repository.me(); } on ApiException catch (e) { if (e.statusCode == 401) await _clear(); } } }
    catch (_) { _user = null; }
    finally { restoring = false; notifyListeners(); }
  }

  Future<void> login({required String email, required String password}) async { final (token, user) = await _repository.login(email: email, password: password); await _start(token, user); }
  Future<void> signup({required String fullName, required String email, required String phone, required String password}) async { final (token, user) = await _repository.signup(fullName: fullName, email: email, phone: phone, password: password); await _start(token, user); }
  Future<void> logout() async { try { await _repository.logout(); } catch (_) {} await _clear(); notifyListeners(); }
  /// Drops the local session without calling the server, e.g. after a 401.
  Future<void> expire() async { await _clear(); notifyListeners(); }

  Future<void> updateProfile({required String fullName, required String email, required String phone, String? currentPassword, String? newPassword}) async { _user = await _repository.updateMe(fullName: fullName, email: email, phone: phone, currentPassword: currentPassword, newPassword: newPassword); notifyListeners(); }
  Future<void> loadBookings() async {
    loadingBookings = true; bookingsError = null; notifyListeners();
    try { _bookings = await _repository.myBookings(); }
    on ApiException catch (e) { if (e.statusCode == 401) { await _clear(); } else { bookingsError = e.message; } }
    catch (e) { bookingsError = e.toString().replaceFirst('Exception: ', ''); }
    finally { loadingBookings = false; notifyListeners(); }
  }
  void addBooking(Booking booking) { _bookings = [booking, ..._bookings.where((b) => b.id != booking.id)]; notifyListeners(); }

  Future<void> _start(String token, AppUser user) async { _repository.token = token; _user = user; _bookings = []; try { (await SharedPreferences.getInstance()).setString(_tokenKey, token); } catch (_) {} notifyListeners(); }
  Future<void> _clear() async { _repository.token = null; _user = null; _bookings = []; try { (await SharedPreferences.getInstance()).remove(_tokenKey); } catch (_) {} }
}
