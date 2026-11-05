import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/farm_planning.dart';
import '../../../domain/models/farm.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/wizard/guided_wizard_screen.dart';
import '../../common/wizard/wizard_inputs.dart';
import '../../common/wizard/wizard_models.dart';
import 'farms_screen.dart' show FarmDraft;

/// Step-by-step farm creation. Pops with a [FarmDraft], exactly like the
/// older single-sheet form, so saving works the same way.
class FarmWizardScreen extends ConsumerStatefulWidget {
  /// Creates the wizard.
  const FarmWizardScreen({super.key});

  @override
  ConsumerState<FarmWizardScreen> createState() => _FarmWizardScreenState();
}

class _FarmWizardScreenState extends ConsumerState<FarmWizardScreen> {
  static const List<WizardChoice<FarmType>> _typeChoices =
      <WizardChoice<FarmType>>[
    WizardChoice<FarmType>(
      value: FarmType.crop,
      emoji: '🌾',
      label: LocalizedText('Crops', ha: 'Amfanin gona', fr: 'Cultures'),
      hint: LocalizedText(
        'Maize, yam, vegetables and other plants',
        ha: 'Masara, doya, kayan lambu da sauran tsirrai',
        fr: 'Maïs, igname, légumes et autres plantes',
      ),
    ),
    WizardChoice<FarmType>(
      value: FarmType.livestock,
      emoji: '🐄',
      label: LocalizedText('Animals', ha: 'Dabbobi', fr: 'Élevage'),
      hint: LocalizedText(
        'Goats, sheep, cattle, poultry, pigs',
        ha: 'Awaki, tumaki, shanu, kaji, aladu',
        fr: 'Chèvres, moutons, bovins, volaille, porcs',
      ),
    ),
    WizardChoice<FarmType>(
      value: FarmType.greenhouse,
      emoji: '🌿',
      label: LocalizedText('Greenhouse', ha: 'Gidan kore', fr: 'Serre'),
      hint: LocalizedText(
        'Plants grown under cover',
        ha: 'Tsirrai da ake nomawa a gida mai rufi',
        fr: 'Cultures sous abri',
      ),
    ),
    WizardChoice<FarmType>(
      value: FarmType.combined,
      emoji: '🚜',
      label: LocalizedText(
        'Crops and animals',
        ha: 'Amfanin gona da dabbobi',
        fr: 'Cultures et élevage',
      ),
      hint: LocalizedText(
        'A mixed farm, maybe with a greenhouse too',
        ha: 'Gona mai hade, watakila da gidan kore',
        fr: 'Une ferme mixte, peut-être avec une serre',
      ),
    ),
  ];

  static const List<WizardChoice<FarmerCategory>> _categoryChoices =
      <WizardChoice<FarmerCategory>>[
    WizardChoice<FarmerCategory>(
      value: FarmerCategory.subsistence,
      emoji: '🍽️',
      label: LocalizedText('For my family', ha: 'Don iyalina', fr: 'Pour ma famille'),
      hint: LocalizedText(
        'Mostly to feed my household',
        ha: 'Galibi don ciyar da gidana',
        fr: 'Surtout pour nourrir mon foyer',
      ),
    ),
    WizardChoice<FarmerCategory>(
      value: FarmerCategory.semiCommercial,
      emoji: '🧺',
      label: LocalizedText(
        'Family and sale',
        ha: 'Iyali da sayarwa',
        fr: 'Famille et vente',
      ),
      hint: LocalizedText(
        'Feed my household and sell the extra',
        ha: 'Ciyar da gida in sayar da ragowar',
        fr: 'Nourrir mon foyer et vendre le surplus',
      ),
    ),
    WizardChoice<FarmerCategory>(
      value: FarmerCategory.marketOriented,
      emoji: '🏪',
      label: LocalizedText('For the market', ha: 'Don kasuwa', fr: 'Pour le marché'),
      hint: LocalizedText(
        'Mainly to sell and earn income',
        ha: 'Galibi don sayarwa a samu kuɗi',
        fr: 'Surtout pour vendre et gagner un revenu',
      ),
    ),
  ];

