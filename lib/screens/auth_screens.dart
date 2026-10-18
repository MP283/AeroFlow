import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_controller.dart';
import '../widgets/app_shell.dart';

final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
String? _required(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;
String? _validEmail(String? v) => _email.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address';

/// Login form. With [popOnSuccess] it pops `true` (used mid-booking); otherwise it navigates to [redirect] or home.
class LoginScreen extends StatefulWidget { const LoginScreen({super.key, this.redirect, this.popOnSuccess = false}); final String? redirect; final bool popOnSuccess; @override State<LoginScreen> createState() => _LoginScreenState(); }
class _LoginScreenState extends State<LoginScreen> {
  final key = GlobalKey<FormState>(); final email = TextEditingController(); final password = TextEditingController(); bool busy = false, hidden = true; String? error;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => _AuthLayout(title: 'Log in', heading: 'Welcome back', subheading: widget.popOnSuccess ? 'Log in to finish booking your seats.' : 'Log in to manage your trips and book faster.', form: Form(key: key, child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (error != null) _ErrorBanner(error!),
    TextFormField(controller: email, autofocus: true, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)), validator: _validEmail), const SizedBox(height: 14),
    TextFormField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.password], onFieldSubmitted: (_) => _submit(), decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: _required), const SizedBox(height: 22),
    FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Log in')), const SizedBox(height: 18),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('New to AeroFlow?', style: TextStyle(color: muted)), TextButton(onPressed: _toSignup, child: const Text('Create an account', style: TextStyle(fontWeight: FontWeight.w800)))]),
  ]))));
  Future<void> _submit() async { if (busy || !(key.currentState?.validate() ?? false)) return; setState(() { busy = true; error = null; }); try { await context.read<AuthController>().login(email: email.text.trim(), password: password.text); if (mounted) _finish(context, widget.popOnSuccess, widget.redirect); } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); } finally { if (mounted) setState(() => busy = false); } }
  Future<void> _toSignup() async { final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => SignupScreen(redirect: widget.redirect, popOnSuccess: true, fromLogin: true))); if (done == true && mounted) _finish(context, widget.popOnSuccess, widget.redirect); }
}

