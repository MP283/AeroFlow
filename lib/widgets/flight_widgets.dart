import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'app_shell.dart';

class AirlineBadge extends StatelessWidget { const AirlineBadge({super.key, required this.airline, this.size = 44}); final String airline; final double size; @override Widget build(BuildContext context) => Container(width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(gradient: const LinearGradient(colors: [blue, Color(0xff0057a8)]), borderRadius: BorderRadius.circular(size * .28)), child: Text(airline.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .34))); }

/// Departure → arrival block with a dotted flight path and duration, as on a ticket.
class RouteTimeline extends StatelessWidget {
  const RouteTimeline({super.key, required this.flight, this.large = false});
  final Flight flight;
  final bool large;
  @override Widget build(BuildContext context) => Row(children: [
    Flexible(flex: 2, child: _end(flight.departure, flight.origin, CrossAxisAlignment.start)),
    Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Column(children: [Text(formatDuration(flight.duration), style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Row(children: [const _Dot(), const Expanded(child: DottedLine()), Transform.rotate(angle: 1.5708, child: const Icon(Icons.flight_rounded, size: 18, color: blue)), const Expanded(child: DottedLine()), const _Dot()]), const SizedBox(height: 4), const Text('Non-stop', style: TextStyle(fontSize: 12, color: Color(0xff079455), fontWeight: FontWeight.w700))]))),
    Flexible(flex: 2, child: _end(flight.arrival, flight.destination, CrossAxisAlignment.end)),
  ]);
  Widget _end(DateTime time, Airport airport, CrossAxisAlignment align) => Column(crossAxisAlignment: align, children: [FittedBox(fit: BoxFit.scaleDown, child: Text(DateFormat('HH:mm').format(time), style: TextStyle(fontSize: large ? 30 : 24, fontWeight: FontWeight.w800, color: navy, height: 1.1))), Text(airport.code, style: TextStyle(fontSize: large ? 16 : 14, fontWeight: FontWeight.w800, color: blue)), Text(airport.city, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted)), if (large) Text(DateFormat('EEE, dd MMM yyyy').format(time), textAlign: align == CrossAxisAlignment.end ? TextAlign.end : TextAlign.start, style: const TextStyle(fontSize: 12, color: muted))]);
}

class _Dot extends StatelessWidget { const _Dot(); @override Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: blue, width: 2))); }

class DottedLine extends StatelessWidget { const DottedLine({super.key, this.color = const Color(0xffb8c4d6), this.dash = 4, this.axis = Axis.horizontal}); final Color color; final double dash; final Axis axis; @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) { final length = axis == Axis.horizontal ? c.maxWidth : c.maxHeight; final count = (length / (dash * 2)).floor().clamp(0, 400); return Flex(direction: axis, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(count, (_) => SizedBox(width: axis == Axis.horizontal ? dash : 1.4, height: axis == Axis.horizontal ? 1.4 : dash, child: ColoredBox(color: color)))); }); }

IconData seatPositionIcon(SeatPosition p) => switch (p) { SeatPosition.window => Icons.wb_sunny_outlined, SeatPosition.aisle => Icons.directions_walk_rounded, SeatPosition.middle => Icons.more_horiz_rounded };
Color seatPositionColor(SeatPosition p) => switch (p) { SeatPosition.window => const Color(0xffdc6803), SeatPosition.aisle => const Color(0xff6941c6), SeatPosition.middle => muted };

