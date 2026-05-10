import 'package:flutter/material.dart';

/// Extension methods for BuildContext to access theme and media query properties.
extension ContextExtensions on BuildContext {
  /// Gets the current theme.
  ThemeData get theme => Theme.of(this);

  /// Gets the color scheme.
  ColorScheme get colorScheme => theme.colorScheme;

  /// Gets the text theme.
  TextTheme get textTheme => theme.textTheme;

  /// Gets the media query data.
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Gets the screen size.
  Size get screenSize => mediaQuery.size;

  /// Gets the screen width.
  double get screenWidth => screenSize.width;

  /// Gets the screen height.
  double get screenHeight => screenSize.height;

  /// Checks if the device is in landscape orientation.
  bool get isLandscape => mediaQuery.orientation == Orientation.landscape;

  /// Checks if the device is in portrait orientation.
  bool get isPortrait => mediaQuery.orientation == Orientation.portrait;

  /// Gets the padding from safe area.
  EdgeInsets get padding => mediaQuery.padding;

  /// Gets the view insets (keyboard, etc.).
  EdgeInsets get viewInsets => mediaQuery.viewInsets;

  /// Gets the device pixel ratio.
  double get devicePixelRatio => mediaQuery.devicePixelRatio;

  /// Gets the theme spacing extension.
  dynamic get spacing => theme.extensions;

  /// Gets the theme motion extension.
  dynamic get motion => theme.extensions;

  /// Gets the theme shadow extension.
  dynamic get shadow => theme.extensions;

  /// Shows a snackbar with the given message.
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colorScheme.error : colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  /// Shows a loading dialog.
  void showLoadingDialog() {
    showDialog(
      context: this,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Hides the current dialog.
  void hideDialog() {
    Navigator.of(this).pop();
  }

  /// Pushes a new route.
  Future<T?> push<T>(Widget page) {
    return Navigator.of(this).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Pushes a named route.
  Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    return Navigator.of(this).pushNamed(routeName, arguments: arguments);
  }

  /// Pops the current route.
  void pop<T>([T? result]) {
    Navigator.of(this).pop(result);
  }

  /// Gets the focus scope.
  FocusScopeNode get focusScope => FocusScope.of(this);

  /// Unfocuses the current focus.
  void unfocus() {
    focusScope.unfocus();
  }
}