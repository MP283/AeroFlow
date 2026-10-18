import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../controllers/flight_controller.dart';
import '../data/api_flight_repository.dart';
import '../models/models.dart';
import '../widgets/app_shell.dart';
import '../widgets/flight_widgets.dart';
import 'auth_screens.dart';

class CheckoutScreen extends StatefulWidget { const CheckoutScreen({super.key, required this.flight, required this.selectedSeats, required this.allSeats}); final Flight flight; final List<Seat> selectedSeats; final List<Seat> allSeats; @override State<CheckoutScreen> createState() => _CheckoutScreenState(); }
class _CheckoutScreenState extends State<CheckoutScreen> {
  final key = GlobalKey<FormState>(); late final TextEditingController name, email, phone; String payment = 'Credit Card'; Booking? booking; bool submitting = false;
  static const _payments = [('Credit Card', Icons.credit_card_rounded, 'Visa, Mastercard, RuPay'), ('UPI', Icons.qr_code_rounded, 'Google Pay, PhonePe, Paytm'), ('Net Banking', Icons.account_balance_rounded, 'All major Indian banks')];
  double get total => widget.selectedSeats.fold(0.0, (sum, s) => sum + s.price);
  @override void initState() { super.initState(); final user = context.read<AuthController>().user; name = TextEditingController(text: user?.fullName); email = TextEditingController(text: user?.email); phone = TextEditingController(text: user?.phone); }
  @override void dispose() { name.dispose(); email.dispose(); phone.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    if (booking != null) return AppShell(title: 'Booking confirmed', step: BookingStep.confirmed, child: SingleChildScrollView(child: Center(child: Column(children: [const SizedBox(height: 8), const Icon(Icons.check_circle_rounded, color: Color(0xff079455), size: 52), const SizedBox(height: 10), const Text("You're all set!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), Text('A confirmation has been saved to your account (${booking!.email}).', style: const TextStyle(color: muted)), const SizedBox(height: 24), ETicket(booking: booking!), const SizedBox(height: 20), Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [FilledButton.icon(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/account', (_) => false), icon: const Icon(Icons.luggage_rounded), label: const Text('View in My Trips')), OutlinedButton.icon(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false), icon: const Icon(Icons.search_rounded), label: const Text('Book another flight'))]), const SizedBox(height: 24)]))));
    return AppShell(title: 'Checkout', step: BookingStep.checkout, child: Form(key: key, child: LayoutBuilder(builder: (context, c) { final wide = c.maxWidth > 920;
      final details = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_heading(Icons.person_outline_rounded, 'Passenger details', 'Prefilled from your account. Use the name exactly as on your ID.'), const SizedBox(height: 18),
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full name'), validator: _required), const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) { final e = TextFormField(controller: email, decoration: const InputDecoration(labelText: 'Email address'), keyboardType: TextInputType.emailAddress, validator: (v) => (v?.contains('@') ?? false) ? null : 'Enter a valid email'); final p = TextFormField(controller: phone, decoration: const InputDecoration(labelText: 'Phone number'), keyboardType: TextInputType.phone, validator: _required); return c.maxWidth > 520 ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: e), const SizedBox(width: 14), Expanded(child: p)]) : Column(children: [e, const SizedBox(height: 14), p]); }),
        ])), const SizedBox(height: 16),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_heading(Icons.lock_outline_rounded, 'Payment method', 'Payments are simulated in this demo.'), const SizedBox(height: 14),
          for (final (label, icon, hint) in _payments) Padding(padding: const EdgeInsets.only(bottom: 10), child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => setState(() => payment = label), child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: payment == label ? const Color(0xffe6f4fc) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: payment == label ? blue : line, width: payment == label ? 1.6 : 1)), child: Row(children: [Icon(icon, color: payment == label ? blue : muted), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w800)), Text(hint, style: const TextStyle(fontSize: 12, color: muted))])), Icon(payment == label ? Icons.radio_button_checked : Icons.radio_button_off, color: payment == label ? blue : muted)])))),
        ])),
      ]);
      final summary = Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Trip summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${widget.flight.airline} · ${widget.flight.flightNumber} · ${DateFormat('EEE, dd MMM yyyy').format(widget.flight.departure)}', style: const TextStyle(color: muted, fontSize: 13)), const SizedBox(height: 18),
        RouteTimeline(flight: widget.flight), const Divider(height: 32),
        ...widget.selectedSeats.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SeatTag(seat: s), const SizedBox(width: 8), Expanded(child: Text(s.travelClass.label, style: const TextStyle(fontSize: 12, color: muted))), Text(money(s.price), style: const TextStyle(fontWeight: FontWeight.w700))]))),
        const Divider(height: 24), Row(children: [const Expanded(child: Text('Total (incl. taxes)', style: TextStyle(fontWeight: FontWeight.w700))), Text(money(total), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800))]), const SizedBox(height: 18),
        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: sunset), onPressed: submitting ? null : _confirm, icon: submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.lock_rounded, size: 18), label: Text('Pay ${money(total)}')),
      ]));
      return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [IconButton(tooltip: 'Back to seats', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), const SizedBox(width: 4), const Text('Complete your booking', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800))]), const SizedBox(height: 18),
        wide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: details), const SizedBox(width: 24), Expanded(flex: 2, child: summary)]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, const SizedBox(height: 16), summary])]));
    })));
  }
  Widget _heading(IconData icon, String title, String subtitle) => Row(children: [CircleAvatar(radius: 18, backgroundColor: const Color(0xffe6f4fc), child: Icon(icon, color: blue, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(fontSize: 12, color: muted))]))]);
  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;
  Future<void> _confirm() async {
    if (!(key.currentState?.validate() ?? false) || submitting) return; setState(() => submitting = true); final auth = context.read<AuthController>();
    try { final result = await context.read<FlightController>().confirmBooking(flight: widget.flight, seats: widget.selectedSeats, passengerName: name.text.trim(), email: email.text.trim(), phone: phone.text.trim(), paymentMethod: payment); auth.addBooking(result); if (mounted) setState(() => booking = result); }
    on ApiException catch (e) { if (e.statusCode == 401) { await auth.expire(); if (!mounted) return; final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginScreen(popOnSuccess: true))); if (ok == true && mounted) { setState(() => submitting = false); await _confirm(); return; } } else if (mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message))); } }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted && booking == null) setState(() => submitting = false); }
  }
}

