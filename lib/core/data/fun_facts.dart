import 'dart:math' as math;

/// Curated "did you know" facts for the in-app fun-fact popup.
///
/// Mirrors `functions-node/src/funFacts.ts` (the server-side dataset used by
/// the daily push notification) so both surfaces show consistent content.
/// Each [lessonId] MUST match a real id in the Flutter app's
/// `_learningLessons` list (lib/presentation/screens/learn/learn_screen.dart)
/// so tapping "Learn more" opens a real lesson via `/learn/lesson/:id`.
enum FunFactCategory { crop, livestock, general }

class FunFact {
  const FunFact({
    required this.fact,
    required this.lessonId,
    required this.category,
  });

  final String fact;
  final String lessonId;
  final FunFactCategory category;
}

const List<FunFact> kFunFacts = <FunFact>[
  FunFact(
    fact:
        'Checking topsoil moisture first thing in the morning — before the sun warms it — gives the most accurate read on whether a field actually needs water today.',
    lessonId: 'soil-moisture',
    category: FunFactCategory.crop,
  ),
  FunFact(
    fact:
        'A thin layer of mulch over exposed beds can noticeably slow surface drying between waterings, stretching the time between irrigation rounds.',
    lessonId: 'soil-moisture',
    category: FunFactCategory.crop,
  ),
  FunFact(
    fact:
        "Spotting pest pressure early — before it spreads across beds — is far cheaper than treating an infestation that's already taken hold.",
    lessonId: 'crop-pest-scouting',
    category: FunFactCategory.crop,
  ),
  FunFact(
    fact:
        "A short pest-scouting walk through your crop rows a few times a week catches problems while they're still small and easy to manage.",
    lessonId: 'crop-pest-scouting',
    category: FunFactCategory.crop,
  ),
  FunFact(
    fact:
        'A simple dated vaccine calendar is one of the most reliable ways to avoid missed doses across a livestock group.',
    lessonId: 'livestock-vaccination',
    category: FunFactCategory.livestock,
  ),
  FunFact(
    fact:
        'Logging reactions, missed doses, and next steps right after a vaccination event makes follow-up far easier later.',
    lessonId: 'livestock-vaccination',
    category: FunFactCategory.livestock,
  ),
  FunFact(
    fact:
        'A steady feeding and watering routine — same times, same amounts — keeps livestock healthier than irregular feeding.',
    lessonId: 'feeding-and-grazing',
    category: FunFactCategory.livestock,
  ),
  FunFact(
    fact:
        'Consistent grazing and feed timing reduces stress on animals, which shows up in better growth and health over time.',
    lessonId: 'feeding-and-grazing',
    category: FunFactCategory.livestock,
  ),
  FunFact(
    fact:
        'Sometimes holding produce a little longer instead of selling immediately can mean a noticeably better price at market.',
    lessonId: 'market-timing',
    category: FunFactCategory.general,
  ),
  FunFact(
    fact:
        'Reading market timing well — knowing when to sell and when to hold stock — is a skill that pays off as much as the harvest itself.',
    lessonId: 'market-timing',
    category: FunFactCategory.general,
  ),
  FunFact(
    fact:
        'Using rain, temperature, and humidity forecasts to plan farm tasks ahead of time helps avoid wasted work on bad-weather days.',
    lessonId: 'weather-work-plan',
    category: FunFactCategory.general,
  ),
  FunFact(
    fact:
        "A quick look at the week's weather outlook before scheduling spraying, harvesting, or transport can save a lot of rework.",
    lessonId: 'weather-work-plan',
    category: FunFactCategory.general,
  ),
  FunFact(
    fact:
        'Careful post-harvest handling keeps produce fresher for longer between the field and the buyer, protecting the value of your harvest.',
    lessonId: 'post-harvest-handling',
    category: FunFactCategory.general,
  ),
  FunFact(
    fact:
        'Simple farm record keeping — income, expenses, and yields — often makes the difference when applying for finance or credit later.',
    lessonId: 'record-keeping',
    category: FunFactCategory.general,
  ),
  FunFact(
    fact:
        'Keeping a basic log of what was planted, spent, and sold turns guesswork into real decisions for next season.',
    lessonId: 'record-keeping',
    category: FunFactCategory.general,
  ),
];

FunFact pickRandomFunFact(FunFactCategory category) {
  final List<FunFact> inCategory = kFunFacts
      .where((FunFact entry) => entry.category == category)
      .toList(growable: false);
  final List<FunFact> pool = inCategory.isNotEmpty ? inCategory : kFunFacts;
  return pool[math.Random().nextInt(pool.length)];
}
