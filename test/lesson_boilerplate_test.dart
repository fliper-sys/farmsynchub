import 'package:farmsynchub/core/i18n/lesson_boilerplate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Hausa and Pidgin lesson boilerplate cover the same sentences', () {
    expect(kLessonBoilerplateHa.keys.toSet(),
        kLessonBoilerplatePcm.keys.toSet());
    expect(kLessonBoilerplateHa, isNotEmpty);
    for (final String value in <String>[
      ...kLessonBoilerplateHa.values,
      ...kLessonBoilerplatePcm.values,
    ]) {
      expect(value.trim(), isNotEmpty);
    }
  });
}
