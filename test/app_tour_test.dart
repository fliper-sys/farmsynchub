import 'package:farmsynchub/presentation/common/tour/app_spotlight_tour.dart';
import 'package:farmsynchub/providers/app_preferences_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every tour step is written in all three languages', () {
    for (final TourStep step in AppTourSteps.dashboard) {
      for (final text in <dynamic>[step.title, step.body]) {
        expect(text.en, isNotEmpty);
        expect(text.ha, isNotNull, reason: text.en);
        expect(text.fr, isNotNull, reason: text.en);
        expect(text.resolve(AppLanguage.hausa), isNot(text.en));
        expect(text.resolve(AppLanguage.french), isNot(text.en));
      }
    }
  });

  test('tour starts and ends with centred messages', () {
    expect(AppTourSteps.dashboard.first.targetId, isNull);
    expect(AppTourSteps.dashboard.last.targetId, isNull);
    expect(AppTourSteps.dashboard.last.celebrate, isTrue);
  });

  test('each spotlight target id is unique', () {
    final List<String> ids = AppTourSteps.dashboard
        .map((TourStep s) => s.targetId)
        .whereType<String>()
        .toList();
    expect(ids.toSet().length, ids.length);
  });

  test('target keys are stable per id', () {
    expect(TourTargets.keyFor('dash_hero'), same(TourTargets.keyFor('dash_hero')));
    expect(TourTargets.keyFor('dash_hero'),
        isNot(same(TourTargets.keyFor('dash_news'))));
    expect(TourTargets.rectOf('never_attached'), isNull);
  });
}
