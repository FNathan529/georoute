import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart'; // Adjust path if needed

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

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
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('No authenticated user found');
        if (mounted) {
          setState(() {
            _userName = 'Guest';
            _userEmail = 'Not logged in';
            _isLoading = false;
          });
        }
        return;
      }
      print('Loading profile for user: ${user.id} (${user.email})');
      // Fetch profile (no avatar_url column)
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
      print('Profile fetch error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load profile: $e')),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    await _fetchUserData();
  }

  void _showEditProfileDialog() {
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
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
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
                        backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Update failed: $e')),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // ─── Logout now goes directly to onboarding ─────────────────────
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
                // Sign out from Supabase (this clears the session)
                await supabase.auth.signOut();
                // Navigate to onboarding (root route '/')
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                      context, '/', (route) => false);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logout failed: $e'),
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
                    // Header with gradient background
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
                              colors: [Color(0xFF651FFF), Color(0xFF4527A0)],
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
                        // Floating stats card
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
                          // Stats Card (duplicate for visual balance - optional)
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
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Your Stats',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1B2559)),
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
                                    offset: const Offset(0, 4)),
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
                                          color: Color(0xFF1B2559)),
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
                                    offset: const Offset(0, 4)),
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
                                            color: Color(0xFF1B2559)),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                    Icons.person_outline, 'Edit Profile',
                                    onTap: _showEditProfileDialog),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                    Icons.favorite_border, 'Manage Preferences',
                                    onTap: () {}),
                                const Divider(height: 1),
                                _buildSettingsItem(
                                    Icons.location_on, 'Location Settings',
                                    onTap: () {}),
                                const Divider(height: 1),
                                _buildSettingsItem(Icons.logout, 'Log Out',
                                    onTap: _handleLogout),
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
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF1B2559))),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title,
      {required VoidCallback onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration:
            BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
        child: Icon(icon, color: Colors.grey[700], size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 15)),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}