  static const List<WizardChoice<SoilType>> _soilChoices =
      <WizardChoice<SoilType>>[
    WizardChoice<SoilType>(
      value: SoilType.clay,
      emoji: '🧱',
      label: LocalizedText('Clay', ha: 'Yumɓu (clay)', fr: 'Argile'),
      hint: LocalizedText(
        'Sticky when wet, hard when dry. Holds water.',
        ha: 'Tana mannewa idan ta jike, ta yi tauri idan ta bushe. Tana riƙe ruwa.',
        fr: 'Collante mouillé, dure sèche. Retient l’eau.',
      ),
    ),
    WizardChoice<SoilType>(
      value: SoilType.sandy,
      emoji: '🏖️',
      label: LocalizedText('Sandy', ha: 'Yashi (sandy)', fr: 'Sableux'),
      hint: LocalizedText(
        'Gritty and loose. Water drains fast.',
        ha: 'Mai yashi da sako-sako. Ruwa yana wucewa da sauri.',
        fr: 'Granuleux et meuble. L’eau s’écoule vite.',
      ),
    ),
    WizardChoice<SoilType>(
      value: SoilType.loamy,
      emoji: '🌱',
      label: LocalizedText(
        'Loamy',
        ha: 'Loam (ƙasa mai kyau ga noma)',
        fr: 'Limoneux',
      ),
      hint: LocalizedText(
        'Soft, crumbly and dark. Best for most crops.',
        ha: 'Mai laushi, mai rushewa kuma baƙa. Ta fi dacewa da yawancin amfanin gona.',
        fr: 'Douce, friable et sombre. Idéale pour la plupart des cultures.',
      ),
    ),
    WizardChoice<SoilType>(
      value: SoilType.silt,
      emoji: '🟤',
      label: LocalizedText(
        'Silt',
        ha: 'Silt (ƙasa mai laushi kamar gari)',
        fr: 'Silteux',
      ),
      hint: LocalizedText(
        'Smooth like flour when dry. Holds moisture well.',
        ha: 'Mai santsi kamar gari idan ta bushe. Tana riƙe danshi sosai.',
        fr: 'Lisse comme de la farine sèche. Retient bien l’humidité.',
      ),
    ),
  ];

  static const List<WizardChoice<WaterSource>> _waterChoices =
      <WizardChoice<WaterSource>>[
    WizardChoice<WaterSource>(
      value: WaterSource.rainfall,
      emoji: '🌧️',
      label: LocalizedText('Rainfall', ha: 'Ruwan sama', fr: 'Pluie'),
      hint: LocalizedText(
        'Only when it rains',
        ha: 'Sai lokacin damina',
        fr: 'Seulement quand il pleut',
      ),
    ),
    WizardChoice<WaterSource>(
      value: WaterSource.borehole,
      emoji: '🚰',
      label: LocalizedText('Borehole', ha: 'Rijiyar burtsatse', fr: 'Forage'),
      hint: LocalizedText(
        'Pumped from underground',
        ha: 'Ana ɗaukowa daga ƙarƙashin ƙasa',
        fr: 'Pompée depuis le sous-sol',
      ),
    ),
    WizardChoice<WaterSource>(
      value: WaterSource.river,
      emoji: '🏞️',
      label: LocalizedText(
        'River or stream',
        ha: 'Kogi ko rafi',
        fr: 'Rivière ou ruisseau',
      ),
      hint: LocalizedText(
        'Taken from flowing water',
        ha: 'Ana ɗiba daga rafi',
        fr: 'Prélevée dans un cours d’eau',
      ),
    ),
    WizardChoice<WaterSource>(
      value: WaterSource.dam,
      emoji: '💧',
      label: LocalizedText(
        'Dam or pond',
        ha: 'Madatsar ruwa ko tafki',
        fr: 'Barrage ou étang',
      ),
      hint: LocalizedText(
        'Stored water',
        ha: 'Ruwan da aka tara',
        fr: 'Eau stockée',
      ),
    ),
    WizardChoice<WaterSource>(
      value: WaterSource.irrigation,
      emoji: '💦',
      label: LocalizedText('Irrigation', ha: 'Ban ruwa (irrigation)', fr: 'Irrigation'),
      hint: LocalizedText(
        'Pipes, channels or sprinklers',
        ha: 'Bututu, ramuka ko feshi',
        fr: 'Tuyaux, canaux ou arroseurs',
      ),
    ),
  ];

  final TextEditingController _name = TextEditingController();
  final TextEditingController _ward = TextEditingController();
  final TextEditingController _size = TextEditingController();
  final TextEditingController _cropCapacity = TextEditingController();
  final TextEditingController _livestockCapacity = TextEditingController();
  final TextEditingController _greenhouseCount = TextEditingController();
  final TextEditingController _greenhouseArea = TextEditingController();

