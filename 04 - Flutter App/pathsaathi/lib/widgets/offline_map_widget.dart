import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' hide Path;

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// 100% Offline GIS Map for PathSaathi
/// Zero Internet / Zero Network Tile Dependency when offline.
/// Renders full Geographic Subcontinent Terrain, Indian Sacred Rivers,
/// National Pilgrimage Corridors, Prayagraj Kumbh Confluence, and
/// live OpenStreetMap overlay when connected online.
class OfflineMapWidget extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final LatLng? sourceMarker;
  final LatLng? destination;
  final String? destinationName;
  final String? destinationId;
  final List<LatLng>? routePoints;
  final List<MapMarker>? markers;
  final bool showControls;
  final bool compact;

  const OfflineMapWidget({
    super.key,
    this.initialCenter =
        const LatLng(25.4385, 81.8750), // Prayagraj Kumbh Ground
    this.initialZoom = 15.0,
    this.sourceMarker,
    this.destination,
    this.destinationName,
    this.destinationId,
    this.routePoints,
    this.markers,
    this.showControls = true,
    this.compact = false,
  });

  @override
  State<OfflineMapWidget> createState() => _OfflineMapWidgetState();
}

class MapMarker {
  final LatLng point;
  final String label;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const MapMarker({
    required this.point,
    required this.label,
    this.icon = Icons.location_on,
    this.color = _saffron,
    this.subtitle,
  });
}

class _OfflineMapWidgetState extends State<OfflineMapWidget> {
  late final MapController _mapController;
  late double _currentZoom;
  late LatLng _currentCenter;

  // Key GIS coordinates for Prayagraj Kumbh Mela
  static const _sangam = LatLng(25.4358, 81.8814);
  static const _userLoc = LatLng(25.4412, 81.8745);
  static const _shaktiCamp = LatLng(25.4460, 81.8680); // Sector 7
  static const _gate3Bus = LatLng(25.4485, 81.8610); // Gate 3
  static const _medicalPost = LatLng(25.4420, 81.8750); // Medical 2
  static const _hanumanTemple = LatLng(25.4380, 81.8790); // Bade Hanuman Mandir
  static const _langar = LatLng(25.4440, 81.8710); // Annakshetra
  static const _waterPoint = LatLng(25.4395, 81.8765); // Jal Sewa

  // Key Pilgrimage Cities across India
  static const _varanasi = LatLng(25.3109, 83.0107);
  static const _ayodhya = LatLng(26.7922, 82.1998);
  static const _haridwar = LatLng(29.9457, 78.1642);
  static const _ujjain = LatLng(23.1765, 75.7885);
  static const _puri = LatLng(19.8135, 85.8312);
  static const _tirupati = LatLng(13.6288, 79.4192);
  static const _rameswaram = LatLng(9.2876, 79.3129);
  static const _dwarka = LatLng(22.2442, 68.9685);
  static const _delhi = LatLng(28.6139, 77.2090);
  static const _mumbai = LatLng(19.0760, 72.8777);
  static const _hyderabad = LatLng(17.3850, 78.4867);
  static const _bengaluru = LatLng(12.9716, 77.5946);
  static const _kolkata = LatLng(22.5726, 88.3639);

