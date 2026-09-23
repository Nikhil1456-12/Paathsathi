// lib/models/city_map_bundle.dart
//
// Data model for a Pilgrimage City Offline Map Bundle.
//
// Each bundle is a self-contained downloadable package with:
//   - An MBTiles raster tile file (zoom 0–17, street-level offline map)
//   - Facilities JSON  (hotels, dharamshalas, hospitals, water ATMs, toilets)
//   - Safety JSON      (lost & found zones, police posts, emergency contacts)
//   - Schedule JSON    (ritual timings, ghat aarti, bathing dates)
//   - Pre-computed walking routes (pilgrimage waypoints as LatLng lists)
//
// Bundle files are stored in:
//   getApplicationDocumentsDirectory()/maps/{cityId}.mbtiles
//   getApplicationDocumentsDirectory()/maps/{cityId}_data.json

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum BundleStatus {
  notDownloaded,
  downloading,
  downloaded,
  failed,
  sourceUnavailable, // no real download source configured (truthful, not an error)
}

class CityMapBundle {
  final String id;
  final String name;
  final String nameHindi;
  final String nameTelugu;
  final String nameTamil;
  final String state;
  final String significance; // Why pilgrims visit
  final LatLng center;
  final double defaultZoom;
  final int mbtilesSize;   // MB
  final int dataSize;      // MB (facilities + safety + schedule JSON)
  final String mbtilesUrl; // Remote download URL
  final String dataUrl;    // Remote data JSON URL
  final IconData icon;
  final Color themeColor;
  final bool isPrimary;    // Auto-download on first WiFi (Prayagraj only)

  const CityMapBundle({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.nameTelugu,
    required this.nameTamil,
    required this.state,
    required this.significance,
    required this.center,
    required this.defaultZoom,
    required this.mbtilesSize,
    required this.dataSize,
    required this.mbtilesUrl,
    required this.dataUrl,
    required this.icon,
    required this.themeColor,
    this.isPrimary = false,
  });

  int get totalSizeMb => mbtilesSize + dataSize;

  String get localMbtilesFileName => '${id}.mbtiles';
  String get localDataFileName => '${id}_data.json';

  /// Whether this bundle has a REAL, reachable download source configured.
  /// The default catalog points at a demo/placeholder CDN host that does not
  /// resolve; we must not attempt (or advertise) downloads from it. A source is
  /// considered real only when it is https and NOT the known placeholder host.
  bool get hasRealSource {
    final u = mbtilesUrl.toLowerCase();
    if (!u.startsWith('https://')) return false;
    const placeholderHosts = ['infosys-demo', 'example.', 'localhost', 'placeholder'];
    return !placeholderHosts.any((h) => u.contains(h));
  }

  String getLocalizedName(String langCode) {
    switch (langCode) {
      case 'hi': return nameHindi;
      case 'te': return nameTelugu;
      case 'ta': return nameTamil;
      default:   return name;
    }
  }
}

// ── Pilgrimage City Bundle Catalog ────────────────────────────────────────────

class CityBundleCatalog {
  CityBundleCatalog._();

  // Base CDN URL — replace with actual Infosys backend or public CDN
  static const String _cdnBase =
      'https://pathsaathi-cdn.infosys-demo.in/maps/v1';

