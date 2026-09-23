// lib/screens/transport_options_screen.dart
//
// Shows curated transport options (bus / train) for the CONFIRMED destination
// and lets the user pick one. The selection is saved into the active journey
// plan. All data is indicative/offline (clearly labelled); no live booking here
// (reservation happens in a later step).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/journey_models.dart';
import '../core/nav_history.dart';
import '../providers/travel_context.dart';
import '../services/transport_repository.dart';
import '../database/app_database.dart';
import '../services/location_service.dart';
import '../services/place_search_service.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class TransportOptionsScreen extends ConsumerStatefulWidget {
  const TransportOptionsScreen({super.key});

  @override
  ConsumerState<TransportOptionsScreen> createState() =>
      _TransportOptionsScreenState();
}

class _TransportOptionsScreenState
    extends ConsumerState<TransportOptionsScreen> {
  List<TransportOption> _options = [];
  String? _locationError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dest = ref.read(travelContextProvider).confirmedDestination;
    if (dest == null) {
      setState(() => _loading = false);
      return;
    }
    final origin = await LocationService.instance.currentOnce();
    if (origin == null) {
      if (!mounted) return;
      setState(() {
        _locationError = 'Your current GPS location is unavailable. Enable '
            'Location and try again so tickets use the correct source.';
        _loading = false;
      });
      return;
    }
    final opts = await TransportRepository.instance.optionsForRoute(
      dest,
      origin: origin,
    );
    if (!mounted) return;
    setState(() {
      _options = opts;
      _loading = false;
    });
  }

  Future<void> _select(TransportOption opt) async {
    final dest = ref.read(travelContextProvider).confirmedDestination;
    if (dest == null) return;
    // Save/refresh the active journey plan with this transport choice.
    await AppDatabase.instance.upsertActivePlan(JourneyPlan(
      id: 0,
      destinationId: TransportRepository.destinationKeyForPlace(dest),
      destinationName: dest.name,
      destinationCoords: dest.coords,
      transportOptionId: opt.id,
      createdAt: DateTime.now(),
    ).toRow());
    if (!mounted) return;
    // Show stay recommendations immediately after transport selection.
    context.go('/accommodation');
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
        title: Text('Ways to reach ${dest?.name ?? ''}',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _saffron))
          : _locationError != null
              ? _emptyState(_locationError!)
              : dest == null
                  ? _emptyState(
                      'No confirmed destination. Please choose a destination first.')
                  : _options.isEmpty
                      ? _emptyState(
                          'No transport data for ${dest.name} in the offline dataset yet.')
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _routeBanner(dest),
                            const SizedBox(height: 12),
                            ..._options.map(_optionCard),
                          ],
                        ),
    );
  }

  Widget _routeBanner(Place dest) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF86EFAC)),
        ),
        child: Row(children: [
          const Icon(Icons.route, size: 17, color: _green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Route: ${_options.first.fromName} → ${dest.name}. '
              'Options are bound to your GPS source; schedules and fares are '
              'indicative and must be confirmed with the operator.',
              style: GoogleFonts.outfit(fontSize: 12, color: _green),
            ),
          ),
        ]),
      );

  Widget _optionCard(TransportOption o) {
    final isTrain = o.mode == 'train';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isTrain ? _green : _saffron).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  isTrain ? Icons.train_rounded : Icons.directions_bus_rounded,
                  color: isTrain ? _green : _saffron,
                  size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.operator,
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text('${o.fromName} → ${o.toName}',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: const Color(0xFF6B7280))),
                  ]),
            ),
            Text('₹${o.priceInr}',
                style: GoogleFonts.outfit(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _green)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _chip(Icons.schedule, '${o.depTime} → ${o.arrTime}'),
            const SizedBox(width: 8),
            _chip(Icons.category_outlined, o.mode.toUpperCase()),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white),
              onPressed: () => _select(o),
              child: Text('Select this option',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: const Color(0xFF6B7280)),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.outfit(
                  fontSize: 11, color: const Color(0xFF374151))),
        ]),
      );

  Widget _emptyState(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.info_outline, size: 40, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                    fontSize: 14, color: const Color(0xFF6B7280))),
          ]),
        ),
      );
}
