// lib/services/place_search_service.dart
//
// 100% OFFLINE destination search for PathSaathi. No online geocoding.
//
// Ships a compact, hardcoded index of the key Kashi/Varanasi (and Prayagraj
// origin) landmarks a lost pilgrim would search for, with multilingual aliases
// so "Kashi", "Banaras", "काशी", "వారణాసి" all resolve to Kashi Vishwanath.
//
// Coordinates are real (OpenStreetMap-sourced) so bearing/distance guidance is
// truthful even with no map tiles available.

import 'package:latlong2/latlong.dart';

class Place {
  final String id;
  final String name;        // canonical display name
  final String category;    // temple | station | hospital | ghat | transport | city | camp
  final LatLng coords;
  final List<String> aliases; // lowercase search terms (incl. transliterations)
  final String? note;

  const Place({
    required this.id,
    required this.name,
    required this.category,
    required this.coords,
    this.aliases = const [],
    this.note,
  });
}

class PlaceSearchService {
  PlaceSearchService._();
  static final PlaceSearchService instance = PlaceSearchService._();

  /// Real coordinates. Kept small on purpose — the critical pilgrim POIs only.
  static const List<Place> places = [
    // ── KASHI / VARANASI ────────────────────────────────────────────────
    Place(
      id: 'kashi_vishwanath',
      name: 'Kashi Vishwanath Temple',
      category: 'temple',
      coords: LatLng(25.3109, 83.0107),
      aliases: [
        'kashi', 'kaashi', 'काशी', 'కాశీ', 'காசி', 'ਕਾਸ਼ੀ',
        'vishwanath', 'kashi vishwanath', 'kashi vishwanath temple',
        'banaras', 'benares', 'varanasi temple', 'golden temple varanasi',
        'बाबा विश्वनाथ', 'विश्वनाथ',
      ],
      note: 'Main Jyotirlinga temple, Lahori Tola, Varanasi',
    ),
    Place(
      id: 'varanasi_city',
      name: 'Varanasi (Kashi)',
      category: 'city',
      coords: LatLng(25.3176, 82.9739),
      aliases: [
        'varanasi', 'kashi', 'banaras', 'benares', 'वाराणसी', 'वारानसी',
        'వారణాసి', 'வாரணாசி', 'ਵਾਰਾਣਸੀ', 'बनारस', 'काशी',
      ],
      note: 'Holy city on the Ganga',
    ),
    Place(
      id: 'dashashwamedh_ghat',
      name: 'Dashashwamedh Ghat',
      category: 'ghat',
      coords: LatLng(25.3076, 83.0104),
      aliases: ['dashashwamedh', 'ganga aarti ghat', 'main ghat', 'दशाश्वमेध', 'aarti ghat'],
      note: 'Main Ganga Aarti ghat',
    ),
    Place(
      id: 'manikarnika_ghat',
      name: 'Manikarnika Ghat',
      category: 'ghat',
      coords: LatLng(25.3109, 83.0155),
      aliases: ['manikarnika', 'मणिकर्णिका', 'burning ghat'],
    ),
    Place(
      id: 'varanasi_jn',
      name: 'Varanasi Junction Railway Station',
      category: 'station',
      coords: LatLng(25.3272, 82.9866),
      aliases: [
        'varanasi station', 'varanasi junction', 'cantt station', 'railway station',
        'train station', 'रेलवे स्टेशन', 'स्टेशन', 'రైల్వే స్టేషన్', 'ரயில் நிலையம்',
        'bhu station', 'varanasi cantt',
      ],
      note: 'Varanasi Cantt (BSB)',
    ),
    Place(
      id: 'banaras_airport',
      name: 'Lal Bahadur Shastri Airport (Varanasi)',
      category: 'transport',
      coords: LatLng(25.4524, 82.8593),
      aliases: ['airport', 'varanasi airport', 'babatpur', 'हवाई अड्डा', 'విమానాశ్రయం', 'flight'],
    ),
    Place(
      id: 'bhu_hospital',
      name: 'BHU Sir Sunderlal Hospital',
      category: 'hospital',
      coords: LatLng(25.2677, 82.9913),
      aliases: ['hospital', 'bhu hospital', 'sunderlal', 'अस्पताल', 'ఆసుపత్రి', 'மருத்துவமனை', 'medical'],
    ),
    Place(
      id: 'varanasi_bus_stand',
      name: 'Varanasi Cantt Bus Stand',
      category: 'transport',
      coords: LatLng(25.3218, 82.9865),
      aliases: ['bus stand', 'bus station', 'roadways', 'बस अड्डा', 'బస్ స్టాండ్', 'பேருந்து நிலையம்'],
    ),
    Place(
      id: 'sarnath',
      name: 'Sarnath',
      category: 'temple',
      coords: LatLng(25.3811, 83.0244),
      aliases: ['sarnath', 'सारनाथ', 'buddha', 'deer park'],
    ),

    // ── PRAYAGRAJ (origin / Kumbh) — for the current-event scenario ──────
    Place(
      id: 'sangam',
      name: 'Triveni Sangam (Prayagraj)',
      category: 'ghat',
      coords: LatLng(25.4358, 81.8814),
      aliases: ['sangam', 'triveni', 'संगम', 'संगम घाट', 'త్రివేణి సంగమం'],
    ),
    Place(
      id: 'prayagraj',
      name: 'Prayagraj (Allahabad)',
      category: 'city',
      coords: LatLng(25.4358, 81.8463),
      aliases: [
        'prayagraj', 'allahabad', 'प्रयागराज', 'इलाहाबाद', 'ప్రయాగ్‌రాజ్', 'பிரயாக்ராஜ்',
      ],
    ),
    Place(
      id: 'prayagraj_jn',
      name: 'Prayagraj Junction',
      category: 'station',
      coords: LatLng(25.4272, 81.8266),
      aliases: ['prayagraj station', 'allahabad junction', 'prayagraj junction'],
    ),

    // ── MAJOR CITIES (multilingual) — general travel destinations ────────
    Place(
      id: 'delhi',
      name: 'Delhi',
      category: 'city',
      coords: LatLng(28.6139, 77.2090),
      aliases: [
        'delhi', 'new delhi', 'दिल्ली', 'नई दिल्ली', 'ఢిల్లీ', 'డిల్లీ',
        'டெல்லி', 'புது டெல்லி', 'ਦਿੱਲੀ', 'দিল্লি', 'દિલ્હી', 'ದೆಹಲಿ', 'ദില്ലി',
      ],
      note: 'National capital',
    ),
    Place(
      id: 'mumbai',
      name: 'Mumbai',
      category: 'city',
      coords: LatLng(19.0760, 72.8777),
      aliases: [
        'mumbai', 'bombay', 'मुंबई', 'बॉम्बे', 'ముంబై', 'மும்பை', 'ਮੁੰਬਈ',
        'মুম্বই', 'મુંબઈ', 'ಮುಂಬೈ', 'മുംബൈ',
      ],
    ),
    Place(
      id: 'dwarka',
      name: 'Dwaraka',
      category: 'temple',
      coords: LatLng(22.2394, 68.9678),
      aliases: [
        'dwarka', 'dwaraka', 'dwarkadhish', 'द्वारका', 'द्वारिका',
        'ద్వారక', 'துவாரகை', 'દ્વારકા',
      ],
      note: 'Dwarkadhish Temple — one of the Char Dham',
    ),
    Place(
      id: 'kolkata',
      name: 'Kolkata',
      category: 'city',
      coords: LatLng(22.5726, 88.3639),
      aliases: ['kolkata', 'calcutta', 'कोलकाता', 'కోల్‌కతా', 'கொல்கத்தா', 'কলকাতা'],
    ),
    Place(
      id: 'chennai',
      name: 'Chennai',
      category: 'city',
      coords: LatLng(13.0827, 80.2707),
      aliases: ['chennai', 'madras', 'चेन्नई', 'చెన్నై', 'சென்னை', 'চেন্নাই'],
    ),
    Place(
      id: 'hyderabad',
      name: 'Hyderabad',
      category: 'city',
      coords: LatLng(17.3850, 78.4867),
      aliases: ['hyderabad', 'हैदराबाद', 'హైదరాబాద్', 'ஹைதராபாத்', 'হায়দরাবাদ'],
    ),
    Place(
      id: 'bengaluru',
      name: 'Bengaluru',
      category: 'city',
      coords: LatLng(12.9716, 77.5946),
      aliases: ['bengaluru', 'bangalore', 'बेंगलुरु', 'बैंगलोर', 'బెంగళూరు', 'பெங்களூரு', 'ಬೆಂಗಳೂರು'],
    ),
    Place(
      id: 'ayodhya_city',
      name: 'Ayodhya',
      category: 'city',
      coords: LatLng(26.7922, 82.1998),
      aliases: ['ayodhya', 'अयोध्या', 'అయోధ్య', 'அயோத்தி'],
    ),
    Place(
      id: 'haridwar_city',
      name: 'Haridwar',
      category: 'city',
      coords: LatLng(29.9457, 78.1642),
      aliases: ['haridwar', 'हरिद्वार', 'హరిద్వార్', 'ஹரித்வார்'],
    ),

    // ── CHAR DHAM / HIMALAYAN PILGRIMAGE ─────────────────────────────────
    Place(
      id: 'kedarnath',
      name: 'Kedarnath',
      category: 'temple',
      coords: LatLng(30.7346, 79.0669),
      aliases: [
        'kedarnath', 'kedar', 'केदारनाथ', 'केदार', 'కేదార్‌నాథ్', 'கேதார்நாத்',
        'ਕੇਦਾਰਨਾਥ', 'কেদারনাথ', 'કેદારનાથ',
      ],
      note: 'Kedarnath Jyotirlinga, Uttarakhand',
    ),
    Place(
      id: 'badrinath',
      name: 'Badrinath',
      category: 'temple',
      coords: LatLng(30.7433, 79.4938),
      aliases: ['badrinath', 'badri', 'बद्रीनाथ', 'బద్రీనాథ్', 'பத்ரிநாத்'],
    ),
    Place(
      id: 'gangotri',
      name: 'Gangotri',
      category: 'temple',
      coords: LatLng(30.9947, 78.9398),
      aliases: ['gangotri', 'गंगोत्री', 'గంగోత్రి'],
    ),
    Place(
      id: 'yamunotri',
      name: 'Yamunotri',
      category: 'temple',
      coords: LatLng(31.0139, 78.4600),
      aliases: ['yamunotri', 'यमुनोत्री', 'యమునోత్రి'],
    ),
    Place(
      id: 'tirupati',
      name: 'Tirupati',
      category: 'temple',
      coords: LatLng(13.6288, 79.4192),
      aliases: ['tirupati', 'tirumala', 'तिरुपति', 'తిరుపతి', 'திருப்பதி', 'balaji'],
    ),
    Place(
      id: 'visakhapatnam',
      name: 'Visakhapatnam',
      category: 'city',
      coords: LatLng(17.6868, 83.2185),
      aliases: [
        'visakhapatnam', 'vizag', 'waltair', 'విశాఖపట్నం', 'విశాఖ', 'వైజాగ్',
        'विशाखापट्टनम', 'विशाखापत्तनम', 'వైజాగ్ సిటీ', 'simhachalam', 'సింహాచలం', 'விசாகப்பட்டினம்'
      ],
      note: 'Coastal pilgrimage hub, Simhachalam Varaha Lakshmi Narasimha Temple',
    ),
    Place(
      id: 'srikakulam',
      name: 'Srikakulam',
      category: 'city',
      coords: LatLng(18.2949, 83.8938),
      aliases: [
        'srikakulam', 'chicacole', 'శ్రీకాకుళం', 'శ్రీకాకుళము',
        'श्रीकाकुलम', 'arasavalli', 'అరసవల్లి', 'srikurmam', 'శ్రీకూర్మం', 'ஸ்ரீகாகுளம்'
      ],
      note: 'Ancient pilgrimage center, Arasavalli Sun Temple & Srikurmam Kurmanatha Temple',
    ),
    Place(
      id: 'shirdi',
      name: 'Shirdi',
      category: 'temple',
      coords: LatLng(19.7645, 74.4762),
      aliases: ['shirdi', 'sai baba', 'शिर्डी', 'షిర్డీ', 'ஷீர்டி'],
    ),
    Place(
      id: 'puri',
      name: 'Puri (Jagannath)',
      category: 'temple',
      coords: LatLng(19.8135, 85.8312),
      aliases: ['puri', 'jagannath', 'पुरी', 'జగన్నాథ', 'ஜகன்நாத்'],
    ),
    Place(
      id: 'ujjain',
      name: 'Ujjain (Mahakaleshwar)',
      category: 'temple',
      coords: LatLng(23.1828, 75.7681),
      aliases: ['ujjain', 'mahakal', 'mahakaleshwar', 'उज्जैन', 'ఉజ్జయిని', 'உஜ்ஜைன்'],
    ),
    Place(
      id: 'pune',
      name: 'Pune',
      category: 'city',
      coords: LatLng(18.5204, 73.8567),
      aliases: ['pune', 'poona', 'पुणे', 'పూణే', 'புனே'],
    ),
    Place(
      id: 'jaipur',
      name: 'Jaipur',
      category: 'city',
      coords: LatLng(26.9124, 75.7873),
      aliases: ['jaipur', 'जयपुर', 'జైపూర్', 'ஜெய்பூர்'],
    ),
  ];

