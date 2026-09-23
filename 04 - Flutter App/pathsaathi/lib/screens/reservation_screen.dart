// lib/screens/reservation_screen.dart
//
// Confirms the selected transport as an on-device PROTOTYPE reservation (real
// local record + confirmation reference; no money, no live seat — clearly
// labelled). After confirming, proceeds to journey preparation (pre-caching).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/journey_models.dart';
import '../providers/travel_context.dart';
import '../core/nav_history.dart';
import '../services/reservation_service.dart';
import '../services/transport_repository.dart';
import '../database/app_database.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key});

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  TransportOption? _selected;
  bool _loading = true;
  bool _confirming = false;
  Reservation? _confirmed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dest = ref.read(travelContextProvider).confirmedDestination;
    final plan = await AppDatabase.instance.getActivePlan();
    if (dest != null && plan != null && plan['transport_option_id'] != null) {
      final opts = await TransportRepository.instance.optionsForPlace(dest);
      final id = plan['transport_option_id'] as int;
      for (final o in opts) {
        if (o.id == id) { _selected = o; break; }
      }
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _confirm() async {
    final dest = ref.read(travelContextProvider).confirmedDestination;
    final o = _selected;
    if (o == null || dest == null) return;
    setState(() => _confirming = true);
    final res = await ReservationService.instance.create(
      type: 'transport',
      title: '${o.mode.toUpperCase()} to ${dest.name}',
      details: '${o.operator} • ${o.fromName} → ${o.toName} • '
          '${o.depTime}→${o.arrTime} • ₹${o.priceInr}',
    );
    if (!mounted) return;
    setState(() {
      _confirmed = res;
      _confirming = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dest = ref.watch(travelContextProvider).confirmedDestination;

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
        title: Text('Reserve', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _saffron))
          : _selected == null
              ? _empty('No transport option selected. Please pick one first.')
              : _confirmed != null
                  ? _confirmedView(_confirmed!, dest?.name ?? '')
                  : _confirmView(_selected!, dest?.name ?? ''),
    );
  }

  Widget _confirmView(TransportOption o, String destName) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _demoBanner(),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Reserve your travel to $destName',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _row('Mode', o.mode.toUpperCase()),
              _row('Operator', o.operator),
              _row('Route', '${o.fromName} → ${o.toName}'),
              _row('Time', '${o.depTime} → ${o.arrTime}'),
              _row('Fare (indicative)', '₹${o.priceInr}'),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white),
              onPressed: _confirming ? null : _confirm,
              icon: _confirming
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_confirming ? 'Reserving…' : 'Confirm reservation',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );

  Widget _confirmedView(Reservation r, String destName) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: _green, size: 40),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Reservation confirmed',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Reference: ${r.refCode}',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _green)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(r.details,
                  style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563))),
            ]),
          ),
          const SizedBox(height: 12),
          _demoBanner(),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _saffron, foregroundColor: Colors.white),
              // Proceed to journey preparation (pre-caching for offline).
              onPressed: () => context.go('/journey-prepare'),
              icon: const Icon(Icons.cloud_download_outlined),
              label: Text('Prepare journey for offline →',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );

  Widget _demoBanner() => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2563EB)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF1E3A8A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demo reservation — a real on-device record with a reference, but '
              'no payment and no live seat/room booking.',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E3A8A)),
            ),
          ),
        ]),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 120,
            child: Text(k, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF6B7280))),
          ),
          Expanded(
            child: Text(v, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _empty(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(msg,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF6B7280))),
        ),
      );
}
