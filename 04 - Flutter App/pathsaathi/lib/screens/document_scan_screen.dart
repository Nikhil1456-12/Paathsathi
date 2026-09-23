import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/profile_service.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class DocumentScanScreen extends StatelessWidget {
  const DocumentScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('Scan your Document', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document type selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: _green),
                    const SizedBox(width: 12),
                    Text('Aadhaar Card', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.keyboard_arrow_down, color: Color(0xFF9CA3AF)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Camera preview
              Container(
                width: double.infinity, height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E), borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    // Corner brackets
                    ...[ Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight]
                        .map((a) => Align(alignment: a, child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _cornerBracket(a),
                        ))),
                    Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 40),
                        const SizedBox(height: 8),
                        Text('Position document in frame', style: GoogleFonts.outfit(fontSize: 13, color: Colors.white54)),
                      ],
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Checklist
              ...[
                ('Front side scanned', true),
                ('Back side scanned', true),
                ('Data extracted', true),
              ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 22, height: 22,
                    decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 14)),
                  const SizedBox(width: 12),
                  Text(item.$1, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500)),
                ]),
              )),
              const SizedBox(height: 16),
              // Extracted data card
              Container(
                width: double.infinity, padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Extracted Data', style: GoogleFonts.outfit(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ...['Name: XXXX XXXX', 'DOB: XX/XX/XXXX', 'Gender: X', 'XXXX XXXX 1234'].map(
                      (t) => Padding(padding: const EdgeInsets.only(bottom: 4),
                        child: Text(t, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF111827))))),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _saffron, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    // Onboarding chain complete → remember it so the splash
                    // gate sends the user straight to home next time.
                    await ProfileService.instance.markOnboardingDone();
                    if (context.mounted) context.go('/home');
                  },
                  child: Text('Next  →', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cornerBracket(Alignment a) {
    final isTop = a == Alignment.topLeft || a == Alignment.topRight;
    final isLeft = a == Alignment.topLeft || a == Alignment.bottomLeft;
    return SizedBox(width: 24, height: 24,
      child: CustomPaint(painter: _BracketPainter(isTop: isTop, isLeft: isLeft)));
  }
}

class _BracketPainter extends CustomPainter {
  final bool isTop, isLeft;
  const _BracketPainter({required this.isTop, required this.isLeft});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = _saffron..strokeWidth = 3..style = PaintingStyle.stroke;
    final path = Path();
    if (isTop && isLeft) { path.moveTo(0, size.height); path.lineTo(0, 0); path.lineTo(size.width, 0); }
    else if (isTop && !isLeft) { path.moveTo(0, 0); path.lineTo(size.width, 0); path.lineTo(size.width, size.height); }
    else if (!isTop && isLeft) { path.moveTo(0, 0); path.lineTo(0, size.height); path.lineTo(size.width, size.height); }
    else { path.moveTo(0, size.height); path.lineTo(size.width, size.height); path.lineTo(size.width, 0); }
    canvas.drawPath(path, p);
  }
  @override bool shouldRepaint(_) => false;
}
