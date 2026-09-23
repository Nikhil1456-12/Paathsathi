import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../agents/document_agent.dart';
import '../services/secure_window.dart';
import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

/// Attempts fingerprint / face unlock. Returns true if authenticated,
/// false if the user cancelled or biometrics are unavailable (caller then
/// falls back to the PIN gate).
Future<bool> _biometricUnlock() async {
  final auth = LocalAuthentication();
  try {
    final canCheck =
        await auth.canCheckBiometrics || await auth.isDeviceSupported();
    if (!canCheck) return false;
    return await auth.authenticate(
      localizedReason: 'Unlock your secure documents',
      options: const AuthenticationOptions(
        biometricOnly: false, // allow device PIN/pattern as fallback
        stickyAuth: true,
      ),
    );
  } catch (_) {
    return false;
  }
}

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<SecureDocument> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Block screenshots/recording while documents are on screen.
    SecureWindow.enable();
    _loadDocuments();
  }

  @override
  void dispose() {
    SecureWindow.disable();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    final list = await DocumentAgent.instance.getDocuments();
    if (mounted) {
      setState(() {
        _docs = list;
        _loading = false;
      });
    }
  }

  void _showAddDocumentDialog() {
    final titleCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Identity');
    final numberCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String? pickedImageB64;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.shield_outlined, color: _green),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Add Encrypted Document',
                    style: GoogleFonts.outfit(
                        fontSize: 17, fontWeight: FontWeight.w700))),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                    labelText: 'Title (e.g. Aadhaar / PAN / Passport)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              // Number field with a mic button for spoken-number capture.
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Document number (type or speak)',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.mic, color: _green),
                    tooltip: 'Speak the number',
                    onPressed: () =>
                        _captureSpokenNumber(ctx, numberCtrl, setDlg),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              // Attach a photo of the document (stored encrypted, on-device).
              OutlinedButton.icon(
                onPressed: () async {
                  final b64 = await _pickDocumentImage();
                  if (b64 != null) setDlg(() => pickedImageB64 = b64);
                },
                icon: Icon(
                    pickedImageB64 == null
                        ? Icons.photo_camera_outlined
                        : Icons.check_circle,
                    color: _green),
                label: Text(
                    pickedImageB64 == null
                        ? 'Attach photo of document'
                        : 'Photo attached ✓',
                    style: GoogleFonts.outfit(color: _green)),
              ),
              const SizedBox(height: 6),
              Text('Stored encrypted on this device only. Never uploaded.',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: const Color(0xFF6B7280))),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.outfit(color: const Color(0xFF4B5563))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final number = numberCtrl.text.trim();
                if (title.isEmpty) return;
                // Require at least one form of content (number or photo).
                if (number.isEmpty && pickedImageB64 == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Add a number or attach a photo.')));
                  return;
                }
                try {
                  if (pickedImageB64 != null) {
                    await DocumentAgent.instance.addImageDocument(
                      title: title,
                      docType: typeCtrl.text.trim(),
                      imageBase64: pickedImageB64!,
                    );
                  } else {
                    await DocumentAgent.instance.addNumberDocument(
                      title: title,
                      docType: typeCtrl.text.trim(),
                      number: number,
                    );
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Could not save document: $e')),
                    );
                  }
                  return;
                }
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                _loadDocuments();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content:
                          Text('🔒 Document encrypted & stored on-device.')));
                }
              },
              child: Text('Save Securely',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  /// Pick a document photo from the gallery and return it base64-encoded.
  Future<String?> _pickDocumentImage() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 70);
      if (xfile == null) return null;
      final bytes = await xfile.readAsBytes();
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Capture a spoken document number: listen, then read it back for confirm.
  Future<void> _captureSpokenNumber(
      BuildContext ctx,
      TextEditingController numberCtrl,
      void Function(void Function()) setDlg) async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('selected_language_code') ?? 'en';
    final ok = await STTService.instance.initialize();
    if (!ok) return;
    await STTService.instance.startListening(
      langCode: lang,
      onResult: (words, isFinal) async {
        if (!isFinal) return;
        // Keep only digits from the spoken result.
        final digits = words.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.isEmpty) return;
        setDlg(() => numberCtrl.text = digits);
        // Read the number back for the user to confirm (accessibility + safety).
        await TTSService.instance.speak(digits.split('').join(' '));
      },
      onError: (_) {},
    );
  }

  void _showViewDocumentDialog(SecureDocument doc) {
    final pinCtrl = TextEditingController();
    bool unlocked = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            Icon(unlocked ? Icons.lock_open_rounded : Icons.lock_outline,
                color: unlocked ? _green : _saffron),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                unlocked ? doc.title : 'PIN Verification Required',
                style: GoogleFonts.outfit(
                    fontSize: 17, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          content: unlocked
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('AES-256 Decrypted ✅',
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: _green,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    Text('Document Number:',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: const Color(0xFF6B7280))),
                    Text(doc.maskedNumber,
                        style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text('Extracted Content:',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: const Color(0xFF6B7280))),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(doc.rawContent,
                          style: GoogleFonts.outfit(fontSize: 13, height: 1.4)),
                    ),
                    if (doc.hasImage) ...[
                      const SizedBox(height: 14),
                      Text('Attached photo:',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: const Color(0xFF6B7280))),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          base64Decode(doc.imageBase64!),
                          width: double.infinity,
                          height: 180,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text(
                              'Attached photo could not be decoded.'),
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<bool>(
                      future: DocumentAgent.instance.hasPin(),
                      builder: (c, snap) {
                        final hasPin = snap.data ?? true;
                        return Text(
                          hasPin
                              ? 'Enter your security PIN to unlock:'
                              : 'Set a new security PIN (min 4 digits) to protect your documents:',
                          style: GoogleFonts.outfit(
                              fontSize: 13, color: const Color(0xFF4B5563)),
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 8),
                      decoration: const InputDecoration(
                        hintText: '••••',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ],
                ),
          actions: [
            if (unlocked) ...[
              TextButton(
                onPressed: () async {
                  await DocumentAgent.instance.deleteDocument(doc.id);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadDocuments();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Document deleted safely.')),
                    );
                  }
                },
                child: Text('Delete',
                    style: GoogleFonts.outfit(color: Colors.red)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx),
                child: Text('Close', style: GoogleFonts.outfit()),
              ),
            ] else ...[
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.outfit()),
              ),
              // Biometric unlock (fingerprint / face) — preferred for elderly users
              TextButton.icon(
                icon: const Icon(Icons.fingerprint, color: _green),
                label: Text('Fingerprint',
                    style: GoogleFonts.outfit(color: _green)),
                onPressed: () async {
                  final ok = await _biometricUnlock();
                  if (ok) {
                    setDialogState(() => unlocked = true);
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text('Biometric unavailable — use your PIN.')),
                    );
                  }
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _saffron, foregroundColor: Colors.white),
                onPressed: () async {
                  final entered = pinCtrl.text.trim();
                  final hasPin = await DocumentAgent.instance.hasPin();
                  if (!ctx.mounted) return;
                  if (!hasPin) {
                    // First-time setup: the entered PIN becomes the vault PIN.
                    try {
                      await DocumentAgent.instance.setPin(entered);
                      if (!ctx.mounted) return;
                      setDialogState(() => unlocked = true);
                    } catch (_) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                            content: Text('PIN must be at least 4 digits.')),
                      );
                    }
                    return;
                  }
                  final ok = await DocumentAgent.instance.verifyPin(entered);
                  if (!ctx.mounted) return;
                  if (ok) {
                    setDialogState(() => unlocked = true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('❌ Incorrect PIN.')),
                    );
                  }
                },
                child: Text('Unlock',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('My Secure Documents',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.shield_rounded,
                color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Protected badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_user, color: _green, size: 16),
                const SizedBox(width: 6),
                Text('AES-256 Hardware Encrypted Vault',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: _green,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _docs.isEmpty
                      ? Center(
                          child: Text(
                              'No documents stored yet.\nTap below to add your first document.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                  color: const Color(0xFF6B7280))),
                        )
                      : ListView.separated(
                          itemCount: _docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final d = _docs[i];
                            return GestureDetector(
                              onTap: () => _showViewDocumentDialog(d),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFE5E7EB)),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 8,
                                        offset: Offset(0, 2)),
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.credit_card_rounded,
                                        color: _green, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(d.title,
                                              style: GoogleFonts.outfit(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF111827))),
                                          Text(
                                              '${d.docType} • ${d.maskedNumber}',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  color:
                                                      const Color(0xFF4B5563))),
                                          const SizedBox(height: 4),
                                          Text('Tap to view (PIN protected)',
                                              style: GoogleFonts.outfit(
                                                  fontSize: 11,
                                                  color: _green,
                                                  fontWeight: FontWeight.w500)),
                                        ]),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text('Protected',
                                        style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            color: _green,
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_ios,
                                      size: 14, color: Color(0xFF9CA3AF)),
                                ]),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _saffron,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _showAddDocumentDialog,
                icon: const Icon(Icons.shield_outlined),
                label: Text('Add Encrypted Document',
                    style: GoogleFonts.outfit(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock, size: 12, color: Color(0xFF9CA3AF)),
                const SizedBox(width: 4),
                Text('Stored securely on this device  •  AES-256 Encrypted',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: const Color(0xFF9CA3AF))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