/// Boarding-pass style ticket with a perforated tear line; also used on the account page.
class ETicket extends StatelessWidget {
  const ETicket({super.key, required this.booking, this.past = false});
  final Booking booking;
  final bool past;
  @override Widget build(BuildContext context) { final f = booking.flight; final accent = past ? const Color(0xff667085) : navy; return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: line), boxShadow: const [BoxShadow(color: Color(0x140b192c), blurRadius: 24, offset: Offset(0, 8))]), clipBehavior: Clip.antiAlias, child: Column(children: [
    Container(color: accent, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), child: Row(children: [const AeroFlowMark(light: true), const Spacer(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('E-TICKET', style: TextStyle(color: Color(0xff9aa8bd), fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w800)), SelectableText(_ref(booking.id), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1))])])),
    Padding(padding: const EdgeInsets.fromLTRB(22, 20, 22, 18), child: Column(children: [RouteTimeline(flight: f, large: true), const SizedBox(height: 18), Wrap(spacing: 28, runSpacing: 12, alignment: WrapAlignment.spaceBetween, children: [_field('PASSENGER', booking.passengerName), _field('FLIGHT', f.flightNumber), _field('BOARDING', DateFormat('HH:mm').format(f.departure.subtract(const Duration(minutes: 45)))), _field('CABIN', booking.seats.isEmpty ? '-' : booking.seats.first.travelClass.label), _field('PAID', money(booking.totalAmount))])])),
    const Row(children: [_Notch(left: true), Expanded(child: DottedLine()), _Notch(left: false)]),
    Padding(padding: const EdgeInsets.fromLTRB(22, 14, 22, 20), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('SEATS', style: TextStyle(fontSize: 10, letterSpacing: 1.2, color: Color(0xff667085), fontWeight: FontWeight.w800)), const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: booking.seats.map((s) => SeatTag(seat: s)).toList())])), const SizedBox(width: 16), Icon(Icons.qr_code_2_rounded, size: 72, color: accent)])),
  ]))); }
  static String _ref(String id) => id.replaceFirst('booking-', '').split('-').first.toUpperCase();
  Widget _field(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: Color(0xff667085), fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: navy))]);
}
class _Notch extends StatelessWidget { const _Notch({required this.left}); final bool left; @override Widget build(BuildContext context) => Container(width: 12, height: 24, decoration: BoxDecoration(color: page, borderRadius: left ? const BorderRadius.horizontal(right: Radius.circular(12)) : const BorderRadius.horizontal(left: Radius.circular(12)))); }