/// Chip such as "12A · Window" used wherever booked or selected seats are listed.
class SeatTag extends StatelessWidget { const SeatTag({super.key, required this.seat, this.dark = false}); final Seat seat; final bool dark; @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: dark ? const Color(0x26ffffff) : const Color(0xfff2f6fc), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(seatPositionIcon(seat.position), size: 14, color: dark ? Colors.white : seatPositionColor(seat.position)), const SizedBox(width: 5), Text('${seat.number} · ${seat.position.label}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: dark ? Colors.white : navy))])); }

/// Type-ahead airport picker: matches code, city or airport name and suggests as you type.
/// Text that isn't a picked suggestion leaves the value null ("Anywhere" on search).
class AirportField extends StatefulWidget {
  const AirportField({super.key, required this.label, required this.airports, required this.value, required this.onChanged, this.icon, this.required = false, this.hint = 'City or airport'});
  final String label, hint;
  final IconData? icon;
  final List<Airport> airports;
  final Airport? value;
  final ValueChanged<Airport?> onChanged;
  final bool required;
  @override State<AirportField> createState() => _AirportFieldState();
}
class _AirportFieldState extends State<AirportField> {
  late final controller = TextEditingController(text: widget.value?.displayName ?? ''); final focus = FocusNode();
  @override void initState() { super.initState(); controller.addListener(() => setState(() {})); focus.addListener(_onBlur); }
  /// Leaving the field with typed text but no pick selects the best match (e.g. "mumb" → Mumbai).
  void _onBlur() { if (focus.hasFocus || widget.value != null || controller.text.trim().isEmpty) return; final best = matches(widget.airports, controller.text).firstOrNull; if (best != null) { controller.text = best.displayName; widget.onChanged(best); } }
  @override void didUpdateWidget(AirportField old) { super.didUpdateWidget(old); final text = widget.value?.displayName ?? ''; if (widget.value?.code != old.value?.code && controller.text != text && (widget.value != null || !focus.hasFocus)) controller.text = text; }
  @override void dispose() { controller.dispose(); focus.dispose(); super.dispose(); }

  static Iterable<Airport> matches(List<Airport> airports, String query) {
    final q = query.trim().toLowerCase(); if (q.isEmpty) return const [];
    int rank(Airport a) => a.code.toLowerCase() == q ? 0 : a.city.toLowerCase().startsWith(q) ? 1 : a.code.toLowerCase().startsWith(q) ? 2 : a.city.toLowerCase().contains(q) ? 3 : a.name.toLowerCase().contains(q) ? 4 : 9;
    return (airports.where((a) => rank(a) < 9).toList()..sort((a, b) { final r = rank(a).compareTo(rank(b)); return r != 0 ? r : a.city.compareTo(b.city); })).take(8);
  }

  @override Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) => RawAutocomplete<Airport>(
    textEditingController: controller, focusNode: focus,
    displayStringForOption: (a) => a.displayName,
    optionsBuilder: (v) => v.text == widget.value?.displayName ? const <Airport>[] : matches(widget.airports, v.text),
    onSelected: (a) { widget.onChanged(a); focus.unfocus(); },
    fieldViewBuilder: (context, textController, focusNode, onSubmit) => TextFormField(controller: textController, focusNode: focusNode, onFieldSubmitted: (_) => onSubmit(),
      onChanged: (text) { if (widget.value != null && text != widget.value!.displayName) widget.onChanged(null); },
      validator: (_) => widget.value != null ? null : controller.text.trim().isNotEmpty ? 'Pick an airport from the suggestions' : widget.required ? 'Required' : null,
      decoration: InputDecoration(labelText: widget.label, hintText: widget.hint, prefixIcon: widget.icon == null ? null : Icon(widget.icon, color: blue), suffixIcon: controller.text.isEmpty ? null : IconButton(tooltip: 'Clear', icon: const Icon(Icons.close, size: 18), onPressed: () { controller.clear(); widget.onChanged(null); }))),
    optionsViewBuilder: (context, onSelected, options) => Align(alignment: Alignment.topLeft, child: Material(elevation: 6, borderRadius: BorderRadius.circular(12), color: Colors.white, child: ConstrainedBox(constraints: BoxConstraints(maxHeight: 320, maxWidth: c.maxWidth < 280 ? 280 : c.maxWidth), child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), shrinkWrap: true, children: [
      for (final (i, a) in options.indexed) Builder(builder: (context) { final highlighted = AutocompleteHighlightedOption.of(context) == i; return InkWell(onTap: () => onSelected(a), child: Container(color: highlighted ? const Color(0xffe6f4fc) : null, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [Container(width: 46, padding: const EdgeInsets.symmetric(vertical: 4), alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xfff2f6fc), borderRadius: BorderRadius.circular(6)), child: Text(a.code, style: const TextStyle(fontWeight: FontWeight.w800, color: blue))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a.city, style: const TextStyle(fontWeight: FontWeight.w700, color: navy)), Text(a.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted))]))]))); }),
    ])))),
  ));
}
