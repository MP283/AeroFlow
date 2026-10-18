import 'package:flutter/foundation.dart';
import '../data/api_flight_repository.dart';
import '../models/models.dart';

/// Admin reports (sales, users, invoices) for one booking-date range; loaded lazily when the Reports tab opens.
class ReportsController extends ChangeNotifier {
  ReportsController(this._repository);
  final ApiFlightRepository _repository;
  ReportRange range = _lastDays(30);
  SalesReport? sales;
  UserReport? users;
  List<Invoice> invoices = [];
  bool loading = false, loaded = false;
  String? error;
  int _request = 0; // only the latest load() may publish results

  Future<void> load() async {
    final request = ++_request; loading = true; error = null; notifyListeners();
    try { final r = range; final results = await Future.wait([_repository.salesReport(r), _repository.userReport(r), _repository.invoices(r)]); if (request != _request) return; sales = results[0] as SalesReport; users = results[1] as UserReport; invoices = results[2] as List<Invoice>; loaded = true; }
    catch (e) { if (request == _request) error = e.toString().replaceFirst('Exception: ', ''); }
    finally { if (request == _request) { loading = false; notifyListeners(); } }
  }
  /// Loads on first use only; later visits keep the current data until refreshed.
  Future<void> ensureLoaded() async { if (!loaded && !loading) await load(); }
  Future<void> setRange(DateTime from, DateTime to) { range = (from: _date(from), to: _date(to)); return load(); }

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
  static ReportRange _lastDays(int days) { final today = _date(DateTime.now()); return (from: today.subtract(Duration(days: days - 1)), to: today); }
}
