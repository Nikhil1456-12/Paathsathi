import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

enum AgentType {
  transport,
  accommodation,
  navigation,
  itinerary,
  safety,
  document,
  general,
}

class AgentResponse {
  final AgentType type;
  final String title;
  final String subtitle;
  final String primaryValue;
  final String badgeText;
  final Color badgeColor;
  final IconData primaryIcon;
  final String spokenTextEnglish;
  final String spokenTextHindi;
  final String spokenTextTelugu;
  final String? spokenTextTamil;
  final String? spokenTextMarathi;
  final String? spokenTextPunjabi;
  final Map<String, dynamic> rawData;
  final LatLng? destinationCoords;
  final String? actionButtonText;
  final String? actionButtonRoute;

  const AgentResponse({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.primaryValue,
    required this.badgeText,
    this.badgeColor = const Color(0xFF16A34A),
    required this.primaryIcon,
    required this.spokenTextEnglish,
    required this.spokenTextHindi,
    required this.spokenTextTelugu,
    this.spokenTextTamil,
    this.spokenTextMarathi,
    this.spokenTextPunjabi,
    this.rawData = const {},
    this.destinationCoords,
    this.actionButtonText,
    this.actionButtonRoute,
  });

  String getSpokenText(String langCode) {
    switch (langCode) {
      case 'hi':
        return spokenTextHindi;
      case 'te':
        return spokenTextTelugu;
      case 'ta':
        return spokenTextTamil ?? spokenTextHindi;
      case 'mr':
        return spokenTextMarathi ?? spokenTextHindi;
      case 'pa':
        return spokenTextPunjabi ?? spokenTextHindi;
      case 'en':
      default:
        return spokenTextEnglish;
    }
  }
}
