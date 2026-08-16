import 'package:flutter/widgets.dart';

/// Native platforms use the imperative `GoogleSignIn.signIn()` popup instead
/// of a rendered button, so this is never actually shown.
Widget buildGoogleSignInButton() => const SizedBox.shrink();
