/// PathSaathi Bilingual String System
/// Format: "English (Native Script)"
/// If English is selected → only English shown
/// Otherwise → "English (Translation)"

class AppStrings {
  AppStrings._();

  // ── Core helper ──────────────────────────────────────────────────────────────
  static String bi(String english, Map<String, String> translations, String langCode) {
    if (langCode == 'en') return english;
    final t = translations[langCode];
    if (t == null || t.isEmpty) return english;
    return '$english ($t)';
  }

  // ── Greeting ─────────────────────────────────────────────────────────────────
  static String greeting(String name, String lang) => bi(
    'Namaste, $name 🙏',
    {'hi': 'नमस्ते, $name 🙏', 'te': 'నమస్కారం, $name 🙏', 'ta': 'வணக்கம், $name 🙏', 'pa': 'ਸਤਿ ਸ੍ਰੀ ਅਕਾਲ, $name 🙏', 'mr': 'नमस्कार, $name 🙏'},
    lang,
  );

  static String howCanIHelp(String lang) => bi(
    'How can I help you today?',
    {'hi': 'आज मैं आपकी कैसे मदद करूं?', 'te': 'నేను మీకు ఎలా సహాయం చేయాలి?', 'ta': 'இன்று நான் உங்களுக்கு எப்படி உதவலாம்?', 'pa': 'ਅੱਜ ਮੈਂ ਤੁਹਾਡੀ ਕਿਵੇਂ ਮਦਦ ਕਰਾਂ?', 'mr': 'आज मी तुम्हाला कशी मदत करू?'},
    lang,
  );

  static String tapToSpeak(String lang) => bi(
    'TAP TO SPEAK',
    {'hi': 'बोलने के लिए टैप करें', 'te': 'మాట్లాడటానికి నొక్కండి', 'ta': 'பேச தட்டவும்', 'pa': 'ਬੋਲਣ ਲਈ ਟੈਪ ਕਰੋ', 'mr': 'बोलण्यासाठी टॅप करा'},
    lang,
  );

  static String speakInYourLang(String lang) => bi(
    'Speak in your language',
    {'hi': 'अपनी भाषा में बोलें', 'te': 'మీ భాషలో మాట్లాడండి', 'ta': 'உங்கள் மொழியில் பேசுங்கள்', 'pa': 'ਆਪਣੀ ਭਾਸ਼ਾ ਵਿੱਚ ਬੋਲੋ', 'mr': 'आपल्या भाषेत बोला'},
    lang,
  );

  // ── Quick Chips ───────────────────────────────────────────────────────────────
  static String whereDoIGo(String lang) => bi(
    '📍 Where do I go?',
    {'hi': 'मैं कहाँ जाऊं?', 'te': 'నేను ఎక్కడికి వెళ్ళాలి?', 'ta': 'நான் எங்கே போகணும்?', 'pa': 'ਮੈਂ ਕਿੱਥੇ ਜਾਵਾਂ?', 'mr': 'मी कुठे जाऊ?'},
    lang,
  );

  static String myJourney(String lang) => bi(
    '🗓 My Journey',
    {'hi': 'मेरी यात्रा', 'te': 'నా ప్రయాణం', 'ta': 'என் பயணம்', 'pa': 'ਮੇਰੀ ਯਾਤਰਾ', 'mr': 'माझी यात्रा'},
    lang,
  );

  static String emergency(String lang) => bi(
    '🆘 Emergency',
    {'hi': 'आपातकाल', 'te': 'అత్యవసరం', 'ta': 'அவசரநிலை', 'pa': 'ਐਮਰਜੈਂਸੀ', 'mr': 'आणीबाणी'},
    lang,
  );

  // ── Grid Cards ────────────────────────────────────────────────────────────────
  static String transport(String lang) => bi(
    'Transport',
    {'hi': 'परिवहन', 'te': 'రవాణా', 'ta': 'போக்குவரத்து', 'pa': 'ਟ੍ਰਾਂਸਪੋਰਟ', 'mr': 'वाहतूक'},
    lang,
  );

  static String navigate(String lang) => bi(
    'Navigate',
    {'hi': 'नेविगेट', 'te': 'నావిగేట్', 'ta': 'வழிசெலுத்து', 'pa': 'ਨੈਵੀਗੇਟ', 'mr': 'नेव्हिगेट'},
    lang,
  );

  static String myStay(String lang) => bi(
    'My Stay',
    {'hi': 'मेरा निवास', 'te': 'నా నివాసం', 'ta': 'என் தங்குமிடம்', 'pa': 'ਮੇਰਾ ਠਹਿਰਾਅ', 'mr': 'माझे निवासस्थान'},
    lang,
  );

  static String itinerary(String lang) => bi(
    'Itinerary',
    {'hi': 'यात्रा कार्यक्रम', 'te': 'యాత్రా కార్యక్రమం', 'ta': 'பயண அட்டவணை', 'pa': 'ਯਾਤਰਾ ਯੋਜਨਾ', 'mr': 'प्रवास कार्यक्रम'},
    lang,
  );

