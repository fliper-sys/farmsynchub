import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/ai_provider.dart';

final aiChatProvider = ChangeNotifierProvider<AiProvider>((ref) {
  final provider = AiProvider();
  provider.init();
  return provider;
});
