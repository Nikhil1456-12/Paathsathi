import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../agents/agent_orchestrator.dart';
import '../providers/language_provider.dart';
import '../services/tts_service.dart';
import '../core/nav_history.dart';

const _green = Color(0xFF1A6B3C);

/// Emergency screen — the highest-stakes screen for elderly/panicking pilgrims.
///
/// Every action here WORKS:
///   • Tapping an emergency type routes the query through the agent swarm and
///     immediately speaks the guidance aloud (offline TTS).
///   • The call buttons actually open the phone dialer (tel:) for 108/112/1090.
///   • On open, the screen speaks a short "stay calm, help is available" prompt.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  @override
  void initState() {
    super.initState();
    // Speak a calming prompt aloud the moment the screen opens — critical for
    // users who cannot read and may be in distress.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakIntro());
  }

  Future<void> _speakIntro() async {
    final lang = ref.read(languageProvider).code;
    await TTSService.instance.initialize(langCode: lang);
    await TTSService.instance.speak(_introText(lang));
  }

  @override
  void dispose() {
    TTSService.instance.stop();
    super.dispose();
  }

  /// Launches the device dialer with the given emergency number.
  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _snack('Could not open dialer. Please dial $number manually.');
      }
    } catch (_) {
      _snack('Could not open dialer. Please dial $number manually.');
    }
  }

  /// Routes an emergency intent through the agent swarm, speaks the response,
  /// and opens the AI response screen with map + guidance.
  Future<void> _triggerEmergency(String query, String number) async {
    // Speak immediately so users get audio confirmation the tap registered.
    final lang = ref.read(languageProvider).code;
    await TTSService.instance.initialize(langCode: lang);

    // Process through the orchestrator (Cache tier answers SOS/medical <1ms).
    await ref.read(orchestratorProvider.notifier).processUserQuery(query);
    final resp = ref.read(orchestratorProvider).latestResponse;
    if (resp != null) {
      await TTSService.instance.speak(resp.getSpokenText(lang));
    }
    if (mounted) context.push('/ai-response');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF1F1),
      body: SafeArea(
        child: Column(children: [
          // Red header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: const BoxDecoration(color: Color(0xFFDC2626)),
            child: Row(children: [
              IconButton(
                  onPressed: () {
                    TTSService.instance.stop();
                    smartBack(context);
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('🚨 EMERGENCY',
                      style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(_whatHappened(lang),
                      style: GoogleFonts.outfit(fontSize: 14, color: Colors.white70)),
                ]),
              ),
              // Speak the whole screen aloud
              IconButton(
                tooltip: 'Read aloud',
                onPressed: _speakIntro,
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                const SizedBox(height: 8),
                _eCard(const Color(0xFFDC2626), Icons.local_hospital,
                    _medical(lang), _medicalSub(lang),
                    onTap: () => _triggerEmergency('medical emergency doctor help', '108')),
                const SizedBox(height: 12),
                _eCard(const Color(0xFFEA580C), Icons.person_search,
                    _lostPerson(lang), _lostPersonSub(lang),
                    onTap: () => _triggerEmergency('lost person missing child', '1090')),
                const SizedBox(height: 12),
                _eCard(const Color(0xFFD97706), Icons.location_off,
                    _imLost(lang), _imLostSub(lang),
                    onTap: () => _triggerEmergency('i am lost help me find my way', '1090')),
                const SizedBox(height: 12),
                _eCard(const Color(0xFF2563EB), Icons.shield_outlined,
                    _safety(lang), _safetySub(lang),
                    onTap: () => _triggerEmergency('police safety help emergency', '112')),
                const SizedBox(height: 24),

                // Mesh info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(14)),
                  child: Row(children: [
                    const Icon(Icons.bluetooth, color: _green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_meshInfo(lang),
                            style: GoogleFonts.outfit(fontSize: 13, color: _green))),
                  ]),
                ),
                const SizedBox(height: 16),

                // Real call buttons for the key national helplines
                Row(children: [
                  Expanded(child: _callBtn('🚑 108', 'Ambulance', '108')),
                  const SizedBox(width: 10),
                  Expanded(child: _callBtn('🚓 112', 'Police', '112')),
                  const SizedBox(width: 10),
                  Expanded(child: _callBtn('🧒 1090', 'Lost & Found', '1090')),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _callBtn(String big, String label, String number) => SizedBox(
        height: 62,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFDC2626),
            side: const BorderSide(color: Color(0xFFDC2626), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: EdgeInsets.zero,
          ),
          onPressed: () => _call(number),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(big, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800)),
            Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w500)),
          ]),
        ),
      );

  Widget _eCard(Color color, IconData icon, String title, String sub,
          {required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(sub, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white70)),
            ])),
            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
          ]),
        ),
      );

  // ── Localized strings ─────────────────────────────────────────────────────
  static String _introText(String l) {
    const t = {
      'en': 'Stay calm. Help is available. Tap the type of emergency, or tap a number to call for help.',
      'hi': 'शांत रहें। मदद उपलब्ध है। आपातकाल का प्रकार चुनें, या कॉल करने के लिए नंबर दबाएं।',
      'te': 'ప్రశాంతంగా ఉండండి. సహాయం అందుబాటులో ఉంది. అత్యవసర రకాన్ని నొక్కండి లేదా కాల్ చేయడానికి నంబర్ నొక్కండి.',
      'ta': 'அமைதியாக இருங்கள். உதவி கிடைக்கும். அவசர வகையைத் தட்டவும் அல்லது அழைக்க எண்ணைத் தட்டவும்.',
      'pa': 'ਸ਼ਾਂਤ ਰਹੋ। ਮਦਦ ਉਪਲਬਧ ਹੈ। ਐਮਰਜੈਂਸੀ ਦੀ ਕਿਸਮ ਚੁਣੋ ਜਾਂ ਕਾਲ ਕਰਨ ਲਈ ਨੰਬਰ ਦਬਾਓ।',
      'mr': 'शांत राहा. मदत उपलब्ध आहे. आणीबाणीचा प्रकार निवडा किंवा कॉल करण्यासाठी नंबर दाबा.',
    };
    return t[l] ?? t['en']!;
  }

  static String _whatHappened(String l) => const {
        'en': 'What happened?', 'hi': 'क्या हुआ?', 'te': 'ఏమి జరిగింది?',
        'ta': 'என்ன நடந்தது?', 'pa': 'ਕੀ ਹੋਇਆ?', 'mr': 'काय झाले?'
      }[l] ?? 'What happened?';

  static String _medical(String l) => const {
        'en': 'Medical Emergency', 'hi': 'चिकित्सा आपातकाल', 'te': 'వైద్య అత్యవసరం',
        'ta': 'மருத்துவ அவசரம்', 'pa': 'ਮੈਡੀਕਲ ਐਮਰਜੈਂਸੀ', 'mr': 'वैद्यकीय आणीबाणी'
      }[l] ?? 'Medical Emergency';
  static String _medicalSub(String l) => const {
        'en': 'Ambulance & first aid', 'hi': 'एम्बुलेंस और प्राथमिक उपचार',
        'te': 'అంబులెన్స్ & ప్రథమ చికిత్స', 'ta': 'ஆம்புலன்ஸ் & முதலுதவி',
        'pa': 'ਐਂਬੂਲੈਂਸ ਤੇ ਮੁੱਢਲੀ ਸਹਾਇਤਾ', 'mr': 'रुग्णवाहिका आणि प्रथमोपचार'
      }[l] ?? 'Ambulance & first aid';

  static String _lostPerson(String l) => const {
        'en': 'Lost Person', 'hi': 'खोया व्यक्ति', 'te': 'తప్పిపోయిన వ్యక్తి',
        'ta': 'தொலைந்த நபர்', 'pa': 'ਗੁੰਮ ਵਿਅਕਤੀ', 'mr': 'हरवलेली व्यक्ती'
      }[l] ?? 'Lost Person';
  static String _lostPersonSub(String l) => const {
        'en': 'Report a missing person', 'hi': 'लापता व्यक्ति की रिपोर्ट करें',
        'te': 'తప్పిపోయిన వ్యక్తిని నివేదించండి', 'ta': 'காணாமல் போனவரைப் புகார் செய்யவும்',
        'pa': 'ਗੁੰਮ ਵਿਅਕਤੀ ਦੀ ਰਿਪੋਰਟ ਕਰੋ', 'mr': 'बेपत्ता व्यक्तीची तक्रार करा'
      }[l] ?? 'Report a missing person';

  static String _imLost(String l) => const {
        'en': "I'm Lost", 'hi': 'मैं खो गया हूं', 'te': 'నేను తప్పిపోయాను',
        'ta': 'நான் தொலைந்துவிட்டேன்', 'pa': 'ਮੈਂ ਗੁਆਚ ਗਿਆ ਹਾਂ', 'mr': 'मी हरवलो आहे'
      }[l] ?? "I'm Lost";
  static String _imLostSub(String l) => const {
        'en': 'Help me find my way', 'hi': 'मुझे रास्ता खोजने में मदद करें',
        'te': 'నా దారిని కనుగొనడంలో సహాయం చేయండి', 'ta': 'என் வழியைக் கண்டுபிடிக்க உதவுங்கள்',
        'pa': 'ਮੈਨੂੰ ਰਾਹ ਲੱਭਣ ਵਿੱਚ ਮਦਦ ਕਰੋ', 'mr': 'मला माझा मार्ग शोधण्यास मदत करा'
      }[l] ?? 'Help me find my way';

  static String _safety(String l) => const {
        'en': 'Safety Alert', 'hi': 'सुरक्षा चेतावनी', 'te': 'భద్రతా హెచ్చరిక',
        'ta': 'பாதுகாப்பு எச்சரிக்கை', 'pa': 'ਸੁਰੱਖਿਆ ਚੇਤਾਵਨੀ', 'mr': 'सुरक्षा इशारा'
      }[l] ?? 'Safety Alert';
  static String _safetySub(String l) => const {
        'en': 'Report safety concern / call police', 'hi': 'पुलिस को बुलाएं / सुरक्षा शिकायत',
        'te': 'పోలీసుకు కాల్ / భద్రతా ఫిర్యాదు', 'ta': 'காவல்துறையை அழைக்கவும்',
        'pa': 'ਪੁਲਿਸ ਨੂੰ ਕਾਲ ਕਰੋ', 'mr': 'पोलिसांना कॉल करा'
      }[l] ?? 'Report safety concern / call police';

  static String _meshInfo(String l) => const {
        'en': 'Alerts work offline via local Bluetooth mesh network',
        'hi': 'अलर्ट स्थानीय ब्लूटूथ मेश नेटवर्क से ऑफ़लाइन काम करते हैं',
        'te': 'హెచ్చరికలు స్థానిక బ్లూటూత్ మెష్ నెట్‌వర్క్ ద్వారా ఆఫ్‌లైన్‌లో పనిచేస్తాయి',
        'ta': 'எச்சரிக்கைகள் உள்ளூர் ப்ளூடூத் மெஷ் வலையமைப்பு மூலம் ஆஃப்லைனில் வேலை செய்யும்',
        'pa': 'ਚੇਤਾਵਨੀਆਂ ਸਥਾਨਕ ਬਲੂਟੁੱਥ ਮੈਸ਼ ਨੈੱਟਵਰਕ ਰਾਹੀਂ ਆਫਲਾਈਨ ਕੰਮ ਕਰਦੀਆਂ ਹਨ',
        'mr': 'सूचना स्थानिक ब्लूटूथ मेश नेटवर्कद्वारे ऑफलाइन कार्य करतात'
      }[l] ?? 'Alerts work offline via local Bluetooth mesh network';
}
