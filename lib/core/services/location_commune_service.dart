import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CommunePosition {
  const CommunePosition({
    required this.city,
    required this.commune,
    required this.position,
    required this.isGps,
  });

  final String city;
  final String commune;
  final LatLng position;
  final bool isGps;

  String get label => '$commune, $city';
}

class LocationCommuneService {
  static const _communes = <CommunePosition>[
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo',
      position: LatLng(5.4300, -4.0200),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Adjame',
      position: LatLng(5.3650, -4.0230),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Attecoube',
      position: LatLng(5.3500, -4.0350),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody',
      position: LatLng(5.3600, -3.9670),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Koumassi',
      position: LatLng(5.3000, -3.9500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory',
      position: LatLng(5.3020, -3.9850),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Plateau',
      position: LatLng(5.3200, -4.0160),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Port-Bouet',
      position: LatLng(5.2600, -3.9300),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Treichville',
      position: LatLng(5.2950, -4.0080),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon',
      position: LatLng(5.3470, -4.0910),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bingerville',
      commune: 'Bingerville Centre',
      position: LatLng(5.3550, -3.8850),
      isGps: false,
    ),
    CommunePosition(
      city: 'Anyama',
      commune: 'Anyama Centre',
      position: LatLng(5.4940, -4.0510),
      isGps: false,
    ),
    CommunePosition(
      city: 'Songon',
      commune: 'Songon Centre',
      position: LatLng(5.3190, -4.2500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Grand-Bassam',
      commune: 'Grand-Bassam Centre',
      position: LatLng(5.2118, -3.7388),
      isGps: false,
    ),
  ];

  static const CommunePosition fallback = CommunePosition(
    city: 'Abidjan',
    commune: 'Plateau',
    position: LatLng(5.3200, -4.0160),
    isGps: false,
  );

  Future<CommunePosition> currentCommune() async {
    final gps = await _currentPosition();
    if (gps == null) return fallback;
    final point = LatLng(gps.latitude, gps.longitude);
    final nearest = nearestCommune(point);
    return CommunePosition(
      city: nearest.city,
      commune: nearest.commune,
      position: point,
      isGps: true,
    );
  }

  static CommunePosition nearestCommune(LatLng point) {
    const distance = Distance();
    var nearest = fallback;
    var shortest = double.infinity;
    for (final commune in _communes) {
      final meters = distance(point, commune.position);
      if (meters < shortest) {
        shortest = meters;
        nearest = commune;
      }
    }
    return nearest;
  }

  Future<Position?> _currentPosition() async {
    if (kIsWeb) return null;
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
}