  FarmType _type = FarmType.combined;
  FarmerCategory _category = FarmerCategory.subsistence;
  SoilType _soil = SoilType.loamy;
  WaterSource _water = WaterSource.rainfall;

  @override
  void dispose() {
    _name.dispose();
    _ward.dispose();
    _size.dispose();
    _cropCapacity.dispose();
    _livestockCapacity.dispose();
    _greenhouseCount.dispose();
    _greenhouseArea.dispose();
    super.dispose();
  }

  // Accepts "1,5" as well as "1.5" so French-speaking farmers are not stuck.
  double? _decimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  double get _sizeHa => _decimal(_size.text) ?? 0;

  bool get _usesCrops =>
      _type == FarmType.crop ||
      _type == FarmType.combined ||
      _type == FarmType.greenhouse;
  bool get _usesLivestock =>
      _type == FarmType.livestock || _type == FarmType.combined;
  bool get _usesGreenhouse =>
      _type == FarmType.greenhouse || _type == FarmType.combined;

  // A capacity the farmer typed wins; an empty box uses our suggestion.
  double get _cropCapacityValue => _cropCapacity.text.trim().isEmpty
      ? FarmPlanning.suggestedCropCapacity(_sizeHa, _type)
      : (_decimal(_cropCapacity.text) ?? 0);
  int get _livestockCapacityValue => _livestockCapacity.text.trim().isEmpty
      ? FarmPlanning.suggestedLivestockCapacity(_sizeHa, _type)
      : (int.tryParse(_livestockCapacity.text.trim()) ?? 0);
  int get _greenhouseCountValue => _greenhouseCount.text.trim().isEmpty
      ? FarmPlanning.suggestedGreenhouseUnits(_sizeHa, _type)
      : (int.tryParse(_greenhouseCount.text.trim()) ?? 0);
  double get _greenhouseAreaValue => _greenhouseArea.text.trim().isEmpty
      ? FarmPlanning.suggestedGreenhouseArea(_sizeHa, _type)
      : (_decimal(_greenhouseArea.text) ?? 0);

  void _rebuild() => setState(() {});

  void _finish() {
    Navigator.of(context).pop(
      FarmDraft(
        name: _name.text.trim(),
        ward: _ward.text.trim(),
        sizeHa: _sizeHa,
        farmType: _type,
        farmerCategory: _category,
        soilType: _soil,
        waterSource: _water,
        cropCapacityHa: _usesCrops ? _cropCapacityValue : 0,
        livestockCapacity: _usesLivestock ? _livestockCapacityValue : 0,
        greenhouseCount: _usesGreenhouse ? _greenhouseCountValue : 0,
        greenhouseAreaHa: _usesGreenhouse ? _greenhouseAreaValue : 0,
      ),
    );
  }

  LocalizedText? _validateName() {
    final String name = _name.text.trim();
    final String ward = _ward.text.trim();
    if (name.isEmpty) {
      return const LocalizedText(
        'Please give your farm a name.',
        ha: 'Da fatan za ka ba gonar ka suna.',
        fr: 'Veuillez donner un nom à votre ferme.',
      );
    }
    if (name.length > 40) {
      return const LocalizedText(
        'The farm name must be 40 letters or fewer.',
        ha: 'Sunan gona kada ya wuce haruffa 40.',
        fr: 'Le nom doit comporter 40 caractères au maximum.',
      );
    }
    if (ward.isEmpty) {
      return const LocalizedText(
        'Please enter your ward.',
        ha: 'Da fatan za ka shigar da mazabar ka.',
        fr: 'Veuillez saisir votre ward (quartier).',
      );
    }
    if (ward.length > 30) {
      return const LocalizedText(
        'The ward must be 30 letters or fewer.',
        ha: 'Mazaba kada ta wuce haruffa 30.',
        fr: 'Le ward doit comporter 30 caractères au maximum.',
      );
    }
    return null;
  }