  // ── Indian Subcontinent GIS Boundary Polygons ───────────────────────
  static const List<LatLng> _subcontinentOutline = [
    LatLng(35.5, 74.5), LatLng(35.8, 76.8), LatLng(34.8, 78.5),
    LatLng(33.0, 79.2),
    LatLng(31.5, 79.2), LatLng(30.2, 80.5), LatLng(28.8, 80.2),
    LatLng(27.5, 81.8),
    LatLng(26.8, 85.0), LatLng(26.6, 88.0), LatLng(27.8, 88.5),
    LatLng(27.8, 89.0),
    LatLng(27.0, 92.0), LatLng(28.0, 94.0), LatLng(28.5, 96.5),
    LatLng(27.5, 97.0),
    LatLng(26.0, 95.5), LatLng(24.5, 94.2), LatLng(22.2, 93.0),
    LatLng(23.5, 91.5),
    LatLng(22.0, 89.5), LatLng(21.7, 88.2), LatLng(20.5, 86.8),
    LatLng(19.8, 85.8),
    LatLng(18.5, 84.5), LatLng(17.7, 83.3), LatLng(16.0, 80.8),
    LatLng(14.0, 80.1),
    LatLng(13.1, 80.3), LatLng(10.8, 79.8), LatLng(9.3, 79.3),
    LatLng(8.5, 78.1),
    LatLng(8.08, 77.55), // Kanyakumari
    LatLng(8.5, 76.9), LatLng(9.9, 76.2), LatLng(11.2, 75.8),
    LatLng(12.0, 75.2),
    LatLng(13.0, 74.8), LatLng(14.8, 74.1), LatLng(15.5, 73.8),
    LatLng(17.0, 73.3),
    LatLng(19.0, 72.8), LatLng(21.0, 72.8), LatLng(20.7, 71.0),
    LatLng(21.5, 69.5),
    LatLng(22.3, 69.0), LatLng(23.0, 68.6), LatLng(23.8, 68.3),
    LatLng(24.5, 70.5),
    LatLng(25.5, 70.2), LatLng(27.0, 70.5), LatLng(28.5, 71.8),
    LatLng(30.5, 73.8),
    LatLng(32.0, 74.8), LatLng(33.5, 74.0),
  ];

  static const List<LatLng> _sriLankaOutline = [
    LatLng(9.8, 80.2),
    LatLng(8.6, 81.2),
    LatLng(6.9, 81.8),
    LatLng(5.9, 80.5),
    LatLng(7.0, 79.8),
    LatLng(8.8, 79.8),
  ];

  // Coarse bundled world landmasses for offline orientation. This is not
  // street data; detailed streets are rendered only from local map tiles.
  static const List<List<LatLng>> _worldLandmasses = [
    [
      LatLng(72, -168),
      LatLng(72, -125),
      LatLng(65, -105),
      LatLng(55, -80),
      LatLng(45, -70),
      LatLng(25, -80),
      LatLng(8, -82),
      LatLng(10, -60),
      LatLng(25, -55),
      LatLng(45, -60),
      LatLng(60, -95),
      LatLng(72, -168),
    ],
    [
      LatLng(83, -70),
      LatLng(70, -20),
      LatLng(45, -10),
      LatLng(35, 10),
      LatLng(20, 35),
      LatLng(5, 50),
      LatLng(-35, 25),
      LatLng(-35, 15),
      LatLng(-5, -15),
      LatLng(10, -20),
      LatLng(30, -10),
      LatLng(45, -35),
      LatLng(60, -55),
      LatLng(83, -70),
    ],
    [
      LatLng(75, 30),
      LatLng(60, 60),
      LatLng(55, 95),
      LatLng(70, 140),
      LatLng(55, 165),
      LatLng(35, 145),
      LatLng(20, 120),
      LatLng(5, 105),
      LatLng(10, 75),
      LatLng(25, 55),
      LatLng(40, 35),
      LatLng(75, 30),
    ],
    [
      LatLng(-10, 110),
      LatLng(-25, 115),
      LatLng(-40, 140),
      LatLng(-35, 155),
      LatLng(-15, 150),
      LatLng(0, 135),
      LatLng(-10, 110),
    ],
    [
      LatLng(-60, -180),
      LatLng(-60, 180),
      LatLng(-75, 100),
      LatLng(-75, -60),
      LatLng(-60, -180),
    ],
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentZoom = widget.initialZoom;
    _currentCenter = widget.initialCenter;
  }

  void _recenter() {
    _mapController.move(widget.initialCenter, widget.initialZoom);
    setState(() {
      _currentZoom = widget.initialZoom;
      _currentCenter = widget.initialCenter;
    });
  }

  void _zoomIn() {
    final newZoom = (_currentZoom + 0.8).clamp(1.0, 19.0);
    _mapController.move(_currentCenter, newZoom);
    setState(() => _currentZoom = newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - 0.8).clamp(1.0, 19.0);
    _mapController.move(_currentCenter, newZoom);
    setState(() => _currentZoom = newZoom);
  }

  bool get _isNearPrayagraj {
    final destId = widget.destinationId?.toLowerCase() ?? '';
    final destName = widget.destinationName?.toLowerCase() ?? '';
    final isPrayagrajName = destId == 'prayagraj' ||
        destName.contains('prayagraj') ||
        destName.contains('kumbh');
    const dist = Distance();
    final d = dist.as(LengthUnit.Meter, widget.initialCenter, _sangam);
    return isPrayagrajName && d < 20000;
  }

