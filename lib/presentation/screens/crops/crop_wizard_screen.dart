import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/crop_planning.dart';
import '../../../core/utils/currency_utils.dart';
import '../../../data/services/crop_advice_catalog.dart';
import '../../../domain/models/crop.dart';
import '../../../domain/models/farm.dart';
import '../../../providers/app_preferences_provider.dart';
import '../../common/widgets/app_text_field.dart';
import '../../common/wizard/guided_wizard_screen.dart';
import '../../common/wizard/wizard_inputs.dart';
import '../../common/wizard/wizard_models.dart';
import 'crops_screen.dart' show CropDraft;

/// A crop people commonly plant: the English name is what the advice catalog
/// recognises, the other two are only for the button label.
class _CommonCrop {
  const _CommonCrop(this.english, this.hausa, this.french);

  final String english;
  final String hausa;
  final String french;
}

/// Step-by-step crop creation. Pops with a [CropDraft], exactly like the older
/// single-sheet form, so saving works the same way.
class CropWizardScreen extends ConsumerStatefulWidget {
  /// Creates the wizard for the given [farms] (at least one).
  const CropWizardScreen({super.key, required this.farms});

  /// Farms the crop can be linked to.
  final List<Farm> farms;

  @override
  ConsumerState<CropWizardScreen> createState() => _CropWizardScreenState();
}

class _CropWizardScreenState extends ConsumerState<CropWizardScreen> {
  static const List<_CommonCrop> _commonCrops = <_CommonCrop>[
    _CommonCrop('Maize', 'Masara', 'Maïs'),
    _CommonCrop('Yam', 'Doya', 'Igname'),
    _CommonCrop('Tomato', 'Tumatir', 'Tomate'),
    _CommonCrop('Cassava', 'Rogo', 'Manioc'),
    _CommonCrop('Rice', 'Shinkafa', 'Riz'),
    _CommonCrop('Groundnut', 'Gyaɗa', 'Arachide'),
    _CommonCrop('Cowpea', 'Wake', 'Niébé'),
    _CommonCrop('Millet', 'Gero', 'Mil'),
    _CommonCrop('Potato', 'Dankalin turawa', 'Pomme de terre'),
    _CommonCrop('Pepper', 'Barkono', 'Piment'),
  ];

  static const List<WizardChoice<CropStage>> _stageChoices =
      <WizardChoice<CropStage>>[
    WizardChoice<CropStage>(
      value: CropStage.seeding,
      emoji: '🌰',
      label: LocalizedText('Just planted', ha: 'Sabon shuka', fr: 'Tout juste planté'),
      hint: LocalizedText(
        'Seeds are in the ground',
        ha: 'Iri yana cikin ƙasa',
        fr: 'Les graines sont en terre',
      ),
    ),
    WizardChoice<CropStage>(
      value: CropStage.germination,
      emoji: '🌱',
      label: LocalizedText('Sprouting', ha: 'Ɓuɓɓugowa', fr: 'Levée'),
      hint: LocalizedText(
        'First small shoots are showing',
        ha: 'Ƙananan ganye na farko sun fito',
        fr: 'Les premières pousses apparaissent',
      ),
    ),
    WizardChoice<CropStage>(
      value: CropStage.vegetative,
      emoji: '🌿',
      label: LocalizedText(
        'Growing leaves',
        ha: 'Girman ganye',
        fr: 'Croissance des feuilles',
      ),
      hint: LocalizedText(
        'Plants are getting bigger and greener',
        ha: 'Tsirrai suna girma suna kore',
        fr: 'Les plants grandissent et verdissent',
      ),
    ),
    WizardChoice<CropStage>(
      value: CropStage.flowering,
      emoji: '🌼',
      label: LocalizedText('Flowering', ha: 'Fure', fr: 'Floraison'),
      hint: LocalizedText(
        'Flowers are opening',
        ha: 'Furanni suna buɗewa',
        fr: 'Les fleurs s’ouvrent',
      ),
    ),
    WizardChoice<CropStage>(
      value: CropStage.fruiting,
      emoji: '🍅',
      label: LocalizedText('Fruiting', ha: 'Yin ’ya’ya', fr: 'Fructification'),
      hint: LocalizedText(
        'Fruit or grain is forming',
        ha: 'Ana samun ’ya’ya ko hatsi',
        fr: 'Les fruits ou grains se forment',
      ),
    ),
  ];