  LocalizedText? _validateSize() {
    if (_size.text.trim().isEmpty) {
      return const LocalizedText(
        'Please enter the size of your farm.',
        ha: 'Da fatan za ka shigar da girman gonar ka.',
        fr: 'Veuillez saisir la taille de votre ferme.',
      );
    }
    final double? size = _decimal(_size.text);
    if (size == null) {
      return const LocalizedText(
        'Enter a number, for example 1.5',
        ha: 'Shigar da lamba, misali 1.5',
        fr: 'Saisissez un nombre, par exemple 1.5',
      );
    }
    if (size < 0.1 || size > 10) {
      return const LocalizedText(
        'The size must be between 0.1 and 10 hectares.',
        ha: 'Girman dole ya kasance tsakanin hekta 0.1 da 10.',
        fr: 'La taille doit être comprise entre 0,1 et 10 hectares.',
      );
    }
    return null;
  }

  LocalizedText? _validateCapacity() {
    bool badDecimal(TextEditingController c) {
      final String text = c.text.trim();
      if (text.isEmpty) {
        return false;
      }
      final double? value = _decimal(text);
      return value == null || value < 0;
    }

    bool badInt(TextEditingController c) {
      final String text = c.text.trim();
      if (text.isEmpty) {
        return false;
      }
      final int? value = int.tryParse(text);
      return value == null || value < 0;
    }

    final bool bad = (_usesCrops && badDecimal(_cropCapacity)) ||
        (_usesLivestock && badInt(_livestockCapacity)) ||
        (_usesGreenhouse &&
            (badInt(_greenhouseCount) || badDecimal(_greenhouseArea)));
    if (!bad) {
      return null;
    }
    return const LocalizedText(
      'Please enter a valid number, or leave the box empty to use our suggestion.',
      ha: 'Da fatan za ka shigar da lamba mai inganci, ko ka bar akwatin babu komai don amfani da shawararmu.',
      fr: 'Saisissez un nombre valide, ou laissez la case vide pour utiliser notre suggestion.',
    );
  }

  LocalizedText _landUseNote() {
    switch (_type) {
      case FarmType.crop:
        return const LocalizedText(
          'Crop farms usually keep most land for planting, with space left for paths and water.',
          ha: 'Gonakin amfanin gona yawanci suna ware mafi yawan fili don shuka, su bar wuri don hanyoyi da ruwa.',
          fr: 'Les fermes de culture réservent en général l’essentiel du terrain aux plantations, avec de la place pour les chemins et l’eau.',
        );
      case FarmType.livestock:
        return const LocalizedText(
          'Keep animal numbers modest so housing, cleanliness and feeding stay manageable.',
          ha: 'Ka rage yawan dabbobi domin matsuguni, tsafta da ciyarwa su zama masu sauƙin gudanarwa.',
          fr: 'Gardez un nombre d’animaux raisonnable pour que l’abri, l’hygiène et l’alimentation restent gérables.',
        );
      case FarmType.greenhouse:
        return const LocalizedText(
          'Greenhouses work best when the space is used well and kept compact.',
          ha: 'Gidajen kore suna aiki sosai idan an yi amfani da wurin sosai kuma an tsara shi a taƙaice.',
          fr: 'Les serres fonctionnent mieux quand l’espace est bien exploité et compact.',
        );
      case FarmType.combined:
        return const LocalizedText(
          'On mixed farms, split the land between crops, animals and paths so work flows smoothly.',
          ha: 'A gonaki masu hade, raba fili tsakanin amfanin gona, dabbobi da hanyoyi domin aiki ya yi sauƙi.',
          fr: 'Sur une ferme mixte, répartissez la terre entre cultures, animaux et passages pour travailler sans encombre.',
        );
    }
  }

  String _labelOf<T>(
    List<WizardChoice<T>> choices,
    T value,
    AppLanguage language,
  ) {
    return choices
        .firstWhere((WizardChoice<T> c) => c.value == value)
        .label
        .resolve(language);
  }

  String _suggested(AppLanguage language, String value) {
    return language.tr(
      en: 'Suggested: $value',
      ha: 'Shawara: $value',
      fr: 'Suggestion : $value',
    );
  }

