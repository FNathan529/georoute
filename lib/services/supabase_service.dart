import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Safe getter with null check — throws clear error if Supabase not ready
  SupabaseClient get client {
    final c = Supabase.instance.client;
    if (c == null) {
      throw Exception(
        "Supabase client is null. "
        "Make sure Supabase.initialize() completed in main.dart BEFORE using any service.",
      );
    }
    return c;
  }

  // ────────────────────────────────────────────────
  //  USER REGISTRATION & LOGIN
  // ────────────────────────────────────────────────
  Future<void> registerUser({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    await client.from('users').insert({
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'registration_status': 'pending',
      'role': 'tourist',
    });
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final response =
        await client.from('users').select().eq('email', email).maybeSingle();
    return response as Map<String, dynamic>?;
  }

  // ────────────────────────────────────────────────
  //  DESTINATIONS (User + Admin)
  // ────────────────────────────────────────────────

  /// Get active destinations for users (filtered)
  Future<List<Map<String, dynamic>>> getDestinations() async {
    final response = await client
        .from('destinations')
        .select()
        .eq('status', 'active')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get recent destinations for dashboard (sorted by created_at)
  Future<List<Map<String, dynamic>>> getRecentDestinations({
    int limit = 5,
  }) async {
    try {
      final response = await client
          .from('destinations')
          .select('id, name, category, image_url, status, created_at')
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching recent destinations: $e');
      return [];
    }
  }

  /// Get ALL destinations for admin (unfiltered)
  Future<List<Map<String, dynamic>>> getAllDestinations() async {
    final response = await client
        .from('destinations')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Add new destination (admin only)
  Future<void> addDestination(Map<String, dynamic> data) async {
    await client.from('destinations').insert(data);
  }

  /// Update existing destination (admin only)
  Future<void> updateDestination(
      String id, Map<String, dynamic> updates) async {
    await client.from('destinations').update(updates).eq('id', id);
  }

  /// Delete destination (admin only)
  Future<void> deleteDestination(String id) async {
    await client.from('destinations').delete().eq('id', id);
  }

  // ────────────────────────────────────────────────
  //  USERS (Admin Approval & Management)
  // ────────────────────────────────────────────────

  /// Get all users for admin_users page
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await client
        .from('users')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Approve or reject a user
  Future<void> updateUserStatus(String userId, String newStatus) async {
    await client
        .from('users')
        .update({'registration_status': newStatus}).eq('id', userId);
  }

  // ────────────────────────────────────────────────
  //  TRAVEL HISTORY & PLANNER
  // ────────────────────────────────────────────────

  Future<void> addToHistory({
    required String userId,
    required String destinationId,
    required String destinationName,
    String? note,
    double? rating,
  }) async {
    await client.from('travel_history').insert({
      'user_id': userId,
      'destination_id': destinationId,
      'destination_name': destinationName,
      'note': note ?? '',
      'rating_given': rating,
    });
  }

  Future<List<Map<String, dynamic>>> getUserHistory(String userId) async {
    final response = await client
        .from('travel_history')
        .select()
        .eq('user_id', userId)
        .order('visited_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTripPlan(String userId) async {
    final response = await client
        .from('trip_plans')
        .select()
        .eq('user_id', userId)
        .order('order_index', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addToPlan({
    required String userId,
    required Map<String, dynamic> destination,
    required int orderIndex,
  }) async {
    await client.from('trip_plans').insert({
      'user_id': userId,
      'destination_id': destination['destination_id'],
      'name': destination['name'],
      'type': destination['type'],
      'distance': destination['distance'],
      'duration': destination['duration'],
      'cost': destination['cost'],
      'image': destination['image'],
      'order_index': orderIndex,
    });
  }

  Future<void> updatePlan(
      String userId, List<Map<String, dynamic>> newPlan) async {
    await client.from('trip_plans').delete().eq('user_id', userId);

    for (int i = 0; i < newPlan.length; i++) {
      await addToPlan(
        userId: userId,
        destination: newPlan[i],
        orderIndex: i,
      );
    }
  }

  Future<void> clearPlan(String userId) async {
    await client.from('trip_plans').delete().eq('user_id', userId);
  }

  /// Get all category names for dropdowns
  Future<List<String>> getCategoryNames() async {
    final response = await client
        .from('categories')
        .select('name')
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((row) => row['name'] as String)
        .toList();
  }

  // ────────────────────────────────────────────────
  //  DESTINATION COMMENTS & RATINGS (User Reviews)
  // ────────────────────────────────────────────────

  // Add comment + optional rating (1-5 stars)
  Future<void> addDestinationComment({
    required String destinationId,
    required String commentText,
    int? rating, // 1-5 or null
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not logged in');

    await client.from('destination_comments').insert({
      'destination_id': destinationId,
      'user_id': userId,
      'comment_text': commentText.trim(),
      'rating': rating,
    });
  }

  // Get comments for a destination (with username from users table)
// Get comments for a destination (with username join)
  /// Returns a map with:
  /// - 'comments': List<Map> of enriched comments
  /// - 'avg_rating': String (e.g. '4.3' or '0.0')
  /// - 'rating_count': int (total number of ratings)
  Future<Map<String, dynamic>> getDestinationComments(
      String destinationId) async {
    try {
      debugPrint('Fetching comments + rating for ID: $destinationId');

      // 1. Get comments + user IDs
      final comments = await client
          .from('destination_comments')
          .select('id, comment_text, rating, created_at, user_id')
          .eq('destination_id', destinationId)
          .order('created_at', ascending: false);

      // 2. Calculate avg rating & count right here (no extra query)
      double avgRating = 0.0;
      int ratingCount = 0;

      if (comments.isNotEmpty) {
        final ratings = comments
            .where((c) => c['rating'] != null)
            .map((c) => (c['rating'] as num).toDouble())
            .toList();

        if (ratings.isNotEmpty) {
          avgRating = ratings.reduce((a, b) => a + b) / ratings.length;
          ratingCount = ratings.length;
        }
      }

      debugPrint('Calculated avg: $avgRating from $ratingCount ratings');

      // 3. Get usernames if there are comments
      List<Map<String, dynamic>> enrichedComments = comments;

      if (comments.isNotEmpty) {
        final userIds = comments.map((c) => c['user_id']).toSet().toList();
        final users = await client
            .from('users')
            .select('id, full_name')
            .inFilter('id', userIds);

        final userMap = {
          for (var u in users) u['id']: u['full_name'] ?? 'Anonymous'
        };

        enrichedComments = comments.map((c) {
          return {
            ...c,
            'users': {'full_name': userMap[c['user_id']] ?? 'Anonymous'},
          };
        }).toList();
      }

      debugPrint('Comments enriched: ${enrichedComments.length}');

      // 4. Return everything in one nice map
      return {
        'comments': enrichedComments,
        'avg_rating': avgRating.toStringAsFixed(1),
        'rating_count': ratingCount,
      };
    } catch (e) {
      debugPrint('getDestinationComments error: $e');
      return {
        'comments': <Map<String, dynamic>>[],
        'avg_rating': '0.0',
        'rating_count': 0,
      };
    }
  }
  // ────────────────────────────────────────────────
  //  ADMIN DASHBOARD & REPORTS STATS
  // ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminStats() async {
    final destTotal = await client.from('destinations').select('id').count();
    final destActive = await client
        .from('destinations')
        .select('id')
        .eq('status', 'active')
        .count();

    final userTotal = await client.from('users').select('id').count();
    final userPending = await client
        .from('users')
        .select('id')
        .eq('registration_status', 'pending')
        .count();

    return {
      'total_destinations': destTotal.count ?? 0,
      'active_destinations': destActive.count ?? 0,
      'total_users': userTotal.count ?? 0,
      'pending_users': userPending.count ?? 0,
    };
  }

  Future<Map<String, dynamic>> getReportStats() async {
    try {
      final dest = await client.from('destinations').select('''
          count(*)::integer as total, 
          count(*) filter (where status = 'active')::integer as active
        ''').single();

      final users = await client.from('users').select('''
          count(*)::integer as total, 
          count(*) filter (where registration_status = 'pending')::integer as pending
        ''').single();

      final avg = await client
          .from('destinations')
          .select('avg(rating)::numeric as avg_rating')
          .single();

      debugPrint('REPORT STATS SUCCESS - total dest: ${dest['total'] ?? 0}');

      return {
        'total_destinations': dest['total'] ?? 0,
        'active_destinations': dest['active'] ?? 0,
        'total_users': users['total'] ?? 0,
        'pending_users': users['pending'] ?? 0,
        'avg_rating': (avg['avg_rating'] as num?)?.toStringAsFixed(1) ?? '0.0',
        'monthly_visits': 'Tracking coming soon',
      };
    } catch (e) {
      debugPrint('getReportStats error: $e');
      return {
        'total_destinations': 0,
        'active_destinations': 0,
        'total_users': 0,
        'pending_users': 0,
        'avg_rating': '0.0',
        'monthly_visits': 'N/A',
      };
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    try {
      final response = await client.from('destinations').select('''
          category, 
          count(*)::integer as destinations, 
          avg(rating)::numeric as rating
        ''').order('category', ascending: true);

      debugPrint('CATEGORY STATS SUCCESS - rows: ${response.length}');

      final List<Map<String, dynamic>> result = [
        {
          'category': 'Category',
          'destinations': 'Destinations',
          'rating': 'Avg Rating'
        },
      ];

      for (final row in response) {
        result.add({
          'category': row['category'] as String? ?? 'Uncategorized',
          'destinations': row['destinations'] as int? ?? 0,
          'rating': (row['rating'] as num?)?.toStringAsFixed(1) ?? 'N/A',
        });
      }

      return result;
    } catch (e) {
      debugPrint('getCategoryStats error: $e');
      return [
        {
          'category': 'Category',
          'destinations': 'Destinations',
          'rating': 'Avg Rating'
        },
        {'category': 'Error loading data', 'destinations': '-', 'rating': '-'},
      ];
    }
  }
}
