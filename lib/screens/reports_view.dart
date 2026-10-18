import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/reports_controller.dart';
import '../models/models.dart';
import '../utils/web_export.dart';
import '../widgets/app_shell.dart';

final _date = DateFormat('d MMM yyyy'), _dateTime = DateFormat('d MMM yyyy, HH:mm'), _iso = DateFormat('yyyy-MM-dd'), _month = DateFormat('MMM yyyy');
const _green = Color(0xff12a150);

/// Admin "Reports" tab: one date range drives the Sales, Users and Invoices sub-tabs.
class ReportsView extends StatefulWidget { const ReportsView({super.key}); @override State<ReportsView> createState() => _ReportsViewState(); }
class _ReportsViewState extends State<ReportsView> {
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.read<ReportsController>().ensureLoaded(); }); }
  @override Widget build(BuildContext context) {
    final r = context.watch<ReportsController>();
    return DefaultTabController(length: 3, child: Builder(builder: (context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _RangeButton(range: r.range, onChanged: (from, to) => r.setRange(from, to)),
        OutlinedButton.icon(onPressed: r.loading ? null : r.load, icon: const Icon(Icons.refresh_rounded, size: 18), label: const Text('Refresh')),
        FilledButton.icon(onPressed: r.loaded && !r.loading ? () => _downloadCsv(r, DefaultTabController.of(context).index) : null, icon: const Icon(Icons.download_rounded, size: 18), label: const Text('Download CSV')),
      ]), const SizedBox(height: 14),
      const Align(alignment: Alignment.centerLeft, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, labelColor: navy, unselectedLabelColor: muted, indicatorColor: blue, dividerColor: line, labelStyle: TextStyle(fontWeight: FontWeight.w800), tabs: [Tab(text: 'Sales'), Tab(text: 'Users'), Tab(text: 'Invoices')])),
      SizedBox(height: 3, child: r.loading && r.loaded ? const LinearProgressIndicator(minHeight: 3) : null), const SizedBox(height: 12),
      Expanded(child: r.error != null ? Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load reports', message: r.error!, action: OutlinedButton(onPressed: r.load, child: const Text('Try again'))))
        : !r.loaded ? const Center(child: CircularProgressIndicator())
        : TabBarView(children: [_SalesTab(report: r.sales!, range: r.range), _UsersTab(report: r.users!), _InvoicesTab(invoices: r.invoices)])),
    ])));
  }

  void _downloadCsv(ReportsController r, int tab) {
    final kind = const ['sales', 'users', 'invoices'][tab]; final rows = switch (tab) { 0 => _salesCsv(r.sales!), 1 => _usersCsv(r.users!), _ => _invoicesCsv(r.invoices) };
    downloadFile('aeroflow-$kind-${_iso.format(r.range.from)}_${_iso.format(r.range.to)}.csv', toCsv([['AeroFlow $kind report', '${_iso.format(r.range.from)} to ${_iso.format(r.range.to)}'], [], ...rows]), 'text/csv;charset=utf-8');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloaded the ${kind[0].toUpperCase()}${kind.substring(1)} report.')));
  }
}

