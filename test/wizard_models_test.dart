import 'package:farmsynchub/presentation/common/wizard/wizard_models.dart';
import 'package:farmsynchub/providers/app_preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalizedText', () {
    test('resolves each language', () {
      const LocalizedText text =
          LocalizedText('Next', ha: 'Na gaba', fr: 'Suivant');
      expect(text.resolve(AppLanguage.english), 'Next');
      expect(text.resolve(AppLanguage.hausa), 'Na gaba');
      expect(text.resolve(AppLanguage.french), 'Suivant');
    });

    test('falls back to English when a translation is missing', () {
      const LocalizedText text = LocalizedText('Only English');
      expect(text.resolve(AppLanguage.hausa), 'Only English');
      expect(text.resolve(AppLanguage.french), 'Only English');
    });
  });

  group('WizardText', () {
    test('stepOf is translated and carries both numbers', () {
      expect(WizardText.stepOf(AppLanguage.english, 2, 6), 'Step 2 of 6');
      expect(WizardText.stepOf(AppLanguage.french, 2, 6), 'Étape 2 sur 6');
      expect(WizardText.stepOf(AppLanguage.hausa, 2, 6), contains('2'));
      expect(WizardText.stepOf(AppLanguage.hausa, 2, 6), contains('6'));
    });
  });
}
