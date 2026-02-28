import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({Key? key}) : super(key: key);

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late SupabaseService _service;
  late String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';

  final List<String> _sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Role (Admin First)',
    'Status (Pending First)',
  ];

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _service = SupabaseService();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await _service.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading users: $e')),
      );
    }
  }

  Future<void> _updateUserStatus(String userId, String newStatus) async {
    try {
      await _service.updateUserStatus(userId, newStatus);
      await _loadUsers(); // Auto-refresh the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User status updated to $newStatus'),
          backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter users
    List<Map<String, dynamic>> displayedUsers = _users.where((user) {
      final name = (user['full_name'] as String?)?.toLowerCase() ?? '';
      final email = (user['email'] as String?)?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    // Sort users
    displayedUsers.sort((a, b) {
      switch (_sortOption) {
        case 'Name (A-Z)':
          return (a['full_name'] as String? ?? '')
              .compareTo(b['full_name'] as String? ?? '');
        case 'Name (Z-A)':
          return (b['full_name'] as String? ?? '')
              .compareTo(a['full_name'] as String? ?? '');
        case 'Role (Admin First)':
          final roleA = a['role'] as String? ?? 'tourist';
          final roleB = b['role'] as String? ?? 'tourist';
          return roleA.compareTo(roleB);
        case 'Status (Pending First)':
          final statusOrder = {'pending': 0, 'approved': 1, 'rejected': 2};
          final statusA =
              statusOrder[a['registration_status'] ?? 'pending'] ?? 3;
          final statusB =
              statusOrder[b['registration_status'] ?? 'pending'] ?? 3;
          return statusA.compareTo(statusB);
        default:
          return 0;
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSideNavigationBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(child: _buildSearchBar()),
                      const SizedBox(width: 15),
                      _buildSortDropdown(),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTableHeaders(),
                        const Divider(height: 30),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (displayedUsers.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: Text('No users found')),
                          )
                        else
                          ...displayedUsers.map((user) => _buildUserRow(user)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  SIDEBAR
  // ────────────────────────────────────────────────
  Widget _buildSideNavigationBar(BuildContext context) {
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
              context, Icons.grid_view, 'Dashboard', '/AdminDashboard', false),
          _buildSideNavItem(context, Icons.place, 'Destinations',
              '/AdminDestinations', false),
          _buildSideNavItem(
              context, Icons.category, 'Categories', '/AdminCategories', false),
          _buildSideNavItem(
              context, Icons.people, 'Users', '/AdminUsers', true),
          _buildSideNavItem(
              context, Icons.description, 'Reports', '/AdminReports', false),
          const Spacer(),
                      _buildSideNavItem(context, Icons.slideshow, 'Onboarding Slides',
                '/admin-onboarding', false),
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
  //  HEADER
  // ────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'User Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B2559),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Manage registered users and approve/reject access',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────
  //  SEARCH BAR
  // ────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search by name or email...',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  SORT DROPDOWN
  // ────────────────────────────────────────────────
  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButton<String>(
        value: _sortOption,
        icon: const Icon(Icons.sort, color: Colors.grey),
        underline: const SizedBox(),
        items: _sortOptions.map((String value) {
          return DropdownMenuItem<String>(value: value, child: Text(value));
        }).toList(),
        onChanged: (newValue) {
          if (newValue != null) setState(() => _sortOption = newValue);
        },
      ),
    );
  }

  // ────────────────────────────────────────────────
  //  TABLE HEADERS
  // ────────────────────────────────────────────────
  Widget _buildTableHeaders() {
    return Row(
      children: const [
        Expanded(
            flex: 2,
            child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 3,
            child:
                Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child: Text('Join Date',
                style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child: Center(
                child: Text('Status',
                    style: TextStyle(fontWeight: FontWeight.bold)))),
        Expanded(
            flex: 1,
            child: Center(
                child: Text('Actions',
                    style: TextStyle(fontWeight: FontWeight.bold)))),
      ],
    );
  }

  // ────────────────────────────────────────────────
  //  USER ROW (with Approve/Reject buttons)
  // ────────────────────────────────────────────────
  Widget _buildUserRow(Map<String, dynamic> user) {
    final status = user['registration_status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final isApproved = status == 'approved';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              user['full_name'] as String? ?? 'No name',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              user['email'] as String? ?? 'No email',
              style: const TextStyle(color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user['role'] as String? ?? 'tourist',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              user['created_at'] != null
                  ? (user['created_at'] as String).split('T')[0]
                  : 'N/A',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isApproved
                      ? Colors.green
                      : status == 'rejected'
                          ? Colors.red
                          : Colors.orange,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: isPending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          tooltip: 'Approve',
                          onPressed: () =>
                              _updateUserStatus(user['id'], 'approved'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          tooltip: 'Reject',
                          onPressed: () =>
                              _updateUserStatus(user['id'], 'rejected'),
                        ),
                      ],
                    )
                  : const Icon(Icons.check_circle, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
