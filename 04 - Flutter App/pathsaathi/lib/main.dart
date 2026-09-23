import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/nav_history.dart';
import 'database/app_database.dart';
import 'agents/document_agent.dart';
import 'services/connectivity_service.dart';
import 'services/cache_manager.dart';
import 'services/whisper_service.dart';
import 'services/llm_service.dart';
import 'services/nlu_service.dart';
import 'services/tier_router.dart';
import 'services/map_bundle_service.dart';
import 'services/device_tier_service.dart';
import 'services/destination_resolver.dart';
import 'services/semantic_search_service.dart';
import 'services/tile_cache_service.dart';
import 'agents/agent_registry_setup.dart';
import 'services/routing_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Full crash stack trace to logcat (debug only) ──────────────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    // ignore: avoid_print
    print('══════════════════════════════════════════════');
    // ignore: avoid_print
    print('PATHSAATHI CRASH: ${details.exception}');
    // ignore: avoid_print
    print('STACK TRACE:\n${details.stack}');
    // ignore: avoid_print
    print('══════════════════════════════════════════════');
    FlutterError.presentError(details);
  };
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Initialize SQLite database and secure documents vault offline
  await AppDatabase.instance.database;
  await DocumentAgent.instance.initializeDefaultDocs();

  // Register the specialist agent swarm behind the common PathSaathiAgent
  // interface so the planner dispatches polymorphically (central coordination).
  registerPathSaathiAgents();

  // Preload the offline routing graphs so SafetyAgent/NavigationAgent can give
  // real along-path distances + turn cues with no network (airplane-mode safe).
  unawaited(RoutingService.instance.initialize());

  // Detect device tier from real RAM so we only load a model set that fits.
  await DeviceTierService.initialize();

  // Initialize offline-first services
  await ConnectivityService.instance.initialize();
  await CacheManager.instance.initialize();

  // Build the offline semantic-search index over the advisory/FAQ corpus and
  // detect any embedding model (stays lexical/truthful if none present).
  unawaited(SemanticSearchService.instance.initialize());

  // Configure the COMPLIANT map tile source (MapTiler) — real street tiles that
  // permit app + offline-cache use. This replaces OSM's blocked public servers.
  // Used for online display AND for offline region pre-caching.
  TileCacheService.instance.configureTileSource(
    'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=MbWaVcyuDmunFVIaYoWk',
  );

  // Wire the destination-resolution pipeline's online check to real connectivity
  // (used to decide online-geocoder availability vs. truthful offline-unavailable).
  DestinationResolutionService.instance.onlineCheck =
      () => ConnectivityService.instance.status != ConnectivityStatus.offline;

  // Initialize AI services (non-blocking — degrade gracefully if not downloaded)
  // Offline voice: ensure the Whisper model is present — auto-downloads once in
  // the background when online (WiFi), then activates offline voice. If offline,
  // it silently defers; text input keeps working meanwhile.
  unawaited(WhisperService.instance.ensureModelAvailable());
  unawaited(LlmService.instance.initialize());
  unawaited(NluService.instance.initialize());

  // Initialize 3-Tier Router — probes Fog node (LAN) and Cloud in background.
  // Non-blocking: falls back to on-device if neither is reachable.
  unawaited(TierRouter.instance.initialize());

  // Initialize offline map bundle service — scan existing downloads + open MbTiles.
  // Auto-downloads Prayagraj bundle silently on WiFi (zero user action needed).
  unawaited(MapBundleService.instance.initialize().then((_) {
    MapBundleService.instance.autoDownloadPrimaryBundles();
  }));

  runApp(const ProviderScope(child: PathSaathiApp()));
}

class PathSaathiApp extends StatelessWidget {
  const PathSaathiApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Track visited locations so back arrows return to the previous page.
    NavHistory.instance.attach(appRouter);
    return MaterialApp.router(
      title: 'PathSaathi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}