  void _toggleOverview() {
    if (_currentZoom >= 9.0) {
      // Switch to Pan-India Overview
      _mapController.move(const LatLng(22.8, 80.0), 4.8);
      setState(() {
        _currentCenter = const LatLng(22.8, 80.0);
        _currentZoom = 4.8;
      });
    } else {
      // Switch back to initial center
      _mapController.move(widget.initialCenter, widget.initialZoom);
      setState(() {
        _currentCenter = widget.initialCenter;
        _currentZoom = widget.initialZoom;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetDest = widget.destination ?? widget.initialCenter;
    final sourcePoint = widget.sourceMarker ?? widget.initialCenter;
    final isLocalZoom = _currentZoom >= 10.5;
    final isWorldOverview = _currentZoom < 7.0;
    final isNearPrayagraj = _isNearPrayagraj;

    // Dynamic walking route polyline (between user and target)
    final defaultRoute = widget.routePoints ??
        [
          _userLoc,
          LatLng((_userLoc.latitude + targetDest.latitude) / 2 + 0.0008,
              (_userLoc.longitude + targetDest.longitude) / 2 - 0.0005),
          targetDest,
        ];

    // ── 1. Full Geographic GIS Polygons (Landmass & Local Rivers) ─────
    final polygons = <Polygon>[
      if (isWorldOverview)
        ..._worldLandmasses.map(
          (points) => Polygon(
            points: points,
            color: const Color(0xFFF7F5EE),
            borderColor: const Color(0xFF94A3B8),
            borderStrokeWidth: 1.2,
          ),
        ),
      // A. National Landmass (India Mainland)
      if (!isWorldOverview)
        Polygon(
          points: _subcontinentOutline,
          color: const Color(0xFFF7F5EE), // Warm Cartographic Terrain
          borderColor: const Color(0xFF94A3B8),
          borderStrokeWidth: 1.8,
        ),

      // B. Sri Lanka Island
      if (!isWorldOverview)
        Polygon(
          points: _sriLankaOutline,
          color: const Color(0xFFF7F5EE),
          borderColor: const Color(0xFF94A3B8),
          borderStrokeWidth: 1.2,
        ),

      // C. Local Prayagraj Kumbh Confluence (Rendered at local zoom ONLY when near Prayagraj)
      if (isLocalZoom && isNearPrayagraj) ...[
        // Ganga River (North-West to South-East)
        Polygon(
          points: const [
            LatLng(25.4900, 81.8300),
            LatLng(25.4700, 81.8550),
            LatLng(25.4520, 81.8700),
            LatLng(25.4410, 81.8790),
            LatLng(25.4358, 81.8814),
            LatLng(25.4150, 81.9050),
            LatLng(25.3900, 81.9400),
            LatLng(25.3900, 81.9600),
            LatLng(25.4250, 81.9200),
            LatLng(25.4480, 81.8900),
            LatLng(25.4650, 81.8750),
            LatLng(25.4850, 81.8500),
            LatLng(25.5000, 81.8350),
          ],
          color: const Color(0xFF93C5FD).withValues(alpha: 0.60),
          borderColor: const Color(0xFF3B82F6).withValues(alpha: 0.8),
          borderStrokeWidth: 2.0,
        ),

        // Yamuna River (South-West to Sangam Confluence)
        Polygon(
          points: const [
            LatLng(25.4050, 81.8200),
            LatLng(25.4180, 81.8480),
            LatLng(25.4280, 81.8650),
            LatLng(25.4358, 81.8814),
            LatLng(25.4310, 81.8840),
            LatLng(25.4220, 81.8680),
            LatLng(25.4120, 81.8500),
            LatLng(25.3980, 81.8250),
          ],
          color: const Color(0xFF60A5FA).withValues(alpha: 0.60),
          borderColor: const Color(0xFF2563EB).withValues(alpha: 0.8),
          borderStrokeWidth: 2.0,
        ),

        // Sangam Sandy Ghat Bank
        Polygon(
          points: const [
            LatLng(25.4400, 81.8750),
            LatLng(25.4380, 81.8850),
            LatLng(25.4320, 81.8850),
            LatLng(25.4330, 81.8760),
          ],
          color: const Color(0xFFFEF3C7).withValues(alpha: 0.90),
          borderColor: const Color(0xFFFDE68A),
          borderStrokeWidth: 1.5,
        ),

        // Sector 7 Pilgrim Camp Zone (Green Tint)
        Polygon(
          points: const [
            LatLng(25.4510, 81.8610),
            LatLng(25.4510, 81.8720),
            LatLng(25.4420, 81.8720),
            LatLng(25.4420, 81.8610),
          ],
          color: const Color(0xFFDCFCE7).withValues(alpha: 0.75),
          borderColor: _green.withValues(alpha: 0.55),
          borderStrokeWidth: 1.5,
        ),

        // Sector 4 Ghat Zone
        Polygon(
          points: const [
            LatLng(25.4420, 81.8610),
            LatLng(25.4420, 81.8720),
            LatLng(25.4350, 81.8720),
            LatLng(25.4350, 81.8610),
          ],
          color: const Color(0xFFDCFCE7).withValues(alpha: 0.55),
          borderColor: _green.withValues(alpha: 0.45),
          borderStrokeWidth: 1.2,
        ),
      ],
    ];

    // ── 2. GIS Road, River & Corridor Polylines ───────────────────────
    final polylines = <Polyline>[
      // A. National Sacred Rivers of India (Shown at National/Regional Zoom)
      if (!isLocalZoom) ...[
        // Ganga River
        Polyline(
          points: const [
            LatLng(30.98, 78.93),
            LatLng(29.94, 78.16),
            LatLng(28.40, 78.50),
            LatLng(26.46, 80.35),
            LatLng(25.4358, 81.8814),
            LatLng(25.31, 83.01),
            LatLng(25.61, 85.14),
            LatLng(25.25, 87.00),
            LatLng(23.50, 88.20),
            LatLng(22.20, 88.00),
          ],
          strokeWidth: 3.5,
          color: const Color(0xFF2563EB),
        ),
        // Yamuna River
        Polyline(
          points: const [
            LatLng(31.01, 78.46),
            LatLng(30.20, 77.50),
            LatLng(28.61, 77.23),
            LatLng(27.49, 77.67),
            LatLng(27.18, 78.01),
            LatLng(25.80, 80.00),
            LatLng(25.4358, 81.8814),
          ],
          strokeWidth: 2.8,
          color: const Color(0xFF3B82F6),
        ),
        // Narmada River
        Polyline(
          points: const [
            LatLng(22.67, 81.75),
            LatLng(23.18, 79.98),
            LatLng(22.20, 77.00),
            LatLng(21.70, 73.00),
            LatLng(21.60, 72.60),
          ],
          strokeWidth: 2.2,
          color: const Color(0xFF0284C7),
        ),
        // Godavari River
        Polyline(
          points: const [
            LatLng(19.93, 73.53),
            LatLng(19.88, 75.34),
            LatLng(19.00, 78.00),
            LatLng(18.50, 80.00),
            LatLng(17.00, 81.78),
            LatLng(16.50, 82.20),
          ],
          strokeWidth: 2.2,
          color: const Color(0xFF0284C7),
        ),
        // Krishna River
        Polyline(
          points: const [
            LatLng(17.92, 73.66),
            LatLng(16.50, 76.50),
            LatLng(16.20, 78.50),
            LatLng(16.50, 80.64),
            LatLng(15.80, 80.90),
          ],
          strokeWidth: 2.0,
          color: const Color(0xFF0284C7),
        ),
        // Kaveri River
        Polyline(
          points: const [
            LatLng(12.38, 75.49),
            LatLng(12.42, 76.71),
            LatLng(11.50, 78.00),
            LatLng(10.78, 79.13),
            LatLng(11.14, 79.85),
          ],
          strokeWidth: 2.0,
          color: const Color(0xFF0284C7),
        ),
        // Brahmaputra River
        Polyline(
          points: const [
            LatLng(27.90, 95.50),
            LatLng(27.00, 93.50),
            LatLng(26.18, 91.75),
            LatLng(25.50, 89.80),
          ],
          strokeWidth: 2.8,
          color: const Color(0xFF0284C7),
        ),
        // Indus / Sindhu River
        Polyline(
          points: const [
            LatLng(34.50, 78.00),
            LatLng(34.20, 77.00),
            LatLng(35.00, 75.00),
            LatLng(33.00, 72.00),
          ],
          strokeWidth: 2.2,
          color: const Color(0xFF0284C7),
        ),

        // B. National Golden Quadrilateral & Pilgrimage Arteries
        // Delhi - Prayagraj - Varanasi - Kolkata (NH 19)
        Polyline(
          points: const [
            _delhi,
            LatLng(27.18, 78.01),
            LatLng(26.46, 80.35),
            LatLng(25.4385, 81.8750),
            _varanasi,
            _kolkata
          ],
          strokeWidth: 3.5,
          color: Colors.white,
          borderStrokeWidth: 1.2,
          borderColor: const Color(0xFF94A3B8),
        ),
        // Prayagraj - Ayodhya
        Polyline(
          points: const [
            LatLng(25.4385, 81.8750),
            LatLng(25.92, 81.99),
            _ayodhya
          ],
          strokeWidth: 3.0,
          color: Colors.white,
          borderStrokeWidth: 1.0,
          borderColor: const Color(0xFF94A3B8),
        ),
        // Delhi - Haridwar
        Polyline(
          points: const [_delhi, LatLng(29.0, 77.7), _haridwar],
          strokeWidth: 3.0,
          color: Colors.white,
          borderStrokeWidth: 1.0,
          borderColor: const Color(0xFF94A3B8),
        ),
        // Delhi - Jaipur - Mumbai
        Polyline(
          points: const [
            _delhi,
            LatLng(26.9, 75.8),
            LatLng(23.0, 72.5),
            _mumbai
          ],
          strokeWidth: 3.0,
          color: Colors.white,
          borderStrokeWidth: 1.0,
          borderColor: const Color(0xFF94A3B8),
        ),
        // Mumbai - Bangalore - Chennai
        Polyline(
          points: const [
            _mumbai,
            LatLng(18.5, 73.8),
            _bengaluru,
            LatLng(13.08, 80.27)
          ],
          strokeWidth: 3.0,
          color: Colors.white,
          borderStrokeWidth: 1.0,
          borderColor: const Color(0xFF94A3B8),
        ),
        // Hyderabad - Nagpur - Prayagraj
        Polyline(
          points: const [
            _hyderabad,
            LatLng(21.14, 79.08),
            LatLng(24.58, 80.83),
            LatLng(25.4385, 81.8750)
          ],
          strokeWidth: 3.0,
          color: Colors.white,
          borderStrokeWidth: 1.0,
          borderColor: const Color(0xFF94A3B8),
        ),
      ],

      // C. Local Prayagraj Roads & Active Walking Route
      if (isLocalZoom && isNearPrayagraj) ...[
        // Triveni Marg
        Polyline(
          points: const [
            LatLng(25.4580, 81.8520),
            LatLng(25.4485, 81.8610),
            LatLng(25.4412, 81.8745),
            LatLng(25.4370, 81.8795),
            LatLng(25.4358, 81.8814),
          ],
          strokeWidth: 7.0,
          color: Colors.white,
          borderStrokeWidth: 2.0,
          borderColor: const Color(0xFFCBD5E1),
        ),

        // Bandha Marg
        Polyline(
          points: const [
            LatLng(25.4600, 81.8680),
            LatLng(25.4460, 81.8680),
            LatLng(25.4360, 81.8680),
          ],
          strokeWidth: 5.0,
          color: Colors.white,
          borderStrokeWidth: 1.5,
          borderColor: const Color(0xFFCBD5E1),
        ),

        // Naini Bridge Road
        Polyline(
          points: const [
            LatLng(25.4100, 81.8500),
            LatLng(25.4240, 81.8650),
            LatLng(25.4340, 81.8750),
            LatLng(25.4400, 81.8780),
          ],
          strokeWidth: 5.0,
          color: const Color(0xFFF1F5F9),
          borderStrokeWidth: 1.5,
          borderColor: const Color(0xFF94A3B8),
        ),
      ],

      // Active Walking Route
      if (widget.routePoints != null)
        Polyline(
          points: widget.routePoints!,
          strokeWidth: 6.0,
          color: _saffron,
          borderStrokeWidth: 2.5,
          borderColor: Colors.white,
        )
      else if (isLocalZoom && isNearPrayagraj)
        Polyline(
          points: defaultRoute,
          strokeWidth: 6.0,
          color: _saffron,
          borderStrokeWidth: 2.5,
          borderColor: Colors.white,
        ),
    ];

    // ── 3. Markers: Filtered Intelligently by Zoom Level ──────────────
    final allMarkers = <Marker>[];

    if (!isLocalZoom) {
      if (sourcePoint != targetDest) {
        allMarkers.add(_nationalBadge(sourcePoint, 'You 📍', const Color(0xFF2563EB),
            isPrimary: true));
      }
      allMarkers.add(_nationalBadge(targetDest, widget.destinationName ?? 'Destination 🚩',
          _saffron, isPrimary: true));
      // ── Pan-India Sacred Pilgrimage Hubs (Shown when zoomed out) ────
      allMarkers.addAll([
        _nationalBadge(_sangam, 'Prayagraj (Sangam) 🚩', _saffron,
            isPrimary: true),
        _nationalBadge(_varanasi, 'Varanasi 🛕', const Color(0xFFD97706)),
        _nationalBadge(_ayodhya, 'Ayodhya 🏹', const Color(0xFFD97706)),
        _nationalBadge(_haridwar, 'Haridwar 🌊', const Color(0xFF0284C7)),
        _nationalBadge(_ujjain, 'Ujjain 🕉️', const Color(0xFFD97706)),
        _nationalBadge(_puri, 'Puri 🚩', const Color(0xFFD97706)),
        _nationalBadge(_tirupati, 'Tirupati 🛕', const Color(0xFFD97706)),
        _nationalBadge(_rameswaram, 'Rameswaram 🌊', const Color(0xFF0284C7)),
        _nationalBadge(_dwarka, 'Dwarka 🚩', const Color(0xFFD97706)),
        _nationalBadge(_delhi, 'New Delhi 🏛️', const Color(0xFF475569)),
        _nationalBadge(_mumbai, 'Mumbai 🏙️', const Color(0xFF475569)),
        _nationalBadge(_hyderabad, 'Hyderabad 🏙️', const Color(0xFF475569)),
        _nationalBadge(_bengaluru, 'Bengaluru 🏙️', const Color(0xFF475569)),
        _nationalBadge(_kolkata, 'Kolkata 🏙️', const Color(0xFF475569)),
      ]);
    } else {
      if (isNearPrayagraj) {
        // User Location
        allMarkers.add(
          Marker(
            point: _userLoc,
            width: 60,
            height: 52,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    'YOU 📍',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.my_location, color: _green, size: 24),
              ],
            ),
          ),
        );

        // Target Destination Marker
        allMarkers.add(
          Marker(
            point: targetDest,
            width: 95,
            height: 58,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _saffron,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    widget.destinationName ?? 'Sangam Ghat 🚩',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.location_on, color: _saffron, size: 28),
              ],
            ),
          ),
        );

