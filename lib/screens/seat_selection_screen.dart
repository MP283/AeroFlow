import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../models/models.dart';
import '../widgets/app_shell.dart';
import '../widgets/flight_widgets.dart';
import 'auth_screens.dart';
import 'checkout_screen.dart';

const _available = Color(0xffdcebfa), _selected = blue, _booked = Color(0xffe4e7ec);

class SeatSelectionScreen extends StatefulWidget { const SeatSelectionScreen({super.key, required this.flight}); final Flight flight; @override State<SeatSelectionScreen> createState() => _SeatSelectionScreenState(); }
class _SeatSelectionScreenState extends State<SeatSelectionScreen> {
  late List<Seat> seats; final highlight = <SeatPosition>{};
  @override void initState() { super.initState(); seats = [...widget.flight.seats]; }
  List<Seat> get selected => seats.where((s) => s.status == SeatStatus.selected).toList(); double get total => selected.fold(0.0, (sum, s) => sum + s.price);

  @override Widget build(BuildContext context) { final f = widget.flight; return AppShell(title: 'Choose your seats', step: BookingStep.seats, child: LayoutBuilder(builder: (context, c) { final wide = c.maxWidth > 980;
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [IconButton(tooltip: 'Back to results', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)), const SizedBox(width: 4), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${f.origin.city} → ${f.destination.city}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text('${f.airline} · ${f.flightNumber} · ${DateFormat('EEE, dd MMM · HH:mm').format(f.departure)}', style: const TextStyle(color: muted))]))]), const SizedBox(height: 16),
      Wrap(spacing: 18, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const _Legend(color: _available, label: 'Available'), const _Legend(color: _selected, label: 'Selected'), const _Legend(color: _booked, label: 'Booked', cross: true),
        _Legend(color: Colors.white, label: 'Window', marker: seatPositionColor(SeatPosition.window)), _Legend(color: Colors.white, label: 'Aisle', marker: seatPositionColor(SeatPosition.aisle)),
        const SizedBox(width: 8), const Text('Highlight:', style: TextStyle(fontWeight: FontWeight.w700, color: muted)),
        for (final p in [SeatPosition.window, SeatPosition.aisle]) FilterChip(avatar: Icon(seatPositionIcon(p), size: 16, color: seatPositionColor(p)), label: Text('${p.label} seats'), selected: highlight.contains(p), showCheckmark: false, selectedColor: seatPositionColor(p).withValues(alpha: .14), side: BorderSide(color: highlight.contains(p) ? seatPositionColor(p) : line), onSelected: (on) => setState(() => on ? highlight.add(p) : highlight.remove(p))),
      ]),
    ]);
    final map = SingleChildScrollView(child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: FittedBox(fit: BoxFit.scaleDown, child: _fuselage()))));
    if (wide) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, const SizedBox(height: 8), Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: map), const SizedBox(width: 24), SizedBox(width: 340, child: Padding(padding: const EdgeInsets.only(top: 20), child: _summary()))]))]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, Expanded(child: map), _bottomBar()]);
  })); }

  /// Seat letters shown in a cabin: the standard layout plus any extra letters from flights published before it existed.
  List<String> _letters(TravelClass c) => {...cabinLetters[c]!, ...seats.where((s) => s.travelClass == c).map((s) => s.letter)}.toList()..sort();
  double _seatSize(List<String> letters) => letters.length > 4 ? 40 : 48;
  /// Wide enough for the widest cabin row: seats (+6px gaps), 44px aisle, 26px of windows, 52px side padding.
  double get _fuselageWidth => TravelClass.values.where((c) => seats.any((s) => s.travelClass == c)).map((c) { final l = _letters(c); return l.length * (_seatSize(l) + 6) + 44 + 26 + 52; }).fold(420.0, (a, b) => b > a ? b : a);
  Widget _fuselage() => Container(width: _fuselageWidth, padding: const EdgeInsets.fromLTRB(26, 0, 26, 36), decoration: BoxDecoration(color: Colors.white, border: Border.all(color: line, width: 2), borderRadius: const BorderRadius.vertical(top: Radius.circular(200), bottom: Radius.circular(40)), boxShadow: const [BoxShadow(color: Color(0x0f0b192c), blurRadius: 30, offset: Offset(0, 10))]), child: Column(children: [
    const SizedBox(height: 70), const Icon(Icons.airline_seat_flat_angled_rounded, color: Color(0xffb8c4d6)), const Text('FRONT OF AIRCRAFT', style: TextStyle(fontSize: 11, letterSpacing: 1.4, color: muted, fontWeight: FontWeight.w700)), const SizedBox(height: 10),
    for (final c in [TravelClass.first, TravelClass.business, TravelClass.economy]) if (seats.any((s) => s.travelClass == c)) _cabin(c),
  ]));

  Widget _cabin(TravelClass c) {
    final cabin = seats.where((s) => s.travelClass == c).toList(); final letters = _letters(c);
    final left = letters.where((l) => l.compareTo('D') < 0).toList(); final right = letters.where((l) => l.compareTo('D') >= 0).toList();
    final rows = <int, Map<String, Seat>>{}; for (final s in cabin) { (rows[s.row] ??= {})[s.letter] = s; }
    final rowNumbers = rows.keys.toList()..sort(); final size = _seatSize(letters);
    Widget side(List<String> group, Map<String, Seat> row) => Row(mainAxisSize: MainAxisSize.min, children: [for (final l in group) Padding(padding: const EdgeInsets.all(3), child: row[l] == null ? SizedBox(width: size, height: size) : _seat(row[l]!, size))]);
    Widget label(List<String> group) => Row(mainAxisSize: MainAxisSize.min, children: [for (final l in group) SizedBox(width: size + 6, child: Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: muted)))]);
    return Padding(padding: const EdgeInsets.only(top: 18), child: Column(children: [
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12), decoration: BoxDecoration(color: const Color(0xfff5f7fb), borderRadius: BorderRadius.circular(10)), child: Row(children: [Text(c.label.toUpperCase(), style: const TextStyle(letterSpacing: 1.2, color: navy, fontSize: 12, fontWeight: FontWeight.w800)), const Spacer(), Text('from ${money(widget.flight.basePrice(c))}', style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w700))])), const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [const SizedBox(width: 14), label(left), const SizedBox(width: 44), label(right), const SizedBox(width: 14)]),
      for (final r in rowNumbers) Row(mainAxisAlignment: MainAxisAlignment.center, children: [const _Window(), side(left, rows[r]!), SizedBox(width: 44, child: Text('$r', textAlign: TextAlign.center, style: const TextStyle(color: muted, fontWeight: FontWeight.w700, fontSize: 12))), side(right, rows[r]!), const _Window()]),
    ]));
  }

  Widget _seat(Seat seat, double size) {
    final booked = seat.status == SeatStatus.booked; final isSelected = seat.status == SeatStatus.selected;
    final dimmed = highlight.isNotEmpty && !booked && !isSelected && !highlight.contains(seat.position);
    final marker = seat.position == SeatPosition.middle ? null : seatPositionColor(seat.position);
    return Tooltip(message: '${seat.number} · ${seat.position.label} · ${seat.travelClass.label} · ${booked ? 'Booked' : money(seat.price)}', child: Opacity(opacity: dimmed ? .3 : 1, child: InkWell(
      onTap: booked ? null : () => setState(() { final i = seats.indexOf(seat); seats[i] = seat.copyWith(status: isSelected ? SeatStatus.available : SeatStatus.selected); }),
      borderRadius: BorderRadius.circular(8),
      child: Container(width: size, height: size, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: booked ? _booked : isSelected ? _selected : _available, borderRadius: const BorderRadius.vertical(top: Radius.circular(12), bottom: Radius.circular(5))),
        child: Stack(children: [Center(child: booked ? const Icon(Icons.close_rounded, size: 16, color: Color(0xff98a2b3)) : Text(seat.letter, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : navy))), if (marker != null) Positioned(left: 0, right: 0, bottom: 0, height: 4, child: ColoredBox(color: marker))])),
    )));
  }

  /// The seat list scrolls inside the panel so the total and button stay visible however many seats are picked.
  Widget _summary() => Panel(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(selected.isEmpty ? 'Your seats' : 'Your seats (${selected.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12),
    if (selected.isEmpty) const Text('Tap a seat on the map to select it. Orange marks window seats, purple marks aisle seats.', style: TextStyle(color: muted))
    else Flexible(child: ListView(shrinkWrap: true, children: selected.map((s) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [SeatTag(seat: s), const SizedBox(width: 8), Expanded(child: Text(s.travelClass.label, style: const TextStyle(fontSize: 12, color: muted))), Text(money(s.price), style: const TextStyle(fontWeight: FontWeight.w700))]))).toList())),
    const Divider(height: 28), Row(children: [const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)), const Spacer(), Text(money(total), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))]), const SizedBox(height: 16),
    FilledButton(onPressed: selected.isEmpty ? null : _continue, child: const Text('Continue to checkout')),
  ]));
  Widget _bottomBar() => Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: line)), child: Row(children: [Expanded(child: selected.isEmpty ? const Text('Choose one or more seats', style: TextStyle(fontWeight: FontWeight.w700)) : Wrap(spacing: 6, runSpacing: 6, children: selected.map((s) => SeatTag(seat: s)).toList())), const SizedBox(width: 12), Text(money(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(width: 12), FilledButton(onPressed: selected.isEmpty ? null : _continue, child: const Text('Checkout'))]));

  /// Booking needs an account: logged-out travellers log in (or sign up) first and then carry on to checkout.
  Future<void> _continue() async {
    if (!context.read<AuthController>().loggedIn) { final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LoginScreen(popOnSuccess: true))); if (ok != true || !mounted) return; }
    final chosen = selected; await Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(flight: widget.flight, selectedSeats: chosen, allSeats: seats)));
  }
}

class _Window extends StatelessWidget { const _Window(); @override Widget build(BuildContext context) => Container(width: 5, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: const Color(0xffbfe0f7), borderRadius: BorderRadius.circular(3))); }
class _Legend extends StatelessWidget { const _Legend({required this.color, required this.label, this.marker, this.cross = false}); final Color color; final String label; final Color? marker; final bool cross; @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 18, height: 18, clipBehavior: Clip.antiAlias, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(3)), border: Border.all(color: marker == null ? Colors.transparent : line)), child: Stack(children: [if (cross) const Center(child: Icon(Icons.close_rounded, size: 12, color: Color(0xff98a2b3))), if (marker != null) Positioned(left: 0, right: 0, bottom: 0, height: 4, child: ColoredBox(color: marker!))])), const SizedBox(width: 6), Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))]); }