String _amount(double v) => v.toStringAsFixed(2);
List<List<Object?>> _salesCsv(SalesReport s) => [
  ['Total revenue', _amount(s.revenue)], ['Bookings', s.bookings], ['Seats sold', s.seats], ['Average booking', _amount(s.averageBooking)], [],
  ['Date', 'Bookings', 'Seats', 'Revenue'], for (final d in s.byDay) [_iso.format(d.date), d.bookings, d.seats, _amount(d.revenue)], [],
  ['Travel class', 'Seats', 'Revenue'], for (final c in s.byClass) [c.travelClass.label, c.seats, _amount(c.revenue)], [],
  ['Payment method', 'Bookings', 'Revenue'], for (final p in s.byPaymentMethod) [p.method, p.bookings, _amount(p.revenue)], [],
  ['Flight', 'Route', 'Departure', 'Seats sold', 'Capacity', 'Load factor %', 'Revenue'], for (final f in s.byFlight) [f.flightNumber, '${f.origin}-${f.destination}', _dateTime.format(f.departure), f.seatsSold, f.capacity, (f.loadFactor * 100).toStringAsFixed(1), _amount(f.revenue)],
];
List<List<Object?>> _usersCsv(UserReport u) => [
  ['Name', 'Email', 'Phone', 'Role', 'Joined', 'Bookings', 'Seats', 'Total spent', 'Last booking'],
  for (final x in u.users) [x.fullName, x.email, x.phone, x.role, _iso.format(x.createdAt), x.bookings, x.seats, _amount(x.totalSpent), x.lastBookingAt == null ? '' : _dateTime.format(x.lastBookingAt!)],
];
List<List<Object?>> _invoicesCsv(List<Invoice> invoices) => [
  ['Invoice', 'Issued', 'Passenger', 'Email', 'Phone', 'Account', 'Flight', 'Route', 'Departure', 'Seats', 'Payment', 'Amount'],
  for (final i in invoices) [i.invoiceNumber, _dateTime.format(i.issuedAt), i.passengerName, i.email, i.phone, i.accountEmail ?? '', i.flightNumber, '${i.origin} → ${i.destination}', _dateTime.format(i.departure), i.lines.map((l) => l.seat).join(' '), i.paymentMethod, _amount(i.totalAmount)],
];

/// Date-range picker with quick presets.
class _RangeButton extends StatelessWidget {
  const _RangeButton({required this.range, required this.onChanged});
  final ReportRange range; final void Function(DateTime from, DateTime to) onChanged;
  @override Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final presets = <String, (DateTime, DateTime)>{'Last 7 days': (today.subtract(const Duration(days: 6)), today), 'Last 30 days': (today.subtract(const Duration(days: 29)), today), 'Last 90 days': (today.subtract(const Duration(days: 89)), today), 'This month': (DateTime(today.year, today.month), today), 'This year': (DateTime(today.year), today)};
    return PopupMenuButton<String>(tooltip: 'Report period', offset: const Offset(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), onSelected: (v) async {
      if (presets[v] case final p?) { onChanged(p.$1, p.$2); return; }
      final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: today, initialDateRange: DateTimeRange(start: range.from.isAfter(today) ? today : range.from, end: range.to.isAfter(today) ? today : range.to), helpText: 'Report period');
      if (picked != null) onChanged(picked.start, picked.end);
    }, itemBuilder: (_) => [for (final p in presets.keys) PopupMenuItem(value: p, child: Text(p)), const PopupMenuDivider(), const PopupMenuItem(value: 'custom', child: Text('Custom range…'))],
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: line)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.date_range_rounded, size: 18, color: blue), const SizedBox(width: 8), Flexible(child: Text('${_date.format(range.from)} – ${_date.format(range.to)}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: navy))), const SizedBox(width: 4), const Icon(Icons.arrow_drop_down_rounded, color: muted)])));
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.icon);
  final String label, value; final IconData icon;
  @override Widget build(BuildContext context) => SizedBox(width: 230, child: Panel(padding: const EdgeInsets.all(18), child: Row(children: [CircleAvatar(radius: 20, backgroundColor: const Color(0xffe6f4fc), child: Icon(icon, color: blue, size: 20)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy))), Text(label, style: const TextStyle(color: muted, fontSize: 13))]))])));
}
Widget _kpis(List<_Kpi> tiles) => Wrap(spacing: 14, runSpacing: 14, children: tiles);
Widget _card(String title, Widget child, {String? subtitle}) => Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), if (subtitle != null) Text(subtitle, style: const TextStyle(color: muted, fontSize: 13)), const SizedBox(height: 14), child]));
/// Horizontally scrollable table; [numeric] marks right-aligned columns.
Widget _table(List<String> headers, List<List<Widget>> rows, {Set<int> numeric = const {}, void Function(int row)? onTap}) => SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(showCheckboxColumn: false, headingRowHeight: 40, dataRowMinHeight: 44, dataRowMaxHeight: 56, horizontalMargin: 8, columnSpacing: 28, headingTextStyle: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .4),
  columns: [for (var i = 0; i < headers.length; i++) DataColumn(label: Text(headers[i].toUpperCase()), numeric: numeric.contains(i))],
  rows: [for (var r = 0; r < rows.length; r++) DataRow(onSelectChanged: onTap == null ? null : (_) => onTap(r), cells: [for (final c in rows[r]) DataCell(c)])]));
