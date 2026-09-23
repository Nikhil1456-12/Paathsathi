import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/language_selection_screen.dart';
import '../screens/setup_type_screen.dart';
import '../screens/voice_profile_screen.dart';
import '../screens/document_scan_screen.dart';
import '../screens/home_screen.dart';
import '../screens/listening_screen.dart';
import '../screens/confirmation_screen.dart';
import '../screens/ai_response_screen.dart';
import '../screens/my_journey_screen.dart';
import '../screens/transport_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/accommodation_screen.dart';
import '../screens/itinerary_screen.dart';
import '../screens/emergency_screen.dart';
import '../screens/documents_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/speech_test_screen.dart';
import '../screens/model_setup_screen.dart';
import '../screens/fog_dashboard_screen.dart';
import '../screens/city_map_picker_screen.dart';
import '../screens/journey_pack_screen.dart';
import '../screens/transport_options_screen.dart';
import '../screens/reservation_screen.dart';
import '../screens/stay_reservation_screen.dart';
import '../screens/journey_prepare_screen.dart';
import '../screens/active_journey_screen.dart';
import '../screens/offline_survival_screen.dart';
import '../widgets/main_shell.dart';
import '../widgets/back_to_home.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    // ── Entry point ──────────────────────────────────────────
    GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),

    // ── Auth ─────────────────────────────────────────────────
    GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
    GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),

    // ── Onboarding (post-register) ────────────────────────────
    GoRoute(
        path: '/language', builder: (c, s) => const LanguageSelectionScreen()),
    GoRoute(path: '/setup', builder: (c, s) => const SetupTypeScreen()),
    GoRoute(
        path: '/voice-profile', builder: (c, s) => const VoiceProfileScreen()),
    GoRoute(path: '/doc-scan', builder: (c, s) => const DocumentScanScreen()),

    // ── Voice Interaction (back → home) ──────────────────────
    GoRoute(
        path: '/listening',
        builder: (c, s) => const BackToHome(child: ListeningScreen())),
    GoRoute(
        path: '/confirm',
        builder: (c, s) => const BackToHome(child: ConfirmationScreen())),
    GoRoute(
        path: '/ai-response',
        builder: (c, s) => const BackToHome(child: AiResponseScreen())),
    GoRoute(
        path: '/emergency',
        builder: (c, s) => const BackToHome(child: EmergencyScreen())),
    GoRoute(
        path: '/speech-test',
        builder: (c, s) => const BackToHome(child: SpeechTestScreen())),
    GoRoute(
        path: '/model-setup',
        builder: (c, s) => const BackToHome(child: ModelSetupScreen())),
    GoRoute(
        path: '/fog-dashboard',
        builder: (c, s) => const BackToHome(child: FogDashboardScreen())),
    GoRoute(
        path: '/city-map-picker',
        builder: (c, s) => const BackToHome(child: CityMapPickerScreen())),
    GoRoute(
        path: '/journey-pack',
        builder: (c, s) => const BackToHome(child: JourneyPackScreen())),
    GoRoute(
        path: '/transport-options',
        builder: (c, s) => const BackToHome(child: TransportOptionsScreen())),
    GoRoute(
        path: '/reserve',
        builder: (c, s) => const BackToHome(child: ReservationScreen())),
    GoRoute(
        path: '/stay-reserve',
        builder: (c, s) => const BackToHome(child: StayReservationScreen())),
    GoRoute(
        path: '/journey-prepare',
        builder: (c, s) => const BackToHome(child: JourneyPrepareScreen())),
    GoRoute(
        path: '/active-journey',
        builder: (c, s) => const BackToHome(child: ActiveJourneyScreen())),
    GoRoute(
        path: '/offline-survival',
        builder: (c, s) => const BackToHome(child: OfflineSurvivalScreen())),

    // ── Main App Shell with Bottom Nav ───────────────────────
    ShellRoute(
      builder: (c, s, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
        GoRoute(path: '/journey', builder: (c, s) => const MyJourneyScreen()),
        GoRoute(path: '/transport', builder: (c, s) => const TransportScreen()),
        GoRoute(path: '/nav', builder: (c, s) => const NavigationScreen()),
        GoRoute(
            path: '/accommodation',
            builder: (c, s) => const AccommodationScreen()),
        GoRoute(path: '/itinerary', builder: (c, s) => const ItineraryScreen()),
        GoRoute(path: '/documents', builder: (c, s) => const DocumentsScreen()),
        GoRoute(
            path: '/profile-main', builder: (c, s) => const ProfileScreen()),
      ],
    ),
  ],
);
