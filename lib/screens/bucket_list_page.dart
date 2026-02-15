import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'home_page.dart';

class BucketListPage extends StatefulWidget {
  final String currentUserId;
  final Map<String, dynamic>? initialLocation;

  const BucketListPage({
    Key? key,
    required this.currentUserId,
    this.initialLocation,
  }) : super(key: key);

  @override
  State<BucketListPage> createState() => _BucketListPageState();
}

class _BucketListPageState extends State<BucketListPage>
    with WidgetsBindingObserver {
  final SupabaseService _service = SupabaseService();
  List<Map<String, dynamic>> _bucketList = [];
  bool _isLoading = true;

  // We'll check visited status from travel_history
  Set<String> _visitedIds = {}; // Cache visited destination_ids

  double get completionPercentage {
    if (_bucketList.isEmpty) return 0.0;
    final visitedCount = _bucketList
        .where((item) => _visitedIds.contains(item['destination_id']))
        .length;
    return visitedCount / _bucketList.length;
  }

  String get totalVisited {
    final count = _bucketList
        .where((item) => _visitedIds.contains(item['destination_id']))
        .length;
    return '$count/${_bucketList.length}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBucketList();
    _loadVisitedIds(); // NEW: load visited status

    if (widget.initialLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _addToBucket(widget.initialLocation!);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBucketList();
      _loadVisitedIds(); // Refresh visited status when returning
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // NEW: Load visited destination IDs from travel_history
  Future<void> _loadVisitedIds() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final res = await Supabase.instance.client
          .from('travel_history')
          .select('destination_id')
          .eq('user_id', user.id);

      setState(() {
        _visitedIds =
            res.map((row) => row['destination_id'].toString()).toSet();
      });
    } catch (e) {
      print('Error loading visited IDs: $e');
    }
  }

  Future<void> _loadBucketList() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final data = await _service.getTripPlan(widget.currentUserId);
      if (mounted) {
        setState(() {
          _bucketList = data.map((item) {
            // No need to set 'visited' anymore – we check via _visitedIds
            return item;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading bucket list: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addToBucket(Map<String, dynamic> data) async {
    final destId = data['id']?.toString();
    if (destId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cannot add: Missing destination ID'),
            backgroundColor: Colors.red),
      );
      return;
    }

    final newItem = {
      'destination_id': destId,
      'name': data['name'] ?? 'Dream Spot',
      'type': data['type'] ?? 'Unknown',
      'distance': data['distance'] ?? 'N/A',
      'duration': data['duration'] ?? 'N/A',
      'cost': data['price'] ?? '₱ – ',
      'image': data['image_url'] ?? 'https://via.placeholder.com/400x200',
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'order_index': _bucketList.length,
    };

    setState(() => _bucketList.add(newItem));

    try {
      await _service.addToPlan(
        userId: widget.currentUserId,
        destination: newItem,
        orderIndex: _bucketList.length - 1,
      );

      await _loadBucketList(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${newItem['name']} added to your bucket list!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
      setState(() => _bucketList.removeLast());
    }
  }

  Future<void> _markAsVisited(int index) async {
    final item = _bucketList[index];

    // Already visited? (check via history)
    if (_visitedIds.contains(item['destination_id'])) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to mark as visited')),
      );
      return;
    }

    try {
      await _service.addToHistory(
        userId: user.id,
        destinationId: item['destination_id'].toString(),
        destinationName: item['name'],
        note: null,
        rating: null,
      );

      // Update local cache & UI
      setState(() {
        _visitedIds.add(item['destination_id'].toString());
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${item['name']} marked as visited! 🌟'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeAt(int index) async {
    final removed = _bucketList[index];

    setState(() => _bucketList.removeAt(index));

    try {
      await _service.updatePlan(widget.currentUserId, _bucketList);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${removed['name']} removed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error removing: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Bucket List?'),
        content: const Text('Remove all dream destinations?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _bucketList.clear());
    await _service.clearPlan(widget.currentUserId);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bucket list cleared')),
    );
  }

  // ─── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF651FFF), Color(0xFF7C4DFF)],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.favorite_border,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'My Bucket List',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 56),
                  child: Text(
                    'Dream destinations in Misamis Oriental',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bucketList.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadBucketList,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildProgressCard(screenWidth),
                            const SizedBox(height: 24),
                            Text(
                              'My Dreams',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1B2559)),
                            ),
                            const SizedBox(height: 12),
                            ..._bucketList.asMap().entries.map((entry) {
                              final index = entry.key;
                              final item = entry.value;
                              final isVisited = _visitedIds
                                  .contains(item['destination_id'].toString());

                              return Dismissible(
                                key: ValueKey(
                                    '${item['destination_id'] ?? ''}_${item['name'] ?? ''}_$index'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: Colors.redAccent,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  child: const Icon(Icons.delete,
                                      color: Colors.white),
                                ),
                                onDismissed: (direction) {
                                  _removeAt(index);
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                  elevation: 3,
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.network(
                                              item['image'] ??
                                                  'https://via.placeholder.com/400x225',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                color: Colors.grey[300],
                                                child: const Icon(
                                                    Icons.image_not_supported,
                                                    size: 60,
                                                    color: Colors.grey),
                                              ),
                                            ),
                                            if (isVisited)
                                              Container(
                                                color: Colors.black
                                                    .withOpacity(0.5),
                                                child: const Center(
                                                  child: Icon(
                                                      Icons.check_circle,
                                                      size: 80,
                                                      color: Colors.white70),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? 'Dream Spot',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                decoration: isVisited
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(Icons.category_outlined,
                                                    size: 16,
                                                    color: Colors.grey[600]),
                                                const SizedBox(width: 6),
                                                Text(
                                                  item['type'] ?? 'Unknown',
                                                  style: TextStyle(
                                                      color: Colors.grey[700],
                                                      fontSize: 13),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  item['cost'] ?? '—',
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                if (!isVisited)
                                                  OutlinedButton.icon(
                                                    icon: const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 18),
                                                    label: const Text(
                                                        'Mark Visited'),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          Colors.green,
                                                      side: const BorderSide(
                                                          color: Colors.green),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8),
                                                    ),
                                                    onPressed: () =>
                                                        _markAsVisited(index),
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
                            }).toList(),
                            const SizedBox(height: 100), // space for FAB
                          ],
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  HomePage(currentUserId: widget.currentUserId),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add More Spots'),
        backgroundColor: const Color(0xFF651FFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildProgressCard(double screenWidth) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left side: Text + count
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Progress',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  totalVisited,
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Completed',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),

            // Right side: Compact progress circle
            SizedBox(
              width: screenWidth *
                  0.28, // Adjust this for perfect fit on your phone
              height: screenWidth * 0.28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: completionPercentage,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF651FFF)),
                  ),
                  Text(
                    '${(completionPercentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF651FFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border_outlined,
                size: 100, color: Colors.pink[100]),
            const SizedBox(height: 24),
            const Text(
              'Your Bucket List Awaits',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF651FFF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add your must-visit spots in Misamis Oriental — beaches, falls, mountains & more!',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              icon: const Icon(Icons.explore),
              label: const Text('Discover Spots'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF651FFF),
                side: const BorderSide(color: Color(0xFF651FFF)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        HomePage(currentUserId: widget.currentUserId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
