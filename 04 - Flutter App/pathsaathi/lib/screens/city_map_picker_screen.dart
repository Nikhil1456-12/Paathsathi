// lib/screens/city_map_picker_screen.dart
//
// City Map Picker Screen for PathSaathi
//
// Zero-friction city selector for elderly/non-educated pilgrims.
// Large cards, vernacular city names, clear download status indicators,
// one-tap download + navigate flow.
//
// Route: /city-map-picker

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/city_map_bundle.dart';
import '../providers/language_provider.dart';
import '../services/map_bundle_service.dart';
import '../services/connectivity_service.dart';

class CityMapPickerScreen extends ConsumerStatefulWidget {
  const CityMapPickerScreen({super.key});

  @override
  ConsumerState<CityMapPickerScreen> createState() => _CityMapPickerState();
}

class _CityMapPickerState extends ConsumerState<CityMapPickerScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Poll for download progress updates every 500ms
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    final connectivity = ref.watch(connectivityProvider);
    final isOnline = connectivity != ConnectivityStatus.offline;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A6B3C),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(lang),
              style: GoogleFonts.outfit(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            Text(
              _subtitle(lang),
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (!isOnline)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 12, color: Colors.white),
                  SizedBox(width: 4),
                  Text('Offline', style: TextStyle(fontSize: 10, color: Colors.white)),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Storage usage bar
          _StorageSummaryBar(),
          const SizedBox(height: 8),

          // City grid
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: CityBundleCatalog.all.length,
              itemBuilder: (context, i) {
                final bundle = CityBundleCatalog.all[i];
                final state = MapBundleService.instance.stateFor(bundle.id);
                return _CityBundleCard(
                  bundle: bundle,
                  state: state,
                  isOnline: isOnline,
                  langCode: lang,
                  index: i,
                  onNavigate: () => _navigateToCity(bundle),
                  onDownload: () => _downloadCity(bundle),
                  onDelete: () => _deleteCity(bundle),
                  onCancel: () => MapBundleService.instance.cancelDownload(bundle.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToCity(CityMapBundle bundle) {
    // Navigate to the nav screen centered on this city
    context.push('/nav', extra: {
      'cityId': bundle.id,
      'cityName': bundle.name,
      'lat': bundle.center.latitude,
      'lng': bundle.center.longitude,
      'zoom': bundle.defaultZoom,
    });
  }

  Future<void> _downloadCity(CityMapBundle bundle) async {
    final connectivity = ConnectivityService.instance.status;
    if (connectivity == ConnectivityStatus.offline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No internet connection. Please connect to WiFi to download.'),
          backgroundColor: Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    await MapBundleService.instance.downloadBundle(bundle.id);
  }

  Future<void> _deleteCity(CityMapBundle bundle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete ${bundle.name} map?'),
        content: Text('This will free ${bundle.mbtilesSize} MB of storage. '
            'You can re-download it anytime on WiFi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await MapBundleService.instance.deleteBundle(bundle.id);
    }
  }

  // ── Localized strings ─────────────────────────────────────────────────────

  String _title(String lang) {
    switch (lang) {
      case 'hi': return 'तीर्थ शहर — ऑफलाइन नक्शे';
      case 'te': return 'పుణ్యక్షేత్రాలు — ఆఫ్లైన్ మ్యాప్లు';
      case 'ta': return 'புனித நகரங்கள் — ஆஃப்லைன் வரைபடங்கள்';
      default:   return 'Pilgrimage Cities — Offline Maps';
    }
  }

  String _subtitle(String lang) {
    switch (lang) {
      case 'hi': return 'एक बार डाउनलोड करें — बिना इंटरनेट के उपयोग करें';
      case 'te': return 'ఒకసారి డౌన్‌లోడ్ చేయండి — ఇంటర్నెట్ లేకుండా వాడండి';
      default:   return 'Download once — use without internet';
    }
  }
}

// ── City Bundle Card ──────────────────────────────────────────────────────────

class _CityBundleCard extends StatelessWidget {
  final CityMapBundle bundle;
  final BundleDownloadState state;
  final bool isOnline;
  final String langCode;
  final int index;
  final VoidCallback onNavigate;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _CityBundleCard({
    required this.bundle,
    required this.state,
    required this.isOnline,
    required this.langCode,
    required this.index,
    required this.onNavigate,
    required this.onDownload,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = state.isReady;
    final isDownloading = state.isActive;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isReady
              ? bundle.themeColor.withAlpha(80)
              : Colors.grey.withAlpha(40),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onNavigate,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // City icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bundle.themeColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: bundle.themeColor.withAlpha(60)),
                    ),
                    child: Icon(bundle.icon, color: bundle.themeColor, size: 24),
                  ),
                  const SizedBox(width: 12),

                  // City info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bundle.getLocalizedName(langCode),
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (bundle.isPrimary)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B00).withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('AUTO',
                                    style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFFF6B00))),
                              ),
                          ],
                        ),
                        Text(
                          bundle.state,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bundle.significance,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar (when downloading)
              if (isDownloading) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progress,
                    backgroundColor: bundle.themeColor.withAlpha(20),
                    valueColor: AlwaysStoppedAnimation(bundle.themeColor),
                    minHeight: 5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.progressLabel,
                  style: TextStyle(fontSize: 11, color: bundle.themeColor),
                ),
                const SizedBox(height: 8),
              ],

              // Action buttons row
              Row(
                children: [
                  // Map size info
                  Icon(Icons.sd_storage_rounded,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${bundle.mbtilesSize} MB',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const Spacer(),

                  // Action buttons
                  if (isReady) ...[
                    _ActionChip(
                      label: 'Navigate',
                      icon: Icons.navigation_rounded,
                      color: bundle.themeColor,
                      onTap: onNavigate,
                    ),
                    const SizedBox(width: 8),
                    _ActionChip(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.grey,
                      onTap: onDelete,
                    ),
                  ] else if (isDownloading) ...[
                    _ActionChip(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
                      color: Colors.grey,
                      onTap: onCancel,
                    ),
                  ] else ...[
                    _ActionChip(
                      label: 'Navigate',
                      icon: Icons.navigation_rounded,
                      color: Colors.grey,
                      onTap: onNavigate,
                    ),
                    const SizedBox(width: 8),
                    if (isOnline)
                      _ActionChip(
                        label: 'Download',
                        icon: Icons.download_rounded,
                        color: bundle.themeColor,
                        filled: true,
                        onTap: onDownload,
                      )
                    else
                      const Text('Need WiFi',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ],
              ),

              // Offline ready indicator
              if (isReady) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.offline_bolt_rounded,
                          size: 13, color: Color(0xFF16A34A)),
                      const SizedBox(width: 5),
                      Text(
                        'Ready offline — works without internet',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF16A34A),
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate(delay: (index * 60).ms).fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: filled ? Colors.white : color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Storage Summary Bar ───────────────────────────────────────────────────────

class _StorageSummaryBar extends StatelessWidget {
  const _StorageSummaryBar();

  @override
  Widget build(BuildContext context) {
    final readyCount = CityBundleCatalog.all
        .where((b) => MapBundleService.instance.isReady(b.id))
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.map_rounded, size: 18, color: Color(0xFF1A6B3C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$readyCount of ${CityBundleCatalog.all.length} cities downloaded for offline use',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
