import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/supabase_service.dart';

class DeliveryTrackingQuery {
  const DeliveryTrackingQuery({
    required this.orderId,
    required this.address,
    required this.createdAt,
    required this.deliveryAt,
    this.clientLatitude,
    this.clientLongitude,
  });

  final String orderId;
  final String address;
  final DateTime createdAt;
  final DateTime deliveryAt;
  final double? clientLatitude;
  final double? clientLongitude;
}

class DeliveryLivePoint {
  const DeliveryLivePoint({
    required this.position,
    required this.updatedAt,
    required this.isRealtime,
    required this.label,
  });

  final LatLng position;
  final DateTime updatedAt;
  final bool isRealtime;
  final String label;
}

class DeliveryLiveSnapshot {
  const DeliveryLiveSnapshot({
    required this.client,
    required this.courier,
    required this.hasCourierRealtime,
    required this.hasClientRealtime,
  });

  final DeliveryLivePoint client;
  final DeliveryLivePoint courier;
  final bool hasCourierRealtime;
  final bool hasClientRealtime;
}

class DeliveryPositionPublishStatus {
  const DeliveryPositionPublishStatus({
    required this.role,
    required this.updatedAt,
    required this.isLive,
    required this.message,
    this.position,
  });

  final String role;
  final DateTime updatedAt;
  final bool isLive;
  final String message;
  final LatLng? position;
}

