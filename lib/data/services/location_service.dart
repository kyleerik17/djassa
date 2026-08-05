import 'package:djassa/core/services/supabase_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationPublisher {
  static Future<void> startTracking(String userId) async {
    // Permission check omitted for brevity
    
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50, // Update every 50 meters
      ),
    ).listen((Position position) {
      SupabaseService.client.from('courier_locations').upsert({
        'courier_id': userId,
        'lat': position.latitude,
        'lng': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      });
    });
  }
}