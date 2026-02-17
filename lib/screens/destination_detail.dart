import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/distance_calculator.dart';
import '../services/supabase_service.dart';
import 'bucket_list_page.dart';
import 'map_page.dart';

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
  double _personalRating = 5.0;
  bool _isSavingVisit = false;

  double _avgRating = 0.0;
  int _ratingCount = 0;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isPostingComment = false;

  final _commentController = TextEditingController();
  double _publicRating = 0.0;

  Position? _userPosition;
  bool _locationLoading = false;
  String _distanceText = 'Calculating distance...';

  StreamSubscription<List<Map<String, dynamic>>>? _commentSubscription;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadCommentsAndRating();

    final String? destId = widget.destination['id']?.toString();
    if (destId != null && destId.isNotEmpty) {
      _commentSubscription = Supabase.instance.client
          .from('destination_comments')
          .stream(primaryKey: ['id'])
          .eq('destination_id', destId)
          .listen((payload) {
            debugPrint('New comment detected → refreshing');
            _loadCommentsAndRating();
          });
    }
  }

  Future<void> _loadCommentsAndRating() async {
    setState(() => _isLoading = true);

    try {
      final String? destId = widget.destination['id']?.toString();
      if (destId == null || destId.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await _service.getDestinationComments(destId);

      if (!mounted) return;
      setState(() {
        _comments = data['comments'] as List<Map<String, dynamic>>? ?? [];
        _avgRating =
            double.tryParse(data['avg_rating']?.toString() ?? '0.0') ?? 0.0;
        _ratingCount = data['rating_count'] as int? ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _postPublicComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty && _publicRating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a comment or rating')),
      );
      return;
    }

    setState(() => _isPostingComment = true);

    try {
      final String? destId = widget.destination['id']?.toString();
      if (destId == null || destId.isEmpty)
        throw Exception('No destination ID');

      await _service.addDestinationComment(
        destinationId: destId,
        commentText: comment,
        rating: _publicRating.toInt() > 0 ? _publicRating.toInt() : null,
      );

      _commentController.clear();
      setState(() => _publicRating = 0.0);
      await _loadCommentsAndRating();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Review posted!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to post: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isPostingComment = false);
    }
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

      final double? lat = widget.destination['latitude'] as double?;
      final double? lng = widget.destination['longitude'] as double?;

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
    setState(() => _isSavingVisit = true);

    try {
      final String? destId = widget.destination['id']?.toString();
      final String? destName = widget.destination['name']?.toString();

      if (destId == null || destId.isEmpty)
        throw Exception('Missing destination ID');

      await _service.addToHistory(
        userId: widget.currentUserId,
        destinationId: destId,
        destinationName: destName ?? 'Unknown',
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        rating: _personalRating,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Marked as visited! Added to travel history.'),
            backgroundColor: Colors.green),
      );

      _noteController.clear();
      setState(() => _personalRating = 5.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSavingVisit = false);
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
          backgroundColor: Colors.green),
    );
  }

  void _startNavigation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPage(
          currentUserId: widget.currentUserId,
          initialDestination: widget.destination,
          autoStartNavigation: true, // ← This triggers auto navigation
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _commentController.dispose();
    _commentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final name = dest['name'] as String? ?? 'Unnamed Destination';
    final imageUrl =
        dest['image_url'] as String? ?? 'https://via.placeholder.com/800';
    final category = dest['category'] as String? ?? 'Nature';
    final description =
        dest['description'] as String? ?? 'No description available.';
    final attractions = (dest['attractions'] as String?)
            ?.split(',')
            .map((e) => e.trim())
            .toList() ??
        [];
    final activities = (dest['activities'] as String?)
            ?.split(',')
            .map((e) => e.trim())
            .toList() ??
        [];
    final accommodation =
        dest['accommodation'] as String? ?? 'No accommodation information.';
    final bool isLoggedIn = Supabase.instance.client.auth.currentUser != null;

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
                  Text(name,
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Chip(
                      label: Text(category), backgroundColor: Colors.blue[100]),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Icon(Icons.location_on,
                          size: 20, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      _locationLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_distanceText,
                              style: TextStyle(
                                  fontSize: 16, color: Colors.blue[700])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: _avgRating,
                        itemBuilder: (context, _) =>
                            const Icon(Icons.star, color: Colors.amber),
                        itemCount: 5,
                        itemSize: 28,
                      ),
                      const SizedBox(width: 12),
                      Text('$_avgRating ($_ratingCount reviews)',
                          style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 32),

                  Text(description,
                      style: const TextStyle(fontSize: 15, height: 1.5)),
                  const SizedBox(height: 24),

                  if (attractions.isNotEmpty) ...[
                    const Text('Attractions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ...attractions.map((a) => ListTile(
                        leading: const Icon(Icons.star_border),
                        title: Text(a))),
                  ],

                  if (activities.isNotEmpty) ...[
                    const Text('Activities',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    ...activities.map((a) => ListTile(
                        leading: const Icon(Icons.directions_run),
                        title: Text(a))),
                  ],

                  const SizedBox(height: 24),
                  Text('Nearby Accommodations',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(accommodation, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 32),

                  const Text('Community Reviews',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_comments.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No reviews yet — be the first!',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final c = _comments[index];
                        final userName =
                            c['users']?['full_name'] as String? ?? 'Anonymous';
                        final dateStr = c['created_at'] as String?;
                        final date = dateStr != null
                            ? DateFormat('MMM d, yyyy • h:mm a')
                                .format(DateTime.parse(dateStr).toLocal())
                            : 'Unknown date';
                        final rating = c['rating'] as num?;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(userName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(date,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ],
                                ),
                                if (rating != null) ...[
                                  const SizedBox(height: 8),
                                  RatingBarIndicator(
                                    rating: rating.toDouble(),
                                    itemBuilder: (context, _) => const Icon(
                                        Icons.star,
                                        color: Colors.amber),
                                    itemCount: 5,
                                    itemSize: 20,
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(c['comment_text'] as String? ?? '',
                                    style: const TextStyle(height: 1.4)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 32),

                  if (!isLoggedIn)
                    const Center(
                        child: Text('Log in to leave a review',
                            style: TextStyle(color: Colors.grey)))
                  else
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Leave a Review',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            RatingBar.builder(
                              initialRating: _publicRating,
                              minRating: 1,
                              direction: Axis.horizontal,
                              allowHalfRating: false,
                              itemCount: 5,
                              itemSize: 32,
                              itemPadding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              itemBuilder: (context, _) =>
                                  const Icon(Icons.star, color: Colors.amber),
                              onRatingUpdate: (rating) =>
                                  setState(() => _publicRating = rating),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _commentController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: 'Share your experience...',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isPostingComment
                                    ? null
                                    : _postPublicComment,
                                icon: _isPostingComment
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2))
                                    : const Icon(Icons.send),
                                label: Text(
                                  _isPostingComment
                                      ? 'Posting...'
                                      : 'Post Review',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1565FF),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // START NAVIGATION BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.navigation, color: Colors.white),
                      label: const Text('Start Navigation',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _startNavigation,
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text('Mark as Visited (Private)',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add a personal note (optional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      const Text('Your Rating: ',
                          style: TextStyle(fontSize: 16)),
                      Expanded(
                        child: Slider(
                          value: _personalRating,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: _personalRating.toStringAsFixed(1),
                          onChanged: (value) =>
                              setState(() => _personalRating = value),
                        ),
                      ),
                      Text('$_personalRating ★',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isSavingVisit
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.bookmark_added,
                              color: Colors.white),
                      label: Text(
                        _isSavingVisit ? 'Saving...' : 'Mark as Visited',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSavingVisit ? null : _markAsVisited,
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.favorite_border,
                          color: Colors.white),
                      label: const Text('Add to Bucket List',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _addToBucketList,
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