Text _strong(String s) => Text(s, style: const TextStyle(fontWeight: FontWeight.w700, color: navy));

class _SalesTab extends StatelessWidget {
  const _SalesTab({required this.report, required this.range});
  final SalesReport report; final ReportRange range;
  @override Widget build(BuildContext context) { final s = report; return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    _kpis([_Kpi('Revenue', money(s.revenue), Icons.payments_outlined), _Kpi('Bookings', '${s.bookings}', Icons.confirmation_number_outlined), _Kpi('Seats sold', '${s.seats}', Icons.event_seat_outlined), _Kpi('Avg. booking', money(s.averageBooking), Icons.trending_up_rounded)]), const SizedBox(height: 16),
    if (s.bookings == 0) const Panel(child: Center(child: EmptyState(icon: Icons.query_stats_rounded, title: 'No sales in this period', message: 'Bookings made between these dates will be summarised here.')))
    else ...[
      _RevenueChart(days: s.byDay, range: range), const SizedBox(height: 16),
      Wrap(spacing: 16, runSpacing: 16, children: [
        SizedBox(width: 440, child: _card('By travel class', _table(['Class', 'Seats', 'Revenue', 'Share'], [for (final c in s.byClass) [_strong(c.travelClass.label), Text('${c.seats}'), Text(money(c.revenue)), Text('${(c.revenue / s.revenue * 100).toStringAsFixed(1)}%')]], numeric: {1, 2, 3}))),
        SizedBox(width: 440, child: _card('By payment method', _table(['Method', 'Bookings', 'Revenue'], [for (final p in s.byPaymentMethod) [_strong(p.method), Text('${p.bookings}'), Text(money(p.revenue))]], numeric: {1, 2}))),
      ]), const SizedBox(height: 16),
      _card('By flight', subtitle: 'Seats sold in this period against each flight\'s total capacity.', _table(['Flight', 'Route', 'Departure', 'Sold / capacity', 'Load', 'Revenue'], [for (final f in s.byFlight) [_strong(f.flightNumber), Text('${f.origin} → ${f.destination}'), Text(_dateTime.format(f.departure)), Text('${f.seatsSold} / ${f.capacity}'),
        SizedBox(width: 110, child: Row(children: [Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: f.loadFactor, minHeight: 6, backgroundColor: line, color: f.loadFactor >= .8 ? _green : blue))), const SizedBox(width: 8), Text('${(f.loadFactor * 100).round()}%')])), Text(money(f.revenue))]], numeric: {3, 5})),
    ],
  ]); }
}