  static const List<WizardChoice<bool>> _environmentChoices =
      <WizardChoice<bool>>[
    WizardChoice<bool>(
      value: false,
      emoji: '🌤️',
      label: LocalizedText('Open field', ha: 'Gona a waje', fr: 'Plein champ'),
      hint: LocalizedText(
        'Grown outdoors, under the open sky',
        ha: 'Ana nomawa a waje',
        fr: 'Cultivé à l’extérieur',
      ),
    ),
    WizardChoice<bool>(
      value: true,
      emoji: '🏡',
      label: LocalizedText(
        'Greenhouse or net house',
        ha: 'Gidan kore ko gidan raga',
        fr: 'Serre ou abri filet',
      ),
      hint: LocalizedText(
        'Grown under cover to protect from weather and pests',
        ha: 'Ana nomawa a ƙarƙashin rufi don kariya daga yanayi da kwari',
        fr: 'Cultivé sous abri contre la météo et les ravageurs',
      ),
    ),
  ];

  final TextEditingController _name = TextEditingController();
  final TextEditingController _variety = TextEditingController();
  final TextEditingController _land = TextEditingController();
  final TextEditingController _cycle = TextEditingController();
  final TextEditingController _yield = TextEditingController();
  final TextEditingController _cost = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  late String _farmId;
  late bool _protected;
  LandSizeUnit _unit = LandSizeUnit.hectares;
  CropStage _stage = CropStage.seeding;
  DateTime _planting = DateTime.now();

  @override
  void initState() {
    super.initState();
    _farmId = widget.farms.first.id;
    _protected = widget.farms.first.supportsGreenhouse;
  }

