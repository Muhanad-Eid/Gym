import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gym/home.dart';
import 'package:gym/subscribers.dart';
import 'sign_in.dart';
import 'subscriptions.dart';
import 'schedule.dart';
import 'reservation.dart';
import 'reports.dart';
import 'trainers.dart';
import 'sign_up.dart';
import 'forgot_password.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://hjrntlhdobaewwnenojz.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhqcm50bGhkb2JhZXd3bmVub2p6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE2NDY0NTQsImV4cCI6MjA3NzIyMjQ1NH0.Uo8zMy_ChbOtJzfnmaKcooadg3rkhmsDztCCfnBQU3E', 
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.deepPurple,
        primaryColor: Colors.deepPurple,
        fontFamily: 'Roboto',
        
        // AppBar Theme - This ensures all AppBars are purple with white text
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent, // CRITICAL: Fixes Material 3 tinting
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
          actionsIconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Roboto',
          ),
        ),
        
        // Floating Action Button Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
        ),
        
        // Card Theme
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        
        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
          ),
        ),
        
        // Elevated Button Theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
        
        // Color Scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          primary: Colors.deepPurple,
          secondary: Colors.deepPurpleAccent,
        ),
      ),
      home: const SignIn(),
      routes: {
        '/subscribers': (context) => const SubscribersPage(),
        '/sign_in': (context) => const SignIn(),
        '/home': (context) => const GymHomePage(),
        '/subscriptions': (context) => const SubscriptionsPlansPage(),
        '/schedule': (context) => const SchedulePage(),
        '/reservation': (context) => const ReservationPage(),
        '/reports': (context) => const ReportsPage(),
        '/trainers': (context) => const TrainersPage(),
        '/sign_up': (context) => const SignUp(),
        '/forgot_password': (context) => const ForgotPassword(),
      },
    );
  }
}