/// Revenue bars per day (or per month for ranges over ~3 months), with empty periods shown as gaps.
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.days, required this.range});
  final List<SalesDay> days; final ReportRange range;
  @override Widget build(BuildContext context) {
    final monthly = range.to.difference(range.from).inDays > 92; DateTime key(DateTime d) => monthly ? DateTime(d.year, d.month) : DateTime(d.year, d.month, d.day);
    final totals = <DateTime, double>{}; for (var d = key(range.from); !d.isAfter(range.to); d = monthly ? DateTime(d.year, d.month + 1) : DateTime(d.year, d.month, d.day + 1)) { totals[d] = 0; }
    for (final d in days) { totals.update(key(d.date), (v) => v + d.revenue, ifAbsent: () => d.revenue); }
    final peak = totals.values.fold(0.0, math.max); final label = monthly ? _month : _date;
    return _card(monthly ? 'Revenue by month' : 'Revenue by day', subtitle: 'Peak ${money(peak)}', Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 160, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final e in totals.entries) Expanded(child: Tooltip(message: '${label.format(e.key)} · ${money(e.value)}', child: Padding(padding: EdgeInsets.symmetric(horizontal: totals.length > 60 ? 0.5 : 2), child: Container(height: peak == 0 ? 0 : math.max(e.value / peak * 160, e.value > 0 ? 3 : 0), decoration: const BoxDecoration(color: blue, borderRadius: BorderRadius.vertical(top: Radius.circular(3)))))))])),
      Container(height: 1, color: line), const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label.format(totals.keys.first), style: const TextStyle(color: muted, fontSize: 12)), Text(label.format(totals.keys.last), style: const TextStyle(color: muted, fontSize: 12))]),
    ]));
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.report});
  final UserReport report;
  @override Widget build(BuildContext context) { final u = report; return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    _kpis([_Kpi('Total users', '${u.totalUsers}', Icons.groups_outlined), _Kpi('New in period', '${u.newUsers}', Icons.person_add_alt_outlined), _Kpi('Active buyers', '${u.activeBuyers}', Icons.shopping_bag_outlined), _Kpi('Admins', '${u.admins}', Icons.admin_panel_settings_outlined)]), const SizedBox(height: 16),
    _card('All users', subtitle: 'Bookings, seats and spend count only bookings made in the selected period.', _table(['Name', 'Email', 'Phone', 'Role', 'Joined', 'Bookings', 'Seats', 'Total spent', 'Last booking'], [for (final x in u.users) [
      _strong(x.fullName), Text(x.email), Text(x.phone),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: x.isAdmin ? const Color(0xfffff1e9) : const Color(0xffe6f4fc), borderRadius: BorderRadius.circular(20)), child: Text(x.isAdmin ? 'ADMIN' : 'CUSTOMER', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .6, color: x.isAdmin ? sunset : blue))),
      Text(_date.format(x.createdAt)), Text('${x.bookings}'), Text('${x.seats}'), Text(money(x.totalSpent)), Text(x.lastBookingAt == null ? '—' : _dateTime.format(x.lastBookingAt!)),
    ]], numeric: {5, 6, 7})),
  ]); }
}

class _InvoicesTab extends StatelessWidget {
  const _InvoicesTab({required this.invoices});
  final List<Invoice> invoices;
  @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
    _kpis([_Kpi('Invoices', '${invoices.length}', Icons.receipt_long_outlined), _Kpi('Total billed', money(invoices.fold(0.0, (sum, i) => sum + i.totalAmount)), Icons.account_balance_wallet_outlined)]), const SizedBox(height: 16),
    if (invoices.isEmpty) const Panel(child: Center(child: EmptyState(icon: Icons.receipt_long_outlined, title: 'No invoices in this period', message: 'Every booking issues an invoice; they will be listed here.')))
    else _card('Invoices', subtitle: 'Tap an invoice to view or print it.', _table(['Invoice', 'Issued', 'Customer', 'Flight', 'Seats', 'Payment', 'Amount'], [for (final i in invoices) [
      Text(i.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.w800, color: blue)), Text(_dateTime.format(i.issuedAt)), Text(i.passengerName), Text('${i.flightNumber} · ${i.originCode} → ${i.destinationCode}'), Text(i.lines.map((l) => l.seat).join(', ')), Text(i.paymentMethod), _strong(money(i.totalAmount)),
    ]], numeric: {6}, onTap: (row) => showDialog(context: context, builder: (_) => InvoiceDialog(invoice: invoices[row])))),
  ]);
}

