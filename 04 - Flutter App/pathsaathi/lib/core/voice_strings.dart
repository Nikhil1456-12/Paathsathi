// lib/core/voice_strings.dart
//
// Centralized localized strings for the voice/travel/GPS flow. Falls back to
// English when a language is missing. Also provides multilingual yes/no
// detection so the user can confirm destinations by voice in their language.

class VoiceStrings {
  VoiceStrings._();

  /// "You said X. Is that correct?" in the selected language.
  static String confirmDestination(String lang, String place) {
    switch (lang) {
      case 'hi': return 'आपने $place कहा है। क्या यह सही है?';
      case 'te': return 'మీరు $place అని చెప్పారు. ఇది సరైనదేనా?';
      case 'ta': return 'நீங்கள் $place என்று சொன்னீர்கள். இது சரியா?';
      case 'mr': return 'तुम्ही $place म्हणालात. हे बरोबर आहे का?';
      case 'pa': return 'ਤੁਸੀਂ $place ਕਿਹਾ ਹੈ। ਕੀ ਇਹ ਸਹੀ ਹੈ?';
      default:   return 'You said $place. Is that correct?';
    }
  }

  static String notUnderstood(String lang) {
    switch (lang) {
      case 'hi': return 'मुझे समझ नहीं आया कि आप कहाँ जाना चाहते हैं। कृपया शहर का नाम बोलें।';
      case 'te': return 'మీరు ఎక్కడికి వెళ్లాలనుకుంటున్నారో అర్థం కాలేదు. దయచేసి నగరం పేరు చెప్పండి.';
      case 'ta': return 'நீங்கள் எங்கே செல்ல விரும்புகிறீர்கள் என்று புரியவில்லை. நகரத்தின் பெயரைச் சொல்லுங்கள்.';
      default:   return "I didn't catch the destination. Please say the city name.";
    }
  }

  static String confirmedGoing(String lang, String place) {
    switch (lang) {
      case 'hi': return 'ठीक है, $place के लिए मार्ग दिखा रहा हूँ।';
      case 'te': return 'సరే, $place కు మార్గం చూపిస్తున్నాను.';
      case 'ta': return 'சரி, $place க்கு வழியைக் காட்டுகிறேன்.';
      default:   return 'Okay, showing the way to $place.';
    }
  }

  static String yesLabel(String lang) => switch (lang) {
        'hi' => 'हाँ, सही है',
        'te' => 'అవును, సరైనదే',
        'ta' => 'ஆம், சரி',
        _ => 'Yes, correct',
      };

  static String noLabel(String lang) => switch (lang) {
        'hi' => 'नहीं, फिर से',
        'te' => 'కాదు, మళ్ళీ',
        'ta' => 'இல்லை, மீண்டும்',
        _ => 'No, try again',
      };

  // ── Multilingual yes/no detection ─────────────────────────────────────────
  static const _yes = [
    'yes', 'yeah', 'yep', 'correct', "that's right", 'right', 'ok', 'okay', 'sure', 'confirm',
    'हाँ', 'हां', 'सही', 'सही है', 'बिल्कुल', 'ठीक', 'ठीक है', 'जी', 'जी हाँ',
    'అవును', 'సరే', 'సరైనదే', 'ఔను', 'కరెక్ట్',
    'ஆம்', 'சரி', 'சரியானது', 'ஆமாம்',
    'हो', 'बरोबर', 'ਹਾਂ', 'ਸਹੀ',
  ];
  static const _no = [
    'no', 'nope', 'wrong', 'incorrect', 'not right', 'cancel', 'change',
    'नहीं', 'ना', 'गलत', 'नही',
    'కాదు', 'తప్పు', 'వద్దు',
    'இல்லை', 'தவறு', 'வேண்டாம்',
    'नाही', 'ਨਹੀਂ', 'ਗਲਤ',
  ];

  static bool isYes(String text) {
    final t = text.toLowerCase().trim();
    return _yes.any((w) => t == w || t.contains(w));
  }

  static bool isNo(String text) {
    final t = text.toLowerCase().trim();
    return _no.any((w) => t == w || t.contains(w));
  }

  // ── Journey-moment spoken strings (HI/TE/EN; others fall back to English) ──

  /// Spoken when the user reaches the destination area.
  static String arrived(String lang, String place) {
    switch (lang) {
      case 'hi': return 'आप $place पहुँच गए हैं।';
      case 'te': return 'మీరు $place చేరుకున్నారు.';
      case 'ta': return 'நீங்கள் $place வந்துவிட்டீர்கள்.';
      default:   return 'You have reached $place.';
    }
  }

  /// Spoken/shown when a reservation is confirmed.
  static String reservationConfirmed(String lang, String refCode) {
    switch (lang) {
      case 'hi': return 'आरक्षण पक्का हो गया। संदर्भ संख्या $refCode।';
      case 'te': return 'రిజర్వేషన్ ఖరారైంది. రిఫరెన్స్ $refCode.';
      case 'ta': return 'முன்பதிவு உறுதி செய்யப்பட்டது. குறிப்பு $refCode.';
      default:   return 'Reservation confirmed. Reference $refCode.';
    }
  }

  /// Spoken while the trip is being prepared for offline use.
  static String preparingOffline(String lang, String place) {
    switch (lang) {
      case 'hi': return '$place की यात्रा ऑफ़लाइन के लिए तैयार की जा रही है।';
      case 'te': return '$place ప్రయాణాన్ని ఆఫ్‌లైన్ కోసం సిద్ధం చేస్తున్నాం.';
      case 'ta': return '$place பயணம் ஆஃப்லைனுக்கு தயார் செய்யப்படுகிறது.';
      default:   return 'Preparing your journey to $place for offline use.';
    }
  }

  /// Spoken when connectivity is lost during a journey.
  static String offlineNow(String lang) {
    switch (lang) {
      case 'hi': return 'इंटरनेट बंद है। सहेजी गई यात्रा जानकारी का उपयोग किया जा रहा है।';
      case 'te': return 'ఇంటర్నెట్ లేదు. సేవ్ చేసిన ప్రయాణ సమాచారాన్ని ఉపయోగిస్తున్నాం.';
      case 'ta': return 'இணையம் இல்லை. சேமித்த பயணத் தகவலைப் பயன்படுத்துகிறோம்.';
      default:   return 'You are offline. Using your saved trip information.';
    }
  }
}
