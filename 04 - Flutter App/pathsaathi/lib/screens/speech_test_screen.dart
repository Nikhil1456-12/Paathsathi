import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

// ── 20 Test Phrases ────────────────────────────────────────────────────────
const _testPhrases = [
  // English (1-5)
  ('en-US', 'en', 'Bus 47 departs at 6 AM from Platform Gate 3.'),
  ('en-US', 'en', 'Your accommodation is at Sector 5 camp near the Ghats.'),
  ('en-US', 'en', 'Emergency services are available at Gate 12.'),
  ('en-US', 'en', 'Next train to Prayagraj leaves in 30 minutes.'),
  ('en-US', 'en', 'Weather is clear. Safe for your pilgrimage today.'),
  // Hindi (6-10)
  ('hi-IN', 'hi', 'बस 47 सुबह 6 बजे प्लेटफॉर्म 3 से निकलती है।'),
  ('hi-IN', 'hi', 'आपका आवास सेक्टर 5 शिविर में है।'),
  ('hi-IN', 'hi', 'आपातकालीन सेवाएं गेट 12 पर उपलब्ध हैं।'),
  ('hi-IN', 'hi', 'प्रयागराज की अगली ट्रेन 30 मिनट में है।'),
  ('hi-IN', 'hi', 'मौसम साफ है। यात्रा के लिए बिल्कुल सुरक्षित है।'),
  // Telugu (11-15)
  ('te-IN', 'te', 'బస్ 47 తెల్లవారు 6 గంటలకు గేట్ 3 నుండి బయలుదేరుతుంది.'),
  ('te-IN', 'te', 'మీ వసతి సెక్టార్ 5 క్యాంప్‌లో ఉంది.'),
  ('te-IN', 'te', 'అత్యవసర సేవలు గేట్ 12 వద్ద అందుబాటులో ఉన్నాయి.'),
  ('te-IN', 'te', 'ప్రయాగ్‌రాజ్‌కు తదుపరి రైలు 30 నిమిషాల్లో వస్తుంది.'),
  ('te-IN', 'te', 'వాతావరణం స్పష్టంగా ఉంది. ప్రయాణానికి సురక్షితం.'),
  // Tamil (16-18)
  ('ta-IN', 'ta', 'பஸ் 47 காலை 6 மணிக்கு கேட் 3 இல் இருந்து புறப்படுகிறது.'),
  ('ta-IN', 'ta', 'உங்கள் தங்குமிடம் பிரிவு 5 முகாமில் உள்ளது.'),
  ('ta-IN', 'ta', 'வானிலை தெளிவாக உள்ளது. பயணத்திற்கு பாதுகாப்பானது.'),
  // Marathi (19-20)
  ('mr-IN', 'mr', 'बस 47 सकाळी 6 वाजता गेट 3 वरून निघते.'),
  ('mr-IN', 'mr', 'हवामान स्वच्छ आहे. प्रवासासाठी सुरक्षित आहे.'),
];

const _langFlag = {
  'en': '🇺🇸', 'hi': '🇮🇳', 'te': '🔵', 'ta': '🟡', 'pa': '🟠', 'mr': '🟤',
};

enum _Status { pending, running, pass, fail }

class SpeechTestScreen extends StatefulWidget {
  const SpeechTestScreen({super.key});
  @override
  State<SpeechTestScreen> createState() => _State();
}

class _State extends State<SpeechTestScreen> {
  final _tts = FlutterTts();
  final _stt = SpeechToText();

  bool _ttsRunning = false;
  bool _sttRunning = false;
  bool _sttReady = false;
  int _currentTTSIndex = -1;
  List<_Status> _ttsStatus = List.filled(20, _Status.pending);

  // TTS diagnostics
  List<String> _availableLangs = [];
  String _engineInfo = '';

  // STT diagnostics
  String _sttTranscript = '';
  List<String> _availableLocales = [];
  bool _sttChecked = false;

  @override
  void initState() {
    super.initState();
    _probeTTS();
    _probeSTT();
  }

  // ── Probe TTS engine ────────────────────────────────────────────────────
  Future<void> _probeTTS() async {
    try {
      final engines = await _tts.getEngines;
      final langs   = await _tts.getLanguages;
      setState(() {
        _engineInfo = (engines as List).join(', ');
        _availableLangs = (langs as List).cast<String>()..sort();
      });
    } catch (e) {
      setState(() => _engineInfo = 'Error: $e');
    }
  }