class DeliveryTrackingService {
  DeliveryTrackingService({SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final SupabaseClient _client;

  static const LatLng warehousePosition = LatLng(5.3599, -4.0083);

  Future<LatLng?> getCurrentClientPosition() async {
    final position = await _getCurrentPosition();
    if (position == null) return null;
    return LatLng(position.latitude, position.longitude);
  }

  /// Publie en continu la vraie position GPS de l'appareil dans Supabase.
  ///
  /// Utilise le role `client` dans l'application client. Le meme flux peut etre
  /// reutilise cote livreur avec `role: 'courier'` dans l'app/compte livreur.
  Stream<DeliveryPositionPublishStatus> publishDevicePosition({
    required String orderId,
    required String role,
    int distanceFilterMeters = 12,
  }) async* {
    final first = await _getCurrentPosition();
    if (first == null) {
      yield DeliveryPositionPublishStatus(
        role: role,
        updatedAt: DateTime.now(),
        isLive: false,
        message: 'GPS indisponible ou permission refusee',
      );
      return;
    }

    yield await _publishPosition(orderId: orderId, role: role, value: first);

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilterMeters,
    );

    try {
      await for (final position in Geolocator.getPositionStream(
        locationSettings: settings,
      )) {
        yield await _publishPosition(
          orderId: orderId,
          role: role,
          value: position,
        );
      }
    } catch (_) {
      yield DeliveryPositionPublishStatus(
        role: role,
        updatedAt: DateTime.now(),
        isLive: false,
        message: 'Flux GPS interrompu',
      );
    }
  }

  Future<DeliveryPositionPublishStatus> _publishPosition({
    required String orderId,
    required String role,
    required Position value,
  }) async {
    final point = LatLng(value.latitude, value.longitude);
    final synced = await upsertPosition(
      orderId: orderId,
      role: role,
      position: point,
    );
    return DeliveryPositionPublishStatus(
      role: role,
      updatedAt: DateTime.now(),
      isLive: synced,
      position: point,
      message: synced
          ? 'Position GPS synchronisee'
          : 'GPS lu, synchronisation Supabase impossible',
    );
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> upsertPosition({
    required String orderId,
    required String role,
    required LatLng position,
  }) async {
    try {
      await _client.from('delivery_locations').upsert(
        {
          'order_id': orderId,
          'role': role,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'order_id,role',
      );
      return true;
    } catch (_) {
      // La table/policy peut ne pas encore exister en dev : l'app garde un fallback.
      return false;
    }
  }

  Stream<DeliveryLiveSnapshot> watchOrder(DeliveryTrackingQuery query) async* {
    yield await _fetchSnapshot(query);

    try {
      await for (final rows in _client
          .from('delivery_locations')
          .stream(primaryKey: ['id']).eq('order_id', query.orderId)) {
        yield _snapshotFromRows(rows, query);
      }
    } catch (_) {
      // Fallback polling si le realtime Supabase n'est pas active ou si la
      // table n'a pas encore ete ajoutee a la publication supabase_realtime.
      while (true) {
        yield await _fetchSnapshot(query);
        await Future<void>.delayed(const Duration(seconds: 8));
      }
    }
  }

  Future<DeliveryLiveSnapshot> _fetchSnapshot(
    DeliveryTrackingQuery query,
  ) async {
    try {
      final rows = await _client
          .from('delivery_locations')
          .select()
          .eq('order_id', query.orderId);

      return _snapshotFromRows(rows, query);
    } catch (_) {
      return fallbackSnapshot(query, DateTime.now());
    }
  }

  DeliveryLiveSnapshot _snapshotFromRows(
    List<dynamic> rows,
    DeliveryTrackingQuery query,
  ) {
    DeliveryLivePoint? client;
    DeliveryLivePoint? courier;
    for (final row in rows) {
      final json = Map<String, dynamic>.from(row as Map);
      final point = _pointFromJson(json);
      if (point == null) continue;
      final role = '${json['role']}';
      if (role == 'client') client = point.copyWith(label: 'Client');
      if (role == 'courier') courier = point.copyWith(label: 'Livreur');
    }

    final fallback = fallbackSnapshot(query, DateTime.now());
    return DeliveryLiveSnapshot(
      client: client ?? fallback.client,
      courier: courier ?? fallback.courier,
      hasClientRealtime: client != null,
      hasCourierRealtime: courier != null,
    );
  }

  static DeliveryLiveSnapshot fallbackSnapshot(
    DeliveryTrackingQuery query,
    DateTime now,
  ) {
    final clientPosition =
        query.clientLatitude != null && query.clientLongitude != null
            ? LatLng(query.clientLatitude!, query.clientLongitude!)
            : approximateAddressPosition(query.address);
    final progress = _progress(query, now);
    final courierPosition = _interpolate(
      warehousePosition,
      clientPosition,
      progress,
    );

    return DeliveryLiveSnapshot(
      client: DeliveryLivePoint(
        position: clientPosition,
        updatedAt: now,
        isRealtime:
            query.clientLatitude != null && query.clientLongitude != null,
        label: 'Client',
      ),
      courier: DeliveryLivePoint(
        position: courierPosition,
        updatedAt: now,
        isRealtime: false,
        label: 'Livreur',
      ),
      hasClientRealtime:
          query.clientLatitude != null && query.clientLongitude != null,
      hasCourierRealtime: false,
    );
  }

  static LatLng approximateAddressPosition(String address) {
    final lower = address.toLowerCase();
    if (lower.contains('abobo')) return const LatLng(5.4300, -4.0200);
    if (lower.contains('adjam')) return const LatLng(5.3650, -4.0230);
    if (lower.contains('cocody')) return const LatLng(5.3600, -3.9670);
    if (lower.contains('yopougon')) return const LatLng(5.3470, -4.0910);
    if (lower.contains('marcory')) return const LatLng(5.3020, -3.9850);
    if (lower.contains('koumassi')) return const LatLng(5.3000, -3.9500);
    if (lower.contains('plateau')) return const LatLng(5.3200, -4.0160);
    if (lower.contains('port-bou')) return const LatLng(5.2600, -3.9300);
    if (lower.contains('treichville')) return const LatLng(5.2950, -4.0080);
    if (lower.contains('bingerville')) return const LatLng(5.3550, -3.8850);
    if (lower.contains('anyama')) return const LatLng(5.4940, -4.0510);
    if (lower.contains('songon')) return const LatLng(5.3190, -4.2500);
    if (lower.contains('grand-bassam')) return const LatLng(5.2118, -3.7388);
    return const LatLng(5.3364, -4.0267);
  }

  DeliveryLivePoint? _pointFromJson(Map<String, dynamic> json) {
    final latitude = double.tryParse('${json['latitude']}');
    final longitude = double.tryParse('${json['longitude']}');
    if (latitude == null || longitude == null) return null;
    return DeliveryLivePoint(
      position: LatLng(latitude, longitude),
      updatedAt: DateTime.tryParse('${json['updated_at']}') ?? DateTime.now(),
      isRealtime: true,
      label: '${json['role']}',
    );
  }

  static double _progress(DeliveryTrackingQuery query, DateTime now) {
    final deliveryMorning = DateTime(
      query.deliveryAt.year,
      query.deliveryAt.month,
      query.deliveryAt.day,
      8,
    );
    if (!now.isBefore(query.deliveryAt)) return 1;
    if (now.isBefore(deliveryMorning)) return .18;
    final total = query.deliveryAt.difference(deliveryMorning).inSeconds;
    final elapsed = now.difference(deliveryMorning).inSeconds;
    return (.20 + (.74 * (elapsed / total))).clamp(.20, .94);
  }

  static LatLng _interpolate(LatLng start, LatLng end, double progress) {
    return LatLng(
      start.latitude + ((end.latitude - start.latitude) * progress),
      start.longitude + ((end.longitude - start.longitude) * progress),
    );
  }
}

extension on DeliveryLivePoint {
  DeliveryLivePoint copyWith({String? label}) {
    return DeliveryLivePoint(
      position: position,
      updatedAt: updatedAt,
      isRealtime: isRealtime,
      label: label ?? this.label,
    );
  }
}
