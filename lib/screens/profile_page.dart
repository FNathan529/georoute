import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // for offline check

import '../services/supabase_service.dart';
import 'home_page.dart'; // if needed for navigation

// Helper: Check internet (reuse from before)
Future<bool> isConnected() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  } catch (_) {
    return false;
  }
}

class ProfilePage extends StatefulWidget {
  final String? currentUserId; // ← Changed to nullable (guest support)

  const ProfilePage({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final SupabaseService _service = SupabaseService();
  final supabase = Supabase.instance.client;

  String _userName = 'Loading...';
  String _userEmail = 'Loading...';
  int _visitedCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Guest check - skip loading
    if (widget.currentUserId == null) {
      setState(() {
        _userName = 'Guest';
        _userEmail = 'Not logged in';
        _visitedCount = 0;
        _isLoading = false;
      });
    } else {
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    if (widget.currentUserId == null || !mounted) return;

    setState(() => _isLoading = true);

    // Check internet first
    if (!await isConnected()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("No internet connection. Profile data may be outdated."),
            duration: Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          _userName = 'Not logged in';
          _userEmail = 'Guest mode';
          _isLoading = false;
        });
        return;
      }

      // Fetch profile
      final profileResponse = await supabase
          .from('users')
          .select('full_name, email')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      // Count visited places
      final countResult = await supabase
          .from('travel_history')
          .select('count')
          .eq('user_id', user.id)
          .count(CountOption.exact)
          .timeout(const Duration(seconds: 6));

      if (mounted) {
        setState(() {
          final profile = profileResponse ?? {};
          _userName = profile['full_name'] ?? 'User';
          _userEmail = user.email ?? profile['email'] ?? 'No email';
          _visitedCount = countResult.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Profile fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Couldn't load profile right now. Try again later."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchUserData();
  }

  void _showEditProfileDialog() {
    if (widget.currentUserId == null) return;

    final nameController = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Profile"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Full Name",
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'More preferences and avatar support coming soon...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isEmpty || newName == _userName) return;

              try {
                final user = supabase.auth.currentUser;
                await supabase
                    .from('users')
                    .update({'full_name': newName}).eq('id', user!.id);

                if (mounted) {
                  setState(() => _userName = newName);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Name updated successfully!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Couldn't update name. Try again."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // close dialog
              try {
                await supabase.auth.signOut();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/', // back to onboarding
                    (route) => false,
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Logout failed. Try again."),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guest mode: friendly sign-in screen
    if (widget.currentUserId == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FE),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 100, color: Colors.blueGrey),
                const SizedBox(height: 24),
                const Text(
                  "Welcome, Traveler!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565FF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Sign in to access your profile, view your visited places, update your name, and save your travel preferences.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("Sign In / Register"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Continue browsing as guest"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Logged-in user UI
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header with gradient
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.only(bottom: 60),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1565FF), Color(0xFF651FFF)],
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(30),
                              bottomRight: Radius.circular(30),
                            ),
                          ),
                          child: SafeArea(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 40),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.grey[200],
                                    child: const Icon(Icons.person,
                                        size: 40, color: Color(0xFF651FFF)),
                                  ),
                                  const SizedBox(width: 15),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _userName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          _userEmail,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Floating stats
                        Positioned(
                          bottom: -40,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem(Icons.location_on_outlined,
                                    '$_visitedCount', 'Visited', Colors.blue),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[200]),
                                _buildStatItem(Icons.favorite_border, '5',
                                    'Favorites', const Color(0xFF651FFF)),
                                Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[200]),
                                _buildStatItem(Icons.verified_outlined, '3',
                                    'Badges', Colors.green),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Stats section (optional duplicate)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Your Stats',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1B2559),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatItem(
                                        Icons.location_on,
                                        '$_visitedCount',
                                        'Visited',
                                        Colors.blue),
                                    _buildStatItem(Icons.favorite_border, '5',
                                        'Favorites', const Color(0xFF651FFF)),
                                    _buildStatItem(Icons.verified, '3',
                                        'Badges', Colors.green),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Preferences placeholder
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.favorite_border,
                                        color: Color(0xFF5E35B1)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Travel Preferences',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1B2559),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 15),
                                const Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    Chip(
                                        label: Text('Beach'),
                                        backgroundColor: Color(0xFFEDE7F6)),
                                    Chip(
                                        label: Text('Mountain'),
                                        backgroundColor: Color(0xFFEDE7F6)),
                                    Chip(
                                        label: Text('Waterfall'),
                                        backgroundColor: Color(0xFFEDE7F6)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Settings list
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.settings_outlined,
                                          color: Color(0xFF5E35B1)),
                                      SizedBox(width: 8),
                                      Text(
                                        'Settings',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1B2559),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                  Icons.person_outline,
                                  'Edit Profile',
                                  onTap: _showEditProfileDialog,
                                ),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                  Icons.favorite_border,
                                  'Manage Preferences',
                                  onTap: () {},
                                ),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                  Icons.location_on,
                                  'Location Settings',
                                  onTap: () {},
                                ),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                  Icons.logout,
                                  'Log Out',
                                  onTap: _handleLogout,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1B2559),
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title,
      {required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.grey[700], size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.grey[800],
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