        // Compact dots for local amenities
        if (targetDest != _shaktiCamp) {
          _compactDot(_shaktiCamp, 'Shakti Camp', Icons.holiday_village,
              const Color(0xFF16A34A));
        }
        if (targetDest != _gate3Bus) {
          _compactDot(_gate3Bus, 'Gate 3', Icons.directions_bus,
              const Color(0xFF2563EB));
        }
        if (targetDest != _medicalPost) {
          _compactDot(_medicalPost, 'Medical 2', Icons.local_hospital,
              const Color(0xFFDC2626));
        }
        if (targetDest != _hanumanTemple) {
          _compactDot(_hanumanTemple, 'Mandir', Icons.temple_hindu,
              const Color(0xFFD97706));
        }
        _compactDot(_langar, 'Food', Icons.restaurant, const Color(0xFF059669));
        _compactDot(
            _waterPoint, 'Water', Icons.water_drop, const Color(0xFF0284C7));
      } else {
        // Non-Prayagraj target destination marker
        allMarkers.add(
          Marker(
            point: targetDest,
            width: 105,
            height: 58,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _saffron,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Text(
                    widget.destinationName?.isNotEmpty == true
                        ? widget.destinationName!
                        : 'Destination 🚩',
                    style: GoogleFonts.outfit(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.location_on, color: _saffron, size: 28),
              ],
            ),
          ),
        );
      }

      // Add any explicit external markers
      if (widget.markers != null) {
        for (final m in widget.markers!) {
          allMarkers.add(
            Marker(
              point: m.point,
              width: 80,
              height: 48,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: m.color, width: 1.0),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 3)
                      ],
                    ),
                    child: Text(
                      m.label,
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(m.icon, color: m.color, size: 18),
                ],
              ),
            ),
          );
        }
      }
    }

    return Container(
      // Oceanic Marine Blue background for realistic water/coastal geography
      color: const Color(0xFFB4D8EE),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 14 : 20),
        child: Stack(
          children: [
            // ── FlutterMap with Lock on Rotation ─────────────────────────
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.initialCenter,
                initialZoom: widget.initialZoom,
                minZoom: 1.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onPositionChanged: (pos, hasGesture) {
                  _currentCenter = pos.center;
                  setState(() => _currentZoom = pos.zoom);
                },
              ),
              children: [
                // NOTE: No OpenStreetMap TileLayer here. OSM's public tile
                // servers block bulk/app use (403 "Access blocked"), so this
                // widget renders a self-contained offline vector base instead —
                // terrain, rivers, roads and markers — with zero network tiles.

                // GIS Landmass & Rivers
                PolygonLayer(polygons: polygons),

                // GIS Roads, Marg, Arteries & Navigation Route
                PolylineLayer(polylines: polylines),

                // GIS Markers
                MarkerLayer(markers: allMarkers),
              ],
            ),

            if (widget.routePoints == null)
              Positioned(
                top: 82,
                left: 24,
                right: 24,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 8),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.map_outlined, color: _green, size: 28),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Offline street map is not downloaded for this destination. '
                            'Connect once and tap “Download offline map”.',
                            style: TextStyle(
                              color: Color(0xFF374151),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Offline / Real-World Status Pill ─────────────────────────
            Positioned(
              top: 12,
              left: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 6)
                  ],
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isLocalZoom ? _saffron : _green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLocalZoom
                          ? (isNearPrayagraj
                              ? 'Prayagraj Kumbh Ground'
                              : (widget.destinationName?.isNotEmpty == true
                                  ? widget.destinationName!
                                  : 'Destination Area'))
                          : 'Subcontinent / India Map',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Map Controls (Overview Toggle, Recenter, Zoom +, Zoom -) ──
            if (widget.showControls)
              Positioned(
                bottom: 14,
                right: 12,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _mapCtrlBtn(
                      isLocalZoom ? Icons.public : Icons.temple_hindu,
                      _toggleOverview,
                      tooltip: isLocalZoom
                          ? 'View Country Map'
                          : (isNearPrayagraj
                              ? 'View Kumbh Mela'
                              : 'View Destination'),
                    ),
                    const SizedBox(height: 6),
                    _mapCtrlBtn(Icons.my_location, _recenter,
                        tooltip: 'Re-center'),
                    const SizedBox(height: 6),
                    _mapCtrlBtn(Icons.add, _zoomIn, tooltip: 'Zoom In'),
                    const SizedBox(height: 6),
                    _mapCtrlBtn(Icons.remove, _zoomOut, tooltip: 'Zoom Out'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Marker _nationalBadge(LatLng pt, String label, Color color,
      {bool isPrimary = false}) {
    return Marker(
      point: pt,
      width: isPrimary ? 130 : 100,
      height: 48,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: isPrimary ? 7 : 5, vertical: 2),
            decoration: BoxDecoration(
              color:
                  isPrimary ? _saffron : Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color, width: isPrimary ? 1.5 : 1.0),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4)
              ],
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: isPrimary ? 9 : 8,
                color: isPrimary ? Colors.white : const Color(0xFF111827),
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(Icons.location_on, color: color, size: isPrimary ? 22 : 18),
        ],
      ),
    );
  }

  Marker _compactDot(LatLng pt, String label, IconData icon, Color color) {
    return Marker(
      point: pt,
      width: 46,
      height: 40,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Text(
              label,
              style: GoogleFonts.outfit(
                  fontSize: 7,
                  color: const Color(0xFF111827),
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(icon, color: color, size: 16),
        ],
      ),
    );
  }

  Widget _mapCtrlBtn(IconData icon, VoidCallback onTap,
      {required String tooltip}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: const Color(0xFF111827)),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        tooltip: tooltip,
      ),
    );
  }
}
