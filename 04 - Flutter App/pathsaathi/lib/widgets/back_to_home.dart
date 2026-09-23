import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps a screen so the system back button navigates to /home
/// instead of popping the entire app.
class BackToHome extends StatelessWidget {
  final Widget child;
  const BackToHome({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: child,
    );
  }
}
