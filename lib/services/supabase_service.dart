import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../utils/connectivity_helper.dart';

class SupabaseService {
  // Safe client getter with clear error
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

  Future<List<Map<String, dynamic>>> getDestinations({
    int page = 1,
    int limit = 15,
  }) async {
    final response = await client
        .from('destinations')
        .select()
        .eq('status', 'active')
        .order('name', ascending: true)
        .range((page - 1) * limit, page * limit - 1);
    return List<Map<String, dynamic>>.from(response);
  }

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

  Future<List<Map<String, dynamic>>> getAllDestinations() async {
    final response = await client
        .from('destinations')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addDestination(Map<String, dynamic> data) async {
    await client.from('destinations').insert(data);
  }

  Future<void> updateDestination(
      String id, Map<String, dynamic> updates) async {
    await client.from('destinations').update(updates).eq('id', id);
  }

  Future<void> deleteDestination(String id) async {
    await client.from('destinations').delete().eq('id', id);
  }

  // ────────────────────────────────────────────────
  //  USERS (Admin Approval & Management)
  // ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await client
        .from('users')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

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
    String? imageUrl,
    String? category,
  }) async {
    await client.from('travel_history').insert({
      'user_id': userId,
      'destination_id': destinationId,
      'destination_name': destinationName,
      'image_url': imageUrl,
      'category': category ?? 'Unknown', // Ensures category is always saved
      'visited_at': DateTime.now().toIso8601String(),
    });
    debugPrint(
        'Added to history: $destinationName (category: ${category ?? 'Unknown'})');
  }

  Future<List<Map<String, dynamic>>> getUserHistory(String userId) async {
    final response = await client
        .from('travel_history')
        .select(
            '*, category, image_url') // Explicitly fetch category & image_url
        .eq('user_id', userId)
        .order('visited_at', ascending: false);

    debugPrint('History loaded: ${response.length} entries');
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
      'category': destination['category'] ?? 'Unknown',
      'location': destination['location'],
      'travel_time': destination['travel_time'],
      'price_range': destination['price_range'],
      'image_url': destination['image_url'],
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
  //  DESTINATION COMMENTS & RATINGS
  // ────────────────────────────────────────────────

  Future<void> addDestinationComment({
    required String destinationId,
    required String commentText,
    int? rating,
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

  Future<Map<String, dynamic>> getDestinationComments(
      String destinationId) async {
    try {
      final comments = await client
          .from('destination_comments')
          .select('id, comment_text, rating, created_at, user_id')
          .eq('destination_id', destinationId)
          .order('created_at', ascending: false);

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
  //  ADMIN DASHBOARD & REPORTS
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

  Future<T> safeSupabaseCall<T>(Future<T> Function() call) async {
    try {
      if (!await isConnected()) {
        throw Exception('No internet connection');
      }
      return await call();
    } catch (e) {
      String userMessage = 'Something went wrong. Please try again.';

      if (e.toString().contains('No internet')) {
        userMessage = 'No internet connection. Please check your data.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('SocketException')) {
        userMessage = 'Connection timed out. Your network may be slow.';
      } else if (e.toString().contains('403') || e.toString().contains('401')) {
        userMessage = 'Authentication issue. Please log in again.';
      }

      throw Exception(userMessage);
    }
  }

  Future<List<Map<String, dynamic>>> getCategoryStats() async {
    try {
      final response = await client.from('destinations').select('''
          category, 
          count(*)::integer as destinations, 
          avg(rating)::numeric as rating
        ''').order('category', ascending: true);

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
