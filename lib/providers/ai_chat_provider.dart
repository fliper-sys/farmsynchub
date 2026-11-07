import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/ai_provider.dart';
import 'auth_provider.dart';

final aiChatProvider = ChangeNotifierProvider<AiProvider>((ref) {
  // Rebuilt for every account so one person never sees another's records.
  ref.watch(sessionUidProvider);
  final provider = AiProvider();
  provider.init();
  return provider;
});
