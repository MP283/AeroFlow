import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/flight_controller.dart';
import '../models/models.dart';
import '../widgets/app_shell.dart';
import '../widgets/flight_widgets.dart';
import 'seat_selection_screen.dart';

enum _Sort { cheapest, fastest, earliest }

class FlightSearchScreen extends StatefulWidget { const FlightSearchScreen({super.key}); @override State<FlightSearchScreen> createState() => _FlightSearchScreenState(); }
class _FlightSearchScreenState extends State<FlightSearchScreen> {
  Airport? origin; Airport? destination; DateTime? date; TravelClass? travelClass; _Sort sort = _Sort.earliest; bool searched = false;
  @override Widget build(BuildContext context) {
    final controller = context.watch<FlightController>(); final flights = _sorted(controller.flights);
    return AppShell(title: 'Find flights', padded: false, child: ListView(children: [
      _hero(controller),
      _section(Padding(padding: const EdgeInsets.fromLTRB(24, 28, 24, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!searched && controller.flights.isNotEmpty) ...[const Text('Popular routes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 10, children: _routes(controller.flights).map((f) => ActionChip(avatar: const Icon(Icons.trending_up_rounded, size: 16, color: blue), backgroundColor: Colors.white, side: const BorderSide(color: line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), label: Text('${f.origin.city} → ${f.destination.city}', style: const TextStyle(fontWeight: FontWeight.w700)), onPressed: () { setState(() { origin = f.origin; destination = f.destination; date = null; }); _search(controller); })).toList()), const SizedBox(height: 28)],
        Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 12, spacing: 12, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(searched ? '${flights.length} flight${flights.length == 1 ? '' : 's'} found' : 'Upcoming departures', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)), if (searched && (origin != null || destination != null)) Text('${origin?.city ?? 'Anywhere'} → ${destination?.city ?? 'Anywhere'}${date == null ? '' : ' · ${DateFormat('EEE, dd MMM').format(date!)}'}', style: const TextStyle(color: muted))]),
          SegmentedButton<_Sort>(showSelectedIcon: false, style: SegmentedButton.styleFrom(selectedBackgroundColor: navy, selectedForegroundColor: Colors.white, side: const BorderSide(color: line), backgroundColor: Colors.white), segments: const [ButtonSegment(value: _Sort.cheapest, icon: Icon(Icons.savings_outlined, size: 16), label: Text('Cheapest')), ButtonSegment(value: _Sort.fastest, icon: Icon(Icons.speed_rounded, size: 16), label: Text('Fastest')), ButtonSegment(value: _Sort.earliest, icon: Icon(Icons.schedule_rounded, size: 16), label: Text('Earliest'))], selected: {sort}, onSelectionChanged: (v) => setState(() => sort = v.first)),
        ]), const SizedBox(height: 16),
        if (controller.error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(controller.error!, style: const TextStyle(color: Color(0xffd92d20), fontWeight: FontWeight.w600))),
        if (controller.loading) const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else if (flights.isEmpty) const Panel(child: Center(child: EmptyState(icon: Icons.travel_explore_rounded, title: 'No flights match your search', message: 'Try a different date, route or cabin class.')))
        else ...flights.map((f) => _FlightCard(flight: f, travelClass: travelClass)),
      ]))),
      const SiteFooter(),
    ]));
  }

  Widget _section(Widget child) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: child));
  Widget _hero(FlightController controller) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navy, Color(0xff0a3a66), blue])), child: Stack(children: [
    const Positioned(right: 40, top: 10, child: Icon(Icons.flight_rounded, size: 220, color: Color(0x12ffffff))),
    _section(Padding(padding: const EdgeInsets.fromLTRB(24, 44, 24, 40), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Where to next?', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -.5)), const SizedBox(height: 6),
      const Text('Search flights, pick your perfect seat and get your e-ticket instantly.', style: TextStyle(color: Color(0xffc9d6ea), fontSize: 16)), const SizedBox(height: 26),
      Panel(padding: const EdgeInsets.all(20), child: LayoutBuilder(builder: (context, c) { final wide = c.maxWidth > 980; final fields = [
        _airportField('From', Icons.flight_takeoff_rounded, origin, controller.airports, (v) => setState(() => origin = v)),
        IconButton.outlined(tooltip: 'Swap', style: IconButton.styleFrom(side: const BorderSide(color: line)), onPressed: () => setState(() { final o = origin; origin = destination; destination = o; }), icon: const Icon(Icons.swap_horiz_rounded, color: blue)),
        _airportField('To', Icons.flight_land_rounded, destination, controller.airports, (v) => setState(() => destination = v)),
        _dateField(), _classField(),
      ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [wide ? Row(children: [Expanded(flex: 3, child: fields[0]), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: fields[1]), Expanded(flex: 3, child: fields[2]), const SizedBox(width: 12), Expanded(flex: 2, child: fields[3]), const SizedBox(width: 12), Expanded(flex: 2, child: fields[4]), const SizedBox(width: 12), SizedBox(height: 56, child: _searchButton(controller))]) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: fields[0]), Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: fields[1]), Expanded(child: fields[2])]), const SizedBox(height: 12), Row(children: [Expanded(child: fields[3]), const SizedBox(width: 12), Expanded(child: fields[4])]), const SizedBox(height: 12), SizedBox(height: 52, child: _searchButton(controller))])]); })),
    ]))),
  ]));
  Widget _searchButton(FlightController controller) => FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: sunset), onPressed: controller.loading ? null : () => _search(controller), icon: const Icon(Icons.search_rounded), label: const Text('Search flights'));
  Widget _airportField(String label, IconData icon, Airport? value, List<Airport> airports, ValueChanged<Airport?> changed) => AirportField(label: label, icon: icon, value: value, airports: airports, onChanged: changed, hint: 'Anywhere');
  Widget _dateField() => InkWell(borderRadius: BorderRadius.circular(10), onTap: () async { final v = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: date ?? DateTime.now()); if (v != null) setState(() => date = v); }, child: InputDecorator(decoration: InputDecoration(labelText: 'Departure', prefixIcon: const Icon(Icons.calendar_month_rounded, color: blue), suffixIcon: date == null ? null : IconButton(tooltip: 'Any date', icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => date = null))), child: Text(date == null ? 'Any date' : DateFormat('EEE, dd MMM').format(date!), overflow: TextOverflow.ellipsis)));
  Widget _classField() => DropdownButtonFormField<TravelClass>(initialValue: travelClass, isExpanded: true, decoration: const InputDecoration(labelText: 'Cabin', prefixIcon: Icon(Icons.airline_seat_recline_extra_rounded, color: blue)), items: [const DropdownMenuItem<TravelClass>(value: null, child: Text('Any cabin')), ...TravelClass.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label)))], onChanged: (v) => setState(() => travelClass = v));

  void _search(FlightController controller) { setState(() => searched = true); controller.search(origin: origin, destination: destination, date: date, travelClass: travelClass); }
  List<Flight> _routes(List<Flight> flights) { final seen = <String>{}; return flights.where((f) => seen.add('${f.origin.code}-${f.destination.code}')).take(6).toList(); }
  double _price(Flight f) => f.basePrice(travelClass ?? TravelClass.economy);
  List<Flight> _sorted(List<Flight> flights) => [...flights]..sort((a, b) => switch (sort) { _Sort.cheapest => _price(a).compareTo(_price(b)), _Sort.fastest => a.duration.compareTo(b.duration), _Sort.earliest => a.departure.compareTo(b.departure) });
}

