import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/livestock_planning.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../domain/models/farm.dart';
import '../../../domain/models/livestock.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/wizard/guided_wizard_screen.dart';
import '../../common/wizard/wizard_inputs.dart';
import '../../common/wizard/wizard_models.dart';
import 'livestock_screen.dart' show LivestockDraft;

/// Step-by-step livestock group creation. Pops with a [LivestockDraft],
/// exactly like the older single-sheet form, so saving works the same way.
class LivestockWizardScreen extends ConsumerStatefulWidget {
  /// Creates the wizard for the given [farms] (at least one).
  const LivestockWizardScreen({super.key, required this.farms});

  /// Farms the group can be linked to.
  final List<Farm> farms;

  @override
  ConsumerState<LivestockWizardScreen> createState() =>
      _LivestockWizardScreenState();
}

class _LivestockWizardScreenState extends ConsumerState<LivestockWizardScreen> {
  static const Map<LivestockSpecies, String> _emoji =
      <LivestockSpecies, String>{
    LivestockSpecies.goat: '🐐',
    LivestockSpecies.chicken: '🐔',
    LivestockSpecies.pig: '🐖',
    LivestockSpecies.cattle: '🐄',
    LivestockSpecies.sheep: '🐑',
    LivestockSpecies.rabbit: '🐇',
    LivestockSpecies.duck: '🦆',
    LivestockSpecies.fish: '🐟',
    LivestockSpecies.snail: '🐌',
  };

  static const Map<LivestockSpecies, LocalizedText> _speciesName =
      <LivestockSpecies, LocalizedText>{
    LivestockSpecies.goat: LocalizedText('Goats', ha: 'Awaki', fr: 'Chèvres'),
    LivestockSpecies.chicken:
        LocalizedText('Chickens', ha: 'Kaji', fr: 'Poulets'),
    LivestockSpecies.pig: LocalizedText('Pigs', ha: 'Aladu', fr: 'Porcs'),
    LivestockSpecies.cattle:
        LocalizedText('Cattle', ha: 'Shanu', fr: 'Bovins'),
    LivestockSpecies.sheep:
        LocalizedText('Sheep', ha: 'Tumaki', fr: 'Moutons'),
    LivestockSpecies.rabbit:
        LocalizedText('Rabbits', ha: 'Zomaye', fr: 'Lapins'),
    LivestockSpecies.duck:
        LocalizedText('Ducks', ha: 'Agwagwa', fr: 'Canards'),
    LivestockSpecies.fish: LocalizedText('Fish', ha: 'Kifi', fr: 'Poissons'),
    LivestockSpecies.snail:
        LocalizedText('Snails', ha: 'Katantanwa', fr: 'Escargots'),
  };

  static const List<WizardChoice<LivestockPurpose>> _purposeChoices =
      <WizardChoice<LivestockPurpose>>[
    WizardChoice<LivestockPurpose>(
      value: LivestockPurpose.meat,
      emoji: '🥩',
      label: LocalizedText('Meat', ha: 'Nama', fr: 'Viande'),
      hint: LocalizedText(
        'Raised to sell or eat',
        ha: 'Ana kiwo don sayarwa ko ci',
        fr: 'Élevés pour la vente ou la consommation',
      ),
    ),
    WizardChoice<LivestockPurpose>(
      value: LivestockPurpose.milk,
      emoji: '🥛',
      label: LocalizedText('Milk', ha: 'Madara', fr: 'Lait'),
      hint: LocalizedText(
        'Kept for milk every day',
        ha: 'Ana kiwo don madara kullum',
        fr: 'Gardés pour le lait quotidien',
      ),
    ),
    WizardChoice<LivestockPurpose>(
      value: LivestockPurpose.eggs,
      emoji: '🥚',
      label: LocalizedText('Eggs', ha: 'Ƙwai', fr: 'Œufs'),
      hint: LocalizedText(
        'Kept for laying eggs',
        ha: 'Ana kiwo don yin ƙwai',
        fr: 'Gardés pour pondre des œufs',
      ),
    ),
    WizardChoice<LivestockPurpose>(
      value: LivestockPurpose.breeding,
      emoji: '🍼',
      label: LocalizedText('Breeding', ha: 'Hayayyafa', fr: 'Reproduction'),
      hint: LocalizedText(
        'Kept to produce young ones',
        ha: 'Ana kiwo don haihuwa',
        fr: 'Gardés pour avoir des petits',
      ),
    ),
  ];

