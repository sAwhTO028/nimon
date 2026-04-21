import 'package:flutter/widgets.dart';

/// Exposes a [ValueNotifier] so [ProfileScreen] can hide the shell bottom dock
/// while its right-side push drawer is open or animating.
class ProfilePushDrawerDockScope extends InheritedWidget {
  final ValueNotifier<bool> obscuresDock;

  const ProfilePushDrawerDockScope({
    super.key,
    required this.obscuresDock,
    required super.child,
  });

  static ValueNotifier<bool>? obscuresDockOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ProfilePushDrawerDockScope>()
        ?.obscuresDock;
  }

  static ValueNotifier<bool>? maybeObscuresDockOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<ProfilePushDrawerDockScope>()
        ?.obscuresDock;
  }

  @override
  bool updateShouldNotify(ProfilePushDrawerDockScope oldWidget) =>
      obscuresDock != oldWidget.obscuresDock;
}
