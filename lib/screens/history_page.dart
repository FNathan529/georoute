import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'destination_detail.dart';
import 'home_page.dart';

class HistoryPage extends StatefulWidget {
  final String? currentUserId;

  const HistoryPage({Key? key, this.currentUserId}) : super(key: key);

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final SupabaseService _service = SupabaseService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    if (widget.currentUserId == null) {
      setState(() => _isLoading = false);
    } else {
      _loadHistory();
    }
  }

  Future<void> _loadHistory({bool isRefresh = false}) async {
    if (widget.currentUserId == null || !mounted) return;

    if (!isRefresh) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _service.getUserHistory(widget.currentUserId!);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Couldn't load your travel history. Check connection."),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  // Fetch full destination data and open detail page
  Future<void> _openDestinationDetail(String destinationId) async {
    try {
      final fullDestination = await Supabase.instance.client
          .from('destinations')
          .select('*')
          .eq('id', destinationId)
          .single();

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DestinationDetailPage(
            destination: fullDestination,
            currentUserId: widget.currentUserId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error opening destination detail: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load destination details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Stats
  int get placesVisited => _history.length;

  Set<String> get uniqueCategories {
    return _history.map((e) => (e['category'] as String?) ?? 'Other').toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.history_toggle_off,
                    size: 100, color: Colors.blueGrey),
                const SizedBox(height: 24),
                const Text(
                  "Your Travel History is waiting!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565FF),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Sign in to see the places you've visited and your journey stats in Misamis Oriental.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text("Sign In / Register"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Continue browsing as guest"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header
          _buildHeader(context),

          // Main content with working refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _loadHistory(isRefresh: true);
                // Optional: small delay to make refresh feel natural
                await Future.delayed(const Duration(milliseconds: 300));
              },
              color: const Color(0xFF1565FF),
              backgroundColor: Colors.white,
              displacement: 60, // positions spinner nicely below header
              strokeWidth: 3,
              triggerMode: RefreshIndicatorTriggerMode.onEdge,
              child: _isLoading && _history.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _history.isEmpty
                      ? _buildEmptyState()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                          physics:
                              const AlwaysScrollableScrollPhysics(), // allows pull even when content is short
                          children: [
                            // Categories Explored
                            const Text(
                              'Categories Explored',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B2559),
                              ),
                            ),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: uniqueCategories.map((cat) {
                                final count = _history
                                    .where((e) =>
                                        (e['category'] as String?) == cat)
                                    .length;
                                return _buildCategoryChip('$cat ($count)');
                              }).toList(),
                            ),

                            const SizedBox(height: 25),

                            // Recent Visits
                            Text(
                              'Recent Visits ($placesVisited)',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B2559),
                              ),
                            ),
                            const SizedBox(height: 15),

                            ..._history.map((item) {
                              return GestureDetector(
                                onTap: () {
                                  final destinationId =
                                      item['destination_id']?.toString();
                                  if (destinationId == null ||
                                      destinationId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Invalid destination')),
                                    );
                                    return;
                                  }
                                  _openDestinationDetail(destinationId);
                                },
                                child: _buildHistoryCard(item),
                              );
                            }).toList(),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFF1565FF),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 10),
                      const Icon(Icons.history, color: Colors.white, size: 28),
                      const SizedBox(width: 10),
                      const Text(
                        'Travel History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Padding(
                    padding: EdgeInsets.only(left: 72),
                    child: Text(
                      'Your journey so far',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -30,
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
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('$placesVisited', 'Places Visited'),
                Container(width: 1, height: 40, color: Colors.grey[200]),
                _buildStatItem(
                    '${uniqueCategories.length}', 'Categories Explored'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFAA00FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFAA00FF),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final name = item['destination_name'] as String? ?? 'Unknown Place';
    final dateStr = item['visited_at'] as String?;
    final imageUrl = item['image_url'] as String? ??
        'https://via.placeholder.com/80x80?text=No+Image';

    final formattedDate = dateStr != null
        ? DateFormat('MMM dd, yyyy • h:mm a')
            .format(DateTime.parse(dateStr).toLocal())
        : 'Unknown date';

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
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
              imageUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[200],
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: Colors.grey[300],
                child: const Icon(Icons.image_not_supported,
                    color: Colors.grey, size: 40),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1B2559),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_toggle_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No travel history yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start exploring and mark destinations as visited!',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
