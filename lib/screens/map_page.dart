import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../services/supabase_service.dart';
import 'bucket_list_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    Key? key,
    required this.currentUserId,
  }) : super(key: key);

  final String currentUserId;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  double _currentZoom = 11.0;
  LatLng? _currentPosition;
  bool _isDriving = true;
  bool _isLoading = true;
  bool _isNavigating = false;
  bool _followUser = false; // Auto-follow toggle

  List<Map<String, dynamic>> _destinations = [];
  List<Map<String, dynamic>> _nearbyDestinations = [];

  // Navigation
  List<LatLng> _routePoints = [];
  Map<String, dynamic>? _currentDestination;
  List<String> _navigationSteps = [];
  int _currentStepIndex = 0;
  double _remainingDistanceKm = 0.0;

  // Preview from bucket list
  List<LatLng> _previewRoutePoints = [];
  bool _showPreviewRoute = false;

  // Offline fallback
  List<LatLng> _fallbackPoints = [];

  StreamSubscription<Position>? _positionStream;
  Timer? _followTimer;

  final supabase = Supabase.instance.client;
  final _service = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadDestinations();
    _loadPreviewRoute();
    _startLiveLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _followTimer?.cancel();
    super.dispose();
  }

  // ─── Load Destinations ───────────────────────────────────────────────────
  Future<void> _loadDestinations() async {
    try {
      final dests = await _service.getDestinations();
      if (mounted) {
        setState(() {
          _destinations = dests
              .map((d) => {
                    ...d,
                    'location': LatLng(
                      double.tryParse(d['latitude']?.toString() ?? '0') ?? 0,
                      double.tryParse(d['longitude']?.toString() ?? '0') ?? 0,
                    ),
                  })
              .where(
                  (d) => d['location'] != null && d['location'].latitude != 0)
              .toList();

          _updateNearby();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Destinations load error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load places: $e')),
        );
      }
    }
  }

  // ─── Load Bucket List Preview ───────────────────────────────────────────
  Future<void> _loadPreviewRoute() async {
    try {
      final plan = await _service.getTripPlan(widget.currentUserId);
      if (plan.isEmpty || !mounted) return;

      List<LatLng> points = [];
      for (var dest in plan) {
        final lat = double.tryParse(dest['latitude']?.toString() ?? '0') ?? 0.0;
        final lng =
            double.tryParse(dest['longitude']?.toString() ?? '0') ?? 0.0;
        if (lat == 0 || lng == 0) continue;
        points.add(LatLng(lat, lng));
      }

      if (mounted && points.length > 1) {
        setState(() {
          _previewRoutePoints = points;
          _showPreviewRoute = true;
        });

        // 1. Instant fit to bounds (no animation param in v8)
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.all(80),
          ),
        );

        // 2. Smooth animated zoom-in after fit (using animateTo)
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            final currentCamera = _mapController.camera;

            _mapController.move(
              _mapController.camera.center,
              12.0,
            );
          }
        });
      }
    } catch (e) {
      print('Preview route error: $e');
    }
  }

  // ─── Live Location ───────────────────────────────────────────────────────
  void _startLiveLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
          _mapController.move(_currentPosition!, _currentZoom);
        });
      }

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen((Position pos) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(pos.latitude, pos.longitude);
            if (_followUser) {
              _mapController.move(_currentPosition!, _currentZoom);
            }
            _updateNearby();

            if (_isNavigating && _currentDestination != null) {
              _updateRemainingDistance();
            }
          });
        }
      });
    }
  }

  void _updateNearby() {
    if (_currentPosition == null || _destinations.isEmpty) {
      setState(() => _nearbyDestinations = _destinations);
      return;
    }

    const maxKm = 50.0;
    final nearby = <Map<String, dynamic>>[];

    for (var dest in _destinations) {
      final loc = dest['location'] as LatLng;
      final distKm = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            loc.latitude,
            loc.longitude,
          ) /
          1000;

      if (distKm <= maxKm) {
        dest['calculated_distance'] = '${distKm.toStringAsFixed(1)} km';
        nearby.add(dest);
      }
    }

    setState(() => _nearbyDestinations = nearby);
  }

  // ─── Start Navigation (optimized zoom + animation) ──────────────────────
  Future<void> _startInAppNavigation(Map<String, dynamic> dest) async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Waiting for location...")),
      );
      return;
    }

    setState(() {
      _isNavigating = true;
      _currentDestination = dest;
      _routePoints = [];
      _navigationSteps = [];
      _currentStepIndex = 0;
      _remainingDistanceKm = 0.0;
    });

    final profile = _isDriving ? 'driving-car' : 'foot-walking';

    final uri = Uri(
      scheme: 'https',
      host: 'api.openrouteservice.org',
      path: '/v2/directions/$profile',
      queryParameters: {
        'api_key':
            'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijc1YzBhNWIzNDM5OTRjNzc4ZmMzN2YwN2M1OGE3NmJhIiwiaCI6Im11cm11cjY0In0=',
        'start': '${_currentPosition!.longitude},${_currentPosition!.latitude}',
        'end': '${dest['location'].longitude},${dest['location'].latitude}',
        'instructions': 'true',
        'overview': 'full',
        'geometries': 'geojson',
      },
    );

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Route request failed: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['features'] == null || data['features'].isEmpty) {
        throw Exception('No route found');
      }

      final coords =
          data['features'][0]['geometry']['coordinates'] as List<dynamic>;
      final routePoints =
          coords.map((c) => LatLng(c[1] as double, c[0] as double)).toList();

      final stepsData = data['features'][0]['properties']['segments']?[0]
          ?['steps'] as List<dynamic>?;
      final steps = stepsData
              ?.map((s) => s['instruction']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList() ??
          [];

      final totalDistMeters =
          data['features'][0]['properties']['summary']?['distance'] as num?;
      final totalDistKm = (totalDistMeters ?? 0) / 1000;

      if (mounted) {
        setState(() {
          _routePoints = routePoints;
          _navigationSteps = steps;
          _remainingDistanceKm = totalDistKm;
        });

        // 1. Fit bounds instantly (v8 does not support animated fitCamera)
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds:
                LatLngBounds.fromPoints([...routePoints, _currentPosition!]),
            padding: const EdgeInsets.all(100),
          ),
        );

        // 2. Smooth animated zoom-in after fit
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds:
                LatLngBounds.fromPoints([...routePoints, _currentPosition!]),
            padding: const EdgeInsets.all(100),
          ),
        );

