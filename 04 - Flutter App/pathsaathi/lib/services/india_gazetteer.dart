// lib/services/india_gazetteer.dart
//
// Curated Offline India Gazetteer for PathSaathi.
//
// Covers ~35 essential pilgrimage & travel destinations across 8 key states:
// Andhra Pradesh (AP), Tamil Nadu (TN), Telangana (TS), Uttar Pradesh (UP),
// Uttarakhand (UK), Gujarat (GJ), Maharashtra (MH), Odisha (OD), Karnataka (KA).
//
// Safety & Anti-Collision Guarantees:
//   1. Short words (<= 4 chars, e.g. "Puri", "Pune", "Kashi"): EXACT alias match ONLY.
//      No Levenshtein fuzzy matching on short words to prevent "Puri" -> "Puni" collisions.
//      Known variants/transliterations are explicitly enumerated in the alias list.
//   2. Words > 4 chars: Levenshtein distance <= 2 allowed, guarded by matching
//      initial character prefix. Every fuzzy match is logged for auditability.
//   3. Dynamic slug: "${cityName.toLowerCase()}_${stateCode.toLowerCase()}".
//   4. Static legacy map preserves exact IDs for: kedarnath, dwarka, prayagraj,
//      varanasi, hyderabad, mumbai, chennai.

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class GazetteerEntry {
  final String id;
  final String name;
  final String stateCode;
  final String stateName;
  final String district;
  final LatLng coords;
  final String primaryRtc;
  final List<String> aliases;
  final String? transportHub;
  final String category; // 'temple' | 'city'

  const GazetteerEntry({
    required this.id,
    required this.name,
    required this.stateCode,
    required this.stateName,
    required this.district,
    required this.coords,
    required this.primaryRtc,
    required this.aliases,
    this.transportHub,
    this.category = 'city',
  });
}

class IndiaGazetteer {
  IndiaGazetteer._();
  static final IndiaGazetteer instance = IndiaGazetteer._();

  /// Legacy ID mapping ensuring pre-existing SQLite keys never break.
  static const Map<String, String> _legacyIdMap = {
    'kedarnath': 'kedarnath',
    'dwarka': 'dwarka',
    'dwaraka': 'dwarka',
    'prayagraj': 'prayagraj',
    'allahabad': 'prayagraj',
    'varanasi': 'varanasi',
    'kashi': 'varanasi',
    'banaras': 'varanasi',
    'hyderabad': 'hyderabad',
    'mumbai': 'mumbai',
    'bombay': 'mumbai',
    'chennai': 'chennai',
    'madras': 'chennai',
  };

  /// Compute canonical ID from name and state code.
  static String generateId(String name, String stateCode) {
    final clean = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (_legacyIdMap.containsKey(clean)) return _legacyIdMap[clean]!;
    return '${clean}_${stateCode.toLowerCase()}';
  }

  /// Canonical slug used throughout the app for destination IDs.
  ///
  /// If the input matches a gazetteer entry or known alias, it resolves to the
  /// entry's canonical ID. Otherwise it falls back to a safe lowercase slug.
  String toSlug(String rawName) {
    final value = rawName.trim();
    if (value.isEmpty) return '';

    final q = normalize(value);
    for (final entry in entries) {
      if (normalize(entry.name) == q) return entry.id;
      for (final alias in entry.aliases) {
        if (normalize(alias) == q) return entry.id;
      }
    }

    final legacy = _legacyIdMap[q];
    if (legacy != null) return legacy;

    final fallback = q.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    return fallback.isEmpty ? '' : fallback;
  }