  @override
  void dispose() {
    _name.dispose();
    _variety.dispose();
    _land.dispose();
    _cycle.dispose();
    _yield.dispose();
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  // Accepts "0,3" as well as "0.3" so French-speaking farmers are not stuck.
  double? _decimal(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  // Money follows the rest of the app: commas are thousands separators.
  double? _money(String text) => double.tryParse(
      text.replaceAll('₦', '').replaceAll(',', '').trim());

  double get _enteredLand => _decimal(_land.text) ?? 0;
  double get _areaHa => _unit == LandSizeUnit.plots
      ? _enteredLand * CropAdviceCatalog.plotToHa
      : _enteredLand;

  CropAdviceProfile? get _profile => CropAdviceCatalog.detect(_name.text);

  int get _suggestedCycle =>
      CropPlanning.suggestedCycleDays(_profile, _stage, _protected);
  double get _suggestedYield =>
      CropPlanning.suggestedYieldKg(_profile, _areaHa, _stage, _protected);

  // Something the farmer typed wins; an empty box uses our suggestion.
  int get _cycleDays => _cycle.text.trim().isEmpty
      ? _suggestedCycle
      : (int.tryParse(_cycle.text.trim()) ?? _suggestedCycle);
  double get _targetYield => _yield.text.trim().isEmpty
      ? _suggestedYield
      : (_decimal(_yield.text) ?? _suggestedYield);
  double get _costValue =>
      _cost.text.trim().isEmpty ? 0 : (_money(_cost.text) ?? 0);

  DateTime get _harvestDate => _planting.add(Duration(days: _cycleDays));

  CropStatus get _status =>
      _stage == CropStage.seeding || _stage == CropStage.germination
          ? CropStatus.planted
          : CropStatus.growing;

  Farm get _farm => widget.farms.firstWhere((Farm f) => f.id == _farmId);

  String _date(DateTime value) => DateFormat('d MMM yyyy').format(value);

  void _finish() {
    Navigator.of(context).pop(
      CropDraft(
        farmId: _farmId,
        name: _name.text.trim(),
        variety: _variety.text.trim(),
        areaHa: _areaHa,
        landSizeValue: _enteredLand,
        landSizeUnit: _unit,
        plantingDate: _planting,
        expectedHarvestDate: _harvestDate,
        currentStage: _stage,
        status: _status,
        totalInputCost: _costValue,
        cycleLengthDays: _cycleDays,
        targetYieldKg: _targetYield,
        protectedEnvironment: _protected,
        notes: _notes.text.trim(),
      ),
    );
  }

  LocalizedText? _validateCrop() {
    if (_name.text.trim().isEmpty) {
      return const LocalizedText(
        'Please say what you are growing.',
        ha: 'Da fatan za ka faɗi abin da kake nomawa.',
        fr: 'Veuillez indiquer ce que vous cultivez.',
      );
    }
    if (_variety.text.trim().isEmpty) {
      return const LocalizedText(
        'Please enter the variety, or tap “Local variety”.',
        ha: 'Da fatan za ka shigar da iri, ko ka danna “Iri na gida”.',
        fr: 'Veuillez saisir la variété, ou touchez « Variété locale ».',
      );
    }
    return null;
  }

  LocalizedText? _validateLand() {
    if (_land.text.trim().isEmpty) {
      return const LocalizedText(
        'Please enter how much land the crop covers.',
        ha: 'Da fatan za ka shigar da girman filin da amfanin gonar ya mamaye.',
        fr: 'Veuillez saisir la surface occupée par la culture.',
      );
    }
    final double? value = _decimal(_land.text);
    if (value == null) {
      return const LocalizedText(
        'Enter a number, for example 0.3',
        ha: 'Shigar da lamba, misali 0.3',
        fr: 'Saisissez un nombre, par exemple 0.3',
      );
    }
    if (value <= 0) {
      return const LocalizedText(
        'The land size must be more than zero.',
        ha: 'Girman fili dole ya fi sifili.',
        fr: 'La surface doit être supérieure à zéro.',
      );
    }
    return null;
  }

  LocalizedText? _validatePlan() {
    final String cycle = _cycle.text.trim();
    if (cycle.isNotEmpty) {
      final int? days = int.tryParse(cycle);
      if (days == null || days <= 0 || days > 3650) {
        return const LocalizedText(
          'Enter the number of days as a whole number, like 90.',
          ha: 'Shigar da adadin kwanaki a matsayin cikakkiyar lamba, misali 90.',
          fr: 'Saisissez le nombre de jours en nombre entier, par exemple 90.',
        );
      }
    }
    final String yieldText = _yield.text.trim();
    if (yieldText.isNotEmpty) {
      final double? kg = _decimal(yieldText);
      if (kg == null || kg < 0) {
        return const LocalizedText(
          'Enter the expected harvest in kilograms, like 3500.',
          ha: 'Shigar da girbin da ake sa ran samu a kilogiram, misali 3500.',
          fr: 'Saisissez la récolte attendue en kilogrammes, par exemple 3500.',
        );
      }
    }
    return null;
  }

  LocalizedText? _validateCost() {
    final String text = _cost.text.trim();
    if (text.isEmpty) {
      return null;
    }
    final double? value = _money(text);
    if (value == null || value < 0) {
      return const LocalizedText(
        'Please enter a valid amount, like 25000.',
        ha: 'Da fatan za ka shigar da adadin kuɗi mai inganci, misali 25000.',
        fr: 'Veuillez saisir un montant valide, par exemple 25000.',
      );
    }
    return null;
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

  String _landSummary(AppLanguage language) {
    if (_unit == LandSizeUnit.plots) {
      return language.tr(
        en: '${_enteredLand.toStringAsFixed(1)} plots (about ${_areaHa.toStringAsFixed(2)} ha)',
        ha: 'plot ${_enteredLand.toStringAsFixed(1)} (kusan hekta ${_areaHa.toStringAsFixed(2)})',
        fr: '${_enteredLand.toStringAsFixed(1)} parcelles (environ ${_areaHa.toStringAsFixed(2)} ha)',
      );
    }
    return '${_enteredLand.toStringAsFixed(2)} ha';
  }

  void _setUnit(LandSizeUnit next) {
    if (next == _unit) {
      return;
    }
    setState(() {
      final double entered = _decimal(_land.text) ?? 0;
      if (_land.text.trim().isNotEmpty && entered > 0) {
        _land.text = next == LandSizeUnit.plots
            ? (entered / CropAdviceCatalog.plotToHa).toStringAsFixed(1)
            : (entered * CropAdviceCatalog.plotToHa).toStringAsFixed(2);
      }
      _unit = next;
    });
  }

  List<WizardStep> _steps(AppLanguage language) {
    final bool manyFarms = widget.farms.length > 1;
    final CropAdviceProfile? profile = _profile;

    return <WizardStep>[
      if (manyFarms)
        WizardStep(
          id: 'farm',
          icon: Icons.agriculture_rounded,
          image: 'assets/ui/farm.jpeg',
          title: const LocalizedText(
            'Which farm is it on?',
            ha: 'A wace gona ne?',
            fr: 'Sur quelle ferme ?',
          ),
          why: const LocalizedText(
            'Linking the crop to a farm puts its records, tasks and costs in the right place.',
            ha: 'Haɗa amfanin gona da gona yana sanya bayanansa, ayyuka da kuɗi a wurin da ya dace.',
            fr: 'Lier la culture à une ferme range ses dossiers, tâches et coûts au bon endroit.',
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
            onSelected: (String id) => setState(() {
              _farmId = id;
              // Keep this in step with the chosen farm, like the old form.
              _protected = _farm.supportsGreenhouse;
            }),
          ),
        ),
      WizardStep(
        id: 'crop',
        icon: Icons.eco_rounded,
        image: 'assets/ui/crops.jpeg',
        title: const LocalizedText(
          'What are you growing?',
          ha: 'Me kake nomawa?',
          fr: 'Que cultivez-vous ?',
        ),
        why: const LocalizedText(
          'The crop name lets us suggest how long it takes, the right inputs and reminders. Tap a common crop or type your own.',
          ha: 'Sunan amfanin gona yana ba mu damar ba da shawara kan tsawon lokaci, kayan da suka dace da tunatarwa. Danna wani amfanin gona da aka saba ko ka rubuta naka.',
          fr: 'Le nom de la culture nous permet de suggérer la durée, les intrants adaptés et les rappels. Touchez une culture courante ou saisissez la vôtre.',
        ),
        tip: const LocalizedText(
          'Don’t know the variety? Tap “Local variety”.',
          ha: 'Ba ka san irin ba? Danna “Iri na gida”.',
          fr: 'Vous ne connaissez pas la variété ? Touchez « Variété locale ».',
        ),
        validate: _validateCrop,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final _CommonCrop crop in _commonCrops)
                  ChoiceChip(
                    label: Text(language.tr(
                        en: crop.english, ha: crop.hausa, fr: crop.french)),
                    selected:
                        _name.text.trim().toLowerCase() ==
                            crop.english.toLowerCase(),
                    onSelected: (_) {
                      FocusScope.of(context).unfocus();
                      setState(() => _name.text = crop.english);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _name,
              label: language.tr(
                  en: 'Crop name', ha: 'Sunan amfanin gona', fr: 'Nom de la culture'),
              hint: 'Tomato',
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _rebuild(),
            ),
            if (profile != null) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: Color(0xFF0B7F4D)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      language.tr(
                        en: 'Recognised: ${profile.name}. We will suggest matching advice.',
                        ha: 'An gane: ${profile.name}. Za mu ba da shawarwari masu dacewa.',
                        fr: 'Reconnu : ${profile.name}. Nous proposerons des conseils adaptés.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              controller: _variety,
              label: language.tr(en: 'Variety', ha: 'Iri', fr: 'Variété'),
              hint: 'Roma',
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
                    en: 'Local variety', ha: 'Iri na gida', fr: 'Variété locale')),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _variety.text = 'Local');
                },
              ),
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'land',
        icon: Icons.crop_square_rounded,
        image: 'assets/ui/field_sprayer.jpeg',
        title: const LocalizedText(
          'How much land?',
          ha: 'Girman filin nawa ne?',
          fr: 'Quelle surface ?',
        ),
        why: const LocalizedText(
          'We use the land size to work out seed, fertiliser and the harvest to expect. If you measure in plots, choose Plots.',
          ha: 'Muna amfani da girman fili wajen lissafin iri, taki da girbin da ake sa ran samu. Idan kana auna da “plot”, zaɓi Plots.',
          fr: 'La surface sert à calculer semences, engrais et récolte attendue. Si vous mesurez en parcelles (plots), choisissez Plots.',
        ),
        tip: const LocalizedText(
          'One plot is about 648 square metres (0.0648 hectare).',
          ha: 'Plot ɗaya kusan murabba’in mita 648 ne (hekta 0.0648).',
          fr: 'Une parcelle (plot) fait environ 648 m² (0,0648 hectare).',
        ),
        validate: _validateLand,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _land,
              label: language.tr(
                  en: 'Land size', ha: 'Girman fili', fr: 'Surface'),
              hint: _unit == LandSizeUnit.plots ? '4.0' : '0.3',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: <Widget>[
                ChoiceChip(
                  label: Text(language.tr(
                      en: 'Hectares', ha: 'Hekta', fr: 'Hectares')),
                  selected: _unit == LandSizeUnit.hectares,
                  onSelected: (_) => _setUnit(LandSizeUnit.hectares),
                ),
                ChoiceChip(
                  label: Text(language.tr(
                      en: 'Plots', ha: 'Plot', fr: 'Parcelles')),
                  selected: _unit == LandSizeUnit.plots,
                  onSelected: (_) => _setUnit(LandSizeUnit.plots),
                ),
              ],
            ),
            if (_enteredLand > 0) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _unit == LandSizeUnit.plots
                    ? '≈ ${_areaHa.toStringAsFixed(2)} ha'
                    : '≈ ${(_enteredLand / CropAdviceCatalog.plotToHa).toStringAsFixed(1)} plots',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ],
        ),
      ),
      WizardStep(
        id: 'planting',
        icon: Icons.event_rounded,
        image: 'assets/ui/farm_landscape.jpeg',
        title: const LocalizedText(
          'When did you plant?',
          ha: 'Yaushe ka shuka?',
          fr: 'Quand avez-vous planté ?',
        ),
        why: const LocalizedText(
          'The planting date starts the clock. We count forward from it to tell you when to weed, feed and harvest.',
          ha: 'Ranar shuka ita ce farkon ƙidaya. Daga ita muke ƙirga don gaya maka lokacin cire ciyawa, ciyar da shuka da girbi.',
          fr: 'La date de plantation lance le compte à rebours. Nous comptons à partir d’elle pour vous dire quand désherber, fertiliser et récolter.',
        ),
        tip: const LocalizedText(
          'Planting soon? Pick the day you plan to plant.',
          ha: 'Za ka shuka nan ba da jimawa ba? Zaɓi ranar da ka shirya shukawa.',
          fr: 'Vous plantez bientôt ? Choisissez le jour prévu.',
        ),
        builder: (BuildContext context) => WizardDateField(
          label: const LocalizedText(
            'Planting date',
            ha: 'Ranar shuka',
            fr: 'Date de plantation',
          ),
          value: _planting,
          language: language,
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
          onChanged: (DateTime picked) => setState(() => _planting = picked),
        ),
      ),
      WizardStep(
        id: 'stage',
        icon: Icons.spa_rounded,
        image: 'assets/ui/leaf_field.jpeg',
        title: const LocalizedText(
          'How far has it grown?',
          ha: 'Ya girma har ina?',
          fr: 'Où en est la culture ?',
        ),
        why: const LocalizedText(
          'The growth stage tells us what care is due now and how long is left until harvest.',
          ha: 'Matakin girma yana nuna mana kulawar da ake buƙata yanzu da lokacin da ya rage kafin girbi.',
          fr: 'Le stade de croissance indique les soins à faire maintenant et le temps restant avant la récolte.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<CropStage>(
          choices: _stageChoices,
          selected: _stage,
          language: language,
          onSelected: (CropStage value) => setState(() => _stage = value),
        ),
      ),
      WizardStep(
        id: 'environment',
        icon: Icons.home_work_rounded,
        image: 'assets/ui/green house.jpeg',
        title: const LocalizedText(
          'Where is it growing?',
          ha: 'A ina yake girma?',
          fr: 'Où pousse-t-elle ?',
        ),
        why: const LocalizedText(
          'Growing under cover changes how long the crop takes and how much it can yield, so we adjust our suggestions.',
          ha: 'Noma a ƙarƙashin rufi yana canza lokacin girma da yawan amfanin, don haka muna daidaita shawarwarinmu.',
          fr: 'Cultiver sous abri change la durée du cycle et le rendement ; nous adaptons donc nos suggestions.',
        ),
        builder: (BuildContext context) => WizardChoiceGrid<bool>(
          choices: _environmentChoices,
          selected: _protected,
          language: language,
          columns: 1,
          onSelected: (bool value) => setState(() => _protected = value),
        ),
      ),
      WizardStep(
        id: 'plan',
        icon: Icons.insights_rounded,
        image: 'assets/ui/smart_farm.jpeg',
        title: const LocalizedText(
          'Your growing plan',
          ha: 'Shirin nomanka',
          fr: 'Votre plan de culture',
        ),
        why: const LocalizedText(
          'From your crop, land and stage we estimated how long it takes and how much it may yield. Keep our numbers or type your own.',
          ha: 'Daga amfanin gona, fili da mataki, mun ƙiyasta tsawon lokaci da yawan amfanin da zai iya bayarwa. Ka bar lambobinmu ko ka rubuta naka.',
          fr: 'À partir de la culture, de la surface et du stade, nous avons estimé la durée et le rendement possible. Gardez nos chiffres ou saisissez les vôtres.',
        ),
        tip: profile != null
            ? LocalizedText(
                'We recognised ${profile.name}, so these numbers match typical ${profile.name} farming.',
                ha: 'Mun gane ${profile.name}, don haka waɗannan lambobi sun yi daidai da noman ${profile.name} na yau da kullum.',
                fr: 'Nous avons reconnu ${profile.name}, ces chiffres correspondent donc à une culture typique de ${profile.name}.',
              )
            : const LocalizedText(
                'We have no ready-made profile for this crop, so we used general numbers. Adjust them if you know better.',
                ha: 'Ba mu da shirin da aka tanada na wannan amfanin gona, don haka mun yi amfani da lambobi na gama-gari. Gyara su idan kana da ingantattu.',
                fr: 'Nous n’avons pas de profil prêt pour cette culture, nous avons donc utilisé des chiffres généraux. Ajustez-les si vous savez mieux.',
              ),
        validate: _validatePlan,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: AppTextField(
                    controller: _cycle,
                    label: language.tr(
                      en: 'Days to harvest',
                      ha: 'Kwanaki zuwa girbi',
                      fr: 'Jours jusqu’à la récolte',
                    ),
                    hint: _suggested(language, '$_suggestedCycle'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _rebuild(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextField(
                    controller: _yield,
                    label: language.tr(
                      en: 'Expected harvest (kg)',
                      ha: 'Girbin da ake sa ran (kg)',
                      fr: 'Récolte attendue (kg)',
                    ),
                    hint: _suggested(
                        language, _suggestedYield.toStringAsFixed(0)),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => _rebuild(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Icon(Icons.event_available_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    language.tr(
                      en: 'Expected harvest date: ${_date(_harvestDate)}',
                      ha: 'Ranar girbi da ake sa ran: ${_date(_harvestDate)}',
                      fr: 'Date de récolte prévue : ${_date(_harvestDate)}',
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'cost',
        icon: Icons.payments_rounded,
        image: 'assets/ui/produce_market.jpeg',
        title: const LocalizedText(
          'Costs and notes',
          ha: 'Kuɗi da bayanai',
          fr: 'Coûts et notes',
        ),
        why: const LocalizedText(
          'Tracking what you spend on seed, fertiliser and labour shows whether the crop pays. Start with what you have spent so far, or nothing yet.',
          ha: 'Bibiyar kuɗin da kake kashewa kan iri, taki da ma’aikata yana nuna ko amfanin gona yana biya. Fara da abin da ka kashe zuwa yanzu, ko babu komai tukuna.',
          fr: 'Suivre vos dépenses en semences, engrais et main-d’œuvre montre si la culture est rentable. Indiquez ce que vous avez dépensé jusqu’ici, ou rien pour l’instant.',
        ),
        tip: const LocalizedText(
          'You can add seed, fertiliser and labour costs one by one later.',
          ha: 'Za ka iya ƙara kuɗin iri, taki da ma’aikata ɗaya bayan ɗaya daga baya.',
          fr: 'Vous pourrez ajouter plus tard les coûts de semences, d’engrais et de main-d’œuvre un par un.',
        ),
        validate: _validateCost,
        builder: (BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: _cost,
              label: language.tr(
                en: 'Money spent so far (₦)',
                ha: 'Kuɗin da aka kashe zuwa yanzu (₦)',
                fr: 'Argent dépensé jusqu’ici (₦)',
              ),
              hint: '25000',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => _rebuild(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                label: Text(language.tr(
                    en: 'Nothing yet', ha: 'Babu komai tukuna', fr: 'Rien pour l’instant')),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _cost.text = '0');
                },
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _notes,
              label: language.tr(
                  en: 'Notes (optional)',
                  ha: 'Bayanai (na zaɓi)',
                  fr: 'Notes (facultatif)'),
              hint: language.tr(
                en: 'e.g. Planted after the first rains',
                ha: 'misali: An shuka bayan ruwan sama na farko',
                fr: 'ex. Planté après les premières pluies',
              ),
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ],
        ),
      ),
      WizardStep(
        id: 'review',
        icon: Icons.fact_check_rounded,
        image: 'assets/ui/farm produce.jpeg',
        title: const LocalizedText(
          'Check your crop',
          ha: 'Duba amfanin gonar ka',
          fr: 'Vérifiez votre culture',
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
              icon: Icons.eco_rounded,
              label: const LocalizedText('Crop', ha: 'Amfanin gona', fr: 'Culture'),
              value: _name.text.trim(),
            ),
            WizardReviewItem(
              icon: Icons.label_rounded,
              label: const LocalizedText('Variety', ha: 'Iri', fr: 'Variété'),
              value: _variety.text.trim(),
            ),
            WizardReviewItem(
              icon: Icons.crop_square_rounded,
              label: const LocalizedText('Land', ha: 'Fili', fr: 'Surface'),
              value: _landSummary(language),
            ),
            WizardReviewItem(
              icon: Icons.event_rounded,
              label: const LocalizedText('Planted', ha: 'An shuka', fr: 'Planté le'),
              value: _date(_planting),
            ),
            WizardReviewItem(
              icon: Icons.spa_rounded,
              label: const LocalizedText('Stage', ha: 'Mataki', fr: 'Stade'),
              value: _labelOf(_stageChoices, _stage, language),
            ),
            WizardReviewItem(
              icon: Icons.home_work_rounded,
              label: const LocalizedText('Grown in', ha: 'Ana nomawa a', fr: 'Cultivé en'),
              value: _labelOf(_environmentChoices, _protected, language),
            ),
            WizardReviewItem(
              icon: Icons.event_available_rounded,
              label: const LocalizedText(
                  'Harvest around', ha: 'Girbi kusan', fr: 'Récolte vers'),
              value: _date(_harvestDate),
            ),
            WizardReviewItem(
              icon: Icons.scale_rounded,
              label: const LocalizedText(
                  'Expected harvest', ha: 'Girbin da ake sa ran', fr: 'Récolte attendue'),
              value: '${_targetYield.toStringAsFixed(0)} kg',
            ),
            WizardReviewItem(
              icon: Icons.payments_rounded,
              label: const LocalizedText(
                  'Spent so far', ha: 'An kashe', fr: 'Dépensé'),
              value: CurrencyUtils.formatCurrency(_costValue),
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
        'New crop',
        ha: 'Sabon amfanin gona',
        fr: 'Nouvelle culture',
      ),
      finishLabel: const LocalizedText(
        'Add crop',
        ha: 'Ƙara amfanin gona',
        fr: 'Ajouter la culture',
      ),
      steps: _steps(language),
      onFinish: _finish,
    );
  }
}