class SignupScreen extends StatefulWidget { const SignupScreen({super.key, this.redirect, this.popOnSuccess = false, this.fromLogin = false}); final String? redirect; final bool popOnSuccess, fromLogin; @override State<SignupScreen> createState() => _SignupScreenState(); }
class _SignupScreenState extends State<SignupScreen> {
  final key = GlobalKey<FormState>(); final name = TextEditingController(); final email = TextEditingController(); final phone = TextEditingController(); final password = TextEditingController(); final confirm = TextEditingController(); bool busy = false, hidden = true; String? error;
  @override void dispose() { for (final c in [name, email, phone, password, confirm]) { c.dispose(); } super.dispose(); }
  @override Widget build(BuildContext context) => _AuthLayout(title: 'Sign up', heading: 'Create your account', subheading: 'Save your details, see every trip in one place and check out in seconds.', form: Form(key: key, child: AutofillGroup(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (error != null) _ErrorBanner(error!),
    TextFormField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, autofillHints: const [AutofillHints.name], decoration: const InputDecoration(labelText: 'Full name (as on ID)', prefixIcon: Icon(Icons.badge_outlined)), validator: _required), const SizedBox(height: 14),
    TextFormField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.email], decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.mail_outline)), validator: _validEmail), const SizedBox(height: 14),
    TextFormField(controller: phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.telephoneNumber], decoration: const InputDecoration(labelText: 'Mobile number', prefixIcon: Icon(Icons.phone_outlined)), validator: (v) => (v?.trim().length ?? 0) < 6 ? 'Enter a valid phone number' : null), const SizedBox(height: 14),
    TextFormField(controller: password, obscureText: hidden, autofillHints: const [AutofillHints.newPassword], decoration: InputDecoration(labelText: 'Password', helperText: 'At least 8 characters', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(onPressed: () => setState(() => hidden = !hidden), icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined))), validator: (v) => (v?.length ?? 0) < 8 ? 'Use at least 8 characters' : null), const SizedBox(height: 14),
    TextFormField(controller: confirm, obscureText: hidden, onFieldSubmitted: (_) => _submit(), decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline)), validator: (v) => v != password.text ? 'Passwords do not match' : null), const SizedBox(height: 22),
    FilledButton(onPressed: busy ? null : _submit, child: busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Create account')), const SizedBox(height: 18),
    Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text('Already have an account?', style: TextStyle(color: muted)), TextButton(onPressed: () => widget.fromLogin ? Navigator.pop(context) : Navigator.pushReplacementNamed(context, '/login', arguments: widget.redirect), child: const Text('Log in', style: TextStyle(fontWeight: FontWeight.w800)))]),
  ]))));
  Future<void> _submit() async { if (busy || !(key.currentState?.validate() ?? false)) return; setState(() { busy = true; error = null; }); try { await context.read<AuthController>().signup(fullName: name.text.trim(), email: email.text.trim(), phone: phone.text.trim(), password: password.text); if (mounted) _finish(context, widget.popOnSuccess, widget.redirect); } catch (e) { if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', '')); } finally { if (mounted) setState(() => busy = false); } }
}

void _finish(BuildContext context, bool popOnSuccess, String? redirect) => popOnSuccess ? Navigator.pop(context, true) : Navigator.pushNamedAndRemoveUntil(context, redirect ?? '/', (_) => false);

class _AuthLayout extends StatelessWidget {
  const _AuthLayout({required this.title, required this.heading, required this.subheading, required this.form});
  final String title, heading, subheading;
  final Widget form;
  @override Widget build(BuildContext context) => AppShell(title: title, padded: false, child: LayoutBuilder(builder: (context, c) { final wide = c.maxWidth > 900; final card = Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Panel(padding: const EdgeInsets.all(32), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(heading, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: navy)), const SizedBox(height: 6), Text(subheading, style: const TextStyle(color: muted)), const SizedBox(height: 26), form]))))); return wide ? Row(children: [const Expanded(child: _Hero()), Expanded(child: card)]) : card; }));
}

class _Hero extends StatelessWidget {
  const _Hero();
  @override Widget build(BuildContext context) => Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navy, Color(0xff0a3a66), blue])), padding: const EdgeInsets.all(56), child: Stack(children: [
    const Positioned(right: -40, top: 40, child: Icon(Icons.flight_rounded, size: 260, color: Color(0x14ffffff))),
    Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Your next journey\nstarts here.', style: TextStyle(color: Colors.white, fontSize: 40, height: 1.15, fontWeight: FontWeight.w800)), const SizedBox(height: 16),
      const Text('Book flights across India and beyond with live seat maps and instant e-tickets.', style: TextStyle(color: Color(0xffc9d6ea), fontSize: 16)), const SizedBox(height: 32),
      for (final (icon, text) in const [(Icons.event_seat_rounded, 'Pick window or aisle on a live seat map'), (Icons.receipt_long_rounded, 'All your bookings and e-tickets in one place'), (Icons.bolt_rounded, 'Saved details for one-tap checkout')]) Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(children: [CircleAvatar(radius: 16, backgroundColor: const Color(0x26ffffff), child: Icon(icon, size: 17, color: Colors.white)), const SizedBox(width: 12), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))])),
    ]),
  ]));
}

class _ErrorBanner extends StatelessWidget { const _ErrorBanner(this.message); final String message; @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xfffff1f0), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xffffccc7))), child: Row(children: [const Icon(Icons.error_outline, color: Color(0xffd92d20), size: 20), const SizedBox(width: 10), Expanded(child: Text(message, style: const TextStyle(color: Color(0xffb42318), fontWeight: FontWeight.w600)))])); }