class InvoiceDialog extends StatelessWidget {
  const InvoiceDialog({super.key, required this.invoice});
  final Invoice invoice;
  @override Widget build(BuildContext context) { final i = invoice; Widget kv(String k, String v) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 92, child: Text(k, style: const TextStyle(color: muted, fontSize: 13))), Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600)))]));
    Widget block(String title, List<Widget> rows) => SizedBox(width: 270, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: const TextStyle(color: blue, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)), const SizedBox(height: 8), ...rows]));
    return Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: SingleChildScrollView(padding: const EdgeInsets.all(26), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, spacing: 12, children: [const AeroFlowMark(), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text('TAX INVOICE', style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)), Text(i.invoiceNumber, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text('Issued ${_dateTime.format(i.issuedAt)}', style: const TextStyle(color: muted, fontSize: 13))])]),
      const Divider(height: 32, color: line),
      Wrap(spacing: 24, runSpacing: 18, children: [
        block('Bill to', [kv('Passenger', i.passengerName), kv('Email', i.email), kv('Phone', i.phone), if (i.accountEmail != null) kv('Account', i.accountEmail!)]),
        block('Flight', [kv('Flight', '${i.flightNumber} · ${i.airline}'), kv('From', i.origin), kv('To', i.destination), kv('Departs', _dateTime.format(i.departure))]),
      ]), const SizedBox(height: 20),
      Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: line)), child: Column(children: [
        Container(color: soft, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: const Row(children: [Expanded(child: Text('SEAT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted))), Expanded(child: Text('CLASS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted))), Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted))])),
        for (final l in i.lines) Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10), child: Row(children: [Expanded(child: Text(l.seat, style: const TextStyle(fontWeight: FontWeight.w700))), Expanded(child: Text(l.travelClass.label)), Text(money(l.price))])),
        Container(decoration: const BoxDecoration(border: Border(top: BorderSide(color: line))), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [Expanded(child: Text('Paid via ${i.paymentMethod}', style: const TextStyle(color: muted))), const Text('Total  ', style: TextStyle(fontWeight: FontWeight.w700)), Text(money(i.totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))])),
      ])), const SizedBox(height: 8),
      Text('Booking reference ${i.bookingId} · Fares include taxes.', style: const TextStyle(color: muted, fontSize: 12)), const SizedBox(height: 20),
      Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')), FilledButton.icon(onPressed: () => openPrintable(invoiceHtml(i)), icon: const Icon(Icons.print_outlined, size: 18), label: const Text('Print / Save PDF'))]),
    ]))));
  }
}

/// Self-contained printable invoice page (opened in a new tab, prints itself on load).
String invoiceHtml(Invoice i) {
  const esc = HtmlEscape(); String e(String s) => esc.convert(s);
  final lines = i.lines.map((l) => '<tr><td>${e(l.seat)}</td><td>${e(l.travelClass.label)}</td><td class="r">${e(money(l.price))}</td></tr>').join();
  return '''<!doctype html><html><head><meta charset="utf-8"><title>${e(i.invoiceNumber)} · AeroFlow</title><style>
body{font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:#0b192c;max-width:720px;margin:40px auto;padding:0 24px}h1{margin:0;font-size:24px}.brand{font-size:22px;font-weight:800}.brand span{color:#008dda}
.top{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:1px solid #e0e7f2;padding-bottom:18px}.muted{color:#667085;font-size:13px}.cols{display:flex;gap:40px;margin:22px 0}.cols h3{color:#008dda;font-size:11px;letter-spacing:1px;margin:0 0 8px}
.cols p{margin:2px 0;font-size:14px}table{width:100%;border-collapse:collapse;font-size:14px}th{background:#f2f3ff;text-align:left;font-size:11px;color:#667085;padding:10px}td{border-top:1px solid #e0e7f2;padding:10px}.r{text-align:right}.total td{font-weight:800;font-size:16px}
@media print{body{margin:0}}</style></head><body>
<div class="top"><div class="brand">Aero<span>Flow</span></div><div style="text-align:right"><div class="muted">TAX INVOICE</div><h1>${e(i.invoiceNumber)}</h1><div class="muted">Issued ${e(_dateTime.format(i.issuedAt))}</div></div></div>
<div class="cols"><div><h3>BILL TO</h3><p><b>${e(i.passengerName)}</b></p><p>${e(i.email)}</p><p>${e(i.phone)}</p>${i.accountEmail == null ? '' : '<p class="muted">Account: ${e(i.accountEmail!)}</p>'}</div>
<div><h3>FLIGHT</h3><p><b>${e(i.flightNumber)}</b> · ${e(i.airline)}</p><p>${e(i.origin)} → ${e(i.destination)}</p><p>Departs ${e(_dateTime.format(i.departure))}</p></div></div>
<table><thead><tr><th>SEAT</th><th>CLASS</th><th class="r">AMOUNT</th></tr></thead><tbody>$lines</tbody><tfoot><tr class="total"><td colspan="2">Total (paid via ${e(i.paymentMethod)})</td><td class="r">${e(money(i.totalAmount))}</td></tr></tfoot></table>
<p class="muted">Booking reference ${e(i.bookingId)} · Fares include taxes.</p>
<script>window.onload=function(){window.print()}</script></body></html>''';
}
