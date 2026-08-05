import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as gis_web;

/// Renders Google's own FedCM-compliant Sign-In button (Google Identity
/// Services). Required on web since the imperative `signIn()` popup is
/// deprecated and unreliable (`popup_closed`, missing `idToken`).
Widget buildGoogleSignInButton() {
  return SizedBox(
    height: 44,
    width: double.infinity,
    child: gis_web.renderButton(
      configuration: gis_web.GSIButtonConfiguration(
        theme: gis_web.GSIButtonTheme.outline,
        size: gis_web.GSIButtonSize.large,
        text: gis_web.GSIButtonText.continueWith,
        shape: gis_web.GSIButtonShape.rectangular,
      ),
    ),
  );
}
