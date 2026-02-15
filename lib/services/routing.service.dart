// lib/services/routing_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static const String _base = 'https://api.openrouteservice.org/v2/directions';
  static const String _apiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6Ijc1YzBhNWIzNDM5OTRjNzc4ZmMzN2YwN2M1OGE3NmJhIiwiaCI6Im11cm11cjY0In0='; // ← PASTE YOUR KEY HERE

  Future<Map<String, dynamic>?> getRouteWithInstructions({
    required LatLng from,
    required LatLng to,
    required bool isDriving,
  }) async {
    final profile = isDriving ? 'driving-car' : 'foot-walking';
    final uri = Uri.parse(
      '$_base/$profile?api_key=$_apiKey'
      '&start=${from.longitude},${from.latitude}'
      '&end=${to.longitude},${to.latitude}'
      '&instructions=true&overview=full&geometries=geojson',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        return json.decode(res.body);
      }
      print('ORS failed: ${res.statusCode}');
      return null;
    } catch (e) {
      print('Routing error: $e');
      return null;
    }
  }
}
