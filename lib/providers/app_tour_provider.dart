import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set to true to start the guided spotlight tour on the dashboard. The
/// dashboard resets it to false as soon as the tour begins.
///
/// Used by the post-login welcome screen ("Start tour") and by the
/// "Replay app tour" row in Settings.
final appTourRequestedProvider = StateProvider<bool>((ref) => false);
