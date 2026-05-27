import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class CourierProfile {
  const CourierProfile({
    this.licenseNumber = '',
    this.licenseType = 'A',
    this.licensePhotoUrl = '',
    this.vehicleType = 'Moto',
    this.vehiclePlate = '',
    this.emergencyPhone = '',
    this.isAvailable = true,
  });

  final String licenseNumber;
  final String licenseType;
  final String licensePhotoUrl;
  final String vehicleType;
  final String vehiclePlate;
  final String emergencyPhone;
  final bool isAvailable;

  /// Retourne true uniquement si tous les champs obligatoires
  /// sont renseignés, y compris la photo du permis.
  bool get isProfileComplete {
    return licenseNumber.trim().isNotEmpty &&
        licenseType.trim().isNotEmpty &&
        licensePhotoUrl.trim().isNotEmpty &&
        vehicleType.trim().isNotEmpty &&
        vehiclePlate.trim().isNotEmpty &&
        emergencyPhone.trim().isNotEmpty;
  }

  /// Liste des champs manquants pour affichage dans l'UI.
  List<String> get missingFields {
    final missing = <String>[];
    if (licenseNumber.trim().isEmpty) missing.add('Numéro de permis');
    if (licenseType.trim().isEmpty) missing.add('Type de permis');
    if (licensePhotoUrl.trim().isEmpty) missing.add('Photo du permis');
    if (vehicleType.trim().isEmpty) missing.add('Type de véhicule');
    if (vehiclePlate.trim().isEmpty) missing.add('Immatriculation');
    if (emergencyPhone.trim().isEmpty) missing.add('Contact urgence');
    return missing;
  }

  factory CourierProfile.fromJson(Map<String, dynamic> json) {
    return CourierProfile(
      licenseNumber: '${json['license_number'] ?? ''}',
      licenseType: '${json['license_type'] ?? 'A'}',
      licensePhotoUrl: '${json['license_photo_url'] ?? ''}',
      vehicleType: '${json['vehicle_type'] ?? 'Moto'}',
      vehiclePlate: '${json['vehicle_plate'] ?? ''}',
      emergencyPhone: '${json['emergency_phone'] ?? ''}',
      isAvailable: json['is_available'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
        'license_number': licenseNumber.trim(),
        'license_type': licenseType.trim().isEmpty ? 'A' : licenseType.trim(),
        'license_photo_url': licensePhotoUrl.trim(),
        'vehicle_type':
            vehicleType.trim().isEmpty ? 'Moto' : vehicleType.trim(),
        'vehicle_plate': vehiclePlate.trim(),
        'emergency_phone': emergencyPhone.trim(),
        'is_available': isAvailable,
      };
}

class CourierProfileService {
  CourierProfileService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  Future<CourierProfile> fetch() async {
    final user = _client.auth.currentUser;
    if (user == null) return const CourierProfile();

    try {
      final row = await _client
          .from('profiles')
          .select(
            'license_number, license_type, license_photo_url, '
            'vehicle_type, vehicle_plate, emergency_phone, is_available',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (row == null) return const CourierProfile();
      return CourierProfile.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isMissingCourierColumns(e)) {
        return const CourierProfile();
      }
      rethrow;
    }
  }

  Future<CourierProfile> save(CourierProfile profile) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Connectez-vous avant de modifier.');

    try {
      final row = await _client
          .from('profiles')
          .update(profile.toJson())
          .eq('id', user.id)
          .select(
            'license_number, license_type, license_photo_url, '
            'vehicle_type, vehicle_plate, emergency_phone, is_available',
          )
          .single();

      return CourierProfile.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (_isMissingCourierColumns(e)) {
        throw Exception(
          'Colonnes livreur manquantes dans Supabase. Execute le script '
          'supabase/courier_orders.sql ou ajoute les colonnes profiles.',
        );
      }
      rethrow;
    }
  }

  Future<void> setAvailability(bool value) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Connectez-vous avant de modifier.');
    try {
      await _client.from('profiles').update({
        'is_available': value,
      }).eq('id', user.id);
    } on PostgrestException catch (e) {
      if (_isMissingCourierColumns(e)) {
        throw Exception(
          'Colonne profiles.is_available manquante. Execute le SQL livreur.',
        );
      }
      rethrow;
    }
  }

  bool _isMissingCourierColumns(PostgrestException e) {
    final text = '${e.code} ${e.message} ${e.details} ${e.hint}'.toLowerCase();
    return text.contains('license_number') ||
        text.contains('license_type') ||
        text.contains('license_photo_url') ||
        text.contains('vehicle_type') ||
        text.contains('vehicle_plate') ||
        text.contains('emergency_phone') ||
        text.contains('is_available') ||
        text.contains('column') && text.contains('does not exist');
  }
}