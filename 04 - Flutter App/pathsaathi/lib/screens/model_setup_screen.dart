import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/model_manager.dart';
import '../services/device_tier_service.dart';
import '../services/whisper_service.dart';
import '../services/llm_service.dart';
import '../core/nav_history.dart';

const _saffron = Color(0xFFFF6B00);
const _green = Color(0xFF1A6B3C);
const _darkBg = Color(0xFF0D1B12);

/// First-run screen for downloading offline AI models.
/// All models go to app documents directory — 100% offline after download.
class ModelSetupScreen extends ConsumerStatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  ConsumerState<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends ConsumerState<ModelSetupScreen> {
  final Map<String, double> _progress = {};
  final Map<String, bool> _downloaded = {};
  final Map<String, bool> _downloading = {};
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkDownloadStatus();
  }

  Future<void> _checkDownloadStatus() async {
    setState(() => _checkingStatus = true);
    for (final model in ModelCatalog.all) {
      final ok = await ModelManager.isDownloaded(model);
      if (mounted) setState(() => _downloaded[model.id] = ok);
    }
    if (mounted) setState(() => _checkingStatus = false);
  }

  Future<void> _downloadModel(ModelEntry model) async {
    if (_downloading[model.id] == true) return;
    setState(() {
      _downloading[model.id] = true;
      _progress[model.id] = 0.0;
    });

    await ModelManager.download(
      model,
      onProgress: (p) {
        if (mounted) setState(() => _progress[model.id] = p);
      },
      onDone: () async {
        // Activate the newly-downloaded model immediately (no app restart):
        //  • ASR (Whisper)  → offline voice works right away
        //  • LLM (Gemma)    → planner uses the model right away
        if (model.category == 'asr') {
          await WhisperService.instance.initialize();
        } else if (model.category == 'llm') {
          await LlmService.instance.initialize();
        }
        if (mounted) {
          setState(() {
            _downloaded[model.id] = true;
            _downloading[model.id] = false;
            _progress[model.id] = 1.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(model.category == 'asr'
                  ? '✅ ${model.name} ready — offline voice is now enabled!'
                  : '✅ ${model.name} downloaded!'),
              backgroundColor: _green,
            ),
          );
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() => _downloading[model.id] = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ $err'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only offer the model set that fits this device's tier — keeps download
    // size and RAM footprint appropriate (Lite ≈ 800MB, Standard ≈ 1.6GB, Full ≈ 3.1GB).
    final tier = DeviceTierService.tier;
    final priorityModels = ModelCatalog.forTier(tier);
    final totalMb = ModelCatalog.totalSizeMB(tier);

    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _green,
        title: Text(
          'AI Model Setup',
          style: GoogleFonts.outfit(
              fontWeight: FontWeight.w700, fontSize: 20, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => smartBack(context),
        ),
        actions: [
          TextButton.icon(
            onPressed: _checkDownloadStatus,
            icon: const Icon(Icons.refresh, color: Colors.white70, size: 18),
            label: Text('Refresh',
                style:
                    GoogleFonts.outfit(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _green.withValues(alpha: 0.15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🧠 Offline AI Models',
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  'Detected device: ${tier.label} — recommended AI pack ≈ ${totalMb} MB.\n'
                  'Download once on WiFi; the app then works fully offline. Only the '
                  'models that fit your device are shown, to save space and battery.',
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: Colors.white70, height: 1.5),
                ),
              ],
            ),
          ),

          if (_checkingStatus)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _saffron),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: priorityModels.length,
                itemBuilder: (context, i) =>
                    _ModelCard(
                  model: priorityModels[i],
                  isDownloaded: _downloaded[priorityModels[i].id] ?? false,
                  isDownloading: _downloading[priorityModels[i].id] ?? false,
                  progress: _progress[priorityModels[i].id] ?? 0.0,
                  onDownload: () => _downloadModel(priorityModels[i]),
                ),
              ),
            ),

          // Continue Button
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saffron,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    'Continue with Downloaded Models →',
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelCard extends StatelessWidget {
  final ModelEntry model;
  final bool isDownloaded;
  final bool isDownloading;
  final double progress;
  final VoidCallback onDownload;

  const _ModelCard({
    required this.model,
    required this.isDownloaded,
    required this.isDownloading,
    required this.progress,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDownloaded
              ? _green.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(ModelCatalog.categoryIcon(model.category),
                    style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                      Text(
                        '${model.framework}  •  ${model.quantization}  •  ${model.sizeMB} MB',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionWidget(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              model.description,
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_saffron),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%  of ${model.sizeMB} MB',
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.white54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionWidget() {
    if (isDownloaded) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: _green, size: 14),
            const SizedBox(width: 4),
            Text('Ready',
                style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: _green,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    if (isDownloading) {
      return SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          value: progress > 0 ? progress : null,
          strokeWidth: 2.5,
          color: _saffron,
        ),
      );
    }
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: _saffron,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
        minimumSize: Size.zero,
      ),
      onPressed: onDownload,
      icon: const Icon(Icons.download_rounded, size: 14),
      label: const Text('Download'),
    );
  }
}