  static const List<CityMapBundle> all = [

    // ── PRIMARY — Auto-downloaded on first WiFi launch ───────────────────────
    CityMapBundle(
      id: 'prayagraj',
      name: 'Prayagraj (Kumbh Mela)',
      nameHindi: 'प्रयागराज (कुंभ मेला)',
      nameTelugu: 'ప్రయాగరాజ్ (కుంభమేళా)',
      nameTamil: 'பிரயாகராஜ் (கும்பமேளா)',
      state: 'Uttar Pradesh',
      significance: 'Sangam of Ganga, Yamuna & Saraswati. Maha Kumbh 2025.',
      center: LatLng(25.4358, 81.8853),
      defaultZoom: 14.0,
      mbtilesSize: 120,
      dataSize: 8,
      mbtilesUrl: '$_cdnBase/prayagraj.mbtiles',
      dataUrl: '$_cdnBase/prayagraj_data.json',
      icon: Icons.water_rounded,
      themeColor: Color(0xFFFF6B00),
      isPrimary: true,
    ),

    // ── TIER 1 CITIES — Downloaded when user selects as destination ──────────
    CityMapBundle(
      id: 'varanasi',
      name: 'Varanasi (Kashi)',
      nameHindi: 'वाराणसी (काशी)',
      nameTelugu: 'వారణాసి (కాశీ)',
      nameTamil: 'வாரணாசி (காசி)',
      state: 'Uttar Pradesh',
      significance: 'Dashashwamedh Ghat, Kashi Vishwanath. City of Moksha.',
      center: LatLng(25.3176, 83.0062),
      defaultZoom: 14.5,
      mbtilesSize: 80,
      dataSize: 6,
      mbtilesUrl: '$_cdnBase/varanasi.mbtiles',
      dataUrl: '$_cdnBase/varanasi_data.json',
      icon: Icons.local_fire_department_rounded,
      themeColor: Color(0xFFDC2626),
    ),

    CityMapBundle(
      id: 'ayodhya',
      name: 'Ayodhya',
      nameHindi: 'अयोध्या',
      nameTelugu: 'అయోధ్య',
      nameTamil: 'அயோத்தி',
      state: 'Uttar Pradesh',
      significance: 'Ram Janmabhoomi, Ram Temple. Birthplace of Lord Rama.',
      center: LatLng(26.7922, 82.1998),
      defaultZoom: 14.5,
      mbtilesSize: 45,
      dataSize: 4,
      mbtilesUrl: '$_cdnBase/ayodhya.mbtiles',
      dataUrl: '$_cdnBase/ayodhya_data.json',
      icon: Icons.temple_hindu_rounded,
      themeColor: Color(0xFFF59E0B),
    ),

    CityMapBundle(
      id: 'haridwar',
      name: 'Haridwar',
      nameHindi: 'हरिद्वार',
      nameTelugu: 'హరిద్వార్',
      nameTamil: 'ஹரித்வார்',
      state: 'Uttarakhand',
      significance: 'Har Ki Pauri, Ganga Aarti. Gateway to the Himalayas.',
      center: LatLng(29.9457, 78.1642),
      defaultZoom: 14.0,
      mbtilesSize: 60,
      dataSize: 5,
      mbtilesUrl: '$_cdnBase/haridwar.mbtiles',
      dataUrl: '$_cdnBase/haridwar_data.json',
      icon: Icons.waves_rounded,
      themeColor: Color(0xFF0284C7),
    ),

    CityMapBundle(
      id: 'mathura_vrindavan',
      name: 'Mathura & Vrindavan',
      nameHindi: 'मथुरा व वृन्दावन',
      nameTelugu: 'మథుర & వృందావన్',
      nameTamil: 'மதுரா & விருந்தாவனம்',
      state: 'Uttar Pradesh',
      significance: 'Birthplace of Lord Krishna. Banke Bihari, ISKCON.',
      center: LatLng(27.4924, 77.6737),
      defaultZoom: 13.5,
      mbtilesSize: 55,
      dataSize: 4,
      mbtilesUrl: '$_cdnBase/mathura_vrindavan.mbtiles',
      dataUrl: '$_cdnBase/mathura_vrindavan_data.json',
      icon: Icons.spa_rounded,
      themeColor: Color(0xFF7C3AED),
    ),

    CityMapBundle(
      id: 'ujjain',
      name: 'Ujjain',
      nameHindi: 'उज्जैन',
      nameTelugu: 'ఉజ్జయిని',
      nameTamil: 'உஜ்ஜைன்',
      state: 'Madhya Pradesh',
      significance: 'Mahakaleshwar Jyotirlinga. Simhastha Kumbh.',
      center: LatLng(23.1765, 75.7885),
      defaultZoom: 14.0,
      mbtilesSize: 50,
      dataSize: 4,
      mbtilesUrl: '$_cdnBase/ujjain.mbtiles',
      dataUrl: '$_cdnBase/ujjain_data.json',
      icon: Icons.brightness_3_rounded,
      themeColor: Color(0xFF1A6B3C),
    ),

    CityMapBundle(
      id: 'tirupati',
      name: 'Tirupati',
      nameHindi: 'तिरुपति',
      nameTelugu: 'తిరుపతి',
      nameTamil: 'திருப்பதி',
      state: 'Andhra Pradesh',
      significance: 'Tirumala Venkateswara Temple. World\'s most visited pilgrimage.',
      center: LatLng(13.6288, 79.4192),
      defaultZoom: 13.5,
      mbtilesSize: 65,
      dataSize: 5,
      mbtilesUrl: '$_cdnBase/tirupati.mbtiles',
      dataUrl: '$_cdnBase/tirupati_data.json',
      icon: Icons.landscape_rounded,
      themeColor: Color(0xFF059669),
    ),

    CityMapBundle(
      id: 'puri',
      name: 'Puri (Jagannath)',
      nameHindi: 'पुरी (जगन्नाथ)',
      nameTelugu: 'పూరీ (జగన్నాథ)',
      nameTamil: 'பூரி (ஜகன்னாத்)',
      state: 'Odisha',
      significance: 'Jagannath Temple, Rath Yatra. One of Char Dham.',
      center: LatLng(19.8135, 85.8312),
      defaultZoom: 14.0,
      mbtilesSize: 50,
      dataSize: 4,
      mbtilesUrl: '$_cdnBase/puri.mbtiles',
      dataUrl: '$_cdnBase/puri_data.json',
      icon: Icons.directions_car_rounded,
      themeColor: Color(0xFF0284C7),
    ),

    CityMapBundle(
      id: 'shirdi',
      name: 'Shirdi (Sai Baba)',
      nameHindi: 'शिर्डी (साईं बाबा)',
      nameTelugu: 'షిర్డీ (సాయి బాబా)',
      nameTamil: 'ஷீர்டி (சாய் பாபா)',
      state: 'Maharashtra',
      significance: 'Shirdi Sai Baba Samadhi. Millions of devotees yearly.',
      center: LatLng(19.7664, 74.4776),
      defaultZoom: 14.5,
      mbtilesSize: 40,
      dataSize: 3,
      mbtilesUrl: '$_cdnBase/shirdi.mbtiles',
      dataUrl: '$_cdnBase/shirdi_data.json',
      icon: Icons.star_rounded,
      themeColor: Color(0xFFD97706),
    ),
  ];

  static CityMapBundle? findById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  static CityMapBundle get prayagraj =>
      all.firstWhere((b) => b.id == 'prayagraj');

  static List<CityMapBundle> get primaryBundles =>
      all.where((b) => b.isPrimary).toList();
}
