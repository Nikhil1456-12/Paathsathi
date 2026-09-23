// lib/screens/fog_dashboard_screen.dart
//
// Fog / Edge Node Operator Dashboard for PathSaathi
//
// This screen is for camp operators and field supervisors — not for regular
// pilgrims. It shows:
//   • Live Fog node connectivity status
//   • Zone crowd density heatmap (static when Fog is unreachable)
//   • Active SOS cases from MedicalSOSAgent
//   • Lost & Found open cases from LostFoundAgent
//   • Tier routing analytics (Cache/Edge/Device/Cloud hit rates)
//
// Route: /fog-dashboard
// Access: Reachable from Profile → "Operator Tools" (admin only)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../agents/fog/crowd_agent.dart';
import '../agents/fog/lost_found_agent.dart';
import '../agents/fog/medical_sos_agent.dart';
import '../services/fog_service.dart';
import '../services/cloud_service.dart';
import '../services/tier_router.dart';

class FogDashboardScreen extends ConsumerStatefulWidget {
  const FogDashboardScreen({super.key});

  @override
  ConsumerState<FogDashboardScreen> createState() => _FogDashboardState();
}

class _FogDashboardState extends ConsumerState<FogDashboardScreen> {
  Timer? _refreshTimer;
  bool _isProbing = false;

