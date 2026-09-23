import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Maintains a real back stack of visited locations so a back arrow behaves
/// like the back button in a normal app / browser.
///
/// The app navigates almost entirely with `context.go(...)`, which *replaces*
/// the current location rather than pushing onto a pop-able Navigator stack.
/// So `context.pop()` can't reliably return to the previous screen and a naive
/// "last visited location" lookup ping-pongs between two pages forever.
///
/// This class fixes that by keeping its own stack:
///   • Every forward navigation PUSHES the new location onto the stack.
///   • [smartBack] POPS the current location and navigates to the new top,
///     so the entry is consumed (no infinite A→B→A→B loop).
class NavHistory {
  NavHistory._();
  static final NavHistory instance = NavHistory._();

  /// The back stack, oldest → newest. The last element is the current page.
  final List<String> _stack = <String>[];
  static const int _maxEntries = 50;

  GoRouter? _router;

  /// True while [smartBack] is performing a programmatic back navigation, so
  /// the router listener doesn't treat that navigation as a new forward push.
  bool _navigatingBack = false;

  List<String> get stack => List.unmodifiable(_stack);

  /// Start listening to [router] and recording forward navigations.
  /// Safe to call more than once; only the first attach takes effect.
  void attach(GoRouter router) {
    if (_router == router) return;
    _router = router;
    router.routerDelegate.addListener(_onRouteChanged);
    _push(router.routerDelegate.currentConfiguration.uri.toString());
  }

  String _currentLocation() {
    final router = _router;
    if (router == null) return '';
    return router.routerDelegate.currentConfiguration.uri.toString();
  }

  void _onRouteChanged() {
    // Ignore changes we triggered ourselves from smartBack — those are handled
    // directly so the entry is consumed rather than re-pushed.
    if (_navigatingBack) return;
    _push(_currentLocation());
  }

  /// Push a forward navigation onto the stack.
  void _push(String location) {
    if (location.isEmpty) return;
    // Ignore no-op navigations to the same page.
    if (_stack.isNotEmpty && _stack.last == location) return;

    // If the user navigated to a page already in the stack (e.g. a bottom-nav
    // tab they were on before), collapse back to it instead of growing the
    // stack unbounded — this mirrors typical tab/back behaviour.
    final existingIndex = _stack.lastIndexOf(location);
    if (existingIndex != -1) {
      _stack.removeRange(existingIndex + 1, _stack.length);
      return;
    }

    _stack.add(location);
    if (_stack.length > _maxEntries) {
      _stack.removeAt(0);
    }
  }

  /// Whether there is a previous page to go back to.
  bool get canGoBack => _stack.length > 1;

  /// Pops the current page and returns the previous location, or null if the
  /// stack has no previous entry.
  String? popForBack() {
    if (_stack.length < 2) return null;
    _stack.removeLast(); // drop current page
    return _stack.last; // new current page
  }
}

/// Navigates back to the previously visited page, like a normal app back
/// button.
///
/// Order of preference:
/// 1. If a route was `push`ed onto the Navigator, pop it.
/// 2. Otherwise, pop our own back stack and `go` to the previous location.
/// 3. Otherwise, fall back to [fallback] (default `/home`).
void smartBack(BuildContext context, {String fallback = '/home'}) {
  final router = GoRouter.of(context);

  // Prefer a real Navigator pop when a route was pushed.
  if (router.canPop()) {
    router.pop();
    return;
  }

  final history = NavHistory.instance;
  final previous = history.popForBack();

  if (previous != null) {
    history._navigatingBack = true;
    router.go(previous);
    // Clear the guard after the frame so the resulting route change isn't
    // recorded as a new forward push.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      history._navigatingBack = false;
    });
    return;
  }

  // Nothing to go back to — go to a sensible default.
  context.go(fallback);
}
