import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AdminDestinationsPage extends StatefulWidget {
  const AdminDestinationsPage({Key? key}) : super(key: key);

  @override
  State<AdminDestinationsPage> createState() => _AdminDestinationsPageState();
}

class _AdminDestinationsPageState extends State<AdminDestinationsPage> {
  late SupabaseService _service;
  List<Map<String, dynamic>> _destinations = [];
  List<String> _availableCategories = [];
  bool _isLoading = true;
  bool _categoriesLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = SupabaseService();
    _loadDestinations();
    _loadCategories();
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getDestinations();
      setState(() {
        _destinations = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading destinations: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadCategories() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('categories')
          .select()
          .order('name', ascending: true);

      setState(() {
        _availableCategories = (response as List<dynamic>)
            .map((row) => row['name'] as String)
            .toList();
        if (_availableCategories.isEmpty) {
          _availableCategories = ['Uncategorized'];
        }
        _categoriesLoading = false;
      });
    } catch (e) {
      setState(() => _categoriesLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error loading categories: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _buildLabelAndField(String label, String hint,
      {int maxLines = 1, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF1B2559))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
            filled: true,
            fillColor: const Color(0xFFF4F7FE),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelAndDropdown(String label, List<String> items,
      {String? initialValue, required Function(String?) onChanged}) {
    String? currentValue =
        (initialValue != null && items.contains(initialValue))
            ? initialValue
            : (items.isNotEmpty ? items.first : null);

    return StatefulBuilder(
      builder: (context, setInnerState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1B2559))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: currentValue,
                  icon:
                      const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  items: items.map((String value) {
                    return DropdownMenuItem<String?>(
                      value: value,
                      child: Text(value, style: const TextStyle(fontSize: 14)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setInnerState(() => currentValue = val);
                    onChanged(val);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── ADD DESTINATION DIALOG ───────────────────────────────────────────────
  void _showAddDestinationDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final attractionsController = TextEditingController();
    final activitiesController = TextEditingController();
    final accommodationController = TextEditingController();
    final priceController = TextEditingController();
    final locationController = TextEditingController(); // ← Fixed name
    final timeController = TextEditingController();
    final imageController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();

    String? selectedCategory =
        _availableCategories.isNotEmpty ? _availableCategories.first : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Destination'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabelAndField('Destination Name', 'e.g. Tinago Falls',
                  controller: nameController),
              const SizedBox(height: 16),
              _buildLabelAndDropdown(
                'Category',
                _availableCategories,
                initialValue: selectedCategory,
                onChanged: (val) => selectedCategory = val,
              ),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Main Image URL', 'https://example.com/image.jpg',
                  controller: imageController),
              const SizedBox(height: 16),
              _buildLabelAndField('Description', 'Short description...',
                  maxLines: 3, controller: descController),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Attractions', 'e.g. Natural pool, Rock formations',
                  maxLines: 2, controller: attractionsController),
              const SizedBox(height: 16),
              _buildLabelAndField('Activities', 'e.g. Swimming, Trekking',
                  maxLines: 2, controller: activitiesController),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Nearby Accommodations', 'e.g. Homestays ₱800–₱2000',
                  maxLines: 2, controller: accommodationController),
              const SizedBox(height: 16),
              _buildLabelAndField('Price Range', '₱50 – ₱500',
                  controller: priceController),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Location', 'Cagayan de Oro City, Jasaan, etc.',
                  controller: locationController),
              const SizedBox(height: 16),
              _buildLabelAndField('Travel Time from CDO', '45 mins – 1 hour',
                  controller: timeController),
              const SizedBox(height: 24),
              const Text('Location Coordinates (Manual)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _buildLabelAndField('Latitude', 'e.g. 8.4772',
                          controller: latController)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildLabelAndField('Longitude', 'e.g. 124.6478',
                          controller: lngController)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty || selectedCategory == null) return;

              final latText = latController.text.trim();
              final lngText = lngController.text.trim();

              double? latitude =
                  latText.isNotEmpty ? double.tryParse(latText) : null;
              double? longitude =
                  lngText.isNotEmpty ? double.tryParse(lngText) : null;

              final newDest = {
                'name': name,
                'category': selectedCategory,
                'image_url': imageController.text.trim().isNotEmpty
                    ? imageController.text.trim()
                    : null,
                'description': descController.text.trim(),
                'attractions': attractionsController.text.trim(),
                'activities': activitiesController.text.trim(),
                'accommodation': accommodationController.text.trim(),
                'price_range': priceController.text.trim(),
                'location': locationController.text.trim(),
                'travel_time': timeController.text.trim(),
                'rating': 4.0,
                'status': 'active',
                'latitude': latitude,
                'longitude': longitude,
              };

              try {
                await _service.addDestination(newDest);
                await _loadDestinations();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Destination added successfully'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Failed to add: $e'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ─── EDIT DESTINATION DIALOG ──────────────────────────────────────────────
  void _showEditDestinationDialog(Map<String, dynamic> data) {
    final nameController = TextEditingController(text: data['name']);
    final descController =
        TextEditingController(text: data['description'] ?? '');
    final attractionsController =
        TextEditingController(text: data['attractions'] ?? '');
    final activitiesController =
        TextEditingController(text: data['activities'] ?? '');
    final accommodationController =
        TextEditingController(text: data['accommodation'] ?? '');
    final priceController =
        TextEditingController(text: data['price_range'] ?? '');
    final locationController =
        TextEditingController(text: data['location'] ?? '');
    final timeController =
        TextEditingController(text: data['travel_time'] ?? '');
    final imageController =
        TextEditingController(text: data['image_url'] ?? '');
    final latController =
        TextEditingController(text: data['latitude']?.toString() ?? '');
    final lngController =
        TextEditingController(text: data['longitude']?.toString() ?? '');

    String? selectedCategory = data['category'];
    if (selectedCategory == null ||
        !_availableCategories.contains(selectedCategory)) {
      selectedCategory =
          _availableCategories.isNotEmpty ? _availableCategories.first : null;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Destination'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabelAndField('Destination Name', 'e.g. Tinago Falls',
                  controller: nameController),
              const SizedBox(height: 16),
              _buildLabelAndDropdown(
                'Category',
                _availableCategories,
                initialValue: selectedCategory,
                onChanged: (val) => selectedCategory = val,
              ),
              const SizedBox(height: 16),
              _buildLabelAndField('Main Image URL', 'https://...',
                  controller: imageController),
              const SizedBox(height: 16),
              _buildLabelAndField('Description', 'Short description...',
                  maxLines: 3, controller: descController),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Attractions', 'e.g. Natural pool, Rock formations',
                  maxLines: 2, controller: attractionsController),
              const SizedBox(height: 16),
              _buildLabelAndField('Activities', 'e.g. Swimming, Trekking',
                  maxLines: 2, controller: activitiesController),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Nearby Accommodations', 'e.g. Homestays ₱800–₱2000',
                  maxLines: 2, controller: accommodationController),
              const SizedBox(height: 16),
              _buildLabelAndField('Price Range', '₱50 – ₱500',
                  controller: priceController),
              const SizedBox(height: 16),
              _buildLabelAndField(
                  'Location', 'Cagayan de Oro City, Jasaan, etc.',
                  controller: locationController),
              const SizedBox(height: 16),
              _buildLabelAndField('Travel Time from CDO', '45 mins – 1 hour',
                  controller: timeController),
              const SizedBox(height: 24),
              const Text('Location Coordinates (Manual)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _buildLabelAndField('Latitude', 'e.g. 8.4772',
                          controller: latController)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildLabelAndField('Longitude', 'e.g. 124.6478',
                          controller: lngController)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final updates = {
                'name': nameController.text.trim(),
                'category': selectedCategory,
                'image_url': imageController.text.trim(),
                'description': descController.text.trim(),
                'attractions': attractionsController.text.trim(),
                'activities': activitiesController.text.trim(),
                'accommodation': accommodationController.text.trim(),
                'price_range': priceController.text.trim(),
                'location': locationController.text.trim(),
                'travel_time': timeController.text.trim(),
                'status': data['status'] ?? 'active',
                'latitude': double.tryParse(latController.text.trim()),
                'longitude': double.tryParse(lngController.text.trim()),
              };

              try {
                await _service.updateDestination(data['id'], updates);
                await _loadDestinations();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Destination updated'),
                      backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Failed to update: $e'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ─── DELETE CONFIRMATION ──────────────────────────────────────────────────
  void _deleteDestination(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Destination'),
        content: const Text(
            'Are you sure? This will also delete any trip plans that include it.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await _service.deleteDestination(data['id']);
                await _loadDestinations();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Destination deleted'),
                      backgroundColor: Colors.orange),
                );
              } catch (e) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Cannot delete: $e\n(possibly used in user plans)'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = _destinations.where((d) {
      final name = (d['name'] ?? '').toString().toLowerCase();
      final cat = (d['category'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || cat.contains(q);
    }).toList();

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
                  _buildSearchBar(),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 5)),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildTableHeaders(),
                        const Divider(height: 30),
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(Icons.location_off,
                                    size: 80, color: Colors.grey[400]),
                                const SizedBox(height: 16),
                                Text(
                                  "No destinations yet",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Click '+' to add your first destination",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        else
                          ...filtered.map((data) => _buildDestinationRow(data)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDestinationDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Destination'),
        backgroundColor: const Color(0xFF1565FF),
      ),
    );
  }

  // ─── SIDE NAVIGATION & OTHER HELPERS (unchanged) ──────────────────────────
  Widget _buildSideNavigationBar(BuildContext context) {
    return Container(
      width: 250,
      color: const Color(0xFF111C44),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('GeoRoute Admin',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          const Text('Admin User',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 50),
          _buildSideNavItem(
              context, Icons.grid_view, 'Dashboard', '/AdminDashboard', false),
          _buildSideNavItem(
              context, Icons.place, 'Destinations', '/AdminDestinations', true),
          _buildSideNavItem(
              context, Icons.category, 'Categories', '/AdminCategories', false),
          _buildSideNavItem(
              context, Icons.people, 'Users', '/AdminUsers', false),
          _buildSideNavItem(
              context, Icons.description, 'Reports', '/AdminReports', false),
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Destination Management',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B2559))),
            SizedBox(height: 8),
            Text('Manage tourist destinations in Misamis Oriental',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _showAddDestinationDialog,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Destination'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search destination name or category...',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search, color: Colors.grey),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildTableHeaders() {
    return Row(
      children: const [
        Expanded(
            flex: 3,
            child: Text('Destination',
                style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child: Text('Category',
                style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child: Text('Location',
                style: TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
            flex: 2,
            child:
                Text('Price', style: TextStyle(fontWeight: FontWeight.bold))),
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

  Widget _buildDestinationRow(Map<String, dynamic> data) {
    final imageUrl =
        data['image_url'] as String? ?? 'https://via.placeholder.com/50';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['name'] ?? 'Unnamed',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text((data['rating'] ?? 4.0).toString(),
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
              flex: 2,
              child: Text(data['category'] ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['location'] ?? 'N/A',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(data['travel_time'] ?? 'N/A',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              data['price_range'] ?? 'N/A',
              style: const TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.green),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (data['status'] ?? 'active').toLowerCase() == 'active'
                      ? Colors.green
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  (data['status'] ?? 'active').toString().toUpperCase(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 20, color: Colors.grey),
                  onPressed: () => _showEditDestinationDialog(data),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: Colors.redAccent),
                  onPressed: () => _deleteDestination(data),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
