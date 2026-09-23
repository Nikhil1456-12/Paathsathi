// lib/widgets/offline_banner.dart
//
// Slim animated banner that reflects network status.
// Shows amber "Offline Mode" when no internet, orange "Weak connection" on mobile data,
// and hides completely when online.
//
// Usage — wrap your Scaffold body:
//   Column(children: [
//     const OfflineBanner(),
//     Expanded(child: yourContent),
//   ])
//
// Or add to MainShell above the page body.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectivityProvider);

    final config = switch (status) {
      ConnectivityStatus.offline => (
          text: '📴  Offline Mode  •  Using cached data',
          bg: const Color(0xFFFEF3C7),       // amber-100
          fg: const Color(0xFF92400E),       // amber-800
          border: const Color(0xFFF59E0B),   // amber-400
        ),
      ConnectivityStatus.degraded => (
          text: '⚠️  Weak connection  •  Some features may be slow',
          bg: const Color(0xFFFFF7ED),       // orange-50
          fg: const Color(0xFF9A3412),       // orange-800
          border: const Color(0xFFFB923C),   // orange-400
        ),
      ConnectivityStatus.online => null,
    };

    // When online, collapse to zero height with animation
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: config == null
          ? const SizedBox.shrink()
          : _BannerTile(
              text: config.text,
              bg: config.bg,
              fg: config.fg,
              border: config.border,
            ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  const _BannerTile({
    required this.text,
    required this.bg,
    required this.fg,
    required this.border,
  });

  final String text;
  final Color bg;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: fg,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