class _FlightCard extends StatefulWidget { const _FlightCard({required this.flight, this.travelClass}); final Flight flight; final TravelClass? travelClass; @override State<_FlightCard> createState() => _FlightCardState(); }
class _FlightCardState extends State<_FlightCard> {
  bool open = false;
  @override Widget build(BuildContext context) {
    final f = widget.flight; final cabin = widget.travelClass ?? TravelClass.economy; final left = f.availability(cabin);
    final info = Row(children: [AirlineBadge(airline: f.airline), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(f.airline, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), Text('${f.flightNumber} · ${f.airplane.name}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted))]))]);
    final price = Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [Text(cabin.label, style: const TextStyle(fontSize: 12, color: muted)), Text(money(f.basePrice(cabin)), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: navy)), Text(left == 0 ? 'Sold out' : left <= 5 ? 'Only $left seats left' : '$left seats left', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: left <= 5 ? const Color(0xffd92d20) : const Color(0xff079455))), const SizedBox(height: 10), FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeatSelectionScreen(flight: f))), child: const Text('Select seats'))]);
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Panel(padding: EdgeInsets.zero, child: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: LayoutBuilder(builder: (context, c) => c.maxWidth > 760
        ? Row(children: [SizedBox(width: 230, child: info), Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: RouteTimeline(flight: f))), const SizedBox(width: 20, height: 120, child: DottedLine(axis: Axis.vertical)), const SizedBox(width: 20), price])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 16), RouteTimeline(flight: f), const Divider(height: 28), Align(alignment: Alignment.centerRight, child: price)]))),
      InkWell(onTap: () => setState(() => open = !open), child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: const BoxDecoration(color: Color(0xfffafbfd), border: Border(top: BorderSide(color: line))), child: Row(children: [Expanded(child: Text(DateFormat('EEE, dd MMM yyyy').format(f.departure), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600))), Text(open ? 'Hide fares' : 'Compare cabin fares', style: const TextStyle(fontSize: 13, color: blue, fontWeight: FontWeight.w700)), Icon(open ? Icons.expand_less : Icons.expand_more, color: blue)]))),
      if (open) Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), child: Wrap(spacing: 12, runSpacing: 12, children: TravelClass.values.map((c) => Container(width: 210, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: c == cabin ? const Color(0xffe6f4fc) : const Color(0xfff5f7fb), borderRadius: BorderRadius.circular(12), border: Border.all(color: c == cabin ? blue : line)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c.label, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(money(f.basePrice(c)), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text('${f.availability(c)} seats left', style: const TextStyle(fontSize: 12, color: muted))]))).toList())),
    ])));
  }
}
