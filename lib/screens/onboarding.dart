import 'package:flutter/material.dart';

class OnboardingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 1. FULLSCREEN GRADIENT
    final gradient = LinearGradient(
      colors: [Color.fromARGB(255, 47, 19, 207), Color(0xFF1976D2)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: gradient),
        // 2. CENTER & CONSTRAIN
        // We use Center so the "mobile view" sits in the middle of a web monitor
        child: Center(
          child: ConstrainedBox(
            // 3. MAX WIDTH LIMIT
            // 500-600 is a standard "Mobile" width.
            // On phones, this does nothing. On Web, it stops stretching.
            constraints: BoxConstraints(maxWidth: 500),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                child: Column(
                  children: [
                    // SPACER: Pushes the logo down slightly
                    Spacer(flex: 1),

                    // Header Section (Logo & Text)
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.place,
                          size: 44, color: Color.fromARGB(255, 33, 144, 255)),
                    ),
                    SizedBox(height: 24),
                    Text('GeoRoute',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 12),
                    Text(
                      'Your Local Travel Companion\nDiscover Misamis Oriental',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),

                    // SPACER: Creates gap between Header and Features
                    Spacer(flex: 2),

                    // Feature Tiles
                    _FeatureTile(
                      icon: Icon(
                        Icons.explore, // Switched to Icon for easier testing
                        color: Color(0xFF1976D2),
                        size: 22,
                      ),
                      title: 'Discover Gems',
                      subtitle:
                          'Explore amazing destinations\nAcross Misamis Oriental',
                    ),
                    SizedBox(height: 16),
                    _FeatureTile(
                      icon: Icon(Icons.map, color: Color(0xFF1976D2), size: 22),
                      title: 'Plan Your Journey',
                      subtitle: 'Create routes effortlessly',
                    ),
                    SizedBox(height: 16),
                    _FeatureTile(
                      icon: Icon(Icons.bookmark,
                          color: Color(0xFF1976D2), size: 22),
                      title: 'Save Favorites',
                      subtitle: 'Bookmark places & share\nwith friends',
                    ),

                    // SPACER: Pushes button to bottom
                    Spacer(flex: 3),

                    // Get Started Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color.fromARGB(255, 37, 26, 192),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                        ),
                        child: Text('Get Started',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                      ),
                    ),

                    // Small gap at the very bottom
                    SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final Widget icon;
  final String title;
  final String subtitle;
  const _FeatureTile(
      {required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12)),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: Colors.white, radius: 20, child: icon),
          SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: 4),
              Text(subtitle,
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
        ],
      ),
    );
  }
}
