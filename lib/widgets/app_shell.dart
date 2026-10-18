import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';

const navy = Color(0xff0b192c);
const blue = Color(0xff008dda);
const page = Color(0xfff5f7fb);
const soft = Color(0xfff2f3ff);
const line = Color(0xffe0e7f2);
const muted = Color(0xff667085);
const sunset = Color(0xffff7a45);

enum BookingStep { search, seats, checkout, confirmed }

extension BookingStepLabel on BookingStep { String get label => switch (this) { BookingStep.search => 'Search', BookingStep.seats => 'Choose seats', BookingStep.checkout => 'Passenger & payment', BookingStep.confirmed => 'Confirmed' }; }

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.title, required this.child, this.step, this.padded = true});
  final String title;
  final Widget child;
  /// Shows the booking progress bar under the top bar when set.
  final BookingStep? step;
  /// When false the child fills the full width (used by pages with a full-bleed hero).
  final bool padded;
  @override
  Widget build(BuildContext context) => Title(title: '$title · AeroFlow', color: blue, child: Scaffold(
    backgroundColor: page,
    appBar: PreferredSize(preferredSize: const Size.fromHeight(68), child: _TopBar(current: ModalRoute.of(context)?.settings.name)),
    body: SafeArea(top: false, child: Column(children: [
      if (step != null) _Stepper(step: step!),
      Expanded(child: padded ? Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: Padding(padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), child: child))) : child),
    ])),
  ));
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.current});
  final String? current;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>(); final user = auth.user; final wide = MediaQuery.sizeOf(context).width > 820;
    return Material(color: Colors.white, elevation: 0, child: Container(height: 68, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: line))), padding: const EdgeInsets.symmetric(horizontal: 24), child: Row(children: [
      InkWell(onTap: () => _go(context, '/'), child: const AeroFlowMark()), const SizedBox(width: 28),
      if (wide) ...[_link(context, Icons.flight_rounded, 'Flights', '/'), _link(context, Icons.luggage_rounded, 'My Trips', '/account'), if (user?.isAdmin ?? false) _link(context, Icons.dashboard_customize_rounded, 'Partner', '/enlist')],
      const Spacer(),
      if (auth.restoring) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
      else if (user == null) ...[TextButton(onPressed: () => Navigator.pushNamed(context, '/login'), child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.w700))), const SizedBox(width: 8), FilledButton(onPressed: () => Navigator.pushNamed(context, '/signup'), child: const Text('Sign up'))]
      else PopupMenuButton<String>(tooltip: 'Account', offset: const Offset(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), onSelected: (v) async { if (v == 'logout') { await auth.logout(); if (context.mounted) _go(context, '/'); } else { _go(context, v); } },
        itemBuilder: (_) => [PopupMenuItem(enabled: false, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w800, color: navy)), Text(user.email, style: const TextStyle(fontSize: 12, color: muted))])), const PopupMenuDivider(), const PopupMenuItem(value: '/account', child: ListTile(dense: true, leading: Icon(Icons.person_outline), title: Text('My account'))), if (!wide) const PopupMenuItem(value: '/', child: ListTile(dense: true, leading: Icon(Icons.flight_rounded), title: Text('Search flights'))), if (user.isAdmin) const PopupMenuItem(value: '/enlist', child: ListTile(dense: true, leading: Icon(Icons.dashboard_customize_outlined), title: Text('Partner dashboard'))), const PopupMenuItem(value: 'logout', child: ListTile(dense: true, leading: Icon(Icons.logout), title: Text('Log out')))],
        child: Row(mainAxisSize: MainAxisSize.min, children: [if (wide) Padding(padding: const EdgeInsets.only(right: 10), child: Text('Hi, ${user.fullName.split(' ').first}', style: const TextStyle(fontWeight: FontWeight.w700, color: navy))), CircleAvatar(radius: 18, backgroundColor: navy, child: Text(user.initials, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)))])),
    ])));
  }
  Widget _link(BuildContext context, IconData icon, String label, String route) { final active = current == route; return Padding(padding: const EdgeInsets.only(right: 4), child: TextButton.icon(style: TextButton.styleFrom(foregroundColor: active ? blue : navy, backgroundColor: active ? const Color(0xffe6f4fc) : null, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)), onPressed: () => _go(context, route), icon: Icon(icon, size: 18), label: Text(label))); }
  void _go(BuildContext context, String route) => Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final BookingStep step;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, color: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Center(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [for (final s in BookingStep.values) ...[
    if (s.index > 0) Container(width: 48, height: 2, margin: const EdgeInsets.symmetric(horizontal: 10), color: s.index <= step.index ? blue : line),
    CircleAvatar(radius: 12, backgroundColor: s.index < step.index ? blue : s == step ? navy : line, child: s.index < step.index ? const Icon(Icons.check, size: 14, color: Colors.white) : Text('${s.index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: s.index <= step.index ? Colors.white : muted))),
    const SizedBox(width: 8), Text(s.label, style: TextStyle(fontSize: 13, fontWeight: s == step ? FontWeight.w800 : FontWeight.w600, color: s.index <= step.index ? navy : muted)),
  ]]))));
}

