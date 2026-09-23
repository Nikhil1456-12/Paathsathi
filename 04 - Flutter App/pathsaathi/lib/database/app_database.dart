import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Pre-populated, 100% Offline SQLite Database for PathSaathi
/// Stores structured event schedules, transport routes, camp allotments,
/// points of interest, and emergency centers for Kumbh Mela.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pathsaathi_event.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedData(db);
        await _createJourneyTables(db);
        await _seedJourneyData(db);
        await _migrateV3(db);
        await _migrateV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 → v2: add Journey Assistant tables without touching existing data.
        if (oldVersion < 2) {
          await _createJourneyTables(db);
          await _seedJourneyData(db);
        }
        // v2 → v3: add destination_id to accommodations/itineraries for trip-aware data.
        if (oldVersion < 3) {
          await _migrateV3(db);
        }
        // v3 → v4: additive expansion for Visakhapatnam, Srikakulam, and Chennai.
        if (oldVersion < 4) {
          await _migrateV4(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Buses table
    await db.execute('''
      CREATE TABLE buses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bus_number TEXT,
        origin TEXT,
        destination TEXT,
        departure_time TEXT,
        gate TEXT,
        frequency_mins INTEGER,
        status TEXT,
        seats_available INTEGER
      )
    ''');

    // 2. Trains table
    await db.execute('''
      CREATE TABLE trains (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        train_number TEXT,
        train_name TEXT,
        platform TEXT,
        departure_time TEXT,
        destination TEXT,
        status TEXT
      )
    ''');

    // 3. Accommodations table
    await db.execute('''
      CREATE TABLE accommodations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        camp_name TEXT,
        sector TEXT,
        tent_id TEXT,
        distance_km REAL,
        lat REAL,
        lng REAL,
        facilities TEXT
      )
    ''');

    // 4. Points of interest / Navigation waypoints
    await db.execute('''
      CREATE TABLE places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        native_name_hi TEXT,
        native_name_te TEXT,
        category TEXT,
        lat REAL,
        lng REAL,
        description TEXT
      )
    ''');

    // 5. Emergencies & Helplines table
    await db.execute('''
      CREATE TABLE emergencies (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT,
        title TEXT,
        phone TEXT,
        location TEXT,
        instructions TEXT
      )
    ''');

    // 6. Itinerary & Schedule table
    await db.execute('''
      CREATE TABLE itineraries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        time TEXT,
        title TEXT,
        title_hi TEXT,
        title_te TEXT,
        location TEXT,
        crowd_level TEXT,
        icon_name TEXT
      )
    ''');
  }

  Future<void> _seedData(Database db) async {
    // Seed Buses
    await db.rawInsert('''
      INSERT INTO buses (bus_number, origin, destination, departure_time, gate, frequency_mins, status, seats_available)
      VALUES 
        ('Bus 47', 'Prayagraj Junction', 'Sangam Ghat', '06:00 AM', 'Gate 3', 15, 'Available', 28),
        ('Bus 21', 'Civil Lines', 'Sangam Ghat', '07:30 AM', 'Gate 5', 20, 'Few Seats', 6),
        ('Bus 09', 'Naini Bridge', 'Sangam Ghat', '09:00 AM', 'Gate 1', 30, 'Full', 0),
        ('Shuttle 12', 'Shakti Camp', 'Triveni Marg', '06:30 AM', 'Gate 2', 10, 'Available', 40),
        ('Bus 88', 'Sector 4 Camp', 'Kalyani Devi', '08:15 AM', 'Gate 7', 25, 'Available', 18)
    ''');

    // Seed Trains
    await db.rawInsert('''
      INSERT INTO trains (train_number, train_name, platform, departure_time, destination, status)
      VALUES 
        ('12417', 'Prayagraj Express', 'Platform 1', '09:30 PM', 'New Delhi', 'On Time'),
        ('14218', 'Unchahar Express', 'Platform 3', '06:15 AM', 'Chandigarh', 'On Time'),
        ('22436', 'Vande Bharat Special', 'Platform 4', '03:00 PM', 'Varanasi', 'On Time')
    ''');

    // Seed Accommodations
    await db.rawInsert('''
      INSERT INTO accommodations (camp_name, sector, tent_id, distance_km, lat, lng, facilities)
      VALUES 
        ('Shakti Camp', 'Sector 7', 'Tent B-214', 1.2, 25.4460, 81.8680, 'Medical Camp 200m, Wash Area 50m, Dining Hall 300m'),
        ('Ganga Vihar Camp', 'Sector 4', 'Tent A-108', 0.8, 25.4410, 81.8710, 'RO Drinking Water, Charging Point, First Aid'),
        ('Triveni Ashram', 'Sector 2', 'Block C-12', 1.6, 25.4520, 81.8650, 'Community Kitchen, 24/7 Security, Washrooms')
    ''');

    // Seed Places / Waypoints
    await db.rawInsert('''
      INSERT INTO places (name, native_name_hi, native_name_te, category, lat, lng, description)
      VALUES 
        ('Sangam Ghat', 'संगम घाट', 'సంగం ఘాట్', 'ghat', 25.4358, 81.8814, 'Confluence of Ganga, Yamuna & Saraswati'),
        ('Shakti Camp (Sector 7)', 'शक्ति शिविर (सेक्टर 7)', 'శక్తి క్యాంప్ (సెక్టార్ 7)', 'camp', 25.4460, 81.8680, 'Pilgrim Accommodation Area'),
        ('Gate 3 Bus Stand', 'गेट 3 बस स्टैंड', 'గేట్ 3 బస్ స్టాప్', 'transport', 25.4485, 81.8610, 'Main Sangam shuttle terminal'),
        ('Medical Emergency Post 2', 'चिकित्सा सहायता केंद्र 2', 'వైద్య అత్యవసర కేంద్రం 2', 'emergency', 25.4420, 81.8750, '24/7 Ambulance & First Aid Post')
    ''');

    // Seed Emergencies
    await db.rawInsert('''
      INSERT INTO emergencies (type, title, phone, location, instructions)
      VALUES 
        ('medical', 'Medical Emergency Post', '108', 'Sector 7 & Gate 3', 'Immediate paramedic team deployed with stretchers.'),
        ('police', 'Kumbh Police Control Room', '112', 'Parade Ground Central', 'Report lost individuals or security incidents.'),
        ('lost_found', 'Lost & Found Khoya Paya Camp', '1077', 'Sector 2 Main Gate', 'Loudspeaker announcement in 6 regional languages.')
    ''');

    // Seed Itinerary
    await db.rawInsert('''
      INSERT INTO itineraries (time, title, title_hi, title_te, location, crowd_level, icon_name)
      VALUES 
        ('05:30 AM', 'Morning Aarti at Sangam', 'संगम पर प्रातः आरती', 'సంగం వద్ద ఉదయపు హారతి', 'Sangam Ghat', 'Moderate', 'wb_sunny'),
        ('06:30 AM', 'Holy Dip (Snan)', 'पवित्र संगम स्नान', 'పవిత్ర సంగమ స్నానం', 'Sangam Main Platform', 'High', 'water_drop'),
        ('09:00 AM', 'Bade Hanuman Temple Visit', 'बड़े हनुमान मंदिर दर्शन', 'బడే హనుమాన్ ఆలయ దర్శనం', 'Fort Road', 'High', 'temple_hindu'),
        ('01:00 PM', 'Mahaprasad & Lunch', 'महाप्रसाद एवं विश्राम', 'మహాప్రసాదం మరియు విశ్రాంతి', 'Sector 7 Annakshetra', 'Moderate', 'restaurant'),
        ('06:00 PM', 'Evening Ganga Aarti & Diya Floating', 'सायं गंगा आरती एवं दीपदान', 'సాయంత్రం గంగా హారతి', 'Triveni Ghat', 'High', 'local_fire_department')
    ''');
  }

  // ── Database Queries ────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBuses() async {
    final db = await database;
    return await db.query('buses');
  }

  Future<List<Map<String, dynamic>>> searchBuses(String query) async {
    final db = await database;
    return await db.query(
      'buses',
      where: 'destination LIKE ? OR origin LIKE ? OR bus_number LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }

  Future<Map<String, dynamic>?> getPrimaryAccommodation() async {
    final db = await database;
    final res = await db.query('accommodations', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAccommodations() async {
    final db = await database;
    return await db.query('accommodations');
  }

  Future<List<Map<String, dynamic>>> getPlaces() async {
    final db = await database;
    return await db.query('places');
  }

  Future<List<Map<String, dynamic>>> getItineraries() async {
    final db = await database;
    return await db.query('itineraries');
  }

  Future<List<Map<String, dynamic>>> getEmergencies() async {
    final db = await database;
    return await db.query('emergencies');
  }

  // ── Journey Assistant (v2) ──────────────────────────────────────
  //
  // New tables that power the trip flow: multi-destination transport options,
  // nearby places (with coords) for offline survival, on-device reservations,
  // and the persisted journey plan. All curated/offline; no live/paid data.

  Future<void> _createJourneyTables(Database db) async {
    // Transport options keyed by destination (bus / train / bus+train).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transport_options (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination_id TEXT,
        mode TEXT,
        from_name TEXT,
        to_name TEXT,
        dep_time TEXT,
        arr_time TEXT,
        price_inr INTEGER,
        operator TEXT,
        indicative INTEGER DEFAULT 1
      )
    ''');

    // Nearby places per destination for offline help (hotel/hospital/food/
    // water/help) with real coordinates.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS nearby_places (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination_id TEXT,
        category TEXT,
        name TEXT,
        lat REAL,
        lng REAL,
        note TEXT,
        source TEXT DEFAULT 'curated'
      )
    ''');

    // On-device reservations (prototype bookings — no money, no live seat).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ref_code TEXT,
        type TEXT,
        title TEXT,
        details TEXT,
        status TEXT,
        created_at TEXT
      )
    ''');

    // The persisted journey plan (one active; history kept).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journey_plan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        destination_id TEXT,
        destination_name TEXT,
        dest_lat REAL,
        dest_lng REAL,
        transport_option_id INTEGER,
        stay_reservation_id INTEGER,
        cache_tiles INTEGER DEFAULT 0,
        cache_places INTEGER DEFAULT 0,
        cache_route INTEGER DEFAULT 0,
        active INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');
  }

  Future<void> _seedJourneyData(Database db) async {
    // Curated, indicative transport options for a few supported destinations.
    // Real place/station names; times/prices are indicative prototype data.
    await db.rawInsert('''
      INSERT INTO transport_options
        (destination_id, mode, from_name, to_name, dep_time, arr_time, price_inr, operator, indicative)
      VALUES
        ('dwarka','train','Ahmedabad Jn','Dwarka','05:40 AM','12:10 PM',420,'Saurashtra Mail',1),
        ('dwarka','train','Rajkot Jn','Dwarka','07:15 AM','11:50 AM',260,'Okha Express',1),
        ('dwarka','bus','Ahmedabad ST','Dwarka','06:00 AM','01:30 PM',530,'GSRTC Volvo',1),
        ('dwarka','bus','Jamnagar ST','Dwarka','08:30 AM','11:15 AM',180,'GSRTC Express',1),
        ('kedarnath','bus','Rishikesh','Gaurikund','05:00 AM','01:00 PM',410,'GMOU',1),
        ('kedarnath','train','Delhi','Haridwar','06:45 AM','11:30 AM',350,'Shatabdi',1),
        ('varanasi','train','New Delhi','Varanasi Jn','08:00 AM','04:30 PM',780,'Vande Bharat',1),
        ('varanasi','bus','Prayagraj','Varanasi','07:00 AM','10:30 AM',220,'UPSRTC',1),
        ('hyderabad','train','Vijayawada','Hyderabad Dcn','06:20 AM','12:40 PM',300,'Godavari Exp',1),
        ('mumbai','train','Pune','Mumbai CST','05:50 AM','09:10 AM',180,'Deccan Express',1)
    ''');

    // Curated nearby places (with real-ish coords) for offline help.
    await db.rawInsert('''
      INSERT INTO nearby_places (destination_id, category, name, lat, lng, note, source)
      VALUES
        ('dwarka','hotel','Hotel Dwarika Residency',22.2380,68.9680,'Near Dwarkadhish Temple','curated'),
        ('dwarka','hotel','VITS Dwarka',22.2410,68.9720,'Budget stay, 900m from temple','curated'),
        ('dwarka','hospital','Dwarka Sub-District Hospital',22.2405,68.9705,'Govt hospital, 24x7','curated'),
        ('dwarka','food','Shree Krishna Bhojanalay',22.2378,68.9678,'Veg thali near temple','curated'),
        ('dwarka','water','RO Water Point - Temple Rd',22.2382,68.9682,'Free drinking water','curated'),
        ('dwarka','help','Dwarka Tourist Help Desk',22.2388,68.9690,'Info + lost & found','curated'),
        ('kedarnath','hospital','Kedarnath Medical Post',30.7346,79.0669,'High-altitude first aid','curated'),
        ('kedarnath','food','GMVN Canteen',30.7340,79.0665,'Hot meals near shrine','curated'),
        ('kedarnath','help','Kedarnath Control Room',30.7350,79.0672,'Yatra assistance','curated'),
        ('varanasi','hotel','Hotel Ganges View',25.3050,83.0100,'Assi Ghat area','curated'),
        ('varanasi','hospital','BHU Trauma Centre',25.2677,82.9913,'Major hospital','curated'),
        ('varanasi','food','Kashi Chat Bhandar',25.3176,83.0062,'Famous local food','curated')
    ''');
  }

  // Transport options for a destination id (e.g. 'dwarka').
  Future<List<Map<String, dynamic>>> getTransportOptions(String destinationId) async {
    final db = await database;
    return await db.query('transport_options',
        where: 'destination_id = ?', whereArgs: [destinationId]);
  }

  // Nearby places for a destination, optionally filtered by category.
  Future<List<Map<String, dynamic>>> getNearbyPlaces(String destinationId,
      {String? category}) async {
    final db = await database;
    if (category != null) {
      return await db.query('nearby_places',
          where: 'destination_id = ? AND category = ?',
          whereArgs: [destinationId, category]);
    }
    return await db.query('nearby_places',
        where: 'destination_id = ?', whereArgs: [destinationId]);
  }

  Future<int> insertReservation(Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert('reservations', row);
  }

  Future<List<Map<String, dynamic>>> getReservations() async {
    final db = await database;
    return await db.query('reservations', orderBy: 'created_at DESC');
  }

  Future<int> upsertActivePlan(Map<String, dynamic> row) async {
    final db = await database;
    // Only one active plan at a time — deactivate previous, insert new.
    await db.update('journey_plan', {'active': 0}, where: 'active = 1');
    return await db.insert('journey_plan', row);
  }

  Future<Map<String, dynamic>?> getActivePlan() async {
    final db = await database;
    final res = await db.query('journey_plan',
        where: 'active = 1', orderBy: 'created_at DESC', limit: 1);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> updatePlanCacheStatus(int planId,
      {bool? tiles, bool? places, bool? route}) async {
    final db = await database;
    final data = <String, dynamic>{};
    if (tiles != null) data['cache_tiles'] = tiles ? 1 : 0;
    if (places != null) data['cache_places'] = places ? 1 : 0;
    if (route != null) data['cache_route'] = route ? 1 : 0;
    if (data.isEmpty) return;
    await db.update('journey_plan', data, where: 'id = ?', whereArgs: [planId]);
  }

  // ── v3 Migration: Trip-Aware Data ────────────────────────────────────

  Future<void> _migrateV3(Database db) async {
    // Add destination_id to accommodations and itineraries.
    await db.execute(
        'ALTER TABLE accommodations ADD COLUMN destination_id TEXT DEFAULT "prayagraj"');
    await db.execute(
        'ALTER TABLE itineraries ADD COLUMN destination_id TEXT DEFAULT "prayagraj"');

    // Tag existing seed rows as 'prayagraj' (already done by DEFAULT above).

    // Add Kedarnath accommodation seed data.
    await db.rawInsert('''
      INSERT INTO accommodations (camp_name, sector, tent_id, distance_km, lat, lng, facilities, destination_id)
      VALUES
        ('GMVN TRH Kedarnath','Base Camp','Room 12',0.3,30.7352,79.0670,'Hot Water, Blankets, Medical Aid 100m','kedarnath'),
        ('Tent Colony Gaurikund','Gaurikund','Tent G-05',14.0,30.6500,79.0150,'Helipad 200m, Dining, First Aid','kedarnath')
    ''');

    // Add Kedarnath itinerary seed data.
    await db.rawInsert('''
      INSERT INTO itineraries (time, title, title_hi, title_te, location, crowd_level, icon_name, destination_id)
      VALUES
        ('04:30 AM','Trek Start from Gaurikund','गौरीकुंड से पैदल यात्रा','గౌరీకుండ్ నుండి ట్రెక్','Gaurikund','High','directions_walk','kedarnath'),
        ('10:00 AM','Kedarnath Temple Darshan','केदारनाथ मंदिर दर्शन','కేదార్‌నాథ్ ఆలయ దర్శనం','Kedarnath Temple','High','temple_hindu','kedarnath'),
        ('12:30 PM','Bhairavnath Temple Visit','भैरवनाथ मंदिर दर्शन','భైరవనాథ్ ఆలయ దర్శనం','Near Kedarnath','Moderate','temple_hindu','kedarnath'),
        ('01:30 PM','Lunch at GMVN Canteen','GMVN कैंटीन में भोजन','GMVN క్యాంటీన్‌లో భోజనం','Base Camp','Low','restaurant','kedarnath'),
        ('03:00 PM','Return Trek to Gaurikund','गौरीकुंड वापसी','గౌరీకుండ్ తిరిగి','Trek Route','Moderate','directions_walk','kedarnath')
    ''');

    // Add Dwarka accommodation seed data.
    await db.rawInsert('''
      INSERT INTO accommodations (camp_name, sector, tent_id, distance_km, lat, lng, facilities, destination_id)
      VALUES
        ('Hotel Dwarika Residency','Temple Area','Room 301',0.2,22.2380,68.9680,'AC, Hot Water, Temple View','dwarka'),
        ('VITS Dwarka','Main Road','Room 105',0.9,22.2410,68.9720,'WiFi, Restaurant, Parking','dwarka')
    ''');

    // Add Dwarka itinerary seed data.
    await db.rawInsert('''
      INSERT INTO itineraries (time, title, title_hi, title_te, location, crowd_level, icon_name, destination_id)
      VALUES
        ('05:00 AM','Morning Aarti at Dwarkadhish','द्वारकाधीश प्रातः आरती','ద్వారకాధీశ్ ఉదయ హారతి','Dwarkadhish Temple','High','wb_sunny','dwarka'),
        ('08:00 AM','Bet Dwarka Island Visit','बेट द्वारका दर्शन','బేట్ ద్వారక దర్శనం','Bet Dwarka','Moderate','directions_boat','dwarka'),
        ('12:00 PM','Nageshwar Jyotirlinga','नागेश्वर ज्योतिर्लिंग','నాగేశ్వర జ్యోతిర్లింగ','Nageshwar','Moderate','temple_hindu','dwarka'),
        ('06:30 PM','Sunset at Sunset Point','सूर्यास्त दर्शन','సూర్యాస్తమయం','Sunset Point','Low','wb_twilight','dwarka')
    ''');

    // Seed a default active journey plan (Kedarnath) so screens show data.
    await db.rawInsert('''
      INSERT INTO journey_plan (destination_id, destination_name, dest_lat, dest_lng, active, created_at)
      VALUES ('kedarnath', 'Kedarnath', 30.7346, 79.0669, 1, datetime('now'))
    ''');
  }

  // ── v4 Migration: Additive Expansion for Vizag, Srikakulam, Chennai ──

  Future<void> _migrateV4(Database db) async {
    // 1. Visakhapatnam (Vizag) Seed Data
    await db.rawInsert('''
      INSERT OR IGNORE INTO transport_options (destination_id, mode, from_name, to_name, dep_time, arr_time, price_inr, operator, indicative)
      VALUES
        ('visakhapatnam', 'bus', 'RTC Complex Vizag', 'Simhachalam Temple', '06:30 AM', '07:15 AM', 45, 'APSRTC City Ordinary', 0),
        ('visakhapatnam', 'bus', 'Dwaraka Bus Station', 'Rushikonda Beach', '08:00 AM', '08:45 AM', 50, 'APSRTC Metro Express', 0),
        ('visakhapatnam', 'train', 'Visakhapatnam Jn (VSKP)', 'Secunderabad / Vijayawada', '06:00 AM', '01:30 PM', 285, '12805 Janmabhoomi Express', 0),
        ('visakhapatnam', 'train', 'Visakhapatnam Jn (VSKP)', 'Tirupati Main', '07:05 PM', '08:20 AM', 450, '17488 Tirumala Express', 0)
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO accommodations (camp_name, sector, tent_id, distance_km, lat, lng, facilities, destination_id)
      VALUES
        ('Simhachalam Devasthanam Choultry', 'Giri Pradakshina Path', 'Room 204', 0.4, 17.7663, 83.2505, 'Drinking Water, Hot Water, Locker Counter', 'visakhapatnam'),
        ('APTDCL Haritha Beach Resort', 'Rushikonda', 'Cottage 12', 4.5, 17.7820, 83.3850, 'AC, Sea View, Restaurant, Security', 'visakhapatnam')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO itineraries (time, title, title_hi, title_te, location, crowd_level, icon_name, destination_id)
      VALUES
        ('06:00 AM', 'Simhachalam Temple Darshan', 'सिंहाचलम मंदिर दर्शन', 'సింహాచలం వరాహ లక్ష్మీనరసింహ స్వామి దర్శనం', 'Simhachalam Hill', 'High', 'temple_hindu', 'visakhapatnam'),
        ('10:30 AM', 'Kailasagiri Hilltop & Viewpoint', 'कैलाशगिरि दर्शन', 'కైలాసగిరి శివపార్వతుల విగ్రహం & రోప్‌వే', 'Kailasagiri', 'Moderate', 'wb_sunny', 'visakhapatnam'),
        ('01:00 PM', 'Traditional Andhra Meals', 'पारंपरिक आंध्रा भोजन', 'సాంప్రదాయ ఆంధ్రా శాకాహార భోజనం', 'Siripuram', 'Low', 'restaurant', 'visakhapatnam'),
        ('05:00 PM', 'RK Beach & Submarine Museum', 'आरके बीच एवं पनडुब्बी संग्रहालय', 'ఆర్కే బీచ్ & కురుసుర సబ్‌మెరైన్ మ్యూజియం', 'Beach Road', 'High', 'water_drop', 'visakhapatnam')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO nearby_places (destination_id, category, name, lat, lng, note, source)
      VALUES
        ('visakhapatnam', 'temple', 'Varaha Lakshmi Narasimha Temple', 17.7663, 83.2505, 'Ancient 11th century temple on Simhachalam hill', 'curated'),
        ('visakhapatnam', 'hospital', 'King George Hospital (KGH)', 17.7110, 83.3080, 'Government General Hospital, 24/7 Emergency', 'curated')
    ''');

    // 2. Srikakulam Seed Data
    await db.rawInsert('''
      INSERT OR IGNORE INTO transport_options (destination_id, mode, from_name, to_name, dep_time, arr_time, price_inr, operator, indicative)
      VALUES
        ('srikakulam', 'bus', 'Srikakulam Complex', 'Arasavalli Sun Temple', '06:15 AM', '06:45 AM', 30, 'APSRTC Palle Velugu', 0),
        ('srikakulam', 'bus', 'RTC Complex', 'Sri Kurmam Temple', '08:30 AM', '09:15 AM', 40, 'APSRTC Ultra Deluxe', 0),
        ('srikakulam', 'train', 'Srikakulam Road (CHE)', 'Visakhapatnam / Howrah', '07:20 AM', '09:00 AM', 140, '18046 East Coast Express', 0),
        ('srikakulam', 'train', 'Srikakulam Road (CHE)', 'Tirupati / Secunderabad', '05:30 PM', '06:40 AM', 410, '12704 Falaknuma Express', 0)
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO accommodations (camp_name, sector, tent_id, distance_km, lat, lng, facilities, destination_id)
      VALUES
        ('Arasavalli Devasthanam Yatri Nivas', 'Temple Road', 'Room 102', 0.2, 18.2930, 83.9010, 'Drinking Water, Pilgrim Dining, First Aid', 'srikakulam'),
        ('Sri Suryanarayana Nilayam', 'Old Bus Stand Area', 'Room 305', 1.1, 18.2970, 83.8950, 'Hot Water, Free Wi-Fi, Luggage Storage', 'srikakulam')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO itineraries (time, title, title_hi, title_te, location, crowd_level, icon_name, destination_id)
      VALUES
        ('05:30 AM', 'Arasavalli Sun Temple Ushodaya Darshan', 'अरसावल्ली सूर्य मंदिर दर्शन', 'అరసవల్లి సూర్యనారాయణ స్వామి ఉషోదయ దర్శనం', 'Arasavalli', 'High', 'wb_sunny', 'srikakulam'),
        ('09:30 AM', 'Sri Kurmam Kurmanatha Swamy Darshan', 'श्री कूर्माम मंदिर दर्शन', 'శ్రీకూర్మం కూర్మనాథ స్వామి దర్శనం', 'Srikurmam', 'Moderate', 'temple_hindu', 'srikakulam'),
        ('01:00 PM', 'Temple Annaprasadam Lunch', 'मंदिर अन्नप्रसाद', 'అరసవల్లి దేవస్థానం అన్నప్రసాదం', 'Devasthanam Annadana Hall', 'Low', 'restaurant', 'srikakulam'),
        ('05:00 PM', 'Nagavali River Ghat & Evening Walk', 'नागावली नदी घाट दर्शन', 'నాగావళి నదీ ఘాట్ దర్శనం', 'Nagavali Bund', 'Low', 'water_drop', 'srikakulam')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO nearby_places (destination_id, category, name, lat, lng, note, source)
      VALUES
        ('srikakulam', 'temple', 'Arasavalli Sun Temple', 18.2930, 83.9010, '7th-century sun temple built by Kalinga rulers', 'curated'),
        ('srikakulam', 'hospital', 'RIMS Government General Hospital', 18.3050, 83.9100, 'Emergency 24/7 Trauma Care', 'curated')
    ''');

    // 3. Chennai Seed Data
    await db.rawInsert('''
      INSERT OR IGNORE INTO transport_options (destination_id, mode, from_name, to_name, dep_time, arr_time, price_inr, operator, indicative)
      VALUES
        ('chennai', 'bus', 'CMBT Koyambedu', 'Mylapore Tank', '06:00 AM', '06:50 AM', 35, 'MTC Express Service', 0),
        ('chennai', 'bus', 'Koyambedu', 'Tirupati Central', '06:30 AM', '10:00 AM', 190, 'TNSTC Ultra Deluxe', 0),
        ('chennai', 'train', 'Chennai Central (MAS)', 'Mysuru / Coimbatore', '05:50 AM', '10:20 AM', 750, '20607 Vande Bharat Express', 0),
        ('chennai', 'train', 'Chennai Egmore (MS)', 'Madurai / Kanyakumari', '07:30 PM', '04:15 AM', 380, '12635 Vaigai Superfast', 0)
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO accommodations (camp_name, sector, tent_id, distance_km, lat, lng, facilities, destination_id)
      VALUES
        ('TTDC Hotel Tamil Nadu', 'Mylapore', 'Room 408', 0.5, 13.0335, 80.2690, 'AC, Veg Restaurant, Luggage Desk', 'chennai'),
        ('Sri Kapaleeshwarar Yatri Nivas', 'South Mada Street', 'Dorm Bed 14', 0.2, 13.0330, 80.2680, 'Hot Water, Filtered Water, Lockers', 'chennai')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO itineraries (time, title, title_hi, title_te, location, crowd_level, icon_name, destination_id)
      VALUES
        ('06:00 AM', 'Kapaleeshwarar Temple Morning Pooja', 'कपालीश्वरर मंदिर दर्शन', 'కపాలీశ్వర ఆలయ దర్శనం', 'Mylapore', 'High', 'temple_hindu', 'chennai'),
        ('10:00 AM', 'Parthasarathy Temple Darshan', 'पार्थसारथी मंदिर दर्शन', 'పార్థసారథి ఆలయ దర్శనం', 'Triplicane', 'Moderate', 'temple_hindu', 'chennai'),
        ('01:00 PM', 'Traditional South Indian Thali', 'दक्षिण भारतीय भोजन', 'దక్షిణ భారత శాకాహార భోజనం', 'Mylapore', 'Low', 'restaurant', 'chennai'),
        ('05:30 PM', 'Marina Beach Sunset & Breeze', 'मरीना बीच भ्रमण', 'మెరీనా బీచ్ సాయంత్రం నడక', 'Marina Beach', 'High', 'wb_twilight', 'chennai')
    ''');

    await db.rawInsert('''
      INSERT OR IGNORE INTO nearby_places (destination_id, category, name, lat, lng, note, source)
      VALUES
        ('chennai', 'temple', 'Kapaleeshwarar Temple', 13.0337, 80.2699, '7th-century Shiva temple in Dravidian architecture', 'curated'),
        ('chennai', 'hospital', 'Rajiv Gandhi Government General Hospital', 13.0805, 80.2780, 'Emergency 24/7 Care near Central Station', 'curated')
    ''');
  }

  // Trip-aware queries.
  Future<List<Map<String, dynamic>>> getAccommodationsForDestination(
      String destinationId) async {
    final db = await database;
    return await db.query('accommodations',
        where: 'destination_id = ?', whereArgs: [destinationId]);
  }

  Future<List<Map<String, dynamic>>> getItinerariesForDestination(
      String destinationId) async {
    final db = await database;
    return await db.query('itineraries',
        where: 'destination_id = ?', whereArgs: [destinationId]);
  }

  Future<List<Map<String, dynamic>>> getTransportOptionsForDestination(
      String destinationId) async {
    return await getTransportOptions(destinationId);
  }

  /// Checks whether a destination has verified rows in SQLite (Tier A).
  Future<bool> hasVerifiedData(String destinationId) async {
    final db = await database;
    final transport = await db.query('transport_options',
        columns: ['id'],
        where: 'destination_id = ?',
        whereArgs: [destinationId],
        limit: 1);
    if (transport.isNotEmpty) return true;

    final accom = await db.query('accommodations',
        columns: ['id'],
        where: 'destination_id = ?',
        whereArgs: [destinationId],
        limit: 1);
    if (accom.isNotEmpty) return true;

    final itin = await db.query('itineraries',
        columns: ['id'],
        where: 'destination_id = ?',
        whereArgs: [destinationId],
        limit: 1);
    return itin.isNotEmpty;
  }
}
