// lib/screens/journey_prepare_screen.dart
//
// "Prepare journey for offline" — runs PreCacheService and shows honest progress:
// nearby help, route guidance, and the offline map download. When done, the trip
// survives loss of connectivity. Truthful about what did/didn't cache.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/journey_plan_service.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class JourneyPrepareScreen extends ConsumerStatefulWidget {
  const JourneyPrepareScreen({super.key});

  @override
  ConsumerState<JourneyPrepareScreen> createState() => _JourneyPrepareScreenState();
}

class _JourneyPrepareScreenState extends ConsumerState<JourneyPrepareScreen> {
  PreCacheProgress _progress = const PreCacheProgress();
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    await PreCacheService.instance.prepare(
      onUpdate: (p) {
        if (!mounted) return;
        setState(() {
          _progress = p;
          if (p.done) _running = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _progress.status;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text('Preparing your journey', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'While you have internet, PathSaathi is saving everything you\'ll need '
            'at your destination — so it keeps helping you even if the network drops.',
            style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563), height: 1.5),
          ),
          const SizedBox(height: 20),
          _stepTile('Nearby help (hospitals, food, water, stays)', s.places),
          _stepTile('Route guidance to your stay', s.route),
          _stepTileWithProgress('Offline map of the trip area', s.tiles, _progress.tilesProgress),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(children: [
              Icon(_running ? Icons.sync : (s.isComplete ? Icons.check_circle : Icons.info_outline),
                  color: _running ? _saffron : (s.isComplete ? _green : const Color(0xFFEAB308))),
              const SizedBox(width: 10),
              Expanded(
                child: Text(_progress.message.isEmpty ? 'Preparing…' : _progress.message,
                    style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF374151))),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          if (!_running)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white),
                onPressed: () => context.go('/active-journey'),
                icon: const Icon(Icons.navigation_rounded),
                label: Text('Start journey →',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stepTile(String label, bool done) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(children: [
          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? _green : const Color(0xFF9CA3AF), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 14))),
        ]),
      );

  Widget _stepTileWithProgress(String label, bool done, double progress) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(children: [
          Row(children: [
            Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
                color: done ? _green : const Color(0xFF9CA3AF), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 14))),
            if (!done && progress > 0)
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280))),
          ]),
          if (!done && progress > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(_saffron),
                minHeight: 5,
              ),
            ),
          ],
        ]),
      );
}
