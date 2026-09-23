// lib/screens/active_journey_screen.dart
//
// The live journey view: watches JourneyTrackingService for real GPS distance/
// direction to the destination, announces arrival, and offers accommodation
// (if none booked) or navigation to the booked stay. Also the entry to Offline
// Survival Mode when connectivity drops. Everything works offline.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/journey_tracking_service.dart';
import '../core/nav_history.dart';
import '../services/connectivity_service.dart';
import '../services/tts_service.dart';
import '../core/voice_strings.dart';
import '../providers/language_provider.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class ActiveJourneyScreen extends ConsumerStatefulWidget {
  const ActiveJourneyScreen({super.key});

  @override
  ConsumerState<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends ConsumerState<ActiveJourneyScreen> {
  JourneyStatus _status = const JourneyStatus(phase: JourneyPhase.none);

  bool _spokenArrival = false;

  @override
  void initState() {
    super.initState();
    JourneyTrackingService.instance.start();
    JourneyTrackingService.instance.stream.listen((s) {
      if (!mounted) return;
      setState(() => _status = s);
      // Announce arrival ONCE, aloud, in the user's selected language.
      if (s.phase == JourneyPhase.arrived && !_spokenArrival) {
        _spokenArrival = true;
        final lang = ref.read(languageProvider).code;
        final place = s.plan?.destinationName ?? '';
        () async {
          await TTSService.instance.initialize(langCode: lang);
          await TTSService.instance.speak(VoiceStrings.arrived(lang, place));
        }();
      }
    });
    _status = JourneyTrackingService.instance.last;
  }

  @override
  Widget build(BuildContext context) {
    final offline =
        ConnectivityService.instance.status == ConnectivityStatus.offline;
    final s = _status;
    final destName = s.plan?.destinationName ?? 'your destination';

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
        title: Text('Your journey', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (offline) _offlineBanner(),
          if (offline) const SizedBox(height: 12),
          _statusCard(s, destName),
          const SizedBox(height: 16),
          if (s.phase == JourneyPhase.arrived) _arrivedActions(destName),
          const SizedBox(height: 8),
          // Offline survival is always reachable during a journey.
          _tile(Icons.shield_moon_outlined, 'Offline help & survival mode',
              'Nearby help, your documents, emergency dial', () => context.go('/offline-survival')),
          _tile(Icons.navigation_rounded, 'Guidance to destination',
              'Spoken direction + distance (offline)', () => context.go('/nav')),
        ],
      ),
    );
  }

  Widget _statusCard(JourneyStatus s, String destName) {
    IconData icon;
    Color color;
    String title;
    switch (s.phase) {
      case JourneyPhase.arrived:
        icon = Icons.flag_circle; color = _green; title = 'You have reached $destName';
        break;
      case JourneyPhase.enRoute:
        icon = Icons.directions_walk_rounded; color = _saffron; title = 'On the way to $destName';
        break;
      case JourneyPhase.awaitingFix:
        icon = Icons.gps_not_fixed; color = const Color(0xFFEAB308); title = 'Waiting for GPS…';
        break;
      case JourneyPhase.none:
        icon = Icons.info_outline; color = const Color(0xFF6B7280); title = 'No active journey';
        break;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 40),
        const SizedBox(height: 10),
        Text(title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
        if (s.distanceMeters != null) ...[
          const SizedBox(height: 6),
          Text(
            '${_fmt(s.distanceMeters!)}${s.bearingCompass != null ? ' • head ${s.bearingCompass}' : ''}',
            style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF4B5563)),
          ),
        ],
        if (s.message.isNotEmpty && s.distanceMeters == null) ...[
          const SizedBox(height: 6),
          Text(s.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280))),
        ],
      ]),
    );
  }

  Widget _arrivedActions(String destName) {
    final hasStay = _status.plan?.stayReservationId != null;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _green),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hasStay ? 'Navigate to your stay' : 'Book a place to stay?',
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          hasStay
              ? 'Your accommodation is booked. Open guidance to reach it.'
              : 'You haven\'t booked accommodation yet. See nearby stays and help.',
          style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF166534)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity, height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            onPressed: () => context.go('/offline-survival'),
            child: Text(hasStay ? 'Navigate to stay' : 'Show nearby stays & help',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _offlineBanner() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDC2626)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded, size: 16, color: Color(0xFF991B1B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Offline — using saved trip data. GPS still works.',
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF991B1B))),
          ),
        ]),
      );

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback onTap) => Container(
        margin: const EdgeInsets.only(bottom: 10),
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

  static String _fmt(double m) =>
      m < 1000 ? '${m.round()} m away' : '${(m / 1000).toStringAsFixed(1)} km away';
}
