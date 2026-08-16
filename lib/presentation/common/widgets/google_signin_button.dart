// Conditional export: the web implementation renders Google's own GIS button
// (`renderButton`) via `google_sign_in_web`, which internally depends on
// `dart:ui_web` and cannot compile for non-web targets (Android/iOS/Windows).
// The stub keeps this import safe everywhere else.
export 'google_signin_button_web.dart'
    if (dart.library.io) 'google_signin_button_stub.dart';