  // ── Bottom Nav ────────────────────────────────────────────────────────────────
  static String home(String lang) => bi(
    'Home',
    {'hi': 'होम', 'te': 'హోమ్', 'ta': 'முகப்பு', 'pa': 'ਹੋਮ', 'mr': 'होम'},
    lang,
  );

  static String journey(String lang) => bi(
    'Journey',
    {'hi': 'यात्रा', 'te': 'ప్రయాణం', 'ta': 'பயணம்', 'pa': 'ਯਾਤਰਾ', 'mr': 'प्रवास'},
    lang,
  );

  static String documents(String lang) => bi(
    'Docs',
    {'hi': 'दस्तावेज़', 'te': 'పత్రాలు', 'ta': 'ஆவணங்கள்', 'pa': 'ਦਸਤਾਵੇਜ਼', 'mr': 'कागदपत्रे'},
    lang,
  );

  static String profile(String lang) => bi(
    'Profile',
    {'hi': 'प्रोफ़ाइल', 'te': 'ప్రొఫైల్', 'ta': 'சுயவிவரம்', 'pa': 'ਪ੍ਰੋਫਾਈਲ', 'mr': 'प्रोफाइल'},
    lang,
  );

  // ── Transport Screen ──────────────────────────────────────────────────────────
  static String whereAreYouGoing(String lang) => bi(
    'Where are you going?',
    {'hi': 'आप कहाँ जा रहे हैं?', 'te': 'మీరు ఎక్కడికి వెళ్తున్నారు?', 'ta': 'நீங்கள் எங்கே போகிறீர்கள்?', 'pa': 'ਤੁਸੀਂ ਕਿੱਥੇ ਜਾ ਰਹੇ ਹੋ?', 'mr': 'तुम्ही कुठे जात आहात?'},
    lang,
  );

  static String availableBuses(String lang) => bi(
    'Available Buses',
    {'hi': 'उपलब्ध बसें', 'te': 'అందుబాటులో ఉన్న బస్సులు', 'ta': 'கிடைக்கும் பேருந்துகள்', 'pa': 'ਉਪਲਬਧ ਬੱਸਾਂ', 'mr': 'उपलब्ध बस'},
    lang,
  );

  static String bookNow(String lang) => bi(
    'Book',
    {'hi': 'बुक करें', 'te': 'బుక్ చేయి', 'ta': 'புக் செய்', 'pa': 'ਬੁੱਕ ਕਰੋ', 'mr': 'बुक करा'},
    lang,
  );

  // ── Journey Screen ────────────────────────────────────────────────────────────
  static String busToSangam(String lang) => bi(
    'Bus to Sangam',
    {'hi': 'संगम की बस', 'te': 'సంగమ్ బస్', 'ta': 'சங்கமம் பேருந்து', 'pa': 'ਸੰਗਮ ਦੀ ਬੱਸ', 'mr': 'संगमाची बस'},
    lang,
  );

  static String templeVisit(String lang) => bi(
    'Temple Visit',
    {'hi': 'मंदिर दर्शन', 'te': 'గుడి సందర్శన', 'ta': 'கோவில் சந்திப்பு', 'pa': 'ਮੰਦਰ ਦਰਸ਼ਨ', 'mr': 'मंदिर दर्शन'},
    lang,
  );

  static String lunchRest(String lang) => bi(
    'Lunch / Rest',
    {'hi': 'भोजन / आराम', 'te': 'భోజనం / విశ్రాంతి', 'ta': 'உணவு / ஓய்வு', 'pa': 'ਲੰਚ / ਆਰਾਮ', 'mr': 'जेवण / विश्रांती'},
    lang,
  );

  static String returnToCamp(String lang) => bi(
    'Return to Camp',
    {'hi': 'कैंप वापसी', 'te': 'క్యాంపుకు తిరిగి', 'ta': 'முகாமிற்கு திரும்பு', 'pa': 'ਕੈਂਪ ਵਾਪਸੀ', 'mr': 'छावणीत परत'},
    lang,
  );

  // ── Listening Screen ──────────────────────────────────────────────────────────
  static String listening(String lang) => bi(
    'Listening',
    {'hi': 'सुन रहा हूं', 'te': 'వింటున్నాను', 'ta': 'கேட்கிறேன்', 'pa': 'ਸੁਣ ਰਿਹਾ ਹਾਂ', 'mr': 'ऐकत आहे'},
    lang,
  );

  static String tapIfWrong(String lang) => bi(
    'Tap if I heard wrong',
    {'hi': 'गलत सुना तो टैप करें', 'te': 'తప్పు విన్నట్టయితే నొక్కండి', 'ta': 'தவறாக கேட்டால் தட்டவும்', 'pa': 'ਗਲਤ ਸੁਣਿਆ ਤਾਂ ਟੈਪ ਕਰੋ', 'mr': 'चुकीचे ऐकले तर टॅप करा'},
    lang,
  );

