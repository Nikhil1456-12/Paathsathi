// lib/widgets/tier_status_badge.dart
//
// Animated Tier Status Badge for PathSaathi
//
// Shows which intelligence tier served the last response:
//   🟣 CACHE    — Tier 0, OfflineIntentCache (<1ms)
//   🟠 EDGE     — Tier 2, Fog Node (LangGraph, Chroma)
//   🟢 ON-DEVICE— Tier 1, IntentPlanner (Gemma/BERT/Keyword)
//   ☁️ CLOUD    — Tier 3, Infosys Backend + Bhashini
//
// Usage:
//   TierStatusBadge(tier: QueryTier.fog, responseMs: 42)

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/tier_router.dart';
import '../services/fog_service.dart';

class TierStatusBadge extends StatelessWidget {
  final QueryTier tier;
  final int? responseMs;
  final bool compact; // If true, show icon-only version

  const TierStatusBadge({
    super.key,
    required this.tier,
    this.responseMs,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    final label = tier.label;
    final icon = _tierIcon(tier);
    final msLabel = responseMs != null ? ' • ${responseMs}ms' : '';

    if (compact) {
      return Tooltip(
        message: '${tier.description}\n${tier.emoji} $label$msLabel',
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.8, 0.8));
    }

    return Tooltip(
      message: tier.description,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withAlpha(80), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
            Text(
              '$label$msLabel',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.1),
    );
  }

  static Color _tierColor(QueryTier tier) {
    switch (tier) {
      case QueryTier.cache:    return const Color(0xFF7C3AED);
      case QueryTier.fog:      return const Color(0xFFF97316);
      case QueryTier.onDevice: return const Color(0xFF16A34A);
      case QueryTier.cloud:    return const Color(0xFF0284C7);
    }
  }

  static IconData _tierIcon(QueryTier tier) {
    switch (tier) {
      case QueryTier.cache:    return Icons.bolt_rounded;
      case QueryTier.fog:      return Icons.hub_rounded;
      case QueryTier.onDevice: return Icons.phone_android_rounded;
      case QueryTier.cloud:    return Icons.cloud_done_rounded;
    }
  }
}

// ── Connectivity Tier Indicator (for Home Screen top bar) ─────────────────────

class TierConnectivityIndicator extends StatelessWidget {
  final FogStatus fogStatus;
  final bool cloudAvailable;

  const TierConnectivityIndicator({
    super.key,
    required this.fogStatus,
    required this.cloudAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.device_hub_rounded, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'Intelligence Tier:',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(width: 8),
          // Cache (always available)
          _TierDot(
            label: 'CACHE',
            color: const Color(0xFF7C3AED),
            active: true,
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(width: 6),
          // Fog Edge
          _TierDot(
            label: 'EDGE',
            color: const Color(0xFFF97316),
            active: fogStatus == FogStatus.connected,
            icon: Icons.hub_rounded,
          ),
          const SizedBox(width: 6),
          // On-Device (always available)
          _TierDot(
            label: 'DEVICE',
            color: const Color(0xFF16A34A),
            active: true,
            icon: Icons.phone_android_rounded,
          ),
          const SizedBox(width: 6),
          // Cloud
          _TierDot(
            label: 'CLOUD',
            color: const Color(0xFF0284C7),
            active: cloudAvailable,
            icon: Icons.cloud_done_rounded,
          ),
        ],
      ),
    );
  }
}

class _TierDot extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final IconData icon;

  const _TierDot({
    required this.label,
    required this.color,
    required this.active,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = active ? color : Colors.grey.withAlpha(80);
    return Tooltip(
      message: '$label ${active ? "Available" : "Unavailable"}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: effectiveColor,
              shape: BoxShape.circle,
            ),
          ).animate(
            onPlay: (ctrl) => active ? ctrl.repeat() : ctrl.stop(),
          ).then(delay: 1000.ms).custom(
            duration: 1200.ms,
            builder: (_, value, child) => Opacity(
              opacity: active ? (0.4 + 0.6 * (1 - value)) : 1.0,
              child: child,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: effectiveColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