  static const List<WizardChoice<HousingType>> _housingChoices =
      <WizardChoice<HousingType>>[
    WizardChoice<HousingType>(
      value: HousingType.freeRange,
      emoji: '🌳',
      label: LocalizedText('Free range', ha: 'Yawo a waje', fr: 'En liberté'),
      hint: LocalizedText(
        'Roam outside during the day',
        ha: 'Suna yawo a waje da rana',
        fr: 'Se promènent dehors le jour',
      ),
    ),
    WizardChoice<HousingType>(
      value: HousingType.barn,
      emoji: '🏚️',
      label: LocalizedText('Barn', ha: 'Rumfa', fr: 'Grange'),
      hint: LocalizedText(
        'A large covered building',
        ha: 'Babban gini mai rufi',
        fr: 'Grand bâtiment couvert',
      ),
    ),
    WizardChoice<HousingType>(
      value: HousingType.shed,
      emoji: '🛖',
      label: LocalizedText('Shed', ha: 'Bukka', fr: 'Abri'),
      hint: LocalizedText(
        'A simple shelter',
        ha: 'Matsuguni mai sauƙi',
        fr: 'Un abri simple',
      ),
    ),
    WizardChoice<HousingType>(
      value: HousingType.coop,
      emoji: '🐓',
      label: LocalizedText('Coop or hutch', ha: 'Keji', fr: 'Poulailler ou clapier'),
      hint: LocalizedText(
        'A small cage-style house',
        ha: 'Ƙaramin gida irin keji',
        fr: 'Petit logement type cage',
      ),
    ),
  ];

  static const List<WizardChoice<AnimalGrowthStage>> _stageChoices =
      <WizardChoice<AnimalGrowthStage>>[
    WizardChoice<AnimalGrowthStage>(
      value: AnimalGrowthStage.starter,
      emoji: '🐣',
      label: LocalizedText('Young starters', ha: 'Ƙanana', fr: 'Jeunes'),
      hint: LocalizedText(
        'Just born or very small',
        ha: 'Sabbin haihuwa ko ƙanana sosai',
        fr: 'Nouveau-nés ou très petits',
      ),
    ),
    WizardChoice<AnimalGrowthStage>(
      value: AnimalGrowthStage.grower,
      emoji: '🌱',
      label: LocalizedText('Growing', ha: 'Girma', fr: 'En croissance'),
      hint: LocalizedText(
        'Getting bigger every week',
        ha: 'Suna girma kowane mako',
        fr: 'Grandissent chaque semaine',
      ),
    ),
    WizardChoice<AnimalGrowthStage>(
      value: AnimalGrowthStage.mature,
      emoji: '💪',
      label: LocalizedText('Fully grown', ha: 'Manya', fr: 'Adultes'),
      hint: LocalizedText(
        'Adult size',
        ha: 'Girman babba',
        fr: 'Taille adulte',
      ),
    ),
    WizardChoice<AnimalGrowthStage>(
      value: AnimalGrowthStage.breeding,
      emoji: '🍼',
      label: LocalizedText('Breeding stock', ha: 'Na kiwo', fr: 'Reproducteurs'),
      hint: LocalizedText(
        'Used to produce young',
        ha: 'Ana amfani da su wajen haihuwa',
        fr: 'Utilisés pour la reproduction',
      ),
    ),
    WizardChoice<AnimalGrowthStage>(
      value: AnimalGrowthStage.finishing,
      emoji: '⚖️',
      label: LocalizedText(
        'Being fattened',
        ha: 'Ana ƙara kiba',
        fr: 'En engraissement',
      ),
      hint: LocalizedText(
        'Getting ready for market',
        ha: 'Ana shirya su don kasuwa',
        fr: 'Préparés pour le marché',
      ),
    ),
  ];

  // Value is the health score stored for the group.
  static const List<WizardChoice<int>> _healthChoices = <WizardChoice<int>>[
    WizardChoice<int>(
      value: 95,
      emoji: '😀',
      label: LocalizedText('Very good', ha: 'Lafiya ƙalau', fr: 'Très bonne'),
      hint: LocalizedText(
        'All look strong and active',
        ha: 'Duka suna da ƙarfi da walwala',
        fr: 'Tous semblent forts et actifs',
      ),
    ),
    WizardChoice<int>(
      value: 80,
      emoji: '🙂',
      label: LocalizedText('Fine', ha: 'Lafiya', fr: 'Correcte'),
      hint: LocalizedText(
        'A few minor concerns',
        ha: 'Ƙananan matsaloli kaɗan',
        fr: 'Quelques petits soucis',
      ),
    ),
    WizardChoice<int>(
      value: 55,
      emoji: '😕',
      label: LocalizedText('Weak', ha: 'Raunana', fr: 'Fragile'),
      hint: LocalizedText(
        'Some look thin or slow',
        ha: 'Wasu sun rame ko suna sanyi',
        fr: 'Certains semblent maigres ou lents',
      ),
    ),
    WizardChoice<int>(
      value: 30,
      emoji: '🚑',
      label: LocalizedText('Poor', ha: 'Mara kyau', fr: 'Mauvaise'),
      hint: LocalizedText(
        'Several sick, hurt or lost',
        ha: 'Da dama marasa lafiya, an ji musu rauni ko sun mutu',
        fr: 'Plusieurs malades, blessés ou perdus',
      ),
    ),
  ];