  @override
  void initState() {
    super.initState();
    // Refresh fog status every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _probeFog() async {
    setState(() => _isProbing = true);
    final found = await FogService.instance.discoverFogNode();
    ref.read(fogStatusProvider.notifier).state = FogService.instance.status;
    if (mounted) {
      setState(() => _isProbing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(found
            ? '✅ Fog node found at ${FogService.instance.fogAddress}'
            : '❌ No Fog node found on LAN. Using on-device fallback.'),
        backgroundColor: found
            ? const Color(0xFF16A34A)
            : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fogStatus = FogService.instance.status;
    final cloudAvailable = CloudService.instance.isAvailable;
    final router = TierRouter.instance;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fog Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Camp Operator Tools', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: _isProbing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.radar_rounded),
            tooltip: 'Probe Fog Node',
            onPressed: _isProbing ? null : _probeFog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Tier Connectivity Overview ─────────────────────
          _SectionHeader(title: '📡 Tier Connectivity', icon: Icons.device_hub_rounded),
          const SizedBox(height: 8),
          _TierConnectivityCard(
            fogStatus: fogStatus,
            cloudAvailable: cloudAvailable,
            fogAddress: FogService.instance.fogAddress,
            fogLastContact: FogService.instance.lastContactAgo,
          ),
          const SizedBox(height: 20),

          // ── Routing Analytics ──────────────────────────────
          _SectionHeader(title: '📊 Routing Analytics', icon: Icons.analytics_rounded),
          const SizedBox(height: 8),
          _AnalyticsCard(router: router),
          const SizedBox(height: 20),

          // ── Zone Crowd Density ─────────────────────────────
          _SectionHeader(title: '👥 Zone Crowd Density', icon: Icons.people_rounded),
          const SizedBox(height: 4),
          if (fogStatus != FogStatus.connected)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fog node offline — showing static zone data. '
                      'Live BLE beacon data available when Fog is connected.',
                      style: TextStyle(fontSize: 11, color: Colors.amber),
                    ),
                  ),
                ],
              ),
            ),
          ...CrowdAgent.staticZones.map((z) => _ZoneDensityCard(zone: z)),
          const SizedBox(height: 20),

          // ── Active SOS Cases ───────────────────────────────
          _SectionHeader(title: '🚨 Medical SOS Cases', icon: Icons.emergency_share_rounded),
          const SizedBox(height: 8),
          _SosCasesCard(agent: MedicalSosAgent.instance),
          const SizedBox(height: 20),

          // ── Lost & Found ───────────────────────────────────
          _SectionHeader(title: '🔍 Lost & Found', icon: Icons.search_rounded),
          const SizedBox(height: 8),
          _LostFoundCard(agent: LostFoundAgent.instance),
          const SizedBox(height: 20),

          // ── Medical Posts Directory ────────────────────────
          _SectionHeader(title: '🏥 Medical Posts', icon: Icons.local_hospital_rounded),
          const SizedBox(height: 8),
          ...MedicalSosAgent.kumbhMedicalPosts.map((p) => _MedicalPostCard(post: p)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TierConnectivityCard extends StatelessWidget {
  final FogStatus fogStatus;
  final bool cloudAvailable;
  final String fogAddress;
  final String fogLastContact;

  const _TierConnectivityCard({
    required this.fogStatus,
    required this.cloudAvailable,
    required this.fogAddress,
    required this.fogLastContact,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _TierRow(
              emoji: '🟣',
              label: 'Offline Cache',
              sublabel: 'Hot patterns — always active',
              status: 'ONLINE',
              statusColor: const Color(0xFF7C3AED),
            ),
            const Divider(height: 1),
            _TierRow(
              emoji: '🟠',
              label: 'Fog Edge Node',
              sublabel: fogStatus == FogStatus.connected
                  ? '$fogAddress — last: $fogLastContact'
                  : 'No node found on LAN — tap ⊕ to probe',
              status: fogStatus == FogStatus.connected
                  ? 'CONNECTED'
                  : fogStatus == FogStatus.discovering
                  ? 'PROBING…'
                  : 'OFFLINE',
              statusColor: fogStatus == FogStatus.connected
                  ? const Color(0xFFF97316)
                  : Colors.grey,
            ),
            const Divider(height: 1),
            _TierRow(
              emoji: '🟢',
              label: 'On-Device Agents',
              sublabel: 'Gemma LLM / MobileBERT / Keyword',
              status: 'ONLINE',
              statusColor: const Color(0xFF16A34A),
            ),
            const Divider(height: 1),
            _TierRow(
              emoji: '☁️',
              label: 'Cloud Backend',
              sublabel: cloudAvailable
                  ? 'Infosys + Bhashini — reachable'
                  : 'Infosys backend — unreachable',
              status: cloudAvailable ? 'ONLINE' : 'OFFLINE',
              statusColor: cloudAvailable
                  ? const Color(0xFF0284C7)
                  : Colors.grey,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _TierRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final String status;
  final Color statusColor;

  const _TierRow({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(sublabel, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: statusColor.withAlpha(80)),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final TierRouter router;
  const _AnalyticsCard({required this.router});

  @override
  Widget build(BuildContext context) {
    final total = router.totalQueries;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Queries: $total',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Last: ${router.lastResponseMs}ms',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...QueryTier.values.map((t) => _AnalyticsBar(
              tier: t,
              hits: router.tierHits[t] ?? 0,
              total: total == 0 ? 1 : total,
            )),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _AnalyticsBar extends StatelessWidget {
  final QueryTier tier;
  final int hits;
  final int total;

  const _AnalyticsBar({
    required this.tier,
    required this.hits,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final pct = hits / total;
    final color = _tierColor(tier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tier.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text(
                tier.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '$hits queries (${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withAlpha(30),
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Color _tierColor(QueryTier tier) {
    switch (tier) {
      case QueryTier.cache:    return const Color(0xFF7C3AED);
      case QueryTier.fog:      return const Color(0xFFF97316);
      case QueryTier.onDevice: return const Color(0xFF16A34A);
      case QueryTier.cloud:    return const Color(0xFF0284C7);
    }
  }
}

class _ZoneDensityCard extends StatelessWidget {
  final ZoneDensity zone;
  const _ZoneDensityCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: zone.levelColor.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: zone.levelColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: zone.levelColor.withAlpha(60)),
              ),
              child: Center(
                child: Text(
                  zone.zoneId,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: zone.levelColor,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.zoneName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${zone.estimatedPilgrims.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    )} / ${zone.maxCapacity.toString().replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (m) => '${m[1]},',
                    )} pilgrims',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: zone.occupancyRatio,
                      backgroundColor: zone.levelColor.withAlpha(20),
                      valueColor: AlwaysStoppedAnimation(zone.levelColor),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '→ ${zone.safeAlternativeRoute}',
                    style: TextStyle(fontSize: 10, color: zone.levelColor),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: zone.levelColor.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: zone.levelColor.withAlpha(80)),
              ),
              child: Text(
                zone.levelLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: zone.levelColor,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.05);
  }
}

class _SosCasesCard extends StatelessWidget {
  final MedicalSosAgent agent;
  const _SosCasesCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.emergency_share_rounded, color: Color(0xFFDC2626), size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${agent.activeCaseCount} Active SOS Case(s)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Text(
                  'Connect Fog node for live case dispatch',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LostFoundCard extends StatelessWidget {
  final LostFoundAgent agent;
  const _LostFoundCard({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFFD97706), size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${agent.openCases} Open / ${agent.resolvedCases} Resolved',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Text(
                  'Fog Chroma DB enables cross-device phonetic matching',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalPostCard extends StatelessWidget {
  final MedicalPost post;
  const _MedicalPostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(50)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626).withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.local_hospital_rounded, color: Color(0xFFDC2626), size: 20),
        ),
        title: Text(post.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${post.phone} • ${post.has24HrDoctor ? "24h Doctor" : "First Aid"}'
          '${post.hasAmbulance ? " • 🚑 Ambulance" : ""}',
          style: const TextStyle(fontSize: 11),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF16A34A).withAlpha(15),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            post.zone,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
          ),
        ),
      ),
    );
  }
}