  /// Filler/stop phrases (multilingual) stripped before matching so a sentence
  /// like "मुझे दिल्ली जाना है" or "I want to go to Delhi" resolves to Delhi.
  static const List<String> _fillers = [
    'i want to go to', 'i want to go', 'i need to go to', 'take me to',
    'navigate to', 'go to', 'reach', 'travel to', 'want to', 'please',
    'मुझे', 'जाना', 'है', 'जाना है', 'चलो', 'ले चलो', 'पहुंचना',
    'నాకు', 'వెళ్లాలి', 'వెళ్ళాలి', 'కి', 'కు', 'తీసుకెళ్లు',
    'நான்', 'செல்ல', 'வேண்டும்', 'போக', 'எனக்கு',
  ];

  /// Resolve a free-form (possibly multilingual, possibly mixed) sentence to a
  /// single canonical destination Place. Returns null if nothing matches — the
  /// caller must NOT substitute a default (prevents Delhi→Prayagraj bug).
  Place? resolveDestination(String sentence) {
    final raw = sentence.toLowerCase().trim();
    if (raw.isEmpty) return null;

    // Direct alias hit anywhere in the sentence (works for mixed language,
    // e.g. "मुझे Delhi जाना है" or "నాకు Delhi కి train కావాలి").
    Place? best;
    int bestLen = 0;
    for (final p in places) {
      for (final a in [p.name.toLowerCase(), ...p.aliases]) {
        if (a.isEmpty) continue;
        if (raw.contains(a) && a.length > bestLen) {
          best = p;
          bestLen = a.length; // prefer the longest (most specific) alias match
        }
      }
    }
    if (best != null) return best;

    // Fallback: strip filler words, then run the normal search on the remainder.
    var cleaned = raw;
    for (final f in _fillers) {
      cleaned = cleaned.replaceAll(f, ' ');
    }
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.isEmpty) return null;
    final results = search(cleaned);
    return results.isNotEmpty ? results.first : null;
  }

  /// Offline fuzzy search: matches canonical name or any alias (substring,
  /// case/space-insensitive). Kashi-related terms are boosted to the top.
  List<Place> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final matches = <Place>[];
    for (final p in places) {
      final hay = [p.name.toLowerCase(), ...p.aliases];
      if (hay.any((h) => h.contains(q) || q.contains(h))) {
        matches.add(p);
      }
    }
    // Prioritise exact Kashi Vishwanath / Varanasi for the pilgrim scenario.
    matches.sort((a, b) {
      int rank(Place p) {
        if (p.id == 'kashi_vishwanath') return 0;
        if (p.id == 'varanasi_city') return 1;
        return 2;
      }
      return rank(a).compareTo(rank(b));
    });
    return matches;
  }

  Place? byId(String id) {
    for (final p in places) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Convenience: the canonical Kashi destination.
  Place get kashi => byId('kashi_vishwanath')!;
}
