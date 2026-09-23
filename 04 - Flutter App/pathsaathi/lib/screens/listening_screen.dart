import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../core/app_strings.dart';
import '../services/stt_service.dart';
import '../services/whisper_service.dart';
import '../services/connectivity_service.dart';
import '../services/tts_service.dart';
import '../services/destination_resolver.dart';
import '../providers/travel_context.dart';
import '../agents/agent_orchestrator.dart';
import '../core/nav_history.dart';

const _saffron = Color(0xFFFF6B00);
const _green = Color(0xFF1A6B3C);

class ListeningScreen extends ConsumerStatefulWidget {
  const ListeningScreen({super.key});

  @override
  ConsumerState<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends ConsumerState<ListeningScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late TextEditingController _textCtrl;

  String _transcript = '';
  String? _speechError;
  bool _isListening = false;
  bool _navigating = false;
  double _soundLevel = 0.0;
  double _lastConfidence = 1.0;
  bool _lowConfidence = false;
  String?
      _unresolvedQuery; // set when a destination request could not be resolved
  bool _unresolvedOffline = false;
  bool _usingWhisperFallback =
      false; // true while offline Whisper ASR is recording

  // Vernacular quick questions by language code
  static const Map<String, List<String>> _quickQuestions = {
    'hi': [
      'मेरी बस कहाँ है?',
      'बस कब आएगी?',
      'मेरा तंबू (कैंप) कहाँ है?',
      'डॉक्टर / अस्पताल कहाँ है?',
      'आज की आरती और स्नान का समय',
    ],
    'te': [
      'నా బస్ ఎక్కడ ఉంది?',
      'బస్ ఎప్పుడు వస్తుంది?',
      'నా క్యాంప్ ఎక్కడ ఉంది?',
      'వైద్య సహాయం / డాక్టర్ ఎక్కడ?',
      'ఈరోజు ప్రణాళిక సమయాలు',
    ],
    'en': [
      'Where is my bus?',
      'When is the bus?',
      'Where is my tent?',
      'Where is doctor / medical post?',
      'Today schedule & Snan time',
    ],
    'ta': [
      'என் பேருந்து எங்கே?',
      'பேருந்து எப்போது வரும்?',
      'என் முகாம் எங்கே?',
      'மருத்துவ உதவி எங்கே?',
      'இன்றைய அட்டவணை',
    ],
    'mr': [
      'माझी बस कुठे आहे?',
      'बस कधी येईल?',
      'माझा कॅम्प कुठे आहे?',
      'डॉक्टर / रुग्णालय कुठे आहे?',
      'आजचे वेळापत्रक',
    ],
    'pa': [
      'ਮੇਰੀ ਬੱਸ ਕਿੱਥੇ ਹੈ?',
      'ਬੱਸ ਕਦੋਂ ਆਵੇਗੀ?',
      'ਮੇਰਾ ਕੈਂਪ ਕਿੱਥੇ ਹੈ?',
      'ਡਾਕਟਰ ਕਿੱਥੇ ਹੈ?',
      'ਅੱਜ ਦਾ ਸ਼ਡਿਊਲ',
    ],
  };

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _startListening();
  }

  Future<void> _startListening() async {
    final langCode = ref.read(languageProvider).code;
    final stt = STTService.instance;

    // Ensure no TTS is playing — TTS output and the mic cannot run together,
    // or recognition is cut off the moment it starts.
    await TTSService.instance.stop();

    setState(() {
      _speechError = null;
      _isListening = true;
      _lowConfidence = false;
      _lastConfidence = 1.0;
      _unresolvedQuery = null;
      _unresolvedOffline = false;
      _usingWhisperFallback = false;
    });

    // OFFLINE-FIRST VOICE: if the device is offline and a real on-device Whisper
    // model is present, use it directly — it's fully self-contained and doesn't
    // depend on any Google voice pack. This is the most reliable offline route.
    final offline =
        ConnectivityService.instance.status == ConnectivityStatus.offline;
    if (offline && WhisperService.instance.isModelReady) {
      setState(() => _usingWhisperFallback = true);
      final text =
          await WhisperService.instance.transcribeFromMic(langCode: langCode);
      if (!mounted) return;
      setState(() {
        _usingWhisperFallback = false;
        _isListening = false;
      });
      if (text.trim().isNotEmpty) {
        setState(() => _transcript = text.trim());
        _submitQuery(text.trim());
      } else {
        setState(() => _speechError =
            'Did not catch that. Please try again or type your request below.');
      }
      return;
    }

    final ok = await stt.initialize();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _isListening = false;
        _speechError =
            stt.lastError.isNotEmpty ? stt.lastError : 'Microphone not ready';
      });
      return;
    }

    await stt.startListening(
      langCode: langCode,
      onConfidence: (c) {
        if (!mounted) return;
        setState(() => _lastConfidence = c);
      },
      onResult: (words, isFinal) {
        if (!mounted) return;
        if (words.isNotEmpty) {
          setState(() {
            _transcript = words;
            _speechError = null;
          });
        }
        if (isFinal && words.isNotEmpty && !_navigating) {
          // NOISE ROBUSTNESS: if the recognizer is unsure (common in loud crowds),
          // do NOT act automatically — show the transcript and let the user
          // confirm, retry, or pick a quick question instead.
          if (_lastConfidence < 0.55) {
            setState(() => _lowConfidence = true);
          } else {
            _submitQuery(words);
          }
        }
      },
      onSoundLevel: (level) {
        if (!mounted) return;
        setState(() => _soundLevel = level);
      },
      onError: (errorMsg) async {
        if (!mounted) return;
        // The platform recognizer failed (e.g. no offline voice pack, or the
        // device is offline). If a real on-device Whisper model is present, use
        // it as a genuine offline ASR fallback: record → transcribe.
        if (WhisperService.instance.isModelReady && !_navigating) {
          setState(() {
            _speechError = null;
            _usingWhisperFallback = true;
          });
          final text = await WhisperService.instance
              .transcribeFromMic(langCode: langCode);
          if (!mounted) return;
          setState(() {
            _usingWhisperFallback = false;
            _isListening = false;
          });
          if (text.trim().isNotEmpty) {
            setState(() => _transcript = text.trim());
            _submitQuery(text.trim());
            return;
          }
        }
        setState(() {
          _isListening = false;
          _speechError = errorMsg;
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
        }
      },
    );
  }

  /// Submit a query to the pipeline.
  ///
  /// [fromVoiceOrText] = true for free voice/typed input (the user is naming a
  /// destination). If such input does NOT resolve to a real place, we show a
  /// truthful "couldn't understand" retry — we do NOT fall through to the agent
  /// swarm, because that fabricates a default Prayagraj/Sangam route (the P1
  /// regression seen with garbled Whisper output like "ndu ke darnaad...").
  ///
  /// Only the curated quick-question chips (known non-destination advisory
  /// queries) pass [fromVoiceOrText] = false to reach the agent swarm.
  void _submitQuery(String query, {bool fromVoiceOrText = true}) {
    if (_navigating || !mounted) return;
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return;

    _navigating = true;
    STTService.instance.stop();

    setState(() => _transcript = cleanQuery);

    // ── DESTINATION RESOLUTION PIPELINE (provider-based, not a fixed list) ──
    final result = DestinationResolutionService.instance.resolve(cleanQuery);

    if (result.isResolved) {
      // Resolved to a canonical Place → hold as PENDING and confirm. No default.
      ref
          .read(travelContextProvider.notifier)
          .proposeDestination(result.place!);
      context.go('/confirm');
      return;
    }

    // Unresolved. For voice/typed input OR anything that looks like a
    // destination request, show the truthful retry. This is the hard gate that
    // stops garbled ASR / unknown places from reaching the orchestrator's
    // default transport response (no Prayagraj/Sangam fabrication, ever).
    if (_looksLikeDestinationRequest(cleanQuery)) {
      _navigating = false;
      if (!mounted) return;
      setState(() {
        _unresolvedQuery = result.query.isNotEmpty ? result.query : cleanQuery;
        _unresolvedOffline = result.kind == ResolutionKind.unavailableOffline;
      });
      return;
    }

    // Any natural-language question is sent to the companion/agent pipeline.
    // Destination requests remain behind the confirmation gate above.
    ref.read(orchestratorProvider.notifier).processUserQuery(cleanQuery);
    context.go('/confirm');
  }

  /// Heuristic: did the user try to name a place to go to? Uses travel-intent
  /// cue words across languages. Non-destination agent queries (bus/hospital/
  /// schedule) intentionally do NOT match, so they still reach the agent swarm.
  bool _looksLikeDestinationRequest(String q) {
    final s = q.toLowerCase();
    const cues = [
      'go to',
      'want to go',
      'take me to',
      'reach',
      'travel to',
      'navigate to',
      'जाना',
      'जाना है',
      'पहुंच',
      'पहुँच',
      'ले चलो',
      'వెళ్లాలి',
      'వెళ్ళాలి',
      'తీసుకెళ్లు',
      'వెళ్ళాలనుకుంటున్నా',
      'செல்ல',
      'போக',
    ];
    return cues.any((c) => s.contains(c));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    STTService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    final questions = _quickQuestions[lang] ?? _quickQuestions['en']!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B12), // Deep dark green background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const SizedBox(height: 12),

            // Top Status Bar
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white70, size: 20),
                onPressed: () => smartBack(context),
              ),
              const Spacer(),
              Row(children: [
                _isListening
                    ? _BlinkingDot()
                    : const Icon(Icons.mic_off,
                        color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Text(
                  _isListening ? AppStrings.listening(lang) : 'Voice Ready',
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      color: Colors.white,
                      fontWeight: FontWeight.w700),
                ),
              ]),
              const Spacer(),
              const SizedBox(width: 40),
            ]),

            const SizedBox(height: 14),

            // Pulsing Mic Circle Button with Live Sound Reaction
            GestureDetector(
              onTap: () {
                if (_transcript.isNotEmpty) {
                  _submitQuery(_transcript);
                } else {
                  _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) {
                  final soundScale =
                      (_soundLevel.clamp(0.0, 10.0) / 10.0) * 0.15;
                  final totalScale =
                      _isListening ? (_pulseAnim.value + soundScale) : 1.0;
                  return Transform.scale(
                    scale: totalScale,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [_saffron, Color(0xFFCC5500)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _saffron.withValues(
                                alpha: _isListening ? 0.55 : 0.25),
                            blurRadius: _isListening ? 28 : 12,
                            spreadRadius: _isListening ? 6 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // Animated Mic Waveform Bars (React to Voice Sound Level)
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(7, (i) {
                  final baseHeights = [10.0, 16.0, 22.0, 18.0, 24.0, 14.0, 8.0];
                  final soundMultiplier = _isListening
                      ? (1.0 + (_soundLevel.clamp(0.0, 10.0) / 2.5))
                      : 0.5;
                  final height =
                      (baseHeights[i] * soundMultiplier).clamp(4.0, 24.0);
                  return Container(
                    width: 4,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    decoration: BoxDecoration(
                      color: _isListening ? _saffron : Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 10),

            // Transcript Box / Status & Guidance
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _speechError != null
                      ? Colors.amber.shade700
                      : Colors.white24,
                ),
              ),
              child: Column(children: [
                Text(
                  _transcript.isNotEmpty
                      ? '"$_transcript"'
                      : (_speechError != null
                          ? _errorMessageForLang(lang)
                          : '"Speak now in ${_langName(lang)}..."'),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: _transcript.isNotEmpty
                        ? Colors.white
                        : (_speechError != null
                            ? const Color(0xFFFDE68A)
                            : Colors.white70),
                    fontWeight: _transcript.isNotEmpty
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontStyle: _transcript.isNotEmpty
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🎙 ${_langName(lang)} Active',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: _green,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.push('/model-setup'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: WhisperService.instance.isModelReady
                              ? _green
                              : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              WhisperService.instance.isModelReady
                                  ? Icons.memory
                                  : Icons.cloud_outlined,
                              size: 11,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              WhisperService.instance.isModelReady
                                  ? 'Whisper Offline'
                                  : 'Android STT',
                              style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 12),

            // ── Enable offline voice prompt (shown after a voice failure when
            //    no on-device Whisper model is present yet). One-time download. ──
            if (_speechError != null && !WhisperService.instance.isModelReady)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2563EB)),
                ),
                child: Column(children: [
                  Text(
                    'Enable offline voice: download the on-device voice model once '
                    '(needs internet this one time). After that, voice works fully offline.',
                    style: GoogleFonts.outfit(
                        fontSize: 12.5, color: const Color(0xFF1E3A8A)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white),
                      onPressed: () => context.push('/model-setup'),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text('Download offline voice',
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),

            // ── Low-confidence "Did I hear right?" prompt (noisy places) ──
            if (_lowConfidence && _transcript.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(children: [
                  Text('It is noisy here — did I hear you correctly?',
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF92400E)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text('"$_transcript"',
                      style: GoogleFonts.outfit(
                          fontSize: 14, color: const Color(0xFF111827)),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white),
                        onPressed: () => _submitQuery(_transcript),
                        child: Text('Yes ✓',
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _lowConfidence = false;
                            _transcript = '';
                          });
                          _startListening();
                        },
                        child: Text('No, retry', style: GoogleFonts.outfit()),
                      ),
                    ),
                  ]),
                ]),
              ),

            // ── Offline Whisper ASR fallback indicator (truthful) ─────────
            if (_usingWhisperFallback)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF2563EB)),
                ),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text('Listening offline (on-device Whisper)…',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: const Color(0xFF1E3A8A))),
                ]),
              ),

            // ── Unresolved destination (truthful, no fabricated fallback) ──
            if (_unresolvedQuery != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDC2626)),
                ),
                child: Column(children: [
                  Text(
                    _unresolvedOffline
                        ? 'Could not find "${_unresolvedQuery!}" in offline data. Connect to the internet to search more places, or try a nearby known place.'
                        : 'Could not find the place "${_unresolvedQuery!}". Please say the destination name again clearly.',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: const Color(0xFF991B1B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _saffron,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        setState(() {
                          _unresolvedQuery = null;
                          _transcript = '';
                        });
                        _startListening();
                      },
                      child: Text('Try again',
                          style:
                              GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),

            // ── Instant Vernacular Search / Text Query Input ─────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.edit_note, color: Colors.white60, size: 22),
                ),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    style:
                        GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Type query in ${_langName(lang)} or English...',
                      hintStyle: GoogleFonts.outfit(
                          color: Colors.white38, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                    ),
                    onSubmitted: _submitQuery,
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.send_rounded, color: _saffron, size: 20),
                  onPressed: () {
                    if (_textCtrl.text.trim().isNotEmpty) {
                      _submitQuery(_textCtrl.text);
                    }
                  },
                ),
              ]),
            ),

            const SizedBox(height: 10),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Or tap any quick question:',
                style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 6),

            // ── Vernacular Quick Question Chips List ─────────────────────
            Expanded(
              child: ListView.separated(
                itemCount: questions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (ctx, i) {
                  final q = questions[i];
                  return InkWell(
                    // Curated advisory chips are trusted non-destination queries
                    // → allowed to reach the agent swarm if they don't resolve.
                    onTap: () => _submitQuery(q, fromVoiceOrText: false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.touch_app_outlined,
                            color: _saffron, size: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            q,
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios,
                            color: Colors.white38, size: 11),
                      ]),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Confirm / Cancel Button
            if (_transcript.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saffron,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => _submitQuery(_transcript),
                  icon: const Icon(Icons.check, size: 20),
                  label: Text('Confirm Voice Query →',
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => context.go('/home'),
                  child:
                      Text('Cancel', style: GoogleFonts.outfit(fontSize: 14)),
                ),
              ),

            const SizedBox(height: 12),
          ]),
        ),
      ),
    );
  }

  static String _errorMessageForLang(String code) {
    switch (code) {
      case 'te':
        return 'ఆఫ్‌లైన్ వాయిస్ గుర్తించబడలేదు. క్రింది ప్రశ్నను ఎంచుకోండి లేదా టైప్ చేయండి:';
      case 'hi':
        return 'आवाज़ नहीं सुनी जा सकी। कृपया नीचे दिया गया प्रश्न चुनें या टाइप करें:';
      case 'ta':
        return 'குரல் கேட்கவில்லை. கீழே உள்ள கேள்வியைத் தட்டவும் அல்லது தட்டச்சு செய்யவும்:';
      case 'mr':
        return 'आवाज ऐकू आला नाही. खालील प्रश्न निवडा किंवा टाइप करा:';
      case 'pa':
        return 'ਆਵਾਜ਼ ਨਹੀਂ ਸੁਣੀ ਗਈ। ਹੇਠਾਂ ਦਿੱਤਾ ਸਵਾਲ ਚੁਣੋ ਜਾਂ ਟਾਈਪ ਕਰੋ:';
      default:
        return 'Voice not detected. Tap a question below or type your query:';
    }
  }

  static String _langName(String code) {
    const names = {
      'en': 'English',
      'hi': 'हिंदी',
      'te': 'తెలుగు',
      'ta': 'தமிழ்',
      'pa': 'ਪੰਜਾਬੀ',
      'mr': 'मराठी',
    };
    return names[code] ?? 'English';
  }
}

class _BlinkingDot extends StatefulWidget {
  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
            color: Colors.redAccent, shape: BoxShape.circle),
      ),
    );
  }
}
