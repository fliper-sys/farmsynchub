import 'package:flutter_test/flutter_test.dart';
import 'package:farmsynchub/providers/app_preferences_provider.dart';

void main() {
  test('pidgin falls back to phrase table, then explicit pcm, then English', () {
    expect(AppLanguage.pidgin.tr(en: 'Add farm'), 'Add farm');
    expect(AppLanguage.pidgin.tr(en: 'Learn today'), 'Learn today');
    expect(AppLanguage.pidgin.tr(en: 'Cancel', pcm: 'Comot'), 'Comot');
    expect(AppLanguage.pidgin.tr(en: 'Unknown phrase xyz'), 'Unknown phrase xyz');
    expect(AppLanguage.pidgin.tr(en: 'Take a photo'), 'Snap photo');
    expect(AppLanguage.english.tr(en: 'Take a photo', ha: 'x'), 'Take a photo');
    expect(AppLanguage.hausa.tr(en: 'a'), 'a');
  });
}
