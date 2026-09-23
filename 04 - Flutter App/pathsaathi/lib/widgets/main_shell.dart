import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/language_provider.dart';
import '../core/app_strings.dart';
import 'offline_banner.dart';

const _green = Color(0xFF1A6B3C);
const _saffron = Color(0xFFFF6B00);

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  DateTime? _lastBackPress;

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(languageProvider).code;
    final loc = GoRouterState.of(context).uri.toString();

    final routes = const ['/home', '/journey', '/nav', '/documents', '/profile-main'];
    final icons = const [
      Icons.home_outlined,
      Icons.calendar_today_outlined,
      Icons.explore_outlined,
      Icons.folder_outlined,
      Icons.person_outline,
    ];

    // Bilingual bottom nav labels
    List<String> labels(String l) => [
      AppStrings.home(l),
      AppStrings.journey(l),
      AppStrings.navigate(l),
      AppStrings.documents(l),
      AppStrings.profile(l),
    ];

    int current = 0;
    for (int i = 0; i < routes.length; i++) {
      if (loc.startsWith(routes[i])) { current = i; break; }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on home, go to home
        if (!loc.startsWith('/home')) {
          context.go('/home');
          return;
        }
        // On home: double-back to exit
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const OfflineBanner(),
            Expanded(child: widget.child),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(children: [
                // First 2 items
                ...[0, 1].map((i) => _navItem(context, i, current, icons[i], labels(lang)[i], routes[i])),
                // Center FAB mic
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onTap: () => context.push('/listening'),
                      child: Hero(
                        tag: 'fab_mic',
                        child: Container(
                          width: 56, height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, color: _saffron,
                            boxShadow: [BoxShadow(color: _saffron.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)],
                          ),
                          child: const Icon(Icons.mic, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
                ),
                // Last 2 items
                ...[3, 4].map((i) => _navItem(context, i, current, icons[i], labels(lang)[i], routes[i])),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext ctx, int i, int current, IconData icon, String label, String route) {
    final sel = i == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => ctx.go(route),
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 22, color: sel ? _green : const Color(0xFF9CA3AF)),
          const SizedBox(height: 3),
          Text(label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              color: sel ? _green : const Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
