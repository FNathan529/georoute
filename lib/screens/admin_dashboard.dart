import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late SupabaseService _service;

  Map<String, dynamic> _stats = {
    'total_destinations': 0,
    'active_destinations': 0,
    'total_users': 0,
    'pending_users': 0,
  };

  List<Map<String, dynamic>> _recentDestinations = [];

  bool _isLoading = true;
  bool _isLoadingDestinations = false;
  String? _userRole; // To check if admin

  @override
  void initState() {
    super.initState();
    _service = SupabaseService();
    _loadUserRole();
    _loadData();
  }

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();

      setState(() {
        _userRole = profile['role'] as String?;
      });
    } catch (e) {
      debugPrint('Error loading user role: $e');
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _isLoadingDestinations = true;
    });

    try {
      final stats = await _service.getAdminStats();
      final destinations = await _service.getRecentDestinations(limit: 5);

      if (mounted) {
        setState(() {
          _stats = stats;
          _recentDestinations = destinations;
          _isLoading = false;
          _isLoadingDestinations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingDestinations = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _userRole == 'admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sidebar
          _buildSideNavigationBar(context, isAdmin: isAdmin),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview of GeoRoute system statistics',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2559),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Statistics Cards
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    _buildStatisticsCards(),

                  const SizedBox(height: 40),

                  // Recent Destinations
                  const Text(
                    'Recent Destinations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2559),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingDestinations)
                    const Center(child: CircularProgressIndicator())
                  else if (_recentDestinations.isEmpty)
                    _buildEmptyDestinations()
                  else
                    _buildRecentDestinationsList(),

                  const SizedBox(height: 40),

                  // New: Admin Onboarding Management (only visible to admins)
                  if (isAdmin) ...[
                    const Text(
                      'Content Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B2559),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildOnboardingCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  SIDEBAR – now shows/hides admin features
  // ────────────────────────────────────────────────
  Widget _buildSideNavigationBar(BuildContext context,
      {required bool isAdmin}) {
    return Container(
      width: 250,
      color: const Color(0xFF111C44),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'GeoRoute Admin',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Admin User',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 50),
          _buildSideNavItem(
              context, Icons.grid_view, 'Dashboard', '/AdminDashboard', true),
          _buildSideNavItem(context, Icons.place, 'Destinations',
              '/AdminDestinations', false),
          _buildSideNavItem(
              context, Icons.category, 'Categories', '/AdminCategories', false),
          _buildSideNavItem(
              context, Icons.people, 'Users', '/AdminUsers', false),
          _buildSideNavItem(
              context, Icons.description, 'Reports', '/AdminReports', false),
          if (isAdmin)
            _buildSideNavItem(context, Icons.slideshow, 'Onboarding Slides',
                '/admin-onboarding', false),
          const Spacer(),
          _buildSideNavItem(context, Icons.logout, 'Logout', '/', false,
              isLogout: true),
        ],
      ),
    );
  }

  Widget _buildSideNavItem(BuildContext context, IconData icon, String title,
      String routeName, bool isSelected,
      {bool isLogout = false}) {
    return GestureDetector(
      onTap: () {
        if (isLogout) {
          Navigator.pushNamedAndRemoveUntil(
              context, '/onboarding', (route) => false);
        } else if (!isSelected) {
          Navigator.pushReplacementNamed(context, routeName);
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? Colors.white : Colors.white70, size: 20),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  STATISTICS CARDS
  // ────────────────────────────────────────────────
  Widget _buildStatisticsCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Total Destinations',
            value: '${_stats['total_destinations'] ?? 0}',
            subtitle: '${_stats['active_destinations'] ?? 0} active',
            icon: Icons.place,
            iconColor: Colors.blue,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildStatCard(
            title: 'Total Users',
            value: '${_stats['total_users'] ?? 0}',
            subtitle: '${_stats['pending_users'] ?? 0} pending',
            icon: Icons.people,
            iconColor: Colors.green,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _buildStatCard(
            title: 'Pending Approvals',
            value: '${_stats['pending_users'] ?? 0}',
            subtitle: 'Waiting for review',
            icon: Icons.hourglass_empty,
            iconColor: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1B2559),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  RECENT DESTINATIONS
  // ────────────────────────────────────────────────
  Widget _buildRecentDestinationsList() {
    return Container(
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
      padding: const EdgeInsets.all(10),
      child: Column(
        children: _recentDestinations.asMap().entries.map((entry) {
          final index = entry.key;
          final dest = entry.value;

          final imageUrl = dest['image_url'] ??
              dest['image'] ??
              'https://via.placeholder.com/60';
          final title = dest['name'] ?? 'Unnamed Destination';
          final category = dest['category'] ?? 'Uncategorized';
          final status = (dest['status'] ?? 'active').toString().toLowerCase();
          final isActive = status == 'active';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B2559),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            category,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < _recentDestinations.length - 1)
                Divider(
                    height: 1,
                    color: Colors.grey[200],
                    indent: 70,
                    endIndent: 20),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyDestinations() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
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
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No destinations added yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  NEW: Onboarding Management Card (for admins)
  // ────────────────────────────────────────────────
  Widget _buildOnboardingCard() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/admin-onboarding');
      },
      child: Container(
        margin: const EdgeInsets.only(top: 20),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1565FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.slideshow,
                  color: Color(0xFF1565FF), size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Manage Onboarding Slides',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2559),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Edit welcome screen images & text',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFF1565FF)),
          ],
        ),
      ),
    );
  }
}