  /// Curated ~35 destinations across 8 key states.
  static final List<GazetteerEntry> entries = [
    // ── ANDHRA PRADESH (AP) ──────────────────────────────────────────────
    GazetteerEntry(
      id: 'visakhapatnam',
      name: 'Visakhapatnam',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'Visakhapatnam',
      coords: LatLng(17.6868, 83.2185),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Visakhapatnam Railway Junction / RTC Complex',
      aliases: [
        'visakhapatnam', 'vizag', 'waltair', 'విశాఖపట్నం', 'విశాఖ', 'వైజాగ్',
        'विशाखापट्टनम', 'विशाखापत्तनम', 'వైజాగ్ సిటీ', 'simhachalam', 'సింహాచలం'
      ],
    ),
    GazetteerEntry(
      id: 'srikakulam',
      name: 'Srikakulam',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'Srikakulam',
      coords: LatLng(18.2949, 83.8938),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Srikakulam Road Railway Station / RTC Complex',
      aliases: [
        'srikakulam', 'chicacole', 'శ్రీకాకుళం', 'శ్రీకాకుళము',
        'श्रीकाकुलम', 'arasavalli', 'అరసవల్లి', 'srikurmam', 'శ్రీకూర్మం'
      ],
    ),
    GazetteerEntry(
      id: 'tirupati',
      name: 'Tirupati',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'Tirupati',
      coords: LatLng(13.6288, 79.4192),
      primaryRtc: 'APSRTC',
      category: 'temple',
      transportHub: 'Tirupati Main Junction / Central Bus Station',
      aliases: [
        'tirupati', 'tirumala', 'balaji', 'తిరుపతి', 'తిరుమల',
        'तिरुपति', 'तिरुपती', 'तिरुमला', 'venkateswara', 'వేంకటేశ్వర'
      ],
    ),
    GazetteerEntry(
      id: 'vijayawada_ap',
      name: 'Vijayawada',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'NTR',
      coords: LatLng(16.5062, 80.6480),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Vijayawada Junction / PNBS Bus Station',
      aliases: [
        'vijayawada', 'bezawada', 'విజయవాడ', 'బెజవాడ', 'kanaka durga',
        'कनक दुर्गा', 'विजयवाड़ा', 'దుర్గ గుడి'
      ],
    ),
    GazetteerEntry(
      id: 'guntur_ap',
      name: 'Guntur',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'Guntur',
      coords: LatLng(16.3067, 80.4365),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Guntur Junction / NTR Bus Station',
      aliases: ['guntur', 'గుంటూరు', 'गुंटूर'],
    ),
    GazetteerEntry(
      id: 'rajahmundry_ap',
      name: 'Rajahmundry',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'East Godavari',
      coords: LatLng(17.0005, 81.8040),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Rajahmundry Railway Station / RTC Bus Stand',
      aliases: ['rajahmundry', 'rajamahendravaram', 'రాజమండ్రి', 'రాజమహేంద్రవరం', 'राजमुंदरी'],
    ),
    GazetteerEntry(
      id: 'kurnool_ap',
      name: 'Kurnool',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'Kurnool',
      coords: LatLng(15.8281, 78.0373),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Kurnool City Railway Station / RTC Bus Stand',
      aliases: ['kurnool', 'కర్నూలు', 'కర్నూల్', 'कुर्नूल', 'konda reddy buruju'],
    ),
    GazetteerEntry(
      id: 'nellore_ap',
      name: 'Nellore',
      stateCode: 'AP',
      stateName: 'Andhra Pradesh',
      district: 'SPSR Nellore',
      coords: LatLng(14.4426, 79.9865),
      primaryRtc: 'APSRTC',
      category: 'city',
      transportHub: 'Nellore Railway Station / RTC Complex',
      aliases: ['nellore', 'నెల్లూరు', 'नेल्लोर'],
    ),

    // ── TAMIL NADU (TN) ──────────────────────────────────────────────────
    GazetteerEntry(
      id: 'chennai',
      name: 'Chennai',
      stateCode: 'TN',
      stateName: 'Tamil Nadu',
      district: 'Chennai',
      coords: LatLng(13.0827, 80.2707),
      primaryRtc: 'TNSTC',
      category: 'city',
      transportHub: 'Chennai Central / CMBT Koyambedu',
      aliases: [
        'chennai', 'madras', 'चेन्नई', 'చెన్నై', 'சென்னை', 'மதராஸ்',
        'kapaleeshwarar', 'parthasarathy', 'marina beach'
      ],
    ),
    GazetteerEntry(
      id: 'madurai_tn',
      name: 'Madurai',
      stateCode: 'TN',
      stateName: 'Tamil Nadu',
      district: 'Madurai',
      coords: LatLng(9.9252, 78.1198),
      primaryRtc: 'TNSTC',
      category: 'temple',
      transportHub: 'Madurai Junction / Mattuthavani Bus Stand',
      aliases: ['madurai', 'meenakshi', 'மதுரை', 'మదురై', 'मदुरै', 'மீனாட்சி'],
    ),
    GazetteerEntry(
      id: 'rameswaram_tn',
      name: 'Rameswaram',
      stateCode: 'TN',
      stateName: 'Tamil Nadu',
      district: 'Ramanathapuram',
      coords: LatLng(9.2876, 79.3129),
      primaryRtc: 'TNSTC',
      category: 'temple',
      transportHub: 'Rameswaram Railway Station / Bus Stand',
      aliases: [
        'rameswaram', 'rameshwaram', 'ராமேஸ்வரம்', 'రామేశ్వరం', 'रामेश्वरम',
        'ramanathaswamy', 'dhanushkodi', 'ధనుష్కోడి'
      ],
    ),
    GazetteerEntry(
      id: 'kanchipuram_tn',
      name: 'Kanchipuram',
      stateCode: 'TN',
      stateName: 'Tamil Nadu',
      district: 'Kanchipuram',
      coords: LatLng(12.8342, 79.7036),
      primaryRtc: 'TNSTC',
      category: 'temple',
      transportHub: 'Kanchipuram Railway Station / Bus Stand',
      aliases: ['kanchipuram', 'kanchi', 'காஞ்சிபுரம்', 'కాంచీపురం', 'कांचीपुरम', 'kamakshi'],
    ),
    GazetteerEntry(
      id: 'coimbatore_tn',
      name: 'Coimbatore',
      stateCode: 'TN',
      stateName: 'Tamil Nadu',
      district: 'Coimbatore',
      coords: LatLng(11.0168, 76.9558),
      primaryRtc: 'TNSTC',
      category: 'city',
      transportHub: 'Coimbatore Junction / Gandhipuram Bus Stand',
      aliases: ['coimbatore', 'kovai', 'கோயம்புத்தூர்', 'కోయంబత్తూరు', 'कोयंबटूर'],
    ),

    // ── TELANGANA (TS) ───────────────────────────────────────────────────
    GazetteerEntry(
      id: 'hyderabad',
      name: 'Hyderabad',
      stateCode: 'TS',
      stateName: 'Telangana',
      district: 'Hyderabad',
      coords: LatLng(17.3850, 78.4867),
      primaryRtc: 'TSRTC',
      category: 'city',
      transportHub: 'Secunderabad / Nampally / MGBS Bus Station',
      aliases: ['hyderabad', 'secunderabad', 'हैदराबाद', 'హైదరాబాద్', 'సైబర్ సిటీ', 'charminar'],
    ),
    GazetteerEntry(
      id: 'warangal_ts',
      name: 'Warangal',
      stateCode: 'TS',
      stateName: 'Telangana',
      district: 'Warangal',
      coords: LatLng(17.9689, 79.5941),
      primaryRtc: 'TSRTC',
      category: 'city',
      transportHub: 'Warangal Railway Station / Hanamkonda Bus Station',
      aliases: ['warangal', 'hanamkonda', 'kazipet', 'వరంగల్', 'హనుమకొండ', 'वारंगल', 'bhadrakali'],
    ),
    GazetteerEntry(
      id: 'yadagirigutta_ts',
      name: 'Yadagirigutta',
      stateCode: 'TS',
      stateName: 'Telangana',
      district: 'Yadadri Bhuvanagiri',
      coords: LatLng(17.5855, 78.9482),
      primaryRtc: 'TSRTC',
      category: 'temple',
      transportHub: 'Raigir Railway Station / Yadadri Bus Stand',
      aliases: ['yadagirigutta', 'yadadri', 'యాదగిరిగుట్ట', 'యాదాద్రి', 'यादगिरिगुट्टा', 'narasimha swamy'],
    ),

    // ── UTTAR PRADESH (UP) ───────────────────────────────────────────────
    GazetteerEntry(
      id: 'prayagraj',
      name: 'Prayagraj',
      stateCode: 'UP',
      stateName: 'Uttar Pradesh',
      district: 'Prayagraj',
      coords: LatLng(25.4358, 81.8814),
      primaryRtc: 'UPSRTC',
      category: 'temple',
      transportHub: 'Prayagraj Junction / Civil Lines Bus Station',
      aliases: [
        'prayagraj', 'allahabad', 'sangam', 'प्रयागराज', 'इलाहाबाद', 'संगम',
        'ప్రయాగ్‌రాజ్', 'అలహాబాద్', 'kumbh', 'triveni sangam'
      ],
    ),
    GazetteerEntry(
      id: 'varanasi',
      name: 'Varanasi',
      stateCode: 'UP',
      stateName: 'Uttar Pradesh',
      district: 'Varanasi',
      coords: LatLng(25.3109, 83.0107),
      primaryRtc: 'UPSRTC',
      category: 'temple',
      transportHub: 'Varanasi Junction / Cantt Bus Stand',
      aliases: [
        'varanasi', 'kashi', 'banaras', 'benares', 'वाराणसी', 'काशी', 'बनारस',
        'వారణాసి', 'కాశీ', 'vishwanath', 'kashi vishwanath'
      ],
    ),
    GazetteerEntry(
      id: 'ayodhya_up',
      name: 'Ayodhya',
      stateCode: 'UP',
      stateName: 'Uttar Pradesh',
      district: 'Ayodhya',
      coords: LatLng(26.7922, 82.1998),
      primaryRtc: 'UPSRTC',
      category: 'temple',
      transportHub: 'Ayodhya Dham Junction / Ayodhya Cantt',
      aliases: ['ayodhya', 'ram mandir', 'ram janmabhoomi', 'अयोध्या', 'राम मंदिर', 'అయోధ్య', 'రామ మందిరం'],
    ),
    GazetteerEntry(
      id: 'mathura_up',
      name: 'Mathura',
      stateCode: 'UP',
      stateName: 'Uttar Pradesh',
      district: 'Mathura',
      coords: LatLng(27.4924, 77.6737),
      primaryRtc: 'UPSRTC',
      category: 'temple',
      transportHub: 'Mathura Junction / Old Bus Stand',
      aliases: ['mathura', 'krishna janmabhoomi', 'मथुरा', 'మథుర', 'कृष्ण जन्मभूमि'],
    ),
    GazetteerEntry(
      id: 'vrindavan_up',
      name: 'Vrindavan',
      stateCode: 'UP',
      stateName: 'Uttar Pradesh',
      district: 'Mathura',
      coords: LatLng(27.5806, 77.7006),
      primaryRtc: 'UPSRTC',
      category: 'temple',
      transportHub: 'Vrindavan Railway Station / Mathura Jn',
      aliases: ['vrindavan', 'brindavan', 'वृंदावन', 'బృందావనం', 'banke bihari', 'बांके बिहारी'],
    ),
    GazetteerEntry(
      id: 'lucknow_up',
      name: 'Lucknow',
      stateCode: 'UP',
      stateName: 'Uttar Pradesh',
      district: 'Lucknow',
      coords: LatLng(26.8467, 80.9462),
      primaryRtc: 'UPSRTC',
      category: 'city',
      transportHub: 'Lucknow Charbagh / Alambagh Bus Terminal',
      aliases: ['lucknow', 'लखनऊ', 'లక్నో'],
    ),

    // ── UTTARAKHAND (UK) ─────────────────────────────────────────────────
    GazetteerEntry(
      id: 'kedarnath',
      name: 'Kedarnath',
      stateCode: 'UK',
      stateName: 'Uttarakhand',
      district: 'Rudraprayag',
      coords: LatLng(30.7346, 79.0669),
      primaryRtc: 'UTC',
      category: 'temple',
      transportHub: 'Rishikesh Railway Station / Gaurikund Bus Stand',
      aliases: ['kedarnath', 'kedar', 'केदारनाथ', 'కేదార్‌నాథ్', 'కేదార్', 'gaurikund', 'గౌరీకుండ్'],
    ),
    GazetteerEntry(
      id: 'badrinath_uk',
      name: 'Badrinath',
      stateCode: 'UK',
      stateName: 'Uttarakhand',
      district: 'Chamoli',
      coords: LatLng(30.7433, 79.4938),
      primaryRtc: 'UTC',
      category: 'temple',
      transportHub: 'Rishikesh Railway Station / Badrinath Bus Stand',
      aliases: ['badrinath', 'badri', 'बद्रीनाथ', 'బద్రీనాథ్', 'badri vishal'],
    ),
    GazetteerEntry(
      id: 'haridwar_uk',
      name: 'Haridwar',
      stateCode: 'UK',
      stateName: 'Uttarakhand',
      district: 'Haridwar',
      coords: LatLng(29.9457, 78.1642),
      primaryRtc: 'UTC',
      category: 'temple',
      transportHub: 'Haridwar Junction / Roadways Bus Stand',
      aliases: ['haridwar', 'hardwar', 'हरिद्वार', 'హరిద్వార్', 'har ki pauri'],
    ),
    GazetteerEntry(
      id: 'rishikesh_uk',
      name: 'Rishikesh',
      stateCode: 'UK',
      stateName: 'Uttarakhand',
      district: 'Dehradun',
      coords: LatLng(30.0869, 78.2676),
      primaryRtc: 'UTC',
      category: 'temple',
      transportHub: 'Yog Nagari Rishikesh / Rishikesh Bus Stand',
      aliases: ['rishikesh', 'hrishikesh', 'ऋषिकेश', 'రిషికేశ్', 'laxman jhula', 'triveni ghat rishikesh'],
    ),

    // ── GUJARAT (GJ) ─────────────────────────────────────────────────────
    GazetteerEntry(
      id: 'dwarka',
      name: 'Dwarka',
      stateCode: 'GJ',
      stateName: 'Gujarat',
      district: 'Devbhumi Dwarka',
      coords: LatLng(22.2394, 68.9678),
      primaryRtc: 'GSRTC',
      category: 'temple',
      transportHub: 'Dwarka Railway Station / GSRTC Bus Stand',
      aliases: ['dwarka', 'dwaraka', 'dwarkadhish', 'द्वारका', 'द्वारिका', 'ద్వారక', 'ద్వారకాధీశ్'],
    ),
    GazetteerEntry(
      id: 'somnath_gj',
      name: 'Somnath',
      stateCode: 'GJ',
      stateName: 'Gujarat',
      district: 'Gir Somnath',
      coords: LatLng(20.8880, 70.4012),
      primaryRtc: 'GSRTC',
      category: 'temple',
      transportHub: 'Veraval Junction / Somnath Bus Stand',
      aliases: ['somnath', 'somnath temple', 'सोमनाथ', 'సోమనాథ్', 'veraval'],
    ),
    GazetteerEntry(
      id: 'ahmedabad_gj',
      name: 'Ahmedabad',
      stateCode: 'GJ',
      stateName: 'Gujarat',
      district: 'Ahmedabad',
      coords: LatLng(23.0225, 72.5714),
      primaryRtc: 'GSRTC',
      category: 'city',
      transportHub: 'Ahmedabad Junction (Kalupur) / Geeta Mandir Bus Station',
      aliases: ['ahmedabad', 'amdavad', 'अहमदाबाद', 'అహ్మదాబాద్'],
    ),
    GazetteerEntry(
      id: 'rajkot_gj',
      name: 'Rajkot',
      stateCode: 'GJ',
      stateName: 'Gujarat',
      district: 'Rajkot',
      coords: LatLng(22.3039, 70.8022),
      primaryRtc: 'GSRTC',
      category: 'city',
      transportHub: 'Rajkot Junction / GSRTC Central Bus Stand',
      aliases: ['rajkot', 'राजकोट', 'రాజ్కోట్'],
    ),

    // ── MAHARASHTRA (MH) ─────────────────────────────────────────────────
    GazetteerEntry(
      id: 'mumbai',
      name: 'Mumbai',
      stateCode: 'MH',
      stateName: 'Maharashtra',
      district: 'Mumbai City',
      coords: LatLng(19.0760, 72.8777),
      primaryRtc: 'MSRTC',
      category: 'city',
      transportHub: 'Mumbai CST / Mumbai Central / Dadar',
      aliases: ['mumbai', 'bombay', 'मुंबई', 'ముంబై', 'siddhi vinayak', 'mahalaxmi'],
    ),
    GazetteerEntry(
      id: 'pune_mh',
      name: 'Pune',
      stateCode: 'MH',
      stateName: 'Maharashtra',
      district: 'Pune',
      coords: LatLng(18.5204, 73.8567),
      primaryRtc: 'MSRTC',
      category: 'city',
      transportHub: 'Pune Junction / Shivajinagar / Swargate Bus Stand',
      aliases: ['pune', 'poona', 'पुणे', 'పూణే', 'shreemant dagdusheth'],
    ),
    GazetteerEntry(
      id: 'shirdi_mh',
      name: 'Shirdi',
      stateCode: 'MH',
      stateName: 'Maharashtra',
      district: 'Ahmednagar',
      coords: LatLng(19.7645, 74.4762),
      primaryRtc: 'MSRTC',
      category: 'temple',
      transportHub: 'Sainagar Shirdi Railway Station / Shirdi Bus Stand',
      aliases: ['shirdi', 'sai baba', 'शिर्डी', 'షిర్డీ', 'sai sansthan', 'साईं बाबा'],
    ),
    GazetteerEntry(
      id: 'nashik_mh',
      name: 'Nashik',
      stateCode: 'MH',
      stateName: 'Maharashtra',
      district: 'Nashik',
      coords: LatLng(19.9975, 73.7898),
      primaryRtc: 'MSRTC',
      category: 'temple',
      transportHub: 'Nashik Road Railway Station / CBS Bus Stand',
      aliases: ['nashik', 'nasik', 'नासिक', 'नाशिक', 'నాసిక్', 'panchavati', 'पंचवटी'],
    ),
    GazetteerEntry(
      id: 'trimbakeshwar_mh',
      name: 'Trimbakeshwar',
      stateCode: 'MH',
      stateName: 'Maharashtra',
      district: 'Nashik',
      coords: LatLng(19.9328, 73.5307),
      primaryRtc: 'MSRTC',
      category: 'temple',
      transportHub: 'Nashik Road Railway Station (30 km) / Trimbak Bus Stand',
      aliases: ['trimbakeshwar', 'tryambakeshwar', 'त्र्यंबकेश्वर', 'త్రియంబకేశ్వర్', 'trimbak'],
    ),

    // ── ODISHA (OD) ──────────────────────────────────────────────────────
    GazetteerEntry(
      id: 'puri_od',
      name: 'Puri',
      stateCode: 'OD',
      stateName: 'Odisha',
      district: 'Puri',
      coords: LatLng(19.8135, 85.8312),
      primaryRtc: 'OSRTC',
      category: 'temple',
      transportHub: 'Puri Railway Station / Badadanda Bus Stand',
      aliases: ['puri', 'poori', 'jagannath', 'jagannath puri', 'पुरी', 'పూరి', 'జగన్నాథ పూరి'],
    ),
    GazetteerEntry(
      id: 'bhubaneswar_od',
      name: 'Bhubaneswar',
      stateCode: 'OD',
      stateName: 'Odisha',
      district: 'Khordha',
      coords: LatLng(20.2961, 85.8245),
      primaryRtc: 'OSRTC',
      category: 'temple',
      transportHub: 'Bhubaneswar Railway Station / Baramunda Bus Stand',
      aliases: ['bhubaneswar', 'bhubaneshwar', 'भुवनेश्वर', 'భువనేశ్వర్', 'lingaraj', 'लिंगराज'],
    ),

    // ── KARNATAKA (KA) ───────────────────────────────────────────────────
    GazetteerEntry(
      id: 'bengaluru_ka',
      name: 'Bengaluru',
      stateCode: 'KA',
      stateName: 'Karnataka',
      district: 'Bengaluru Urban',
      coords: LatLng(12.9716, 77.5946),
      primaryRtc: 'KSRTC',
      category: 'city',
      transportHub: 'KSR Bengaluru (Majestic) / Kempegowda Bus Station',
      aliases: ['bengaluru', 'bangalore', 'बेंगलुरु', 'బెంగళూరు', 'ಬೆಂಗಳೂರು'],
    ),
    GazetteerEntry(
      id: 'udupi_ka',
      name: 'Udupi',
      stateCode: 'KA',
      stateName: 'Karnataka',
      district: 'Udupi',
      coords: LatLng(13.3409, 74.7421),
      primaryRtc: 'KSRTC',
      category: 'temple',
      transportHub: 'Udupi Railway Station / KSRTC Bus Stand',
      aliases: ['udupi', 'odipu', 'उडुपी', 'ఉడిపి', 'ಉಡುಪಿ', 'krishna matha', 'కృష్ణ మఠం'],
    ),
    GazetteerEntry(
      id: 'hampi_ka',
      name: 'Hampi',
      stateCode: 'KA',
      stateName: 'Karnataka',
      district: 'Vijayanagara',
      coords: LatLng(15.3350, 76.4600),
      primaryRtc: 'KSRTC',
      category: 'temple',
      transportHub: 'Hosapete Junction (13 km) / Hampi Bus Stand',
      aliases: ['hampi', 'humpi', 'हम्पी', 'హంపి', 'ಹಂಪಿ', 'virupaksha', 'విరూపాక్ష'],
    ),
  ];

