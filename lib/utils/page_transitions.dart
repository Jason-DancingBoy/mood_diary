import 'package:flutter/material.dart';

/// Custom page transition builder — combines slide + fade for a polished feel.
/// Used globally via pageTransitionsTheme so every MaterialPageRoute benefits.
class _CustomTransitionBuilder extends PageTransitionsBuilder {
  const _CustomTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Curved animation for a natural easing feel
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.08, 0.0),
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}

/// The custom transitions theme to apply in [ThemeData.pageTransitionsTheme].
const PageTransitionsTheme customPageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _CustomTransitionBuilder(),
    TargetPlatform.iOS: _CustomTransitionBuilder(),
    TargetPlatform.linux: _CustomTransitionBuilder(),
    TargetPlatform.macOS: _CustomTransitionBuilder(),
    TargetPlatform.windows: _CustomTransitionBuilder(),
  },
);

/// A scale+fade route — use for full-screen image/modal views instead of
/// the default slide transition.
class FadeScalePageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  FadeScalePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}