  // Value is the vaccination percentage stored for the group.
  static const List<WizardChoice<int>> _vaccinationChoices =
      <WizardChoice<int>>[
    WizardChoice<int>(
      value: 100,
      emoji: '✅',
      label: LocalizedText('All of them', ha: 'Dukansu', fr: 'Tous'),
      hint: LocalizedText(
        'Every animal is vaccinated',
        ha: 'Kowace dabba an yi mata allura',
        fr: 'Chaque animal est vacciné',
      ),
    ),
    WizardChoice<int>(
      value: 75,
      emoji: '💉',
      label: LocalizedText('Most', ha: 'Mafi yawa', fr: 'La plupart'),
      hint: LocalizedText(
        'Around three out of four',
        ha: 'Kusan uku cikin huɗu',
        fr: 'Environ trois sur quatre',
      ),
    ),
    WizardChoice<int>(
      value: 40,
      emoji: '🩹',
      label: LocalizedText('Some', ha: 'Wasu', fr: 'Quelques-uns'),
      hint: LocalizedText(
        'Less than half',
        ha: 'Ƙasa da rabi',
        fr: 'Moins de la moitié',
      ),
    ),
    WizardChoice<int>(
      value: 0,
      emoji: '⏳',
      label: LocalizedText('Not yet', ha: 'Ba tukuna', fr: 'Pas encore'),
      hint: LocalizedText(
        'None vaccinated so far',
        ha: 'Ba a yi wa kowa ba tukuna',
        fr: 'Aucun vacciné pour l’instant',
      ),
    ),
  ];

  final TextEditingController _breed = TextEditingController();
  final TextEditingController _value = TextEditingController();
  final TextEditingController _maturity = TextEditingController();
  final TextEditingController _feed = TextEditingController();
  final TextEditingController _water = TextEditingController();
  final TextEditingController _weight = TextEditingController();