  // ── Documents Screen ──────────────────────────────────────────────────────────
  static String myDocuments(String lang) => bi(
    'My Documents',
    {'hi': 'मेरे दस्तावेज़', 'te': 'నా పత్రాలు', 'ta': 'என் ஆவணங்கள்', 'pa': 'ਮੇਰੇ ਦਸਤਾਵੇਜ਼', 'mr': 'माझी कागदपत्रे'},
    lang,
  );

  static String addDocument(String lang) => bi(
    'Add Document',
    {'hi': 'दस्तावेज़ जोड़ें', 'te': 'పత్రం జోడించండి', 'ta': 'ஆவணம் சேர்க்கவும்', 'pa': 'ਦਸਤਾਵੇਜ਼ ਜੋੜੋ', 'mr': 'कागदपत्र जोडा'},
    lang,
  );

  // ── Accommodation ─────────────────────────────────────────────────────────────
  static String bookingConfirmed(String lang) => bi(
    'Booking Confirmed',
    {'hi': 'बुकिंग पुष्टि हो गई', 'te': 'బుకింగ్ నిర్ధారించబడింది', 'ta': 'முன்பதிவு உறுதி செய்யப்பட்டது', 'pa': 'ਬੁਕਿੰਗ ਕਨਫਰਮ ਹੋਈ', 'mr': 'बुकिंग पुष्टी झाली'},
    lang,
  );

  static String showOnMap(String lang) => bi(
    'Show on Map',
    {'hi': 'मानचित्र पर देखें', 'te': 'మ్యాప్‌లో చూపించు', 'ta': 'வரைபடத்தில் காட்டு', 'pa': 'ਨਕਸ਼ੇ ਤੇ ਵੇਖੋ', 'mr': 'नकाशावर दाखवा'},
    lang,
  );

  // ── Emergency ─────────────────────────────────────────────────────────────────
  static String whatHappened(String lang) => bi(
    'What happened?',
    {'hi': 'क्या हुआ?', 'te': 'ఏమి జరిగింది?', 'ta': 'என்ன நடந்தது?', 'pa': 'ਕੀ ਹੋਇਆ?', 'mr': 'काय झाले?'},
    lang,
  );

  static String medicalEmergency(String lang) => bi(
    'Medical Emergency',
    {'hi': 'चिकित्सा आपातकाल', 'te': 'వైద్య అత్యవసరం', 'ta': 'மருத்துவ அவசரநிலை', 'pa': 'ਮੈਡੀਕਲ ਐਮਰਜੈਂਸੀ', 'mr': 'वैद्यकीय आणीबाणी'},
    lang,
  );

  static String iAmLost(String lang) => bi(
    "I'm Lost",
    {'hi': 'मैं खो गया हूं', 'te': 'నేను తప్పిపోయాను', 'ta': 'நான் தொலைந்துவிட்டேன்', 'pa': 'ਮੈਂ ਗੁਆਚ ਗਿਆ ਹਾਂ', 'mr': 'मी हरवलो आहे'},
    lang,
  );

  // ── Offline status ────────────────────────────────────────────────────────────
  static String offlineMode(String lang) => bi(
    'Offline Mode',
    {'hi': 'ऑफ़लाइन मोड', 'te': 'ఆఫ్‌లైన్ మోడ్', 'ta': 'ஆஃப்லைன் முறை', 'pa': 'ਆਫਲਾਈਨ ਮੋਡ', 'mr': 'ऑफलाइन मोड'},
    lang,
  );

  static String offlineReady(String lang) => bi(
    'Offline Ready',
    {'hi': 'ऑफ़लाइन तैयार', 'te': 'ఆఫ్‌లైన్ సిద్ధం', 'ta': 'ஆஃப்லைன் தயார்', 'pa': 'ਆਫਲਾਈਨ ਤਿਆਰ', 'mr': 'ऑफलाइन तयार'},
    lang,
  );

  // ── Voice Script hint ─────────────────────────────────────────────────────────
  static String voiceHint(String lang) {
    const hints = {
      'hi': '"मेरी ट्रेन कहाँ है?"',
      'te': '"నా రైలు ఎక్కడ ఉంది?"',
      'ta': '"என் ரயில் எங்கே இருக்கிறது?"',
      'pa': '"ਮੇਰੀ ਰੇਲਗੱਡੀ ਕਿੱਥੇ ਹੈ?"',
      'mr': '"माझी ट्रेन कुठे आहे?"',
      'en': '"Where is my train?"',
    };
    return hints[lang] ?? '"Where is my train?"';
  }

  // ── Language badge (mic indicator) ───────────────────────────────────────────
  static String langBadge(String lang) {
    const badges = {
      'hi': '🎙 हिंदी',
      'te': '🎙 తెలుగు',
      'ta': '🎙 தமிழ்',
      'pa': '🎙 ਪੰਜਾਬੀ',
      'mr': '🎙 मराठी',
      'en': '🎙 English',
    };
    return badges[lang] ?? '🎙 हिंदी';
  }
}
