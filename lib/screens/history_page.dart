import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/destination_detail.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import 'destination_detail.dart'; // ← Import your detail page here
import 'home_page.dart'; // if needed

class HistoryPage extends StatefulWidget {
  final String currentUserId;

  const HistoryPage({Key? key, required this.currentUserId}) : super(key: key);

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
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getUserHistory(widget.currentUserId);
      setState(() {
        _history = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
    }
  }

  // Calculate stats (used in header)
  int get placesVisited => _history.length;

  Set<String> get uniqueCategories {
    return _history.map((e) => (e['category'] as String?) ?? 'Other').toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Your beautiful header
          _buildHeader(context),

          // Scrollable content with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadHistory,
              color: const Color(0xFF1565FF),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                physics: const BouncingScrollPhysics(),
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

                  // Category Chips
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: uniqueCategories.map((cat) {
                      final count = _history
                          .where((e) => (e['category'] as String?) == cat)
                          .length;
                      return _buildCategoryChip('$cat ($count)');
                    }).toList(),
                  ),

                  const SizedBox(height: 25),

                  // Recent Visits Title
                  Text(
                    'Recent Visits ($placesVisited)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B2559),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Loading / Empty / Content
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_history.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 100),
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No travel history yet',
                                style: TextStyle(
                                    fontSize: 18, color: Colors.grey)),
                            SizedBox(height: 8),
                            Text(
                              'Start exploring and mark destinations as visited!',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._history.map((item) {
                      return GestureDetector(
                        onTap: () {
                          // Navigate to DestinationDetailPage on tap
                          final destinationData = {
                            'id': item['destination_id'],
                            'name': item['destination_name'],
                            'category': item['category'] ?? 'Unknown',
                            'image_url': item['image_url'] ??
                                'https://via.placeholder.com/400x225',
                            'latitude': item['latitude'],
                            'longitude': item['longitude'],
                            'description': item['description'] ??
                                'No description available.',
                            // Add more fields if available in travel_history
                            // or fetch full data using ID if needed
                          };

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DestinationDetailPage(
                                destination: destinationData,
                                currentUserId: widget.currentUserId,
                              ),
                            ),
                          );
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

  // Your header (unchanged)
  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: const BoxDecoration(
            color: Color(0xFF0000FF),
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

        // Floating Stats Card
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
    final note = item['note'] as String?;
    final rating = (item['rating_given'] as num?)?.toDouble() ?? 0.0;

    final formattedDate = dateStr != null
        ? DateFormat('MMM dd, yyyy • h:mm a')
            .format(DateTime.parse(dateStr).toLocal()) // ← same fix here
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
            child: Container(
              width: 80,
              height: 80,
              color: Colors.grey[300],
              child: const Icon(Icons.image, color: Colors.grey, size: 40),
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
                    Text(formattedDate,
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.description_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Rating: ', style: TextStyle(fontSize: 12)),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < rating ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 16,
                        );
                      }),
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
}
