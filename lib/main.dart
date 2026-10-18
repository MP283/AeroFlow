import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/auth_controller.dart';
import 'controllers/flight_controller.dart';
import 'controllers/reports_controller.dart';
import 'data/api_flight_repository.dart';
import 'screens/account_screen.dart';
import 'screens/auth_screens.dart';
import 'screens/enlist_flight_screen.dart';
import 'screens/flight_search_screen.dart';
import 'widgets/app_shell.dart';

void main() {
  final repository = ApiFlightRepository();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AuthController(repository)..restore()),
    ChangeNotifierProvider(create: (_) => FlightController(repository)..load()),
    ChangeNotifierProvider(create: (_) => ReportsController(repository)),
  ], child: const AeroFlowApp()));
}

class AeroFlowApp extends StatelessWidget {
  const AeroFlowApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AeroFlow', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: blue, primary: blue, brightness: Brightness.light), scaffoldBackgroundColor: page,
      textTheme: Typography.blackMountainView.apply(bodyColor: navy, displayColor: navy),
      cardTheme: CardThemeData(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: line))),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: blue, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), textStyle: const TextStyle(fontWeight: FontWeight.w800))),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: navy, side: const BorderSide(color: line), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: const Color(0xfffafbfd), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: line)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: blue, width: 1.6)), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16)),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: navy)),
    initialRoute: '/',
    onGenerateRoute: (settings) => MaterialPageRoute(settings: settings, builder: (_) => switch (settings.name) {
      '/login' => LoginScreen(redirect: settings.arguments as String?),
      '/signup' => SignupScreen(redirect: settings.arguments as String?),
      '/account' => const RequireAuth(route: '/account', child: AccountScreen()),
      '/enlist' => const RequireAuth(route: '/enlist', adminOnly: true, child: EnlistFlightScreen()),
      _ => const FlightSearchScreen(),
    }),
  );
}
