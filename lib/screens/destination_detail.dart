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
  final String? currentUserId;

  const DestinationDetailPage({
    super.key,
    required this.destination,
    this.currentUserId,
  });

  @override
  State<DestinationDetailPage> createState() => _DestinationDetailPageState();
}

class _DestinationDetailPageState extends State<DestinationDetailPage> {
  final SupabaseService _service = SupabaseService();

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

  bool _showAllReviews = false;

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

  void _showLoginRequiredDialog(String action) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Sign in to continue"),
        content: Text(
          "To $action you need to be signed in.\n\n"
          "Log in or create an account to save favorites, leave reviews, and build your personal travel story in Misamis Oriental.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Maybe later"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text("Sign In / Register"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/login');
            },
          ),
        ],
      ),
    );
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
    if (widget.currentUserId == null) {
      _showLoginRequiredDialog("post a review or rating");
      return;
    }

    final comment = _commentController.text.trim();
    if (comment.isEmpty && _publicRating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a comment or rating')),
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
            content: Text('Failed to post review: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isPostingComment = false);
    }
  }

  void _addToBucketList() {
    if (widget.currentUserId == null) {
      _showLoginRequiredDialog("add this destination to your bucket list");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BucketListPage(
          currentUserId: widget.currentUserId!,
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
          autoStartNavigation: true,
        ),
      ),
    );
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

  @override
  void dispose() {
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

    final bool isLoggedIn = widget.currentUserId != null;

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

                  // ─── COMMUNITY REVIEWS ────────────────────────────────────────
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
                    Builder(
                      builder: (context) {
                        final sortedComments =
                            List<Map<String, dynamic>>.from(_comments)
                              ..sort((a, b) {
                                final dateA =
                                    DateTime.tryParse(a['created_at'] ?? '') ??
                                        DateTime(2000);
                                final dateB =
                                    DateTime.tryParse(b['created_at'] ?? '') ??
                                        DateTime(2000);
                                return dateB.compareTo(dateA);
                              });

                        final visibleComments = _showAllReviews
                            ? sortedComments
                            : sortedComments.take(2).toList();

                        return Column(
                          children: [
                            ...visibleComments.map((c) {
                              final rawName =
                                  c['users']?['full_name'] as String?;
                              final maskedName = _maskUsername(rawName);
                              final dateStr = c['created_at'] as String?;
                              final date = dateStr != null
                                  ? DateFormat('MMM d, yyyy • h:mm a')
                                      .format(DateTime.parse(dateStr).toLocal())
                                  : 'Unknown date';
                              final rating = c['rating'] as num?;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            maskedName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15),
                                          ),
                                          Text(
                                            date,
                                            style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      if (rating != null) ...[
                                        const SizedBox(height: 8),
                                        RatingBarIndicator(
                                          rating: rating.toDouble(),
                                          itemBuilder: (context, _) =>
                                              const Icon(Icons.star,
                                                  color: Colors.amber),
                                          itemCount: 5,
                                          itemSize: 20,
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Text(
                                        c['comment_text'] as String? ?? '',
                                        style: const TextStyle(height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                            if (sortedComments.length > 2)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() =>
                                        _showAllReviews = !_showAllReviews);
                                  },
                                  icon: Icon(
                                    _showAllReviews
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: const Color(0xFF1565FF),
                                  ),
                                  label: Text(
                                    _showAllReviews
                                        ? 'See fewer reviews'
                                        : 'See more reviews (${sortedComments.length - 2})',
                                    style: const TextStyle(
                                      color: Color(0xFF1565FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),

                  const SizedBox(height: 32),

                  if (!isLoggedIn)
                    Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.lock_outline_rounded,
                                size: 56, color: Colors.blueGrey),
                            const SizedBox(height: 16),
                            const Text(
                              "Want to share your experience?",
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Sign in to rate this place, write a review, and help other travelers discover the best spots in Misamis Oriental!",
                              textAlign: TextAlign.center,
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 15),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.login),
                              label: const Text("Sign In / Create Account"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/login'),
                            ),
                          ],
                        ),
                      ),
                    )
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

                  const SizedBox(height: 40),

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

                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mask username like "J...h"
  String _maskUsername(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) {
      return 'Traveler';
    }

    final name = fullName.trim();

    if (name.length <= 3) {
      return name;
    }

    final first = name[0];
    final last = name[name.length - 1];

    return '$first...$last';
  }
}
