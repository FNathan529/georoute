import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/admin_onboarding_editor.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your screens
import 'screens/onboarding.dart';
import 'screens/login.dart';
import 'screens/home_page.dart';
import 'screens/admin_dashboard.dart';
import 'screens/admin_destination.dart';
import 'screens/admin_categories.dart';
import 'screens/admin_users.dart';
import 'screens/admin_reports.dart';
import 'screens/admin_onboarding_editor.dart';
import 'screens/register.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xrecadjyvgjuskjdxbbo.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhyZWNhZGp5dmdqdXNramR4YmJvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAyOTU0MzUsImV4cCI6MjA4NTg3MTQzNX0.pLqBvF9Jq3s3MddVs97oguax0Wq74Y8i18aT8MSk83M',
  );

  runApp(const GeoRouteApp());
}

class GeoRouteApp extends StatefulWidget {
  const GeoRouteApp({super.key});

  @override
  State<GeoRouteApp> createState() => _GeoRouteAppState();
}

class _GeoRouteAppState extends State<GeoRouteApp> {
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // Listen for auth changes and redirect
    supabase.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (!mounted) return;

      if (event == AuthChangeEvent.signedIn) {
        print('Auth signed in → redirecting to home');
        Navigator.pushReplacementNamed(context, '/home');
      } else if (event == AuthChangeEvent.signedOut) {
        print('Auth signed out → going to onboarding');
        Navigator.pushReplacementNamed(context, '/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoRoute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF1565FF),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: const Color(0xFF2D7CFF)),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.grey[50],
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      // Use FutureBuilder instead of initialRoute to avoid flicker
      home: FutureBuilder<void>(
        future: _initializeApp(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show a splash/loading screen while checking session
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          } else {
            // Decide which page to show based on session
            final session = supabase.auth.currentSession;
            return session != null
                ? HomePage(currentUserId: session.user.id)
                : OnboardingPage();
          }
        },
      ),
      routes: {
        '/login': (context) => const LoginPage(),
        '/admin-onboarding': (context) => const AdminOnboardingEditor(),
        '/onboarding': (context) => OnboardingPage(),
        '/home': (context) => HomePage(
              currentUserId: supabase.auth.currentUser?.id ?? '',
            ),
        '/register': (context) => const RegisterPage(),
        '/AdminDashboard': (context) => const AdminDashboard(),
        '/AdminDestinations': (context) => const AdminDestinationsPage(),
        '/AdminCategories': (context) => const AdminCategoriesPage(),
        '/AdminUsers': (context) => const AdminUsersPage(),
        '/AdminReports': (context) => const AdminReportsPage(),
      },
    );
  }

  Future<void> _initializeApp() async {
    // Optional: any initialization logic, e.g., fetching user profile
    await Future.delayed(const Duration(milliseconds: 500)); // simulate load
  }
}