  // ── Probe STT ───────────────────────────────────────────────────────────
  Future<void> _probeSTT() async {
    final ok = await _stt.initialize();
    if (ok) {
      final locales = await _stt.locales();
      setState(() {
        _sttReady = true;
        _availableLocales = locales.map((l) => '${l.localeId} (${l.name})').toList()..sort();
        _sttChecked = true;
      });
    } else {
      setState(() { _sttReady = false; _sttChecked = true; });
    }
  }

  // ── Run all 20 TTS tests ────────────────────────────────────────────────
  Future<void> _runAllTTS() async {
    setState(() {
      _ttsRunning = true;
      _ttsStatus = List.filled(20, _Status.pending);
    });

    // Setup TTS — NO engine override, let device pick best
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    for (int i = 0; i < _testPhrases.length; i++) {
      if (!mounted) break;
      final (locale, _, text) = _testPhrases[i];
      setState(() {
        _currentTTSIndex = i;
        _ttsStatus[i] = _Status.running;
      });

      try {
        final langResult = await _tts.setLanguage(locale);
        if (langResult != 1) throw Exception('Language $locale not supported');

        final completer = Future<void>.delayed(const Duration(seconds: 6));
        _tts.setCompletionHandler(() {});
        await _tts.speak(text);
        await completer;

        setState(() => _ttsStatus[i] = _Status.pass);
      } catch (e) {
        setState(() => _ttsStatus[i] = _Status.fail);
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    setState(() { _ttsRunning = false; _currentTTSIndex = -1; });
  }

  // ── Test single TTS phrase ──────────────────────────────────────────────
  Future<void> _testSingleTTS(int i) async {
    final (locale, _, text) = _testPhrases[i];
    setState(() => _ttsStatus[i] = _Status.running);
    try {
      await _tts.setLanguage(locale);
      await _tts.speak(text);
      await Future.delayed(const Duration(seconds: 4));
      setState(() => _ttsStatus[i] = _Status.pass);
    } catch (e) {
      setState(() => _ttsStatus[i] = _Status.fail);
    }
  }

  // ── STT test ────────────────────────────────────────────────────────────
  Future<void> _testSTT(String locale) async {
    if (!_sttReady) { await _probeSTT(); return; }
    setState(() { _sttRunning = true; _sttTranscript = ''; });

    await _stt.listen(
      localeId: locale,
      onResult: (r) {
        setState(() => _sttTranscript = r.recognizedWords);
        if (r.finalResult) setState(() => _sttRunning = false);
      },
      cancelOnError: true,
      partialResults: true,
      listenMode: ListenMode.confirmation,
    );

    await Future.delayed(const Duration(seconds: 8));
    await _stt.stop();
    setState(() => _sttRunning = false);
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passCount = _ttsStatus.where((s) => s == _Status.pass).length;
    final failCount = _ttsStatus.where((s) => s == _Status.fail).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => smartBack(context),
        ),
        title: Text('🧪 STT + TTS Test Lab', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [

        // ── TTS ENGINE INFO ───────────────────────────────────────────────
        _section('🔊 TTS Engine Diagnostics'),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Engines: $_engineInfo',
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF374151))),
          const SizedBox(height: 6),
          Text('Available languages (${_availableLangs.length} total):',
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4,
            children: ['hi-IN','te-IN','ta-IN','pa-IN','mr-IN','en-US'].map((l) {
              final have = _availableLangs.any((al) => al.startsWith(l.split('-')[0]));
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: have ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8)),
                child: Text('$l ${have ? "✅" : "❌"}',
                  style: GoogleFonts.outfit(fontSize: 11,
                    color: have ? _green : const Color(0xFFDC2626))),
              );
            }).toList()),
        ])),

        // ── STT DIAGNOSTICS ───────────────────────────────────────────────
        _section('🎙️ STT Diagnostics'),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(_sttReady ? Icons.check_circle : Icons.cancel,
              color: _sttReady ? _green : Colors.red, size: 18),
            const SizedBox(width: 8),
            Text(_sttChecked
              ? (_sttReady ? 'STT ready (${_availableLocales.length} locales)' : 'STT NOT available on this device')
              : 'Checking STT...',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          if (_sttReady) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4,
              children: ['hi-IN','te-IN','ta-IN','pa-IN','mr-IN','en-US'].map((l) {
                final have = _availableLocales.any((al) => al.startsWith(l));
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: have ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('$l ${have ? "✅" : "⚠️"}',
                    style: GoogleFonts.outfit(fontSize: 11,
                      color: have ? _green : const Color(0xFFD97706))),
                );
              }).toList()),
          ],
        ])),

        // ── STT LIVE TEST ─────────────────────────────────────────────────
        _section('🎙️ STT Live Test'),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tap a language → speak → see transcript:',
            style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF6B7280))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8,
            children: [
              ('en-US','English'), ('hi-IN','हिंदी'),
              ('te-IN','తెలుగు'), ('ta-IN','தமிழ்'), ('mr-IN','मराठी'),
            ].map((l) => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _sttRunning ? Colors.grey : _green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: _sttRunning ? null : () => _testSTT(l.$1),
              child: Text(l.$2, style: GoogleFonts.outfit(fontSize: 12)),
            )).toList()),
          const SizedBox(height: 12),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _sttRunning ? _saffron : const Color(0xFFE5E7EB),
                width: _sttRunning ? 2 : 1)),
            child: Text(
              _sttRunning
                ? (_sttTranscript.isEmpty ? '🎙️ Listening... speak now' : _sttTranscript)
                : (_sttTranscript.isEmpty ? 'Tap a language above to start' : '✅ "$_sttTranscript"'),
              style: GoogleFonts.outfit(fontSize: 15,
                color: _sttTranscript.isEmpty ? const Color(0xFF9CA3AF) : const Color(0xFF111827)),
              textAlign: TextAlign.center),
          ),
          if (_sttRunning) ...[
            const SizedBox(height: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              onPressed: () async { await _stt.stop(); setState(() => _sttRunning = false); },
              child: Text('Stop Listening', style: GoogleFonts.outfit(fontSize: 13))),
          ],
        ])),

        // ── TTS 20 TESTS ──────────────────────────────────────────────────
        _section('🔊 TTS — 20 Test Phrases'),
        if (passCount > 0 || failCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              _badge('✅ $passCount passed', const Color(0xFFDCFCE7), _green),
              const SizedBox(width: 8),
              if (failCount > 0) _badge('❌ $failCount failed', const Color(0xFFFEE2E2), Colors.red),
            ]),
          ),
        SizedBox(width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ttsRunning ? Colors.grey : _saffron,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _ttsRunning ? null : _runAllTTS,
            icon: Icon(_ttsRunning ? Icons.hourglass_empty : Icons.play_arrow_rounded),
            label: Text(
              _ttsRunning ? 'Running test ${_currentTTSIndex + 1}/20...' : '▶ Run All 20 TTS Tests',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),

        // Individual test rows
        ..._testPhrases.asMap().entries.map((e) {
          final i = e.key;
          final (locale, lang, text) = e.value;
          final status = _ttsStatus[i];
          final isActive = _currentTTSIndex == i;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? _saffron :
                  status == _Status.pass ? _green :
                  status == _Status.fail ? Colors.red :
                  const Color(0xFFE5E7EB),
                width: isActive ? 2 : 1),
            ),
            child: ListTile(
              dense: true,
              leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_langFlag[lang] ?? '🌐', style: const TextStyle(fontSize: 18)),
                Text(locale.split('-')[0], style: GoogleFonts.outfit(fontSize: 9, color: const Color(0xFF9CA3AF))),
              ]),
              title: Text(text, style: GoogleFonts.outfit(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _statusIcon(status),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.play_circle_outline, size: 20, color: _green),
                  onPressed: _ttsRunning ? null : () => _testSingleTTS(i),
                  padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),
          );
        }),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
    child: Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF111827))));

  Widget _card(Widget child) => Container(
    width: double.infinity, padding: const EdgeInsets.all(14),
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE5E7EB))),
    child: child);

  Widget _badge(String text, Color bg, Color fg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: GoogleFonts.outfit(fontSize: 12, color: fg, fontWeight: FontWeight.w600)));

  Widget _statusIcon(_Status s) {
    switch (s) {
      case _Status.pass: return const Icon(Icons.check_circle, color: _green, size: 18);
      case _Status.fail: return const Icon(Icons.cancel, color: Colors.red, size: 18);
      case _Status.running: return const SizedBox(width: 18, height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: _saffron));
      case _Status.pending: return const Icon(Icons.radio_button_unchecked, color: Color(0xFFD1D5DB), size: 18);
    }
  }
}
