import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;

  get supabase => null;

  // ────────────────────────────────────────────────
  //  USER REGISTRATION & LOGIN
  // ────────────────────────────────────────────────
  Future<void> registerUser({
    required String fullName,
    required String email,
    required String phone,
  }) async {
    await _client.from('users').insert({
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'registration_status': 'pending',
      'role': 'tourist',
    });
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final response =
        await _client.from('users').select().eq('email', email).maybeSingle();
    return response as Map<String, dynamic>?;
  }

  // ────────────────────────────────────────────────
  //  DESTINATIONS (User + Admin)
  // ────────────────────────────────────────────────

  /// Get active destinations for users (filtered)
  Future<List<Map<String, dynamic>>> getDestinations() async {
    final response = await _client
        .from('destinations')
        .select()
        .eq('status', 'active')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Get ALL destinations for admin (unfiltered)
  Future<List<Map<String, dynamic>>> getAllDestinations() async {
    final response = await _client
        .from('destinations')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Add new destination (admin only)
  Future<void> addDestination(Map<String, dynamic> data) async {
    await _client.from('destinations').insert(data);
  }

  /// Update existing destination (admin only)
  Future<void> updateDestination(
      String id, Map<String, dynamic> updates) async {
    await _client.from('destinations').update(updates).eq('id', id);
  }

  /// Delete destination (admin only)
  Future<void> deleteDestination(String id) async {
    await _client.from('destinations').delete().eq('id', id);
  }

  // ────────────────────────────────────────────────
  //  USERS (Admin Approval & Management)
  // ────────────────────────────────────────────────

  /// Get all users for admin_users page
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Approve or reject a user
  Future<void> updateUserStatus(String userId, String newStatus) async {
    await _client
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
    await _client.from('travel_history').insert({
      'user_id': userId,
      'destination_id': destinationId,
      'destination_name': destinationName,
      'note': note ?? '',
      'rating_given': rating,
    });
  }

  Future<List<Map<String, dynamic>>> getUserHistory(String userId) async {
    final response = await _client
        .from('travel_history')
        .select()
        .eq('user_id', userId)
        .order('visited_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTripPlan(String userId) async {
    final response = await _client
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
    await _client.from('trip_plans').insert({
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
    await _client.from('trip_plans').delete().eq('user_id', userId);

    for (int i = 0; i < newPlan.length; i++) {
      await addToPlan(
        userId: userId,
        destination: newPlan[i],
        orderIndex: i,
      );
    }
  }

  Future<void> clearPlan(String userId) async {
    await _client.from('trip_plans').delete().eq('user_id', userId);
  }

  /// Get all category names for dropdowns
  Future<List<String>> getCategoryNames() async {
    final response = await _client
        .from('categories')
        .select('name')
        .order('name', ascending: true);

    return (response as List<dynamic>)
        .map((row) => row['name'] as String)
        .toList();
  }

  // ────────────────────────────────────────────────
  //  ADMIN DASHBOARD STATS
  // ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getAdminStats() async {
    final destTotal = await _client.from('destinations').select('id').count();
    final destActive = await _client
        .from('destinations')
        .select('id')
        .eq('status', 'active')
        .count();

    final userTotal = await _client.from('users').select('id').count();
    final userPending = await _client
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
}