/// Shows [child] only to logged-in users (and only admins when [adminOnly]); otherwise redirects to /login.
class RequireAuth extends StatelessWidget {
  const RequireAuth({super.key, required this.route, required this.child, this.adminOnly = false});
  final String route;
  final Widget child;
  final bool adminOnly;
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    if (auth.restoring) return const Scaffold(backgroundColor: page, body: Center(child: CircularProgressIndicator()));
    if (!auth.loggedIn) { WidgetsBinding.instance.addPostFrameCallback((_) { if (context.mounted && ModalRoute.of(context)?.isCurrent == true) Navigator.pushReplacementNamed(context, '/login', arguments: route); }); return const Scaffold(backgroundColor: page, body: Center(child: CircularProgressIndicator())); }
    if (adminOnly && !auth.user!.isAdmin) return AppShell(title: 'Partner access', child: Center(child: EmptyState(icon: Icons.lock_outline_rounded, title: 'Partner access only', message: 'Only AeroFlow partner administrators can publish journeys.', action: FilledButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false), child: const Text('Back to flights')))));
    return child;
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(36), child: Column(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 30, backgroundColor: const Color(0xffe6f4fc), child: Icon(icon, color: blue, size: 28)), const SizedBox(height: 14), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted)), if (action != null) ...[const SizedBox(height: 18), action!]]));
}

class AeroFlowMark extends StatelessWidget { const AeroFlowMark({super.key, this.light = false}); final bool light; @override Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 34, height: 34, decoration: BoxDecoration(gradient: const LinearGradient(colors: [blue, Color(0xff0057a8)]), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 20)), const SizedBox(width: 8), RichText(text: TextSpan(style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: light ? Colors.white : navy, letterSpacing: -.3), children: const [TextSpan(text: 'Aero'), TextSpan(text: 'Flow', style: TextStyle(color: blue))]))]); }

class SiteFooter extends StatelessWidget { const SiteFooter({super.key}); @override Widget build(BuildContext context) => Container(color: navy, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28), child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 16, spacing: 24, crossAxisAlignment: WrapCrossAlignment.center, children: [const AeroFlowMark(light: true), Text('© ${DateTime.now().year} AeroFlow · Fares shown in ₹ include taxes', style: const TextStyle(color: Color(0xff9aa8bd), fontSize: 12))])))); }

/// Light card with a hairline border; the base surface used across screens.
class Panel extends StatelessWidget { const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(22), this.color = Colors.white}); final Widget child; final EdgeInsets padding; final Color color; @override Widget build(BuildContext context) => Container(padding: padding, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16), border: Border.all(color: line), boxShadow: const [BoxShadow(color: Color(0x0a0b192c), blurRadius: 18, offset: Offset(0, 6))]), child: child); }

String money(double value) { final digits = value.toStringAsFixed(0); final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','); return '₹$grouped'; }
String formatDuration(Duration d) => '${d.inHours}h ${d.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
