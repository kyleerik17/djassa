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
    // ─── ABIDJAN : 10 communes + quartiers ───────────────────────────────

    // Cocody
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Centre',
      position: LatLng(5.3600, -3.9670),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Angré',
      position: LatLng(5.3750, -3.9550),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Riviera',
      position: LatLng(5.3680, -3.9450),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody 2 Plateaux',
      position: LatLng(5.3520, -3.9750),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Vallon',
      position: LatLng(5.3580, -3.9620),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Anoumabo',
      position: LatLng(5.3550, -3.9580),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Abatta',
      position: LatLng(5.3650, -3.9700),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody M\'Badon',
      position: LatLng(5.3720, -3.9600),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Djorogobité',
      position: LatLng(5.3780, -3.9520),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody II Plateaux',
      position: LatLng(5.3480, -3.9800),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Angré 8ème Tranche',
      position: LatLng(5.3800, -3.9480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Angré 9ème Tranche',
      position: LatLng(5.3820, -3.9450),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Riviera Palmeraie',
      position: LatLng(5.3700, -3.9400),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Riviera Fanta',
      position: LatLng(5.3660, -3.9380),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Riviera Golf',
      position: LatLng(5.3640, -3.9420),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Cocody Angré Château',
      position: LatLng(5.3760, -3.9500),
      isGps: false,
    ),

    // Plateau
    CommunePosition(
      city: 'Abidjan',
      commune: 'Plateau Centre',
      position: LatLng(5.3200, -4.0160),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Plateau Banki',
      position: LatLng(5.3180, -4.0180),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Plateau Administratif',
      position: LatLng(5.3220, -4.0140),
      isGps: false,
    ),

    // Adjamé
    CommunePosition(
      city: 'Abidjan',
      commune: 'Adjamé Centre',
      position: LatLng(5.3650, -4.0230),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Adjamé Williamsville',
      position: LatLng(5.3680, -4.0250),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Adjamé Camp Félix',
      position: LatLng(5.3630, -4.0210),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Adjamé 22 Logements',
      position: LatLng(5.3660, -4.0270),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Adjamé Bel Horizon',
      position: LatLng(5.3640, -4.0200),
      isGps: false,
    ),

    // Plateau (déjà fait ci-dessus)

    // Treichville
    CommunePosition(
      city: 'Abidjan',
      commune: 'Treichville Centre',
      position: LatLng(5.2950, -4.0080),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Treichville Zone Industrielle',
      position: LatLng(5.2900, -4.0120),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Treichville Avocatier',
      position: LatLng(5.2980, -4.0050),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Treichville Gare Sud',
      position: LatLng(5.2920, -4.0100),
      isGps: false,
    ),

    // Marcory
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory Centre',
      position: LatLng(5.3020, -3.9850),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory Zone 4',
      position: LatLng(5.3050, -3.9820),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory Biétry',
      position: LatLng(5.3000, -3.9880),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory Anoumabo',
      position: LatLng(5.3040, -3.9800),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory Résidentiel',
      position: LatLng(5.2990, -3.9870),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Marcory Zone 3',
      position: LatLng(5.3060, -3.9840),
      isGps: false,
    ),

    // Koumassi
    CommunePosition(
      city: 'Abidjan',
      commune: 'Koumassi Centre',
      position: LatLng(5.3000, -3.9500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Koumassi Sicogi',
      position: LatLng(5.2980, -3.9480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Koumassi Résidentiel',
      position: LatLng(5.3020, -3.9520),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Koumassi Cité SIR',
      position: LatLng(5.2960, -3.9460),
      isGps: false,
    ),

    // Port-Bouët
    CommunePosition(
      city: 'Abidjan',
      commune: 'Port-Bouët Centre',
      position: LatLng(5.2600, -3.9300),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Port-Bouët Vridi',
      position: LatLng(5.2550, -3.9350),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Port-Bouët Aéroport',
      position: LatLng(5.2620, -3.9250),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Port-Bouët Vridi Canal',
      position: LatLng(5.2500, -3.9400),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Port-Bouët Gonzagueville',
      position: LatLng(5.2650, -3.9200),
      isGps: false,
    ),

    // Yopougon
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Centre',
      position: LatLng(5.3470, -4.0910),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Niangon',
      position: LatLng(5.3500, -4.0880),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Maroc',
      position: LatLng(5.3450, -4.0950),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Siporex',
      position: LatLng(5.3420, -4.0980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Selmer',
      position: LatLng(5.3480, -4.0930),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Toits Rouges',
      position: LatLng(5.3440, -4.0960),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Wassakara',
      position: LatLng(5.3520, -4.0850),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Camp Gaï',
      position: LatLng(5.3400, -4.1000),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon YM 1',
      position: LatLng(5.3460, -4.0920),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon YM 2',
      position: LatLng(5.3430, -4.0970),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon YM 3',
      position: LatLng(5.3410, -4.0990),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Cité des Sciences',
      position: LatLng(5.3490, -4.0870),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Yopougon Kouté',
      position: LatLng(5.3510, -4.0860),
      isGps: false,
    ),

    // Abobo
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Centre',
      position: LatLng(5.4300, -4.0200),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Baoulé',
      position: LatLng(5.4320, -4.0180),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Avocatier',
      position: LatLng(5.4280, -4.0220),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo PK18',
      position: LatLng(5.4350, -4.0150),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Gbêkro',
      position: LatLng(5.4260, -4.0250),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Abattoir',
      position: LatLng(5.4330, -4.0170),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Cité SIR',
      position: LatLng(5.4290, -4.0210),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Doumé',
      position: LatLng(5.4340, -4.0160),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Abobo Gare',
      position: LatLng(5.4310, -4.0190),
      isGps: false,
    ),

    // Attecoube
    CommunePosition(
      city: 'Abidjan',
      commune: 'Attecoube Centre',
      position: LatLng(5.3500, -4.0350),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Attecoube Allabra',
      position: LatLng(5.3520, -4.0330),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Attecoube Cité SIR',
      position: LatLng(5.3480, -4.0370),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Attecoube Camp Militaire',
      position: LatLng(5.3530, -4.0320),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abidjan',
      commune: 'Attecoube Cité des Arts',
      position: LatLng(5.3490, -4.0360),
      isGps: false,
    ),

    // ─── ABIDJAN PÉRIPHÉRIQUE ────────────────────────────────────────────

    // Anyama
    CommunePosition(
      city: 'Anyama',
      commune: 'Anyama Centre',
      position: LatLng(5.4940, -4.0510),
      isGps: false,
    ),
    CommunePosition(
      city: 'Anyama',
      commune: 'Anyama Est',
      position: LatLng(5.4960, -4.0480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Anyama',
      commune: 'Anyama Ouest',
      position: LatLng(5.4920, -4.0540),
      isGps: false,
    ),
    CommunePosition(
      city: 'Anyama',
      commune: 'Anyama Gare',
      position: LatLng(5.4950, -4.0500),
      isGps: false,
    ),

    // Bingerville
    CommunePosition(
      city: 'Bingerville',
      commune: 'Bingerville Centre',
      position: LatLng(5.3550, -3.8850),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bingerville',
      commune: 'Bingerville Gare',
      position: LatLng(5.3570, -3.8830),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bingerville',
      commune: 'Bingerville Anani',
      position: LatLng(5.3530, -3.8870),
      isGps: false,
    ),

    // Songon
    CommunePosition(
      city: 'Songon',
      commune: 'Songon Centre',
      position: LatLng(5.3190, -4.2500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Songon',
      commune: 'Songon Kassemblé',
      position: LatLng(5.3210, -4.2480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Songon',
      commune: 'Songon Attié',
      position: LatLng(5.3170, -4.2520),
      isGps: false,
    ),

    // Grand-Bassam
    CommunePosition(
      city: 'Grand-Bassam',
      commune: 'Grand-Bassam Centre',
      position: LatLng(5.2118, -3.7388),
      isGps: false,
    ),
    CommunePosition(
      city: 'Grand-Bassam',
      commune: 'Grand-Bassam Moossou',
      position: LatLng(5.2100, -3.7400),
      isGps: false,
    ),
    CommunePosition(
      city: 'Grand-Bassam',
      commune: 'Grand-Bassam Plage',
      position: LatLng(5.2080, -3.7350),
      isGps: false,
    ),
    CommunePosition(
      city: 'Grand-Bassam',
      commune: 'Grand-Bassam Cité Historique',
      position: LatLng(5.2130, -3.7370),
      isGps: false,
    ),

    // ─── AUTRES VILLES MAJEURES ──────────────────────────────────────────

    // Yamoussoukro (capitale politique)
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro Centre',
      position: LatLng(6.8276, -5.2893),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro Kpékplékro',
      position: LatLng(6.8300, -5.2850),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro Morokro',
      position: LatLng(6.8250, -5.2920),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro N\'Gokro',
      position: LatLng(6.8280, -5.2870),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro Habitat',
      position: LatLng(6.8320, -5.2830),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro Université',
      position: LatLng(6.8230, -5.2950),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yamoussoukro',
      commune: 'Yamoussoukro Basilique',
      position: LatLng(6.8290, -5.2880),
      isGps: false,
    ),

    // Bouaké (2ème ville)
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Centre',
      position: LatLng(7.6903, -5.0323),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Commerce',
      position: LatLng(7.6920, -5.0300),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Ahoua',
      position: LatLng(7.6880, -5.0350),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Bel Air',
      position: LatLng(7.6940, -5.0280),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Kokri',
      position: LatLng(7.6860, -5.0380),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Résidentiel',
      position: LatLng(7.6910, -5.0310),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Zone Industrielle',
      position: LatLng(7.6850, -5.0400),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Gare',
      position: LatLng(7.6930, -5.0290),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Dar Es Salam',
      position: LatLng(7.6870, -5.0360),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouaké',
      commune: 'Bouaké Aéroport',
      position: LatLng(7.6950, -5.0250),
      isGps: false,
    ),

    // San-Pédro (2ème port)
    CommunePosition(
      city: 'San-Pédro',
      commune: 'San-Pédro Centre',
      position: LatLng(4.7485, -6.6363),
      isGps: false,
    ),
    CommunePosition(
      city: 'San-Pédro',
      commune: 'San-Pédro Bardot',
      position: LatLng(4.7500, -6.6340),
      isGps: false,
    ),
    CommunePosition(
      city: 'San-Pédro',
      commune: 'San-Pédro Badjigui',
      position: LatLng(4.7460, -6.6380),
      isGps: false,
    ),
    CommunePosition(
      city: 'San-Pédro',
      commune: 'San-Pédro Port',
      position: LatLng(4.7450, -6.6400),
      isGps: false,
    ),
    CommunePosition(
      city: 'San-Pédro',
      commune: 'San-Pédro Cité des Pêcheurs',
      position: LatLng(4.7520, -6.6320),
      isGps: false,
    ),
    CommunePosition(
      city: 'San-Pédro',
      commune: 'San-Pédro Aéroport',
      position: LatLng(4.7550, -6.6300),
      isGps: false,
    ),

    // Daloa (capitale du cacao)
    CommunePosition(
      city: 'Daloa',
      commune: 'Daloa Centre',
      position: LatLng(6.8773, -6.4500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daloa',
      commune: 'Daloa Dogore',
      position: LatLng(6.8800, -6.4480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daloa',
      commune: 'Daloa Gadoké',
      position: LatLng(6.8750, -6.4520),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daloa',
      commune: 'Daloa Commerce',
      position: LatLng(6.8780, -6.4490),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daloa',
      commune: 'Daloa Résidentiel',
      position: LatLng(6.8760, -6.4510),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daloa',
      commune: 'Daloa Zone Industrielle',
      position: LatLng(6.8730, -6.4550),
      isGps: false,
    ),

    // Korhogo (nord)
    CommunePosition(
      city: 'Korhogo',
      commune: 'Korhogo Centre',
      position: LatLng(9.4580, -5.6295),
      isGps: false,
    ),
    CommunePosition(
      city: 'Korhogo',
      commune: 'Korhogo Résidentiel',
      position: LatLng(9.4600, -5.6270),
      isGps: false,
    ),
    CommunePosition(
      city: 'Korhogo',
      commune: 'Korhogo Commerce',
      position: LatLng(9.4560, -5.6320),
      isGps: false,
    ),
    CommunePosition(
      city: 'Korhogo',
      commune: 'Korhogo Aéroport',
      position: LatLng(9.4620, -5.6250),
      isGps: false,
    ),
    CommunePosition(
      city: 'Korhogo',
      commune: 'Korhogo Cité ADM',
      position: LatLng(9.4550, -5.6340),
      isGps: false,
    ),

    // Man (ouest, région des montagnes)
    CommunePosition(
      city: 'Man',
      commune: 'Man Centre',
      position: LatLng(7.4132, -7.5538),
      isGps: false,
    ),
    CommunePosition(
      city: 'Man',
      commune: 'Man Domoraud',
      position: LatLng(7.4150, -7.5520),
      isGps: false,
    ),
    CommunePosition(
      city: 'Man',
      commune: 'Man Maron',
      position: LatLng(7.4110, -7.5550),
      isGps: false,
    ),
    CommunePosition(
      city: 'Man',
      commune: 'Man Commerce',
      position: LatLng(7.4140, -7.5530),
      isGps: false,
    ),
    CommunePosition(
      city: 'Man',
      commune: 'Man Résidentiel',
      position: LatLng(7.4120, -7.5540),
      isGps: false,
    ),
    CommunePosition(
      city: 'Man',
      commune: 'Man Cascade',
      position: LatLng(7.4160, -7.5510),
      isGps: false,
    ),

    // Gagnoa
    CommunePosition(
      city: 'Gagnoa',
      commune: 'Gagnoa Centre',
      position: LatLng(6.1319, -5.9506),
      isGps: false,
    ),
    CommunePosition(
      city: 'Gagnoa',
      commune: 'Gagnoa Commerce',
      position: LatLng(6.1340, -5.9480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Gagnoa',
      commune: 'Gagnoa Résidentiel',
      position: LatLng(6.1300, -5.9530),
      isGps: false,
    ),
    CommunePosition(
      city: 'Gagnoa',
      commune: 'Gagnoa Cité ADM',
      position: LatLng(6.1330, -5.9490),
      isGps: false,
    ),

    // Abengourou (est)
    CommunePosition(
      city: 'Abengourou',
      commune: 'Abengourou Centre',
      position: LatLng(6.7248, -3.4958),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abengourou',
      commune: 'Abengourou Commerce',
      position: LatLng(6.7270, -3.4930),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abengourou',
      commune: 'Abengourou Résidentiel',
      position: LatLng(6.7230, -3.4980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Abengourou',
      commune: 'Abengourou Aéroport',
      position: LatLng(6.7290, -3.4910),
      isGps: false,
    ),

    // Divo
    CommunePosition(
      city: 'Divo',
      commune: 'Divo Centre',
      position: LatLng(6.9333, -5.3667),
      isGps: false,
    ),
    CommunePosition(
      city: 'Divo',
      commune: 'Divo Commerce',
      position: LatLng(6.9350, -5.3640),
      isGps: false,
    ),
    CommunePosition(
      city: 'Divo',
      commune: 'Divo Résidentiel',
      position: LatLng(6.9310, -5.3690),
      isGps: false,
    ),

    // Agboville
    CommunePosition(
      city: 'Agboville',
      commune: 'Agboville Centre',
      position: LatLng(5.9333, -4.2167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Agboville',
      commune: 'Agboville Commerce',
      position: LatLng(5.9350, -4.2140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Agboville',
      commune: 'Agboville Résidentiel',
      position: LatLng(5.9310, -4.2190),
      isGps: false,
    ),

    // Soubré (ouest, barrage)
    CommunePosition(
      city: 'Soubré',
      commune: 'Soubré Centre',
      position: LatLng(5.7833, -6.5833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Soubré',
      commune: 'Soubré Commerce',
      position: LatLng(5.7850, -6.5810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Soubré',
      commune: 'Soubré Résidentiel',
      position: LatLng(5.7810, -6.5850),
      isGps: false,
    ),

    // Séguéla
    CommunePosition(
      city: 'Séguéla',
      commune: 'Séguéla Centre',
      position: LatLng(7.9667, -6.6833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Séguéla',
      commune: 'Séguéla Commerce',
      position: LatLng(7.9680, -6.6810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Séguéla',
      commune: 'Séguéla Résidentiel',
      position: LatLng(7.9650, -6.6850),
      isGps: false,
    ),

    // Odienné (nord-ouest)
    CommunePosition(
      city: 'Odienné',
      commune: 'Odienné Centre',
      position: LatLng(9.5000, -7.5667),
      isGps: false,
    ),
    CommunePosition(
      city: 'Odienné',
      commune: 'Odienné Commerce',
      position: LatLng(9.5020, -7.5640),
      isGps: false,
    ),
    CommunePosition(
      city: 'Odienné',
      commune: 'Odienné Résidentiel',
      position: LatLng(9.4980, -7.5690),
      isGps: false,
    ),
    CommunePosition(
      city: 'Odienné',
      commune: 'Odienné Aéroport',
      position: LatLng(9.5040, -7.5620),
      isGps: false,
    ),

    // Touba (nord-ouest)
    CommunePosition(
      city: 'Touba',
      commune: 'Touba Centre',
      position: LatLng(8.2833, -7.7167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Touba',
      commune: 'Touba Commerce',
      position: LatLng(8.2850, -7.7140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Touba',
      commune: 'Touba Résidentiel',
      position: LatLng(8.2810, -7.7190),
      isGps: false,
    ),

    // Bondoukou (est)
    CommunePosition(
      city: 'Bondoukou',
      commune: 'Bondoukou Centre',
      position: LatLng(8.0333, -2.8000),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bondoukou',
      commune: 'Bondoukou Commerce',
      position: LatLng(8.0350, -2.7980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bondoukou',
      commune: 'Bondoukou Résidentiel',
      position: LatLng(8.0310, -2.8020),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bondoukou',
      commune: 'Bondoukou Aéroport',
      position: LatLng(8.0370, -2.7960),
      isGps: false,
    ),

    // Dimbokro
    CommunePosition(
      city: 'Dimbokro',
      commune: 'Dimbokro Centre',
      position: LatLng(6.6500, -4.7000),
      isGps: false,
    ),
    CommunePosition(
      city: 'Dimbokro',
      commune: 'Dimbokro Commerce',
      position: LatLng(6.6520, -4.6980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Dimbokro',
      commune: 'Dimbokro Résidentiel',
      position: LatLng(6.6480, -4.7020),
      isGps: false,
    ),

    // Aboisso (sud-est)
    CommunePosition(
      city: 'Aboisso',
      commune: 'Aboisso Centre',
      position: LatLng(5.4667, -3.2000),
      isGps: false,
    ),
    CommunePosition(
      city: 'Aboisso',
      commune: 'Aboisso Commerce',
      position: LatLng(5.4680, -3.1980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Aboisso',
      commune: 'Aboisso Résidentiel',
      position: LatLng(5.4650, -3.2020),
      isGps: false,
    ),

    // Adzopé
    CommunePosition(
      city: 'Adzopé',
      commune: 'Adzopé Centre',
      position: LatLng(5.9833, -3.9167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Adzopé',
      commune: 'Adzopé Commerce',
      position: LatLng(5.9850, -3.9140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Adzopé',
      commune: 'Adzopé Résidentiel',
      position: LatLng(5.9810, -3.9190),
      isGps: false,
    ),

    // Dabou (sud-ouest)
    CommunePosition(
      city: 'Dabou',
      commune: 'Dabou Centre',
      position: LatLng(5.3167, -4.3833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Dabou',
      commune: 'Dabou Commerce',
      position: LatLng(5.3180, -4.3810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Dabou',
      commune: 'Dabou Résidentiel',
      position: LatLng(5.3150, -4.3850),
      isGps: false,
    ),

    // Lakota (sud)
    CommunePosition(
      city: 'Lakota',
      commune: 'Lakota Centre',
      position: LatLng(5.8333, -5.6667),
      isGps: false,
    ),
    CommunePosition(
      city: 'Lakota',
      commune: 'Lakota Commerce',
      position: LatLng(5.8350, -5.6640),
      isGps: false,
    ),
    CommunePosition(
      city: 'Lakota',
      commune: 'Lakota Résidentiel',
      position: LatLng(5.8310, -5.6690),
      isGps: false,
    ),

    // Issia (centre-ouest)
    CommunePosition(
      city: 'Issia',
      commune: 'Issia Centre',
      position: LatLng(6.4833, -6.3167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Issia',
      commune: 'Issia Commerce',
      position: LatLng(6.4850, -6.3140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Issia',
      commune: 'Issia Résidentiel',
      position: LatLng(6.4810, -6.3190),
      isGps: false,
    ),

    // Vavoua
    CommunePosition(
      city: 'Vavoua',
      commune: 'Vavoua Centre',
      position: LatLng(7.3833, -6.4833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Vavoua',
      commune: 'Vavoua Commerce',
      position: LatLng(7.3850, -6.4810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Vavoua',
      commune: 'Vavoua Résidentiel',
      position: LatLng(7.3810, -6.4850),
      isGps: false,
    ),

    // Bangolo (ouest)
    CommunePosition(
      city: 'Bangolo',
      commune: 'Bangolo Centre',
      position: LatLng(7.6667, -7.4833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bangolo',
      commune: 'Bangolo Commerce',
      position: LatLng(7.6680, -7.4810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bangolo',
      commune: 'Bangolo Résidentiel',
      position: LatLng(7.6650, -7.4850),
      isGps: false,
    ),

    // Duékoué (ouest)
    CommunePosition(
      city: 'Duékoué',
      commune: 'Duékoué Centre',
      position: LatLng(6.7333, -7.1500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Duékoué',
      commune: 'Duékoué Commerce',
      position: LatLng(6.7350, -7.1480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Duékoué',
      commune: 'Duékoué Résidentiel',
      position: LatLng(6.7310, -7.1520),
      isGps: false,
    ),

    // Guiglo (ouest)
    CommunePosition(
      city: 'Guiglo',
      commune: 'Guiglo Centre',
      position: LatLng(6.5333, -7.5167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Guiglo',
      commune: 'Guiglo Commerce',
      position: LatLng(6.5350, -7.5140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Guiglo',
      commune: 'Guiglo Résidentiel',
      position: LatLng(6.5310, -7.5190),
      isGps: false,
    ),

    // Tiassalé (sud)
    CommunePosition(
      city: 'Tiassalé',
      commune: 'Tiassalé Centre',
      position: LatLng(5.8833, -4.8167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiassalé',
      commune: 'Tiassalé Commerce',
      position: LatLng(5.8850, -4.8140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiassalé',
      commune: 'Tiassalé Résidentiel',
      position: LatLng(5.8810, -4.8190),
      isGps: false,
    ),

    // Sikensi (sud)
    CommunePosition(
      city: 'Sikensi',
      commune: 'Sikensi Centre',
      position: LatLng(5.6167, -4.4833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Sikensi',
      commune: 'Sikensi Commerce',
      position: LatLng(5.6180, -4.4810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Sikensi',
      commune: 'Sikensi Résidentiel',
      position: LatLng(5.6150, -4.4850),
      isGps: false,
    ),

    // Grand-Lahou (sud)
    CommunePosition(
      city: 'Grand-Lahou',
      commune: 'Grand-Lahou Centre',
      position: LatLng(5.2000, -4.7500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Grand-Lahou',
      commune: 'Grand-Lahou Plage',
      position: LatLng(5.1980, -4.7520),
      isGps: false,
    ),
    CommunePosition(
      city: 'Grand-Lahou',
      commune: 'Grand-Lahou Résidentiel',
      position: LatLng(5.2020, -4.7480),
      isGps: false,
    ),

    // Jacqueville (sud-ouest)
    CommunePosition(
      city: 'Jacqueville',
      commune: 'Jacqueville Centre',
      position: LatLng(5.1833, -4.4333),
      isGps: false,
    ),
    CommunePosition(
      city: 'Jacqueville',
      commune: 'Jacqueville Plage',
      position: LatLng(5.1810, -4.4350),
      isGps: false,
    ),
    CommunePosition(
      city: 'Jacqueville',
      commune: 'Jacqueville Résidentiel',
      position: LatLng(5.1850, -4.4310),
      isGps: false,
    ),

    // Alépé (sud-est)
    CommunePosition(
      city: 'Alépé',
      commune: 'Alépé Centre',
      position: LatLng(5.7833, -3.7500),
      isGps: false,
    ),
    CommunePosition(
      city: 'Alépé',
      commune: 'Alépé Commerce',
      position: LatLng(5.7850, -3.7480),
      isGps: false,
    ),
    CommunePosition(
      city: 'Alépé',
      commune: 'Alépé Résidentiel',
      position: LatLng(5.7810, -3.7520),
      isGps: false,
    ),

    // Adiaké (sud-est)
    CommunePosition(
      city: 'Adiaké',
      commune: 'Adiaké Centre',
      position: LatLng(5.1167, -3.1667),
      isGps: false,
    ),
    CommunePosition(
      city: 'Adiaké',
      commune: 'Adiaké Commerce',
      position: LatLng(5.1180, -3.1640),
      isGps: false,
    ),
    CommunePosition(
      city: 'Adiaké',
      commune: 'Adiaké Résidentiel',
      position: LatLng(5.1150, -3.1690),
      isGps: false,
    ),

    // Tiémélé (est)
    CommunePosition(
      city: 'Tiémélé',
      commune: 'Tiémélé Centre',
      position: LatLng(6.3833, -3.0167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiémélé',
      commune: 'Tiémélé Commerce',
      position: LatLng(6.3850, -3.0140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiémélé',
      commune: 'Tiémélé Résidentiel',
      position: LatLng(6.3810, -3.0190),
      isGps: false,
    ),

    // Mankono (centre-ouest)
    CommunePosition(
      city: 'Mankono',
      commune: 'Mankono Centre',
      position: LatLng(7.6833, -6.5833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Mankono',
      commune: 'Mankono Commerce',
      position: LatLng(7.6850, -6.5810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Mankono',
      commune: 'Mankono Résidentiel',
      position: LatLng(7.6810, -6.5850),
      isGps: false,
    ),

    // Katiola (centre-nord)
    CommunePosition(
      city: 'Katiola',
      commune: 'Katiola Centre',
      position: LatLng(8.1333, -5.1000),
      isGps: false,
    ),
    CommunePosition(
      city: 'Katiola',
      commune: 'Katiola Commerce',
      position: LatLng(8.1350, -5.0980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Katiola',
      commune: 'Katiola Résidentiel',
      position: LatLng(8.1310, -5.1020),
      isGps: false,
    ),

    // Ferkessédougou (nord)
    CommunePosition(
      city: 'Ferkessédougou',
      commune: 'Ferkessédougou Centre',
      position: LatLng(9.6000, -5.2000),
      isGps: false,
    ),
    CommunePosition(
      city: 'Ferkessédougou',
      commune: 'Ferkessédougou Commerce',
      position: LatLng(9.6020, -5.1980),
      isGps: false,
    ),
    CommunePosition(
      city: 'Ferkessédougou',
      commune: 'Ferkessédougou Résidentiel',
      position: LatLng(9.5980, -5.2020),
      isGps: false,
    ),
    CommunePosition(
      city: 'Ferkessédougou',
      commune: 'Ferkessédougou Aéroport',
      position: LatLng(9.6040, -5.1960),
      isGps: false,
    ),

    // Boundiali (nord)
    CommunePosition(
      city: 'Boundiali',
      commune: 'Boundiali Centre',
      position: LatLng(9.5333, -6.4833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Boundiali',
      commune: 'Boundiali Commerce',
      position: LatLng(9.5350, -6.4810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Boundiali',
      commune: 'Boundiali Résidentiel',
      position: LatLng(9.5310, -6.4850),
      isGps: false,
    ),

    // Kong (nord)
    CommunePosition(
      city: 'Kong',
      commune: 'Kong Centre',
      position: LatLng(9.2000, -4.1333),
      isGps: false,
    ),
    CommunePosition(
      city: 'Kong',
      commune: 'Kong Commerce',
      position: LatLng(9.2020, -4.1310),
      isGps: false,
    ),
    CommunePosition(
      city: 'Kong',
      commune: 'Kong Résidentiel',
      position: LatLng(9.1980, -4.1350),
      isGps: false,
    ),

    // Bouna (est)
    CommunePosition(
      city: 'Bouna',
      commune: 'Bouna Centre',
      position: LatLng(9.2667, -2.9833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouna',
      commune: 'Bouna Commerce',
      position: LatLng(9.2680, -2.9810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bouna',
      commune: 'Bouna Résidentiel',
      position: LatLng(9.2650, -2.9850),
      isGps: false,
    ),

    // Tanda (est)
    CommunePosition(
      city: 'Tanda',
      commune: 'Tanda Centre',
      position: LatLng(7.3833, -3.1667),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tanda',
      commune: 'Tanda Commerce',
      position: LatLng(7.3850, -3.1640),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tanda',
      commune: 'Tanda Résidentiel',
      position: LatLng(7.3810, -3.1690),
      isGps: false,
    ),

    // Kounahiri
    CommunePosition(
      city: 'Kounahiri',
      commune: 'Kounahiri Centre',
      position: LatLng(8.4833, -6.0833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Kounahiri',
      commune: 'Kounahiri Commerce',
      position: LatLng(8.4850, -6.0810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Kounahiri',
      commune: 'Kounahiri Résidentiel',
      position: LatLng(8.4810, -6.0850),
      isGps: false,
    ),

    // Dikodougou
    CommunePosition(
      city: 'Dikodougou',
      commune: 'Dikodougou Centre',
      position: LatLng(9.3833, -5.3167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Dikodougou',
      commune: 'Dikodougou Commerce',
      position: LatLng(9.3850, -5.3140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Dikodougou',
      commune: 'Dikodougou Résidentiel',
      position: LatLng(9.3810, -5.3190),
      isGps: false,
    ),

    // Sinématiali
    CommunePosition(
      city: 'Sinématiali',
      commune: 'Sinématiali Centre',
      position: LatLng(9.4500, -5.1333),
      isGps: false,
    ),
    CommunePosition(
      city: 'Sinématiali',
      commune: 'Sinématiali Commerce',
      position: LatLng(9.4520, -5.1310),
      isGps: false,
    ),
    CommunePosition(
      city: 'Sinématiali',
      commune: 'Sinématiali Résidentiel',
      position: LatLng(9.4480, -5.1350),
      isGps: false,
    ),

    // Niakaramandougou
    CommunePosition(
      city: 'Niakaramandougou',
      commune: 'Niakaramandougou Centre',
      position: LatLng(8.7833, -5.3167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Niakaramandougou',
      commune: 'Niakaramandougou Commerce',
      position: LatLng(8.7850, -5.3140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Niakaramandougou',
      commune: 'Niakaramandougou Résidentiel',
      position: LatLng(8.7810, -5.3190),
      isGps: false,
    ),

    // M'Bahiakro (centre)
    CommunePosition(
      city: 'M\'Bahiakro',
      commune: 'M\'Bahiakro Centre',
      position: LatLng(7.1333, -4.1167),
      isGps: false,
    ),
    CommunePosition(
      city: 'M\'Bahiakro',
      commune: 'M\'Bahiakro Commerce',
      position: LatLng(7.1350, -4.1140),
      isGps: false,
    ),
    CommunePosition(
      city: 'M\'Bahiakro',
      commune: 'M\'Bahiakro Résidentiel',
      position: LatLng(7.1310, -4.1190),
      isGps: false,
    ),

    // Bocanda (centre)
    CommunePosition(
      city: 'Bocanda',
      commune: 'Bocanda Centre',
      position: LatLng(6.9833, -4.3167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bocanda',
      commune: 'Bocanda Commerce',
      position: LatLng(6.9850, -4.3140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bocanda',
      commune: 'Bocanda Résidentiel',
      position: LatLng(6.9810, -4.3190),
      isGps: false,
    ),

    // Daoukro (centre)
    CommunePosition(
      city: 'Daoukro',
      commune: 'Daoukro Centre',
      position: LatLng(7.2833, -3.9167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daoukro',
      commune: 'Daoukro Commerce',
      position: LatLng(7.2850, -3.9140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Daoukro',
      commune: 'Daoukro Résidentiel',
      position: LatLng(7.2810, -3.9190),
      isGps: false,
    ),

    // Prikro (centre)
    CommunePosition(
      city: 'Prikro',
      commune: 'Prikro Centre',
      position: LatLng(7.8833, -3.9167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Prikro',
      commune: 'Prikro Commerce',
      position: LatLng(7.8850, -3.9140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Prikro',
      commune: 'Prikro Résidentiel',
      position: LatLng(7.8810, -3.9190),
      isGps: false,
    ),

    // Béoumi (centre)
    CommunePosition(
      city: 'Béoumi',
      commune: 'Béoumi Centre',
      position: LatLng(7.7833, -5.3167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Béoumi',
      commune: 'Béoumi Commerce',
      position: LatLng(7.7850, -5.3140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Béoumi',
      commune: 'Béoumi Résidentiel',
      position: LatLng(7.7810, -5.3190),
      isGps: false,
    ),

    // Sakassou (centre)
    CommunePosition(
      city: 'Sakassou',
      commune: 'Sakassou Centre',
      position: LatLng(7.2833, -5.2833),
      isGps: false,
    ),
    CommunePosition(
      city: 'Sakassou',
      commune: 'Sakassou Commerce',
      position: LatLng(7.2850, -5.2810),
      isGps: false,
    ),
    CommunePosition(
      city: 'Sakassou',
      commune: 'Sakassou Résidentiel',
      position: LatLng(7.2810, -5.2850),
      isGps: false,
    ),

    // Toumodi (centre)
    CommunePosition(
      city: 'Toumodi',
      commune: 'Toumodi Centre',
      position: LatLng(6.5500, -5.0167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Toumodi',
      commune: 'Toumodi Commerce',
      position: LatLng(6.5520, -5.0140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Toumodi',
      commune: 'Toumodi Résidentiel',
      position: LatLng(6.5480, -5.0190),
      isGps: false,
    ),

    // Tiébissou (centre)
    CommunePosition(
      city: 'Tiébissou',
      commune: 'Tiébissou Centre',
      position: LatLng(6.7833, -5.1667),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiébissou',
      commune: 'Tiébissou Commerce',
      position: LatLng(6.7850, -5.1640),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiébissou',
      commune: 'Tiébissou Résidentiel',
      position: LatLng(6.7810, -5.1690),
      isGps: false,
    ),

    // Didiévi (centre)
    CommunePosition(
      city: 'Didiévi',
      commune: 'Didiévi Centre',
      position: LatLng(6.4833, -4.9167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Didiévi',
      commune: 'Didiévi Commerce',
      position: LatLng(6.4850, -4.9140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Didiévi',
      commune: 'Didiévi Résidentiel',
      position: LatLng(6.4810, -4.9190),
      isGps: false,
    ),

    // Arrah (est)
    CommunePosition(
      city: 'Arrah',
      commune: 'Arrah Centre',
      position: LatLng(6.4833, -3.6167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Arrah',
      commune: 'Arrah Commerce',
      position: LatLng(6.4850, -3.6140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Arrah',
      commune: 'Arrah Résidentiel',
      position: LatLng(6.4810, -3.6190),
      isGps: false,
    ),

    // Bongouanou (est)
    CommunePosition(
      city: 'Bongouanou',
      commune: 'Bongouanou Centre',
      position: LatLng(6.3833, -3.8167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bongouanou',
      commune: 'Bongouanou Commerce',
      position: LatLng(6.3850, -3.8140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Bongouanou',
      commune: 'Bongouanou Résidentiel',
      position: LatLng(6.3810, -3.8190),
      isGps: false,
    ),

    // M'Batto (est)
    CommunePosition(
      city: 'M\'Batto',
      commune: 'M\'Batto Centre',
      position: LatLng(6.1833, -3.8167),
      isGps: false,
    ),
    CommunePosition(
      city: 'M\'Batto',
      commune: 'M\'Batto Commerce',
      position: LatLng(6.1850, -3.8140),
      isGps: false,
    ),
    CommunePosition(
      city: 'M\'Batto',
      commune: 'M\'Batto Résidentiel',
      position: LatLng(6.1810, -3.8190),
      isGps: false,
    ),

    // Ouellé (est)
    CommunePosition(
      city: 'Ouellé',
      commune: 'Ouellé Centre',
      position: LatLng(6.8833, -3.5167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Ouellé',
      commune: 'Ouellé Commerce',
      position: LatLng(6.8850, -3.5140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Ouellé',
      commune: 'Ouellé Résidentiel',
      position: LatLng(6.8810, -3.5190),
      isGps: false,
    ),

    // Akoupé (est)
    CommunePosition(
      city: 'Akoupé',
      commune: 'Akoupé Centre',
      position: LatLng(5.9833, -3.4167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Akoupé',
      commune: 'Akoupé Commerce',
      position: LatLng(5.9850, -3.4140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Akoupé',
      commune: 'Akoupé Résidentiel',
      position: LatLng(5.9810, -3.4190),
      isGps: false,
    ),

    // Yakassé-Attobrou (est)
    CommunePosition(
      city: 'Yakassé-Attobrou',
      commune: 'Yakassé-Attobrou Centre',
      position: LatLng(5.9833, -3.6167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yakassé-Attobrou',
      commune: 'Yakassé-Attobrou Commerce',
      position: LatLng(5.9850, -3.6140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Yakassé-Attobrou',
      commune: 'Yakassé-Attobrou Résidentiel',
      position: LatLng(5.9810, -3.6190),
      isGps: false,
    ),

    // Azaguié (sud)
    CommunePosition(
      city: 'Azaguié',
      commune: 'Azaguié Centre',
      position: LatLng(5.5833, -4.1167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Azaguié',
      commune: 'Azaguié Commerce',
      position: LatLng(5.5850, -4.1140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Azaguié',
      commune: 'Azaguié Résidentiel',
      position: LatLng(5.5810, -4.1190),
      isGps: false,
    ),

    // Dabou (déjà fait)

    // Attécougbé (déjà dans Abidjan)

    // Tiapoum (sud-est)
    CommunePosition(
      city: 'Tiapoum',
      commune: 'Tiapoum Centre',
      position: LatLng(5.2833, -3.1167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiapoum',
      commune: 'Tiapoum Commerce',
      position: LatLng(5.2850, -3.1140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Tiapoum',
      commune: 'Tiapoum Résidentiel',
      position: LatLng(5.2810, -3.1190),
      isGps: false,
    ),

    // Aïkénéssou
    CommunePosition(
      city: 'Aïkénéssou',
      commune: 'Aïkénéssou Centre',
      position: LatLng(6.0833, -3.1167),
      isGps: false,
    ),
    CommunePosition(
      city: 'Aïkénéssou',
      commune: 'Aïkénéssou Commerce',
      position: LatLng(6.0850, -3.1140),
      isGps: false,
    ),
    CommunePosition(
      city: 'Aïkénéssou',
      commune: 'Aïkénéssou Résidentiel',
      position: LatLng(6.0810, -3.1190),
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