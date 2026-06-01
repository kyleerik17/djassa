// lib/core/utils/icon_mapper.dart
import 'package:flutter/material.dart';

/// Mapper centralisé pour convertir IconData ↔ String (pour Supabase)
class IconMapper {
  // ✅ Map String → IconData (clé = String, compatible avec const/final)
  static final _iconMap = <String, IconData>{
    'settings_rounded': Icons.settings_rounded,
    'circle_rounded': Icons.circle_rounded,
    'memory_rounded': Icons.memory_rounded,
    'wifi_tethering_rounded': Icons.wifi_tethering_rounded,
    'thermostat_rounded': Icons.thermostat_rounded,
    'cable_rounded': Icons.cable_rounded,
    'build_rounded': Icons.build_rounded,
    'handyman_rounded': Icons.handyman_rounded,
    'bolt_rounded': Icons.bolt_rounded,
    'storefront_rounded': Icons.storefront_rounded,
    'category_rounded': Icons.category_rounded,
    'home_rounded': Icons.home_rounded,
    'checkroom_rounded': Icons.checkroom_rounded,
    'spa_rounded': Icons.spa_rounded,
    'sports_soccer_rounded': Icons.sports_soccer_rounded,
    'devices_rounded': Icons.devices_rounded,
    'motion_photos_pause': Icons.motion_photos_pause,
    'car_repair': Icons.car_repair,
    'electric_bolt': Icons.electric_bolt,
    'opacity': Icons.opacity,
    'vertical_align_center': Icons.vertical_align_center,
    'light_mode': Icons.light_mode,
    'trip_origin': Icons.trip_origin,
    'dashboard_customize': Icons.dashboard_customize,
    'directions_car': Icons.directions_car,
    // ➕ Ajoutez vos icônes ici au besoin
  };

  /// Convertit un nom d'icône (String) en IconData
  static IconData fromString(String? iconName) {
    if (iconName == null || iconName.isEmpty) return Icons.storefront_rounded;
    return _iconMap[iconName] ?? Icons.storefront_rounded;
  }

  /// ✅ RENOMMÉ : Convertit une IconData en nom d'icône (String) pour Supabase
  static String toIconName(IconData icon) {
    final entry = _iconMap.entries.firstWhere(
      (e) => e.value == icon,
      orElse: () => const MapEntry('storefront_rounded', Icons.storefront_rounded),
    );
    return entry.key;
  }

  /// Vérifie si une icône est supportée
  static bool isSupported(IconData icon) {
    return _iconMap.containsValue(icon);
  }

  /// Liste de tous les noms d'icônes disponibles (pour un picker UI)
  static List<String> get availableIconNames => _iconMap.keys.toList();
}