import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/farm_email_service.dart';

final farmEmailServiceProvider = Provider<FarmEmailService>((ref) {
  return const FarmEmailService();
});