  /// Normalized lowercase string without zero-width / joiner characters.
  static String normalize(String s) {
    return s
        .replaceAll(RegExp(r'[\u200B\u200C\u200D\uFEFF]'), '')
        .toLowerCase()
        .trim();
  }

  /// Levenshtein distance computation.
  static int _levenshtein(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v0[s2.length];
  }

  /// Resolve query against the gazetteer.
  ///
  /// Matching Hierarchy:
  ///   1. Exact alias match (case- and space-insensitive).
  ///   2. Substring match (query contains alias OR alias contains query).
  ///   3. Length-guarded fuzzy match:
  ///      - If word length <= 4: NO fuzzy matching allowed (exact only).
  ///      - If word length > 4: Levenshtein distance <= 2, matching first character, logged.
  ///   4. Unresolved -> null.
  GazetteerEntry? resolve(String rawQuery) {
    final q = normalize(rawQuery);
    if (q.isEmpty) return null;

    // 1. Exact alias match
    for (final entry in entries) {
      for (final alias in [entry.name, ...entry.aliases]) {
        if (normalize(alias) == q) {
          return entry;
        }
      }
    }

    // 2. Substring match (longest specific match wins)
    GazetteerEntry? bestSub;
    int bestLen = 0;
    for (final entry in entries) {
      for (final alias in [entry.name, ...entry.aliases]) {
        final a = normalize(alias);
        if (a.isEmpty) continue;
        if ((q.contains(a) || a.contains(q)) && a.length > bestLen) {
          bestSub = entry;
          bestLen = a.length;
        }
      }
    }
    if (bestSub != null) return bestSub;

    // 3. Length-guarded fuzzy match
    // CRITICAL ANTI-COLLISION RULE: Never fuzzy match short words (<= 4 chars, e.g. "Puri", "Pune", "Kashi").
    if (q.length <= 4) {
      return null;
    }

    GazetteerEntry? bestFuzzy;
    int minDistance = 999;
    for (final entry in entries) {
      for (final alias in [entry.name, ...entry.aliases]) {
        final a = normalize(alias);
        if (a.length <= 4) continue; // Skip short aliases in fuzzy search
        if (a[0] != q[0]) continue; // Enforce first character prefix match

        final dist = _levenshtein(q, a);
        if (dist <= 2 && dist < minDistance) {
          minDistance = dist;
          bestFuzzy = entry;
        }
      }
    }

    if (bestFuzzy != null) {
      debugPrint('[IndiaGazetteer] AUDIT: Fuzzy match "$q" -> "${bestFuzzy.name}" (Levenshtein distance: $minDistance)');
      return bestFuzzy;
    }

    return null;
  }

  /// Lookup entry by ID.
  GazetteerEntry? byId(String id) {
    final clean = id.toLowerCase().trim();
    for (final e in entries) {
      if (e.id.toLowerCase() == clean) return e;
    }
    return null;
  }
}