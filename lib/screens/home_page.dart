import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../utils/distance_calculator.dart';
import 'destination_detail.dart';
import 'history_page.dart';
import 'map_page.dart';
import 'bucket_list_page.dart';
import 'profile_page.dart';

// ────────────────────────────────────────────────
//   Helper: require login for protected features
// ────────────────────────────────────────────────
Future<void> requireAuth({
  required BuildContext context,
  required String? currentUserId,
  required String featureName,
  required VoidCallback onSuccess,
}) async {
  if (currentUserId != null) {
    onSuccess();
    return;
  }

  final bool? shouldLogin = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text("Sign in to continue"),
      content: Text(
        "You need to be signed in to $featureName.\n"
        "Log in or create an account to access your bucket list, travel history, profile, and more.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Maybe later"),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.login, size: 18),
          label: const Text("Sign In"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1565FF),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
        ),
      ],
    ),
  );

  if (shouldLogin == true) {
    Navigator.pushNamed(context, '/login');
  }
}

class HomePage extends StatefulWidget {
  final String? currentUserId;

  const HomePage({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
        HomeContent(currentUserId: widget.currentUserId),
        MapPage(currentUserId: widget.currentUserId),
        BucketListPage(currentUserId: widget.currentUserId),
        HistoryPage(currentUserId: widget.currentUserId),
        ProfilePage(currentUserId: widget.currentUserId),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1565FF),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: (index) {
          if (widget.currentUserId == null &&
              (index == 2 || index == 3 || index == 4)) {
            requireAuth(
              context: context,
              currentUserId: widget.currentUserId,
              featureName: index == 2
                  ? "access your Bucket List"
                  : index == 3
                      ? "view your Travel History"
                      : "access your Profile",
              onSuccess: () {
                setState(() => _currentIndex = index);
              },
            );
            return;
          }
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
              icon: Icon(Icons.favorite_border), label: 'Bucket List'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final String? currentUserId;

  const HomeContent({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final SupabaseService _service = SupabaseService();

  // Pagination vars
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  List<Map<String, dynamic>> _displayedDestinations = [];
  List<Map<String, dynamic>> _allDestinations = [];
  bool _isLoading = true;

  Position? _userPosition;
  bool _locationLoading = false;
  String _locationStatus = ''; // ← Empty by default → hides bar
  bool _locationDeniedForever = false;

  StreamSubscription<List<Map<String, dynamic>>>? _destinationSubscription;

  late List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _getUserLocation();
    _loadCategories();

    _destinationSubscription = Supabase.instance.client
        .from('destinations')
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      if (!mounted) return;
      setState(() {
        _allDestinations = data;
        _filterDestinations();
      });
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore) {
        _loadMoreDestinations();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _destinationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getDestinations(page: 1, limit: 15);
      if (mounted) {
        setState(() {
          _allDestinations = data;
          _displayedDestinations = List.from(data);
          _currentPage = 1;
          _hasMore = data.length >= 15;
          _isLoading = false;
        });
        _updateAllDistances();
      }
    } catch (e) {
      debugPrint('Load destinations error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading destinations')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreDestinations() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final more =
          await _service.getDestinations(page: _currentPage + 1, limit: 15);
      if (mounted) {
        setState(() {
          if (more.isEmpty) {
            _hasMore = false;
          } else {
            _allDestinations.addAll(more);
            _filterDestinations();
            _currentPage++;
            _hasMore = more.length >= 15;
          }
        });
        _updateAllDistances();
      }
    } catch (e) {
      debugPrint('Load more error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load more')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _categories = ['All', ...response.map((row) => row['name'] as String)];
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() {
        _categories = [
          'All',
          'Beach',
          'Waterfall',
          'Mountain',
          'Cultural',
          'Adventure',
          'Waterpark'
        ];
      });
    }
  }

  Future<void> _getUserLocation({bool forceRetry = false}) async {
    if (!forceRetry && _userPosition != null && !_locationDeniedForever) return;

    setState(() {
      _locationLoading = true;
      _locationStatus = 'Checking location...';
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services disabled';
          _locationLoading = false;
          _locationDeniedForever = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Location is off – enable to see distances"),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await Geolocator.openLocationSettings();
                _getUserLocation(forceRetry: true);
              },
            ),
          ),
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() {
          _locationStatus = 'Permission denied';
          _locationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Permission denied – distances won't show")),
        );
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Permission permanently denied';
          _locationDeniedForever = true;
          _locationLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                "Location access permanently denied. Enable in app settings."),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await Geolocator.openAppSettings();
                _getUserLocation(forceRetry: true);
              },
            ),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      setState(() {
        _userPosition = position;
        _locationLoading = false;
        _locationDeniedForever = false;
        _locationStatus = ''; // ← Empty = hide status bar
      });

      _updateAllDistances();
    } catch (e) {
      setState(() {
        _locationStatus = 'Location error';
        _locationLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get location. Try again.")),
      );
    }
  }

  void _updateAllDistances() {
    if (_userPosition == null) return;

    setState(() {
      _displayedDestinations = _displayedDestinations.map((dest) {
        final lat = dest['latitude'] as double?;
        final lng = dest['longitude'] as double?;
        if (lat != null && lng != null) {
          final dist = calculateDistance(
            _userPosition!.latitude,
            _userPosition!.longitude,
            lat,
            lng,
          );
          dest['distanceText'] = '${dist.toStringAsFixed(1)} km away';
        } else {
          dest['distanceText'] = 'Distance N/A';
        }
        return dest;
      }).toList();
    });
  }

  void _filterDestinations() {
    setState(() {
      _displayedDestinations = _allDestinations.where((destination) {
        final name = (destination['name'] as String?)?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        final matchesSearch = name.contains(query);

        final selectedCategory = _categories[_selectedCategoryIndex];
        final category = (destination['category'] as String?) ?? '';
        final matchesCategory =
            (selectedCategory == 'All') || (category == selectedCategory);

        return matchesSearch && matchesCategory;
      }).toList();

      _updateAllDistances();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          await _getUserLocation(forceRetry: true);
          await _loadDestinations();
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              _buildCategories(),
              const SizedBox(height: 25),

              // Location status bar – only shows when there's an issue
              if (_locationLoading ||
                  _locationStatus.isNotEmpty ||
                  _locationDeniedForever)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _locationLoading
                            ? Icons.location_searching
                            : _locationDeniedForever
                                ? Icons.location_disabled
                                : _userPosition != null
                                    ? Icons.check_circle
                                    : Icons.location_off,
                        color: _locationLoading
                            ? Colors.blue
                            : _locationDeniedForever
                                ? Colors.red
                                : _userPosition != null
                                    ? Colors.green
                                    : Colors.grey,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationStatus.isEmpty
                              ? 'Location OK'
                              : _locationStatus,
                          style: TextStyle(
                            color: _locationLoading
                                ? Colors.blue
                                : _locationDeniedForever
                                    ? Colors.red
                                    : _userPosition != null
                                        ? Colors.green[700]
                                        : Colors.grey[700],
                          ),
                        ),
                      ),
                      if (_locationDeniedForever ||
                          _locationStatus.contains('denied') ||
                          _locationStatus.contains('disabled'))
                        TextButton(
                          onPressed: () => _getUserLocation(forceRetry: true),
                          child: const Text('Fix',
                              style: TextStyle(color: Color(0xFF1565FF))),
                        ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Destinations',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    if (_locationLoading)
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
              const SizedBox(height: 15),

              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _displayedDestinations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_off,
                                  size: 80, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                "No destinations yet",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Check back soon or ask admin to add some!",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : _buildDestinationList(),

              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                ),

              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1565FF),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Text(
            'GeoRoute',
            style: TextStyle(
                color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          const Text(
            'Discover Misamis Oriental',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 20),
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
                _filterDestinations();
              });
            },
            decoration: InputDecoration(
              hintText: 'Search destinations...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedCategoryIndex;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
                _filterDestinations();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1565FF) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categories[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDestinationList() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _displayedDestinations.length,
      itemBuilder: (context, index) {
        final data = _displayedDestinations[index];
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;

        String distanceText = data['distanceText'] ?? 'Distance N/A';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DestinationDetailPage(
                  destination: data,
                  currentUserId: widget.currentUserId,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    data['image_url'] as String? ??
                        'https://via.placeholder.com/100',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 100,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data['name'] as String? ?? 'No name',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  (data['avg_rating'] as num?)
                                          ?.toStringAsFixed(1) ??
                                      '–',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${data['location'] ?? 'N/A'}\n${data['travel_time'] ?? 'N/A'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 13,
                          color: _userPosition != null
                              ? Colors.blue[700]
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565FF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['category'] as String? ?? 'Nature',
                              style: const TextStyle(
                                color: Color(0xFF1565FF),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            data['price_range'] as String? ??
                                'Price not available',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
