import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/distance_calculator.dart';
import '../services/supabase_service.dart';
import 'bucket_list_page.dart'; // ← Updated import (no more planner)

class DestinationDetailPage extends StatefulWidget {
  final Map<String, dynamic> destination;
  final String currentUserId;

  const DestinationDetailPage({
    super.key,
    required this.destination,
    required this.currentUserId,
  });

  @override
  State<DestinationDetailPage> createState() => _DestinationDetailPageState();
}

class _DestinationDetailPageState extends State<DestinationDetailPage> {
  final SupabaseService _service = SupabaseService();
  final _noteController = TextEditingController();
  double _rating = 5.0;
  bool _isSaving = false;

  // User location for distance
  Position? _userPosition;
  bool _locationLoading = false;
  String _distanceText = 'Calculating distance...';

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    setState(() => _locationLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _distanceText = 'Location services disabled';
          _locationLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _distanceText = 'Location permission denied';
          _locationLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final lat = widget.destination['latitude'] as double?;
      final lng = widget.destination['longitude'] as double?;

      if (lat != null && lng != null) {
        final dist =
            calculateDistance(position.latitude, position.longitude, lat, lng);
        setState(() {
          _distanceText = '${dist.toStringAsFixed(1)} km away';
          _userPosition = position;
          _locationLoading = false;
        });
      } else {
        setState(() {
          _distanceText = 'Location not available';
          _locationLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _distanceText = 'Error getting distance';
        _locationLoading = false;
      });
    }
  }

  Future<void> _markAsVisited() async {
    setState(() => _isSaving = true);

    try {
      await _service.addToHistory(
        userId: widget.currentUserId,
        destinationId: widget.destination['id'] as String? ?? '',
        destinationName: widget.destination['name'] as String? ?? 'Unknown',
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        rating: _rating,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as visited! Added to your travel history.'),
          backgroundColor: Colors.green,
        ),
      );

      _noteController.clear();
      setState(() => _rating = 5.0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save visit: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _addToBucketList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BucketListPage(
          currentUserId: widget.currentUserId,
          initialLocation: widget.destination,
        ),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to your Bucket List!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.destination['name'] as String? ?? 'Unnamed Destination';
    final imageUrl = widget.destination['image_url'] as String? ??
        'https://via.placeholder.com/800';
    final category = widget.destination['category'] as String? ?? 'Nature';
    final rating =
        (widget.destination['rating'] as num?)?.toStringAsFixed(1) ?? '–';
    final description = widget.destination['description'] as String? ??
        'No description available.';
    final attractions = (widget.destination['attractions'] as String?)
            ?.split(',')
            .map((e) => e.trim())
            .toList() ??
        [];
    final activities = (widget.destination['activities'] as String?)
            ?.split(',')
            .map((e) => e.trim())
            .toList() ??
        [];
    final accommodation = widget.destination['accommodation'] as String? ??
        'No accommodation information.';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.image_not_supported,
                      size: 80, color: Colors.grey),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Rating + Category
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B2559),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565FF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 4),
                            Text(rating,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(category),
                    backgroundColor: const Color(0xFF1565FF).withOpacity(0.2),
                    labelStyle: const TextStyle(color: Color(0xFF1565FF)),
                  ),
                  const SizedBox(height: 16),

                  // Distance from user
                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      _locationLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _distanceText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _userPosition != null
                                    ? Colors.blue[700]
                                    : Colors.grey[700],
                              ),
                            ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Travel info
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(widget.destination['distance_from_cdo'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer, size: 20, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(widget.destination['travel_time'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_money,
                          size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        widget.destination['price_range'] ??
                            'Price not available',
                        style: const TextStyle(
                            color: Colors.green, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  const Text('Description',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description,
                      style: TextStyle(fontSize: 15, height: 1.5)),
                  const SizedBox(height: 24),

                  // Attractions
                  if (attractions.isNotEmpty) ...[
                    const Text('Attractions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...attractions.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.star_border,
                                  color: Color(0xFF1565FF)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(a)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Activities
                  if (activities.isNotEmpty) ...[
                    const Text('Activities',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...activities.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_run,
                                  color: Color(0xFF1565FF)),
                              const SizedBox(width: 8),
                              Expanded(child: Text(a)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Accommodation
                  const Text('Nearby Accommodations',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(accommodation, style: TextStyle(fontSize: 15)),
                  const SizedBox(height: 32),

                  // ─── MARK AS VISITED SECTION ──────────────────────────────────────
                  const Text('Mark as Visited',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: 'Add a note or comment (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Your Rating: ',
                          style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Slider(
                          value: _rating,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _rating.toStringAsFixed(1),
                          onChanged: (value) => setState(() => _rating = value),
                        ),
                      ),
                      Text('$_rating ★',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSaving
                          ? const SizedBox.shrink()
                          : const Icon(Icons.bookmark_added),
                      label: Text(_isSaving ? 'Saving...' : 'Mark as Visited'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSaving ? null : _markAsVisited,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ─── ADD TO BUCKET LIST BUTTON ────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Add to Bucket List'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF651FFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _addToBucketList,
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
