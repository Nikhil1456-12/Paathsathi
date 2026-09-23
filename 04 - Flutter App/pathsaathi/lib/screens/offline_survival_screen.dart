// lib/screens/offline_survival_screen.dart
//
// Offline Survival Mode — everything a stranded, offline user needs, served
// entirely from on-device cache/GPS (ZERO network calls):
//   • Navigate to the booked stay (Level A spoken guidance) if reserved.
//   • Nearby help (hospital / food / water / hotel) from the cached dataset,
//     sorted by real distance from the user's GPS position.
//   • Open securely-stored identity documents (local encrypted vault).
//   • One-tap emergency dial (100 / 108 / 112) via the platform dialler.
//
// Honest: distances need a GPS fix (shown when available); if a category has no
// cached places, it says so rather than inventing any.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/journey_models.dart';
import '../services/journey_plan_service.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';
import '../providers/travel_context.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _red = Color(0xFFDC2626);

class OfflineSurvivalScreen extends ConsumerStatefulWidget {
  const OfflineSurvivalScreen({super.key});

  @override
  ConsumerState<OfflineSurvivalScreen> createState() => _OfflineSurvivalScreenState();
}

class _OfflineSurvivalScreenState extends ConsumerState<OfflineSurvivalScreen> {
  JourneyPlan? _plan;
  LatLng? _here;
  final Map<String, List<NearbyPlace>> _byCategory = {};
  bool _loading = true;

  static const _categories = ['hotel', 'hospital', 'food', 'water', 'help'];
  static const _catLabel = {
    'hotel': 'Stays / Hotels',
    'hospital': 'Hospitals',
    'food': 'Food',
    'water': 'Drinking water',
    'help': 'Help centres',
  };
  static const _catIcon = {
    'hotel': Icons.hotel_rounded,
    'hospital': Icons.local_hospital_rounded,
    'food': Icons.restaurant_rounded,
    'water': Icons.water_drop_rounded,
    'help': Icons.info_rounded,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _plan = await JourneyPlanService.instance.active();
    _here = await LocationService.instance.currentOnce();
    final key = _plan?.destinationId ?? '';
    if (key.isNotEmpty) {
      for (final cat in _categories) {
        final list = _here != null
            ? await NearbyPlacesRepository.instance.nearestTo(key, _here!, category: cat)
            : await NearbyPlacesRepository.instance.forDestination(key, category: cat);
        if (list.isNotEmpty) _byCategory[cat] = list;
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _navigateTo(NearbyPlace p) {
    // Set as the confirmed destination so the existing offline NavigationScreen
    // (Level A spoken guidance on the cached map) guides the user there.
    final place = Place(
      id: 'nearby_${p.id}',
      name: p.name,
      category: p.category,
      coords: p.coords,
      note: p.note,
    );
    ref.read(travelContextProvider.notifier).setConfirmed(place);
    context.go('/nav');
  }

  @override
  Widget build(BuildContext context) {
    final hasStay = _plan?.stayReservationId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('Offline help', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _offlineBanner(),
                const SizedBox(height: 12),

                // Emergency — always first, always available.
                _emergencyCard(),
                const SizedBox(height: 12),

                // My documents — offline vault.
                _actionTile(Icons.badge_outlined, 'My documents',
                    'Show your ID (works offline, encrypted)', () => context.go('/documents')),

                if (hasStay) ...[
                  const SizedBox(height: 12),
                  _actionTile(Icons.hotel_rounded, 'Navigate to your stay',
                      'Spoken direction + distance (offline)', () => context.go('/nav')),
                ],

                const SizedBox(height: 16),
                Text('Nearby help',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                if (_here == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Enable GPS to see distances. Places are still listed below.',
                        style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280))),
                  ),
                const SizedBox(height: 8),

                if (_byCategory.isEmpty)
                  _noData()
                else
                  ..._categories
                      .where((c) => _byCategory.containsKey(c))
                      .map((c) => _categorySection(c, _byCategory[c]!)),
              ],
            ),
    );
  }

  Widget _categorySection(String cat, List<NearbyPlace> places) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(children: [
            Icon(_catIcon[cat], size: 16, color: _green),
            const SizedBox(width: 6),
            Text(_catLabel[cat] ?? cat,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          ...places.take(3).map(_placeCard),
        ],
      );

  Widget _placeCard(NearbyPlace p) {
    String? distLabel;
    if (_here != null) {
      final m = const Distance().as(LengthUnit.Meter, _here!, p.coords);
      distLabel = m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        title: Text(p.name, style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
          distLabel != null ? '$distLabel away • ${p.note}' : p.note,
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280)),
        ),
        trailing: TextButton.icon(
          onPressed: () => _navigateTo(p),
          icon: const Icon(Icons.navigation_rounded, size: 16, color: _green),
          label: Text('Go', style: GoogleFonts.outfit(color: _green, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _emergencyCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _red),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.emergency_rounded, color: _red, size: 20),
            const SizedBox(width: 8),
            Text('Emergency', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _red)),
          ]),
          const SizedBox(height: 4),
          Text('One-tap dial — works with no internet.',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF991B1B))),
          const SizedBox(height: 10),
          Row(children: [
            _dialChip('Police', '100'),
            const SizedBox(width: 8),
            _dialChip('Ambulance', '108'),
            const SizedBox(width: 8),
            _dialChip('SOS', '112'),
          ]),
        ]),
      );

  Widget _dialChip(String label, String number) => Expanded(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _red, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onPressed: () => _dial(number),
          child: Column(children: [
            Text(number, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(label, style: GoogleFonts.outfit(fontSize: 10)),
          ]),
        ),
      );

  Widget _actionTile(IconData icon, String title, String subtitle, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: ListTile(
          leading: Icon(icon, color: _green),
          title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280))),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          onTap: onTap,
        ),
      );

  Widget _offlineBanner() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2563EB)),
        ),
        child: Row(children: [
          const Icon(Icons.offline_bolt_rounded, size: 16, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Everything here works offline, from data saved for your trip.',
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E3A8A))),
          ),
        ]),
      );

  Widget _noData() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          'No nearby-help data was saved for this destination. Prepare the journey '
          'on WiFi to cache nearby help for offline use.',
          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280)),
        ),
      );
}