  late String _farmId;
  LivestockSpecies _species = LivestockSpecies.goat;
  LivestockPurpose _purpose = LivestockPurpose.meat;
  HousingType _housing = HousingType.shed;
  AnimalGrowthStage _stage = AnimalGrowthStage.grower;
  DateTime _acquired = DateTime.now();
  int _count = 10;
  int _males = 0;
  int _females = 0;
  int _ageMonths = 3;
  int _health = 80;
  int _vaccination = 75;

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
  }

  @override
  void dispose() {
    _breed.dispose();
    _value.dispose();
    _maturity.dispose();
    _feed.dispose();
    _water.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  double? _decimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  // Money follows the rest of the app: commas are thousands separators.
  double? _money(String text) =>
      double.tryParse(text.replaceAll('₦', '').replaceAll(',', '').trim());

  Farm get _farm => widget.farms.firstWhere((Farm f) => f.id == _farmId);

  int get _suggestedMaturity => LivestockPlanning.suggestedMaturityMonths(
      _species, _purpose, _ageMonths, _stage);
  double get _suggestedFeed =>
      LivestockPlanning.feedPerAnimalKg(_species, _stage, _ageMonths, _purpose) *
      _count;
  double get _suggestedWater => LivestockPlanning.waterPerAnimalLitres(
          _species, _stage, _ageMonths, _purpose) *
      _count;

  // Something the farmer typed wins; an empty box uses our suggestion.
  int get _maturityMonths => _maturity.text.trim().isEmpty
      ? _suggestedMaturity
      : (int.tryParse(_maturity.text.trim()) ?? _suggestedMaturity);
  double get _feedKg => _feed.text.trim().isEmpty
      ? _suggestedFeed
      : (_decimal(_feed.text) ?? _suggestedFeed);
  double get _waterLitres => _water.text.trim().isEmpty
      ? _suggestedWater
      : (_decimal(_water.text) ?? _suggestedWater);
  double get _weightKg =>
      _weight.text.trim().isEmpty ? 0 : (_decimal(_weight.text) ?? 0);
  double get _estimatedValue =>
      _value.text.trim().isEmpty ? 0 : (_money(_value.text) ?? 0);

  String _date(DateTime value) => DateFormat('d MMM yyyy').format(value);

  String _num(double value) =>
      value >= 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);

  String _labelOf<T>(
    List<WizardChoice<T>> choices,
    T value,
    AppLanguage language,
  ) =>
      choices
          .firstWhere((WizardChoice<T> c) => c.value == value)
          .label
          .resolve(language);

  String _suggested(AppLanguage language, String value) => language.tr(
        en: 'Suggested: $value',
        ha: 'Shawara: $value',
        fr: 'Suggestion : $value',
      );

  void _finish() {
    Navigator.of(context).pop(
      LivestockDraft(
        farmId: _farmId,
        species: _species,
        breed: _breed.text.trim(),
        count: _count,
        maleCount: _males,
        femaleCount: _females,
        purpose: _purpose,
        housingLocation: _housing,
        acquisitionDate: _acquired,
        estimatedValue: _estimatedValue,
        vaccinationStatus: _vaccination,
        healthScore: _health,
        growthStage: _stage,
        averageAgeMonths: _ageMonths,
        targetMaturityMonths: _maturityMonths,
        mortalityCount: 0,
        emoji: _emoji[_species] ?? '🐾',
        coverImageBase64: '',
        coverImageName: '',
        averageWeightKg: _weightKg,
        dailyFeedKg: _feedKg,
        dailyWaterLitres: _waterLitres,
      ),
    );
  }

  LocalizedText? _validateBreed() {
    if (_breed.text.trim().isEmpty) {
      return const LocalizedText(
        'Please enter the breed, or tap “Local breed”.',
        ha: 'Da fatan za ka shigar da irin, ko ka danna “Iri na gida”.',
        fr: 'Veuillez saisir la race, ou touchez « Race locale ».',
      );
    }
    return null;
  }

  LocalizedText? _validateCount() {
    if (_count <= 0) {
      return const LocalizedText(
        'You need at least one animal.',
        ha: 'Dole a samu aƙalla dabba ɗaya.',
        fr: 'Il faut au moins un animal.',
      );
    }
    if (_males + _females > _count) {
      return const LocalizedText(
        'Males and females together cannot be more than the total.',
        ha: 'Adadin maza da mata tare ba zai wuce jimilla ba.',
        fr: 'Mâles et femelles ensemble ne peuvent pas dépasser le total.',
      );
    }
    return null;
  }

  LocalizedText? _validateValue() {
    final String text = _value.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final double? amount = _money(text);
    if (amount == null || amount < 0) {
      return const LocalizedText(
        'Please enter a valid amount, like 250000.',
        ha: 'Da fatan za ka shigar da adadin kuɗi mai inganci, misali 250000.',
        fr: 'Veuillez saisir un montant valide, par exemple 250000.',
      );
    }
    return null;
  }

  LocalizedText? _validatePlan() {
    final String maturity = _maturity.text.trim();
    if (maturity.isNotEmpty) {
      final int? months = int.tryParse(maturity);
      if (months == null || months <= 0 || months > 240) {
        return const LocalizedText(
          'Enter the months as a whole number, like 12.',
          ha: 'Shigar da watanni a matsayin cikakkiyar lamba, misali 12.',
          fr: 'Saisissez les mois en nombre entier, par exemple 12.',
        );
      }
    }
    for (final TextEditingController c in <TextEditingController>[
      _feed,
      _water,
      _weight,
    ]) {
      final String text = c.text.trim();
      if (text.isEmpty) {
        continue;
      }
      final double? number = _decimal(text);
      if (number == null || number < 0) {
        return const LocalizedText(
          'Please enter valid numbers, like 1.5.',
          ha: 'Da fatan za ka shigar da lambobi masu inganci, misali 1.5.',
          fr: 'Veuillez saisir des nombres valides, par exemple 1.5.',
        );
      }
    }
    return null;
  }

  List<WizardStep> _steps(AppLanguage language) {
    final bool manyFarms = widget.farms.length > 1;
    final LocalizedText speciesName = _speciesName[_species]!;

    return <WizardStep>[
      if (manyFarms)
        WizardStep(
          id: 'farm',
          icon: Icons.agriculture_rounded,
          image: 'assets/ui/farm.jpeg',
          title: const LocalizedText(
            'Which farm are they on?',
            ha: 'A wace gona suke?',
            fr: 'Sur quelle ferme sont-ils ?',
          ),
          why: const LocalizedText(
            'Linking the animals to a farm keeps their housing, health and value records in the right place.',
            ha: 'Haɗa dabbobin da gona yana sanya bayanan mazauninsu, lafiya da daraja a wurin da ya dace.',
            fr: 'Lier les animaux à une ferme range logement, santé et valeur au bon endroit.',
          ),
          builder: (BuildContext context) => WizardChoiceGrid<String>(
            columns: 1,
            language: language,
            selected: _farmId,
            choices: <WizardChoice<String>>[
              for (final Farm farm in widget.farms)
                WizardChoice<String>(
                  value: farm.id,
                  emoji: '🌾',
                  label: LocalizedText(farm.name),
                  hint: LocalizedText(
                      '${farm.ward} · ${farm.sizeHa.toStringAsFixed(1)} ha'),
                ),
            ],
            onSelected: (String id) => setState(() => _farmId = id),
          ),
        ),
      WizardStep(
        id: 'species',
        icon: Icons.pets_rounded,
        image: 'assets/ui/farmers.jpeg',
        title: const LocalizedText(
          'What animals do you keep?',
          ha: 'Waɗanne dabbobi kake kiwo?',
          fr: 'Quels animaux élevez-vous ?',
        ),
        why: const LocalizedText(
          'Each animal needs different feed, water, housing and vaccines. Your choice lets us suggest the right ones.',
          ha: 'Kowace dabba tana buƙatar abinci, ruwa, muhalli da alluran rigakafi daban. Zaɓinka yana ba mu damar ba da shawarwari masu dacewa.',
          fr: 'Chaque animal a besoin d’aliments, d’eau, de logement et de vaccins différents. Votre choix nous permet de suggérer les bons.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<LivestockSpecies>(
          language: language,
          selected: _species,
          choices: <WizardChoice<LivestockSpecies>>[
            for (final LivestockSpecies species in LivestockSpecies.values)
              WizardChoice<LivestockSpecies>(
                value: species,
                emoji: _emoji[species],
                label: _speciesName[species]!,
              ),
          ],
          onSelected: (LivestockSpecies value) =>
              setState(() => _species = value),
        ),
      ),
      WizardStep(
        id: 'purpose',
        icon: Icons.flag_rounded,
        image: 'assets/ui/produce_market.jpeg',
        title: const LocalizedText(
          'Why do you keep them?',
          ha: 'Me ya sa kake kiwonsu?',
          fr: 'Pourquoi les élevez-vous ?',
        ),
        why: const LocalizedText(
          'The purpose decides how long they take to be ready and how we plan feed and care.',
          ha: 'Dalilin kiwo yana tantance tsawon lokacin da za su shirya da yadda muke tsara abinci da kulawa.',
          fr: 'L’objectif détermine le temps avant qu’ils soient prêts et la façon dont nous planifions l’alimentation et les soins.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<LivestockPurpose>(
          choices: _purposeChoices,
          selected: _purpose,
          language: language,
          onSelected: (LivestockPurpose value) =>
              setState(() => _purpose = value),
        ),
      ),
      WizardStep(
        id: 'breed',
        icon: Icons.label_rounded,
        image: 'assets/ui/farmers.jpeg',
        title: const LocalizedText(
          'What breed are they?',
          ha: 'Wane irin ne su?',
          fr: 'De quelle race sont-ils ?',
        ),
        why: const LocalizedText(
          'Breed helps you tell your groups apart and understand how big they grow.',
          ha: 'Irin dabba yana taimaka maka bambance ƙungiyoyinka da fahimtar girmansu.',
          fr: 'La race aide à distinguer vos groupes et à comprendre leur taille adulte.',
        ),
        tip: const LocalizedText(
          'Not sure? Tap “Local breed”.',
          ha: 'Ba ka da tabbas? Danna “Iri na gida”.',
          fr: 'Pas sûr ? Touchez « Race locale ».',
        ),
        validate: _validateBreed,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _breed,
              label: language.tr(en: 'Breed', ha: 'Iri', fr: 'Race'),
              hint: 'West African Dwarf',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                avatar: const Icon(Icons.home_rounded, size: 18),
                label: Text(language.tr(
                    en: 'Local breed', ha: 'Iri na gida', fr: 'Race locale')),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _breed.text = 'Local');
                },
              ),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'count',
        icon: Icons.numbers_rounded,
        image: 'assets/ui/farm_landscape.jpeg',
        title: LocalizedText(
          'How many ${speciesName.en.toLowerCase()}?',
          ha: 'Nawa ne ${speciesName.resolve(AppLanguage.hausa).toLowerCase()}?',
          fr: 'Combien de ${speciesName.resolve(AppLanguage.french).toLowerCase()} ?',
        ),
        why: const LocalizedText(
          'Use + and − or the quick buttons. If you know how many are male and female, add that too; otherwise leave them at 0.',
          ha: 'Yi amfani da + da − ko maɓallan sauri. Idan ka san adadin maza da mata, ƙara shi; in ba haka ba, bar su a 0.',
          fr: 'Utilisez + et − ou les boutons rapides. Si vous connaissez le nombre de mâles et de femelles, ajoutez-le ; sinon laissez 0.',
        ),
        validate: _validateCount,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            WizardCounter(
              label: const LocalizedText(
                'Total animals',
                ha: 'Jimillar dabbobi',
                fr: 'Total d’animaux',
              ),
              icon: Icons.groups_rounded,
              value: _count,
              language: language,
              min: 1,
              quickAdds: const <int>[5, 10, 50],
              onChanged: (int v) => setState(() => _count = v),
            ),
            const SizedBox(height: 12),
            WizardCounter(
              label: const LocalizedText('Males', ha: 'Maza', fr: 'Mâles'),
              icon: Icons.male_rounded,
              value: _males,
              language: language,
              quickAdds: const <int>[5],
              onChanged: (int v) => setState(() => _males = v),
            ),
            const SizedBox(height: 12),
            WizardCounter(
              label: const LocalizedText('Females', ha: 'Mata', fr: 'Femelles'),
              icon: Icons.female_rounded,
              value: _females,
              language: language,
              quickAdds: const <int>[5],
              onChanged: (int v) => setState(() => _females = v),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'age',
        icon: Icons.cake_rounded,
        image: 'assets/ui/leaf_field.jpeg',
        title: const LocalizedText(
          'How old are they?',
          ha: 'Shekarunsu nawa?',
          fr: 'Quel âge ont-ils ?',
        ),
        why: const LocalizedText(
          'Age and growth stage decide how much they eat and drink and when they will be ready.',
          ha: 'Shekaru da matakin girma suna tantance yawan ci da shansu da lokacin da za su shirya.',
          fr: 'L’âge et le stade de croissance déterminent ce qu’ils mangent, boivent et quand ils seront prêts.',
        ),
        tip: const LocalizedText(
          'Give the average age in months. Under one month? Leave it at 0.',
          ha: 'Ba da matsakaicin shekaru a watanni. Bai kai wata ɗaya ba? Bar shi a 0.',
          fr: 'Indiquez l’âge moyen en mois. Moins d’un mois ? Laissez 0.',
        ),
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            WizardCounter(
              label: const LocalizedText(
                'Average age (months)',
                ha: 'Matsakaicin shekaru (watanni)',
                fr: 'Âge moyen (mois)',
              ),
              icon: Icons.cake_rounded,
              value: _ageMonths,
              language: language,
              max: 240,
              quickAdds: const <int>[1, 6],
              onChanged: (int v) => setState(() => _ageMonths = v),
            ),
            const SizedBox(height: 16),
            WizardChoiceGrid<AnimalGrowthStage>(
              choices: _stageChoices,
              selected: _stage,
              language: language,
              columns: 1,
              onSelected: (AnimalGrowthStage v) => setState(() => _stage = v),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'housing',
        icon: Icons.home_work_rounded,
        image: 'assets/ui/farm.jpeg',
        title: const LocalizedText(
          'Where do they stay?',
          ha: 'A ina suke zama?',
          fr: 'Où logent-ils ?',
        ),
        why: const LocalizedText(
          'Housing affects health and the care they need, such as dry litter, ventilation and shade.',
          ha: 'Muhalli yana shafar lafiya da kulawar da suke buƙata, kamar busasshen bargo, iska da inuwa.',
          fr: 'Le logement influe sur la santé et les soins, comme la litière sèche, la ventilation et l’ombre.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<HousingType>(
          choices: _housingChoices,
          selected: _housing,
          language: language,
          onSelected: (HousingType v) => setState(() => _housing = v),
        ),
      ),
      WizardStep(
        id: 'acquired',
        icon: Icons.event_rounded,
        image: 'assets/ui/produce_market.jpeg',
        title: const LocalizedText(
          'When did you get them, and what are they worth?',
          ha: 'Yaushe ka same su, kuma nawa ne darajarsu?',
          fr: 'Quand les avez-vous eus, et combien valent-ils ?',
        ),
        why: const LocalizedText(
          'The date starts their record. The value helps you see how your herd or flock grows your wealth. A rough guess is fine.',
          ha: 'Ranar ita ce farkon bayanansu. Daraja yana taimaka maka ganin yadda dabbobinka ke ƙara maka arziki. Ƙiyasi kawai ya isa.',
          fr: 'La date ouvre leur dossier. La valeur montre comment votre troupeau fait croître votre richesse. Une estimation suffit.',
        ),
        tip: const LocalizedText(
          'Not sure of the value? Leave it empty and add it later.',
          ha: 'Ba ka da tabbacin darajar? Bar shi babu komai ka ƙara daga baya.',
          fr: 'Valeur incertaine ? Laissez vide et ajoutez-la plus tard.',
        ),
        validate: _validateValue,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            WizardDateField(
              label: const LocalizedText(
                'Date acquired',
                ha: 'Ranar samu',
                fr: 'Date d’acquisition',
              ),
              value: _acquired,
              language: language,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              onChanged: (DateTime v) => setState(() => _acquired = v),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _value,
              label: language.tr(
                en: 'Estimated value of the group (₦)',
                ha: 'Ƙiyasin darajar ƙungiyar (₦)',
                fr: 'Valeur estimée du groupe (₦)',
              ),
              hint: '250000',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _rebuild(),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'health',
        icon: Icons.favorite_rounded,
        image: 'assets/ui/smart_farm.jpeg',
        title: const LocalizedText(
          'How healthy are they?',
          ha: 'Lafiyarsu ta yaya?',
          fr: 'Sont-ils en bonne santé ?',
        ),
        why: const LocalizedText(
          'Tell us how they look today and how many are vaccinated. We use this to remind you about vaccines and health checks.',
          ha: 'Gaya mana yadda suke a yau da yawan waɗanda aka yi wa allurar rigakafi. Muna amfani da wannan wajen tunatar da kai game da alluran rigakafi da duba lafiya.',
          fr: 'Dites-nous comment ils se portent aujourd’hui et combien sont vaccinés. Cela nous sert à vous rappeler vaccins et contrôles.',
        ),
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              language.tr(
                en: 'How do they look right now?',
                ha: 'Yaya suke kama a yanzu?',
                fr: 'Comment se portent-ils en ce moment ?',
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            WizardChoiceGrid<int>(
              choices: _healthChoices,
              selected: _health,
              language: language,
              onSelected: (int v) => setState(() => _health = v),
            ),
            const SizedBox(height: 18),
            Text(
              language.tr(
                en: 'How many have had vaccines?',
                ha: 'Nawa aka yi wa allurar rigakafi?',
                fr: 'Combien ont reçu des vaccins ?',
              ),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            WizardChoiceGrid<int>(
              choices: _vaccinationChoices,
              selected: _vaccination,
              language: language,
              onSelected: (int v) => setState(() => _vaccination = v),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'plan',
        icon: Icons.insights_rounded,
        image: 'assets/ui/field_sprayer.jpeg',
        title: const LocalizedText(
          'Feeding and growth plan',
          ha: 'Shirin abinci da girma',
          fr: 'Plan d’alimentation et de croissance',
        ),
        why: const LocalizedText(
          'From the animal, age and number you gave, we worked out daily feed and water for the whole group and when they will be mature. Keep our numbers or type your own.',
          ha: 'Daga dabba, shekaru da adadin da ka bayar, mun lissafa abincin yau da kullum da ruwa ga dukan ƙungiyar da lokacin da za su girma. Ka bar lambobinmu ko ka rubuta naka.',
          fr: 'À partir de l’animal, de l’âge et du nombre indiqués, nous avons calculé l’aliment et l’eau quotidiens du groupe et l’âge de maturité. Gardez nos chiffres ou saisissez les vôtres.',
        ),
        validate: _validatePlan,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _feed,
              label: language.tr(
                en: 'Daily feed for the group (kg)',
                ha: 'Abincin yau da kullum na ƙungiya (kg)',
                fr: 'Aliment quotidien du groupe (kg)',
              ),
              hint: _suggested(language, _num(_suggestedFeed)),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _water,
              label: language.tr(
                en: 'Daily water for the group (litres)',
                ha: 'Ruwan yau da kullum na ƙungiya (lita)',
                fr: 'Eau quotidienne du groupe (litres)',
              ),
              hint: _suggested(language, _num(_suggestedWater)),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: _maturity,
                    label: language.tr(
                      en: 'Months to maturity',
                      ha: 'Watanni zuwa girma',
                      fr: 'Mois avant maturité',
                    ),
                    hint: _suggested(language, '$_suggestedMaturity'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _rebuild(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _weight,
                    label: language.tr(
                      en: 'Average weight (kg)',
                      ha: 'Matsakaicin nauyi (kg)',
                      fr: 'Poids moyen (kg)',
                    ),
                    hint: language.tr(
                        en: 'Optional', ha: 'Na zaɓi', fr: 'Facultatif'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _rebuild(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'review',
        icon: Icons.fact_check_rounded,
        image: 'assets/ui/farm produce.jpeg',
        title: const LocalizedText(
          'Check your group',
          ha: 'Duba ƙungiyar dabbobinka',
          fr: 'Vérifiez votre groupe',
        ),
        why: const LocalizedText(
          'Make sure everything looks right. Use Back to change anything. You can also edit it later.',
          ha: 'Ka tabbatar komai daidai ne. Yi amfani da Koma baya don canza kowane abu. Za ka iya gyarawa daga baya ma.',
          fr: 'Vérifiez que tout est correct. Utilisez Retour pour modifier. Vous pourrez aussi le faire plus tard.',
        ),
        builder: (BuildContext context) => WizardReviewCard(
          language: language,
          items: <WizardReviewItem>[
            if (manyFarms)
              WizardReviewItem(
                icon: Icons.agriculture_rounded,
                label: const LocalizedText('Farm', ha: 'Gona', fr: 'Ferme'),
                value: _farm.name,
              ),
            WizardReviewItem(
              icon: Icons.pets_rounded,
              label: const LocalizedText('Animals', ha: 'Dabbobi', fr: 'Animaux'),
              value:
                  '${_emoji[_species]} ${speciesName.resolve(language)} · $_count',
            ),
            WizardReviewItem(
              icon: Icons.label_rounded,
              label: const LocalizedText('Breed', ha: 'Iri', fr: 'Race'),
              value: _breed.text.trim(),
            ),
            WizardReviewItem(
              icon: Icons.flag_rounded,
              label: const LocalizedText('Purpose', ha: 'Manufa', fr: 'Objectif'),
              value: _labelOf(_purposeChoices, _purpose, language),
            ),
            WizardReviewItem(
              icon: Icons.cake_rounded,
              label: const LocalizedText('Age and stage', ha: 'Shekaru da mataki', fr: 'Âge et stade'),
              value:
                  '${language.tr(en: '$_ageMonths months', ha: 'watanni $_ageMonths', fr: '$_ageMonths mois')} · ${_labelOf(_stageChoices, _stage, language)}',
            ),
            WizardReviewItem(
              icon: Icons.home_work_rounded,
              label: const LocalizedText('Housing', ha: 'Muhalli', fr: 'Logement'),
              value: _labelOf(_housingChoices, _housing, language),
            ),
            WizardReviewItem(
              icon: Icons.event_rounded,
              label: const LocalizedText('Acquired', ha: 'An samu', fr: 'Acquis le'),
              value: _date(_acquired),
            ),
            WizardReviewItem(
              icon: Icons.payments_rounded,
              label: const LocalizedText('Value', ha: 'Daraja', fr: 'Valeur'),
              value: CurrencyUtils.formatCurrency(_estimatedValue),
            ),
            WizardReviewItem(
              icon: Icons.favorite_rounded,
              label: const LocalizedText('Health', ha: 'Lafiya', fr: 'Santé'),
              value: _labelOf(_healthChoices, _health, language),
            ),
            WizardReviewItem(
              icon: Icons.vaccines_rounded,
              label: const LocalizedText('Vaccinated', ha: 'An yi allura', fr: 'Vaccinés'),
              value: _labelOf(_vaccinationChoices, _vaccination, language),
            ),
            WizardReviewItem(
              icon: Icons.restaurant_rounded,
              label: const LocalizedText(
                  'Feed and water per day', ha: 'Abinci da ruwa a rana', fr: 'Aliment et eau par jour'),
              value: '${_num(_feedKg)} kg · ${_num(_waterLitres)} L',
            ),
            WizardReviewItem(
              icon: Icons.hourglass_bottom_rounded,
              label: const LocalizedText(
                  'Mature in about', ha: 'Za su girma cikin kusan', fr: 'Matures dans environ'),
              value: language.tr(
                en: '$_maturityMonths months',
                ha: 'watanni $_maturityMonths',
                fr: '$_maturityMonths mois',
              ),
            ),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLanguage language = ref.watch(appLanguageProvider);

    return GuidedWizard(
      title: const LocalizedText(
        'New animal group',
        ha: 'Sabuwar ƙungiyar dabbobi',
        fr: 'Nouveau groupe d’animaux',
      ),
      finishLabel: const LocalizedText(
        'Add group',
        ha: 'Ƙara ƙungiya',
        fr: 'Ajouter le groupe',
      ),
      steps: _steps(language),
      onFinish: _finish,
    );
  }
}
