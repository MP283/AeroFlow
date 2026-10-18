import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../models/models.dart';
import '../widgets/app_shell.dart';
import 'checkout_screen.dart';

class AccountScreen extends StatefulWidget { const AccountScreen({super.key}); @override State<AccountScreen> createState() => _AccountScreenState(); }
class _AccountScreenState extends State<AccountScreen> {
  @override void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.read<AuthController>().loadBookings(); }); }
  @override Widget build(BuildContext context) {
    final auth = context.watch<AuthController>(); final user = auth.user; if (user == null) return const SizedBox.shrink();
    final upcoming = auth.upcoming, past = auth.past;
    return AppShell(title: 'My account', child: DefaultTabController(length: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navy, Color(0xff0a3a66), blue])), child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 18, spacing: 18, children: [
        Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 32, backgroundColor: Colors.white, child: Text(user.initials, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: navy))), const SizedBox(width: 16), Flexible(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.fullName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)), Text('${user.email} · ${user.phone}', style: const TextStyle(color: Color(0xffc9d6ea))), if (user.isAdmin) Container(margin: const EdgeInsets.only(top: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0x33ffffff), borderRadius: BorderRadius.circular(20)), child: const Text('PARTNER ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)))]))]),
        Row(mainAxisSize: MainAxisSize.min, children: [_stat('${upcoming.length}', 'Upcoming'), const SizedBox(width: 12), _stat('${past.length}', 'Completed'), const SizedBox(width: 12), _stat('${upcoming.length + past.length}', 'Total trips')]),
      ])), const SizedBox(height: 16),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: line)), child: TabBar(labelColor: navy, unselectedLabelColor: muted, indicatorColor: blue, indicatorWeight: 3, dividerColor: Colors.transparent, labelStyle: const TextStyle(fontWeight: FontWeight.w800), tabs: [Tab(icon: const Icon(Icons.flight_takeoff_rounded), text: 'Upcoming flights (${upcoming.length})'), Tab(icon: const Icon(Icons.history_rounded), text: 'Past bookings (${past.length})'), const Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Profile & security')])), const SizedBox(height: 16),
      Expanded(child: TabBarView(children: [_trips(auth, upcoming, false), _trips(auth, past, true), const SingleChildScrollView(child: _ProfileForm())])),
    ])));
  }
  Widget _stat(String value, String label) => Container(width: 88, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: const Color(0x1fffffff), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: Color(0xffc9d6ea), fontSize: 12))]));
  Widget _trips(AuthController auth, List<Booking> bookings, bool past) {
    if (auth.loadingBookings && bookings.isEmpty) return const Center(child: CircularProgressIndicator());
    if (auth.bookingsError != null) return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load your trips', message: auth.bookingsError!, action: OutlinedButton(onPressed: auth.loadBookings, child: const Text('Try again'))));
    if (bookings.isEmpty) return Center(child: EmptyState(icon: past ? Icons.history_rounded : Icons.luggage_rounded, title: past ? 'No past trips yet' : 'No upcoming flights', message: past ? 'Flights you have taken will appear here.' : 'Book a flight and your e-ticket will show up here.', action: past ? null : FilledButton.icon(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false), icon: const Icon(Icons.search_rounded), label: const Text('Search flights'))));
    return RefreshIndicator(onRefresh: auth.loadBookings, child: ListView.separated(padding: const EdgeInsets.only(bottom: 24), itemCount: bookings.length, separatorBuilder: (_, __) => const SizedBox(height: 18), itemBuilder: (_, i) => Align(alignment: Alignment.topCenter, child: ETicket(booking: bookings[i], past: past))));
  }
}

class _ProfileForm extends StatefulWidget { const _ProfileForm(); @override State<_ProfileForm> createState() => _ProfileFormState(); }
class _ProfileFormState extends State<_ProfileForm> {
  final key = GlobalKey<FormState>(); late final TextEditingController name, email, phone; final current = TextEditingController(), next = TextEditingController(), confirm = TextEditingController(); bool saving = false;
  @override void initState() { super.initState(); final u = context.read<AuthController>().user!; name = TextEditingController(text: u.fullName); email = TextEditingController(text: u.email); phone = TextEditingController(text: u.phone); }
  @override void dispose() { for (final c in [name, email, phone, current, next, confirm]) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: Form(key: key, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Personal details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const Text('Used to prefill checkout. Keep your name exactly as on your ID.', style: TextStyle(color: muted, fontSize: 13)), const SizedBox(height: 18),
      TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null), const SizedBox(height: 14),
      TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)), validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address'), const SizedBox(height: 14),
      TextFormField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)), validator: (v) => (v?.trim().length ?? 0) < 6 ? 'Enter a valid phone number' : null),
    ])), const SizedBox(height: 16),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Change password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const Text('Leave blank to keep your current password.', style: TextStyle(color: muted, fontSize: 13)), const SizedBox(height: 18),
      TextFormField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Current password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => next.text.isNotEmpty && (v?.isEmpty ?? true) ? 'Enter your current password' : null), const SizedBox(height: 14),
      TextFormField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'New password', prefixIcon: Icon(Icons.lock_reset_rounded)), validator: (v) => (v?.isNotEmpty ?? false) && v!.length < 8 ? 'Use at least 8 characters' : null), const SizedBox(height: 14),
      TextFormField(controller: confirm, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password', prefixIcon: Icon(Icons.lock_reset_rounded)), validator: (v) => v != next.text ? 'Passwords do not match' : null),
    ])), const SizedBox(height: 18),
    Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: saving ? null : _save, icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_outlined), label: const Text('Save changes'))), const SizedBox(height: 24),
  ]))));
  Future<void> _save() async {
    if (saving || !(key.currentState?.validate() ?? false)) return; setState(() => saving = true); final messenger = ScaffoldMessenger.of(context);
    try { await context.read<AuthController>().updateProfile(fullName: name.text.trim(), email: email.text.trim(), phone: phone.text.trim(), currentPassword: current.text, newPassword: next.text); for (final c in [current, next, confirm]) { c.clear(); } messenger.showSnackBar(const SnackBar(content: Text('Your details have been updated.'))); }
    catch (e) { messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')))); }
    finally { if (mounted) setState(() => saving = false); }
  }
}
