// lib/widgets/tier_badge_widget.dart
//
// High-visibility visual indicators for PathSaathi's 3-Tier Data Architecture.
//
// Tier B Badge:
//   - Bold high-contrast warning banner (amber/saffron).
//   - Localized in English, Telugu, and Hindi.
//   - Unmissable in screenshots to prevent confusing template data with live data.
//
// Tier C Empty State:
//   - Honest empty state with venue information desk advice and sync trigger.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/regional_template_service.dart';
import '../services/sync_engine.dart';

class TierBadgeWidget extends StatelessWidget {
  final String? langCode;
  final String? customNote;
  final DestinationTier? tier;
  final String? stateName;

  const TierBadgeWidget({
    super.key,
    this.langCode,
    this.customNote,
    this.tier,
    this.stateName,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveLang = langCode ?? 'en';
    final effectiveState = stateName ?? 'Regional';
    final title = switch (effectiveLang) {
      'te' => 'అంచనా వేసిన సమాచారం — ప్రత్యక్ష డేటా కాదు',
      'hi' => 'अनुमानित विवरण — लाइव डेटा नहीं',
      _ => 'ESTIMATED — NOT LIVE DATA',
    };

    final fallbackSubtitle = switch (effectiveLang) {
      'te' => 'ఈ ప్రాంతంలోని ప్రామాణిక సేవల ఆధారంగా రూపొందించిన సమాచారం. దయచేసి స్థానిక కౌంటర్ వద్ద ధృవీకరించండి.',
      'hi' => 'इस क्षेत्र की सामान्य सेवाओं पर आधारित अनुमानित विवरण। कृपया स्थानीय काउंटर पर पुष्टि करें।',
      _ => 'Regional template based on typical services in $effectiveState. Verify schedules locally at the venue counter.',
    };

    final subtitle = customNote ?? fallbackSubtitle;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED), // High-contrast amber background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316), width: 1.5), // Saffron border
        boxShadow: const [
          BoxShadow(color: Color(0x1AF97316), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFEA580C),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC2410C),
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  customNote ?? subtitle,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF9A3412),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TierCEmptyStateWidget extends StatefulWidget {
  final String destinationName;
  final String? screenType; // legacy
  final String? contentType; // newer API
  final Future<void> Function()? onSyncTriggered;
  final DestinationTier? tier;

  const TierCEmptyStateWidget({
    super.key,
    required this.destinationName,
    this.screenType,
    this.contentType,
    this.onSyncTriggered,
    this.tier,
  });

  @override
  State<TierCEmptyStateWidget> createState() => _TierCEmptyStateWidgetState();
}

class _TierCEmptyStateWidgetState extends State<TierCEmptyStateWidget> {
  bool _syncing = false;
  String? _syncMessage;

  Future<void> _triggerSync() async {
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });

    try {
      if (widget.onSyncTriggered != null) {
        await widget.onSyncTriggered!();
      } else {
        await SyncEngine.instance.syncAll();
      }
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncMessage = 'Sync attempt completed. If online, verified data will update.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncing = false;
        _syncMessage = 'Sync failed. Connect to WiFi or mobile network.';
      });
    }
  }

  void _showHelpDeskDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Venue Help Desk', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'For unindexed destinations, official transport counters, bus terminals, and pilgrimage devasthanams maintain physical bulletin boards and assistance desks.\n\nPlease check with local staff for verified schedules.',
          style: GoogleFonts.outfit(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String get _contentTypeLabel => widget.contentType ?? widget.screenType ?? 'This section';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(Icons.location_off_outlined, size: 36, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 18),
            Text(
              'No offline data available for this location yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1F2937)),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.destinationName.isNotEmpty ? widget.destinationName : "This destination"} is not yet indexed in the offline travel database.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF4B5563), height: 1.4),
            ),
            const SizedBox(height: 24),
            // Action 1: Help desk
            OutlinedButton.icon(
              onPressed: _showHelpDeskDialog,
              icon: const Icon(Icons.info_outline, size: 18),
              label: const Text('Check Venue Help Desk'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            // Action 2: Sync
            FilledButton.icon(
              onPressed: _syncing ? null : _triggerSync,
              icon: _syncing
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sync_rounded, size: 18),
              label: Text(_syncing ? 'Syncing...' : 'Sync When Internet Available'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1A6B3C),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_syncMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _syncMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF047857), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}