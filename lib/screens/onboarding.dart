import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase (make sure you have this in your real app)
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_ANON_KEY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoRoute',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 63, 51, 229),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const OnboardingPage(),
      routes: {
        '/login': (context) =>
            const Scaffold(body: Center(child: Text("Login Page"))),
        // Add '/admin-onboarding' route later when you build the editor
      },
    );
  }
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentPage = 0;
  late Timer _timer;
  List<Map<String, dynamic>> _slides = [];
  bool _isLoading = true;

  // Fallback images (your originals) in case Supabase fetch fails
  final List<String> _fallbackImages = [
    'https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1519681393784-d120267933ba?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
    'https://images.unsplash.com/photo-1518098268026-4e266b1f3d3e?ixlib=rb-4.0.3&auto=format&fit=crop&w=1200&q=80',
  ];
  @override
  void initState() {
    super.initState();
    _fetchOnboardingSlides();

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _slides.isNotEmpty) {
        setState(() {
          _currentPage = (_currentPage + 1) % _slides.length;
        });
      }
    });
  }

  Future<void> _fetchOnboardingSlides() async {
    try {
      final response = await Supabase.instance.client
          .from('onboarding_slides')
          .select()
          .eq('is_active', true)
          .order('slide_order', ascending: true);

      if (mounted) {
        setState(() {
          _slides = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching onboarding slides: $e');
      setState(() {
        // Fallback to hardcoded images
        _slides = _fallbackImages
            .asMap()
            .entries
            .map((e) => {'slide_order': e.key + 1, 'image_url': e.value})
            .toList();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color deepBlue = Color.fromARGB(255, 37, 26, 192);
    const Color vibrantBlue = Color.fromARGB(255, 63, 51, 229);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final currentSlide = _slides.isNotEmpty ? _slides[_currentPage] : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Dynamic background slideshow
          SizedBox.expand(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 1500),
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                return Stack(
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                  fit: StackFit.expand,
                );
              },
              child: Image.network(
                currentSlide?['image_url'] as String? ??
                    'https://via.placeholder.com/800x1200?text=GeoRoute',
                key: ValueKey<int>(_currentPage),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                color: Colors.black.withOpacity(0.2),
                colorBlendMode: BlendMode.darken,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 60),

                // Logo
                SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        'Georoute',
                        style: GoogleFonts.playfairDisplay(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 85,
                            fontWeight: FontWeight
                                .bold, // or w700/w900 for extra impact
                            letterSpacing: -1.5,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 75,
                        top: 10,
                        child: Transform.rotate(
                          angle: -0.2,
                          child: const Icon(
                            Icons.airplanemode_active,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Explore Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 90),
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [vibrantBlue, deepBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: deepBlue.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HomePage(currentUserId: null),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Explore Now',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Branding
                Column(
                  children: [
                    Text(
                      'amazing',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Text(
                      'MISAMIS ORIENTAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    CustomPaint(
                      size: const Size(40, 10),
                      painter: SmilePainter(),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    var path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width / 2, size.height * 1.5, size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}