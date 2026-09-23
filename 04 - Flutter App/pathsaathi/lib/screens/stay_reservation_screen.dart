import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/accommodation_repository.dart';
import '../services/reservation_service.dart';
import '../models/journey_models.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class StayReservationScreen extends ConsumerStatefulWidget {
  const StayReservationScreen({super.key});

  @override
  ConsumerState<StayReservationScreen> createState() =>
      _StayReservationScreenState();
}

class _StayReservationScreenState extends ConsumerState<StayReservationScreen> {
  Reservation? _confirmed;
  bool _confirming = false;

  AccommodationRecommendation? get hotel =>
      AccommodationRepository.instance.selectedHotel;

  Future<void> _confirm() async {
    final selected = hotel;
    if (selected == null) return;
    setState(() => _confirming = true);
    final reservation = await ReservationService.instance.create(
      type: 'stay',
      title: selected.name,
      details:
          '${selected.area} • ${selected.distanceKm} km from destination • '
          '${selected.vacancies} vacancies shown',
    );
    if (!mounted) return;
    setState(() {
      _confirmed = reservation;
      _confirming = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = hotel;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        title: Text('Book your stay',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
      ),
      body: selected == null
          ? const Center(
              child: Text('No hotel selected. Return to the stay page.'))
          : _confirmed == null
              ? _bookingForm(selected)
              : _confirmation(_confirmed!),
    );
  }

  Widget _bookingForm(AccommodationRecommendation selected) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _notice(),
          const SizedBox(height: 14),
          _hotelSummary(selected),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _confirming ? null : _confirm,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _saffron, foregroundColor: Colors.white),
              icon: _confirming
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: Text(_confirming ? 'Booking…' : 'Confirm hotel booking',
                  style: GoogleFonts.outfit(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      );

  Widget _hotelSummary(AccommodationRecommendation hotel) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hotel.name,
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(hotel.area,
              style: GoogleFonts.outfit(color: const Color(0xFF4B5563))),
          const SizedBox(height: 14),
          _row('Rating', '★ ${hotel.rating.toStringAsFixed(1)}'),
          _row('Distance', '${hotel.distanceKm} km'),
          _row('Available rooms', '${hotel.vacancies} vacancies'),
          _row('Facilities', hotel.facilities.join(', ')),
        ]),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 125,
              child: Text(label,
                  style: GoogleFonts.outfit(
                      color: const Color(0xFF6B7280), fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, fontSize: 13))),
        ]),
      );

  Widget _confirmation(Reservation reservation) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Icon(Icons.check_circle, color: _green, size: 72),
          const SizedBox(height: 12),
          Center(
            child: Text('Stay booking confirmed',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Center(
              child: Text('Reference: ${reservation.refCode}',
                  style: GoogleFonts.outfit(
                      color: _green, fontWeight: FontWeight.w700))),
          const SizedBox(height: 18),
          _notice(),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => context.go('/journey-prepare'),
            style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white),
            icon: const Icon(Icons.arrow_forward),
            label: Text('Continue to journey preparation',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      );

  Widget _notice() => Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF93C5FD)),
        ),
        child: Text(
          'Demo booking: this creates an offline confirmation record. '
          'It does not charge money or reserve a live hotel room.',
          style:
              GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF1E3A8A)),
        ),
      );
}