// Manual zoom-in (instant, no smooth animation)
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _isNavigating) {
            final currentCamera = _mapController.camera;
            _mapController.move(currentCamera.center, 13.5);
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Route to ${dest['name']} loaded (${totalDistKm.toStringAsFixed(1)} km)"),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Navigation error: $e');
      if (mounted) {
        setState(() => _isNavigating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Couldn't load route: ${e.toString().split('\n').first}"),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _routePoints = [];
      _fallbackPoints = [];
      _navigationSteps = [];
      _currentDestination = null;
      _currentStepIndex = 0;
      _remainingDistanceKm = 0.0;
      _followUser = false;
    });
    _followTimer?.cancel();
  }

  void _updateRemainingDistance() {
    if (_currentDestination == null ||
        (_routePoints.isEmpty && _fallbackPoints.isEmpty)) return;

    final points = _routePoints.isNotEmpty ? _routePoints : _fallbackPoints;

    double total = 0.0;
    for (int i = 1; i < points.length; i++) {
      total += Geolocator.distanceBetween(
            points[i - 1].latitude,
            points[i - 1].longitude,
            points[i].latitude,
            points[i].longitude,
          ) /
          1000;
    }
    setState(() => _remainingDistanceKm = total);
  }

  // ─── Auto-follow toggle logic ────────────────────────────────────────────
  void _toggleFollowUser() {
    setState(() {
      _followUser = !_followUser;
    });

    if (_followUser) {
      _followTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted && _followUser && _currentPosition != null) {
          _mapController.move(_currentPosition!, _currentZoom);
        }
      });
    } else {
      _followTimer?.cancel();
    }
  }

  // ─── Category Helpers ────────────────────────────────────────────────────
  Color _getCategoryColor(String? type) {
    final t = type?.toLowerCase() ?? '';
    if (t.contains('beach')) return Colors.blue;
    if (t.contains('waterfall')) return Colors.cyan;
    if (t.contains('mountain')) return Colors.brown;
    if (t.contains('view') || t.contains('scenic')) return Colors.orange;
    if (t.contains('waterpark') || t.contains('adventure'))
      return Colors.purple;
    return Colors.grey[700]!;
  }

  IconData _getCategoryIcon(String? type) {
    final t = type?.toLowerCase() ?? '';
    if (t.contains('beach')) return Icons.beach_access;
    if (t.contains('waterfall')) return Icons.water_drop;
    if (t.contains('mountain')) return Icons.terrain;
    if (t.contains('view') || t.contains('scenic')) return Icons.panorama;
    return Icons.location_on;
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w500, color: Colors.grey)),
      ],
    );
  }

  // ─── Destination Bottom Sheet ────────────────────────────────────────────
  void _showLocationDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25)),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25)),
                      image: DecorationImage(
                        image: AssetImage(
                            data['image_url'] ?? 'assets/images/7seas.jpg'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            data['rating']?.toString() ?? '4.5',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] ?? 'Place',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              _getCategoryColor(data['type']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          data['type'] ?? 'Destination',
                          style: TextStyle(
                            color: _getCategoryColor(data['type']),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildInfoRow(
                              Icons.location_on_outlined,
                              data['calculated_distance'] ??
                                  data['distance'] ??
                                  'N/A'),
                          const SizedBox(width: 24),
                          _buildInfoRow(
                              Icons.access_time, data['time'] ?? 'N/A'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('About',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        data['description'] ??
                            data['desc'] ??
                            'No description available.',
                        style: TextStyle(color: Colors.grey[700], height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      const Text('Accommodation',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        data['accommodation'] ??
                            'Nearby resorts, homestays, and hotels available (₱1,000–₱4,000/night)',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Icon(Icons.attach_money, color: Colors.green),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Price Range',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text(data['price'] ?? 'Varies',
                                  style: TextStyle(color: Colors.grey[700])),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    _buildAction(
                      Icons.favorite_border,
                      'Pin',
                      Colors.blue.shade50,
                      Colors.blue,
                      () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BucketListPage(
                              initialLocation: data,
                              currentUserId: widget.currentUserId,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildAction(
                      Icons.check_circle,
                      'Visited',
                      Colors.green.shade50,
                      Colors.green,
                      () async {
                        final user = supabase.auth.currentUser;
                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Log in first')),
                          );
                          return;
                        }
                        try {
                          await _service.addToHistory(
                            userId: user.id,
                            destinationId: data['id'].toString(),
                            destinationName: data['name'],
                            note: null,
                            rating: double.tryParse(
                                data['rating']?.toString() ?? '4.0'),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to your travel history!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigation, color: Colors.white),
                        label: const Text('Start Navigation',
                            style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4527A0),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          _startInAppNavigation(data);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAction(
      IconData icon, String label, Color bg, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    for (var dest in _nearbyDestinations) {
      markers.add(
        Marker(
          point: dest['location'],
          width: 50,
          height: 50,
          child: GestureDetector(
            onTap: () => _showLocationDetails(context, dest),
            child: Icon(
              _getCategoryIcon(dest['type']),
              color: _getCategoryColor(dest['type']),
              size: 40,
            ),
          ),
        ),
      );
    }

    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: _currentPosition!,
          width: 50,
          height: 50,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565FF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Explore Map',
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      Icon(Icons.explore,
                          color: Theme.of(context).primaryColor),
                    ],
                  ),
                ),
                _buildModeToggle(),
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter:
                          _currentPosition ?? const LatLng(8.55, 124.65),
                      initialZoom: 10.5,
                      onPositionChanged: (MapCamera camera, bool hasGesture) {
                        if (hasGesture) _currentZoom = camera.zoom;
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.georoute.app',
                      ),
                      if (_showPreviewRoute && _previewRoutePoints.isNotEmpty)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _previewRoutePoints,
                              color: Colors.blue.withOpacity(0.5),
                              strokeWidth: 4,
                            ),
                          ],
                        ),
                      if (_isNavigating &&
                          (_routePoints.isNotEmpty ||
                              _fallbackPoints.isNotEmpty))
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints.isNotEmpty
                                  ? _routePoints
                                  : _fallbackPoints,
                              color: Colors.blue[700]!,
                              strokeWidth: 6,
                              borderColor: Colors.blue[900]!,
                              borderStrokeWidth: 2.5,
                            ),
                          ],
                        ),
                      MarkerLayer(markers: _buildMarkers()),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                  color: Colors.blue, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          const Text('Your Location',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                      Text('${_nearbyDestinations.length} nearby places',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),

            if (_isNavigating)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                _navigationSteps.isNotEmpty
                                    ? _navigationSteps[_currentStepIndex]
                                    : 'Follow the route',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.red, size: 28),
                              onPressed: _stopNavigation,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'To ${_currentDestination?['name'] ?? 'destination'} • ${_remainingDistanceKm.toStringAsFixed(1)} km left • ~${(_remainingDistanceKm / (_isDriving ? 40 : 5) * 60).toStringAsFixed(0)} min',
                          style:
                              TextStyle(color: Colors.grey[700], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Follow Me button (only during navigation)
            if (_isNavigating)
              Positioned(
                bottom: 100,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  backgroundColor:
                      _followUser ? Colors.green : Colors.grey[700],
                  child: Icon(_followUser
                      ? Icons.my_location
                      : Icons.location_searching),
                  onPressed: _toggleFollowUser,
                ),
              ),

            if (_isLoading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Driving')),
          ButtonSegment(value: false, label: Text('Walking')),
        ],
        selected: {_isDriving},
        onSelectionChanged: (newSelection) {
          setState(() => _isDriving = newSelection.first);
        },
      ),
    );
  }
}