  List<WizardStep> _steps(AppLanguage language) {
    final double sizeHa = _sizeHa;

    return <WizardStep>[
      WizardStep(
        id: 'name',
        icon: Icons.badge_rounded,
        image: 'assets/ui/farm.jpeg',
        title: const LocalizedText(
          'Name your farm',
          ha: 'Ba gonar ka suna',
          fr: 'Donnez un nom à votre ferme',
        ),
        why: const LocalizedText(
          'The name is how you will find this farm later. The ward tells us which local weather and market news to show you.',
          ha: 'Sunan shi ne yadda za ka sake samun gonar nan. Mazaba kuma tana taimaka mana mu nuna maka yanayi da labaran kasuwa na yankinka.',
          fr: 'Le nom vous aide à retrouver cette ferme. Le ward (quartier) nous permet d’afficher la météo et les nouvelles du marché de votre zone.',
        ),
        tip: const LocalizedText(
          'Use a name you will recognise, like “Vwang maize farm”.',
          ha: 'Yi amfani da sunan da za ka gane, kamar “Gonar masara ta Vwang”.',
          fr: 'Choisissez un nom facile à reconnaître, par exemple « Ferme de maïs de Vwang ».',
        ),
        validate: _validateName,
        builder: (BuildContext context) => Column(
          children: <Widget>[
            AppTextField(
              controller: _name,
              label: language.tr(
                  en: 'Farm name', ha: 'Sunan gona', fr: 'Nom de la ferme'),
              hint: 'Pisang King Farms',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _ward,
              label: language.tr(
                  en: 'Ward', ha: 'Mazaba (ward)', fr: 'Ward (quartier)'),
              hint: 'Vwang',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onChanged: (_) => _rebuild(),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'size',
        icon: Icons.straighten_rounded,
        image: 'assets/ui/farm_landscape.jpeg',
        title: const LocalizedText(
          'How big is it?',
          ha: 'Girman gonar',
          fr: 'Quelle est sa taille ?',
        ),
        why: const LocalizedText(
          'The size in hectares is used to suggest how much you can plant or keep. One hectare is about one and a half football pitches.',
          ha: 'Ana amfani da girman gona (hekta) wajen ba da shawarar yawan abin da za ka iya shukawa ko kiwatawa. Hekta ɗaya kusan filin ƙwallon ƙafa ɗaya da rabi ne.',
          fr: 'La taille en hectares sert à suggérer ce que vous pouvez planter ou élever. Un hectare, c’est environ un terrain et demi de football.',
        ),
        tip: const LocalizedText(
          'Not sure of the exact size? A good estimate is fine. You can change it later.',
          ha: 'Ba ka da tabbacin girman? Kimantawa ta isa. Za ka iya gyarawa daga baya.',
          fr: 'Pas sûr de la taille exacte ? Une estimation suffit. Vous pourrez la modifier plus tard.',
        ),
        validate: _validateSize,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _size,
              label: language.tr(
                en: 'Farm size (hectares)',
                ha: 'Girman gona (hekta)',
                fr: 'Superficie (hectares)',
              ),
              hint: '1.2',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String preset in const <String>['0.5', '1', '2', '5'])
                  ChoiceChip(
                    label: Text('$preset ha'),
                    selected: _size.text.trim() == preset,
                    onSelected: (_) {
                      FocusScope.of(context).unfocus();
                      setState(() => _size.text = preset);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'type',
        icon: Icons.agriculture_rounded,
        image: 'assets/ui/smart_farm.jpeg',
        title: const LocalizedText(
          'What do you farm?',
          ha: 'Me kake nomawa ko kiwatawa?',
          fr: 'Que produisez-vous ?',
        ),
        why: const LocalizedText(
          'Your farm type decides which sections we set up for you and how we suggest dividing your land.',
          ha: 'Nau’in gonar ka ne ke tantance sassan da za mu shirya maka da yadda za mu ba da shawarar raba fili.',
          fr: 'Le type de ferme détermine les sections que nous préparons et la façon de répartir votre terre.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<FarmType>(
          choices: _typeChoices,
          selected: _type,
          language: language,
          onSelected: (FarmType value) => setState(() => _type = value),
        ),
      ),
      WizardStep(
        id: 'category',
        icon: Icons.groups_rounded,
        image: 'assets/ui/farmers.jpeg',
        title: const LocalizedText(
          'Who is the farm for?',
          ha: 'Don me kake noma?',
          fr: 'Pour qui produisez-vous ?',
        ),
        why: const LocalizedText(
          'This helps us tune advice, reminders and reports to how you farm. You can change it any time.',
          ha: 'Wannan yana taimaka mana mu daidaita shawarwari, tunatarwa da rahotanni yadda kake noma. Za ka iya canza shi a kowane lokaci.',
          fr: 'Cela nous aide à adapter conseils, rappels et rapports à votre façon de produire. Vous pouvez le changer à tout moment.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<FarmerCategory>(
          choices: _categoryChoices,
          selected: _category,
          language: language,
          columns: 1,
          onSelected: (FarmerCategory value) =>
              setState(() => _category = value),
        ),
      ),
      WizardStep(
        id: 'soil',
        icon: Icons.terrain_rounded,
        image: 'assets/ui/leaf_field.jpeg',
        title: const LocalizedText(
          'What is your soil like?',
          ha: 'Yaya ƙasar gonar take?',
          fr: 'Comment est votre sol ?',
        ),
        why: const LocalizedText(
          'Soil decides which crops grow well and how often you need to water or add manure. Pick the closest match.',
          ha: 'Ƙasa ce ke tantance amfanin gonar da zai yi kyau da sau nawa za ka yi ban ruwa ko ƙara taki. Zaɓi wadda ta fi kama.',
          fr: 'Le sol détermine les cultures qui poussent bien et la fréquence d’arrosage ou de fumure. Choisissez la plus proche.',
        ),
        tip: const LocalizedText(
          'Squeeze a little damp soil in your hand. A long ribbon means clay, crumbling means sandy, a soft shape that holds means loam.',
          ha: 'Ƙwace ɗan ƙasa mai ɗanshi a hannu. Dogon zare yana nufin yumɓu, wargajewa yana nufin yashi, siffa mai laushi da ta riƙe tana nufin loam.',
          fr: 'Serrez un peu de terre humide dans la main. Un long ruban signifie argile, une terre qui s’effrite est sableuse, une forme souple qui tient est un limon.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<SoilType>(
          choices: _soilChoices,
          selected: _soil,
          language: language,
          onSelected: (SoilType value) => setState(() => _soil = value),
        ),
      ),
      WizardStep(
        id: 'water',
        icon: Icons.water_drop_rounded,
        image: 'assets/ui/irrigation pipe.jpeg',
        title: const LocalizedText(
          'Where does your water come from?',
          ha: 'Daga ina ruwan gonar ka yake zuwa?',
          fr: 'D’où vient votre eau ?',
        ),
        why: const LocalizedText(
          'Knowing your water helps us time planting and warn you about dry spells. Rain-fed farms follow the rainy season.',
          ha: 'Sanin hanyar samun ruwa yana taimaka mana mu tsara lokacin shuka mu kuma gargaɗe ka game da fari. Gonakin da ke dogara da ruwan sama suna bin damina.',
          fr: 'Connaître votre eau nous aide à choisir les dates de semis et à vous prévenir des périodes sèches. Les fermes pluviales suivent la saison des pluies.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<WaterSource>(
          choices: _waterChoices,
          selected: _water,
          language: language,
          onSelected: (WaterSource value) => setState(() => _water = value),
        ),
      ),
      WizardStep(
        id: 'capacity',
        icon: Icons.dashboard_customize_rounded,
        image: 'assets/ui/tractor.jpeg',
        title: const LocalizedText(
          'How much can it hold?',
          ha: 'Nawa gonar za ta iya ɗauka?',
          fr: 'Quelle est sa capacité ?',
        ),
        why: const LocalizedText(
          'We worked out a starting plan from your size and farm type. Keep our suggestions, or type your own numbers.',
          ha: 'Mun lissafa shirin farawa daga girman gona da nau’inta. Ka bar shawarwarinmu, ko ka rubuta naka.',
          fr: 'Nous avons calculé un plan de départ à partir de la taille et du type. Gardez nos suggestions ou saisissez vos chiffres.',
        ),
        tip: _landUseNote(),
        validate: _validateCapacity,
        builder: (BuildContext context) => Column(
          children: <Widget>[
            if (_usesCrops) ...<Widget>[
              AppTextField(
                controller: _cropCapacity,
                label: language.tr(
                  en: 'Land for crops (hectares)',
                  ha: 'Fadin amfanin gona (hekta)',
                  fr: 'Terre cultivable (hectares)',
                ),
                hint: _suggested(
                  language,
                  FarmPlanning.suggestedCropCapacity(sizeHa, _type)
                      .toStringAsFixed(1),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => _rebuild(),
              ),
              const SizedBox(height: 14),
            ],
            if (_usesLivestock) ...<Widget>[
              AppTextField(
                controller: _livestockCapacity,
                label: language.tr(
                  en: 'Number of animals it can keep',
                  ha: 'Yawan dabbobin da za a iya kiwatawa',
                  fr: 'Nombre d’animaux possibles',
                ),
                hint: _suggested(
                  language,
                  '${FarmPlanning.suggestedLivestockCapacity(sizeHa, _type)}',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _rebuild(),
              ),
              const SizedBox(height: 14),
            ],
            if (_usesGreenhouse)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: _greenhouseCount,
                      label: language.tr(
                        en: 'Greenhouses',
                        ha: 'Gidajen kore',
                        fr: 'Serres',
                      ),
                      hint: _suggested(
                        language,
                        '${FarmPlanning.suggestedGreenhouseUnits(sizeHa, _type)}',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _rebuild(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppTextField(
                      controller: _greenhouseArea,
                      label: language.tr(
                        en: 'Area (ha)',
                        ha: 'Fadi (hekta)',
                        fr: 'Surface (ha)',
                      ),
                      hint: _suggested(
                        language,
                        FarmPlanning.suggestedGreenhouseArea(sizeHa, _type)
                            .toStringAsFixed(2),
                      ),
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
          'Check your farm',
          ha: 'Duba gonar ka',
          fr: 'Vérifiez votre ferme',
        ),
        why: const LocalizedText(
          'Make sure everything looks right. Use Back to change anything. You can also edit it later.',
          ha: 'Ka tabbatar komai daidai ne. Yi amfani da Koma baya don canza kowane abu. Za ka iya gyarawa daga baya ma.',
          fr: 'Vérifiez que tout est correct. Utilisez Retour pour modifier. Vous pourrez aussi le faire plus tard.',
        ),
        builder: (BuildContext context) => WizardReviewCard(
          language: language,
          items: <WizardReviewItem>[
            WizardReviewItem(
              icon: Icons.badge_rounded,
              label: const LocalizedText('Farm', ha: 'Gona', fr: 'Ferme'),
              value: _name.text.trim(),
            ),
            WizardReviewItem(
              icon: Icons.place_rounded,
              label: const LocalizedText('Ward', ha: 'Mazaba', fr: 'Ward'),
              value: _ward.text.trim(),
            ),
            WizardReviewItem(
              icon: Icons.straighten_rounded,
              label: const LocalizedText('Size', ha: 'Girma', fr: 'Taille'),
              value: '${_sizeHa.toStringAsFixed(1)} ha',
            ),
            WizardReviewItem(
              icon: Icons.agriculture_rounded,
              label: const LocalizedText('Type', ha: 'Nau’i', fr: 'Type'),
              value: _labelOf(_typeChoices, _type, language),
            ),
            WizardReviewItem(
              icon: Icons.groups_rounded,
              label: const LocalizedText(
                  'Farming for', ha: 'Noma don', fr: 'Production pour'),
              value: _labelOf(_categoryChoices, _category, language),
            ),
            WizardReviewItem(
              icon: Icons.terrain_rounded,
              label: const LocalizedText('Soil', ha: 'Ƙasa', fr: 'Sol'),
              value: _labelOf(_soilChoices, _soil, language),
            ),
            WizardReviewItem(
              icon: Icons.water_drop_rounded,
              label: const LocalizedText('Water', ha: 'Ruwa', fr: 'Eau'),
              value: _labelOf(_waterChoices, _water, language),
            ),
            if (_usesCrops)
              WizardReviewItem(
                icon: Icons.grass_rounded,
                label: const LocalizedText(
                    'Land for crops', ha: 'Fadin amfanin gona', fr: 'Terre cultivable'),
                value: '${_cropCapacityValue.toStringAsFixed(1)} ha',
              ),
            if (_usesLivestock)
              WizardReviewItem(
                icon: Icons.pets_rounded,
                label: const LocalizedText(
                    'Animal capacity', ha: 'Yawan dabbobi', fr: 'Capacité d’élevage'),
                value: '$_livestockCapacityValue',
              ),
            if (_usesGreenhouse)
              WizardReviewItem(
                icon: Icons.home_work_rounded,
                label: const LocalizedText(
                    'Greenhouses', ha: 'Gidajen kore', fr: 'Serres'),
                value:
                    '$_greenhouseCountValue · ${_greenhouseAreaValue.toStringAsFixed(2)} ha',
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
        'New farm',
        ha: 'Sabuwar gona',
        fr: 'Nouvelle ferme',
      ),
      finishLabel: const LocalizedText(
        'Create farm',
        ha: 'Ƙirƙiri gona',
        fr: 'Créer la ferme',
      ),
      steps: _steps(language),
      onFinish: _finish,
    );
  }
}
