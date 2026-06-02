import '../../domain/models/crop.dart';

class CropAdviceProfile {
  const CropAdviceProfile({
    required this.name,
    required this.aliases,
    required this.seedRatePerHa,
    required this.seedUnit,
    required this.fertiliserSummary,
    required this.otherInputs,
    required this.stageAdvice,
    required this.reminderOffsetsDays,
    required this.hasPostEmergenceHerbicide,
    required this.referenceNote,
  });

  final String name;
  final List<String> aliases;
  final double seedRatePerHa;
  final String seedUnit;
  final String fertiliserSummary;
  final List<String> otherInputs;
  final Map<CropStage, String> stageAdvice;
  final List<int> reminderOffsetsDays;
  final bool hasPostEmergenceHerbicide;
  final String referenceNote;
}

class CropReminderPlan {
  const CropReminderPlan({
    required this.title,
    required this.dayOffset,
    required this.detail,
  });

  final String title;
  final int dayOffset;
  final String detail;
}

class CropAdviceSummary {
  const CropAdviceSummary({
    required this.profile,
    required this.areaHa,
    required this.areaLabel,
    required this.seedRequirement,
    required this.fertiliserSummary,
    required this.otherInputs,
    required this.stageAdvice,
    required this.reminders,
    required this.referenceNote,
    required this.matchConfidence,
    required this.hasPostEmergenceHerbicide,
  });

  final CropAdviceProfile profile;
  final double areaHa;
  final String areaLabel;
  final double seedRequirement;
  final String fertiliserSummary;
  final List<String> otherInputs;
  final Map<CropStage, String> stageAdvice;
  final List<CropReminderPlan> reminders;
  final String referenceNote;
  final double matchConfidence;
  final bool hasPostEmergenceHerbicide;

  String get seedRequirementLabel {
    final String unit = profile.seedUnit;
    return '${seedRequirement.toStringAsFixed(seedRequirement >= 10 ? 0 : 2)} $unit';
  }
}

class CropAdviceCatalog {
  static const double plotToHa = 0.0648;

  static const List<CropAdviceProfile> _profiles = <CropAdviceProfile>[
    CropAdviceProfile(
      name: 'Maize',
      aliases: <String>['maize', 'corn'],
      seedRatePerHa: 20,
      seedUnit: 'kg',
      fertiliserSummary: 'Apply compound fertiliser at planting, then top dress with nitrogen at 3-4 weeks and again at knee height where rainfall allows.',
      otherInputs: <String>['Seed treatment', 'Weed control', 'Bird/pest scouting'],
      stageAdvice: _cerealAdvice,
      reminderOffsetsDays: <int>[0, 7, 21, 35, 56, 75],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Seed and fertiliser rates are compiled from extension-style recommendations and should be adjusted to your variety and soil test.',
    ),
    CropAdviceProfile(
      name: 'Rice',
      aliases: <String>['rice', 'paddy'],
      seedRatePerHa: 60,
      seedUnit: 'kg',
      fertiliserSummary: 'Use basal fertiliser before transplanting or direct seeding, then top dress nitrogen around tillering and panicle initiation.',
      otherInputs: <String>['Nursery or pre-germination', 'Water control', 'Bird control'],
      stageAdvice: _cerealAdvice,
      reminderOffsetsDays: <int>[0, 10, 25, 45, 65],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Check your rice system (upland, lowland, or irrigated) before applying the rates.',
    ),
    CropAdviceProfile(
      name: 'Sorghum',
      aliases: <String>['sorghum', 'guinea corn'],
      seedRatePerHa: 10,
      seedUnit: 'kg',
      fertiliserSummary: 'Use moderate basal fertiliser and split nitrogen if moisture is dependable.',
      otherInputs: <String>['Seed dressing', 'Weeding', 'Bird scaring'],
      stageAdvice: _cerealAdvice,
      reminderOffsetsDays: <int>[0, 10, 30, 55, 80],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Treat as a dryland cereal and avoid over-fertilising on poor moisture.',
    ),
    CropAdviceProfile(
      name: 'Millet',
      aliases: <String>['millet', 'pearl millet'],
      seedRatePerHa: 5,
      seedUnit: 'kg',
      fertiliserSummary: 'Use a light basal fertiliser and maintain weed control early; millet usually responds better to modest nutrition than heavy dressing.',
      otherInputs: <String>['Seed dressing', 'Weed control', 'Bird control'],
      stageAdvice: _cerealAdvice,
      reminderOffsetsDays: <int>[0, 10, 25, 45],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Best results usually come from early weed control and timely thinning.',
    ),
    CropAdviceProfile(
      name: 'Wheat',
      aliases: <String>['wheat'],
      seedRatePerHa: 100,
      seedUnit: 'kg',
      fertiliserSummary: 'Use basal fertiliser, then split nitrogen during tillering and stem elongation.',
      otherInputs: <String>['Certified seed', 'Fungicide scout', 'Irrigation'],
      stageAdvice: _cerealAdvice,
      reminderOffsetsDays: <int>[0, 14, 30, 50, 70],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Best suited to cooler season production with moisture control.',
    ),
    CropAdviceProfile(
      name: 'Cassava',
      aliases: <String>['cassava', 'tapioca'],
      seedRatePerHa: 10000,
      seedUnit: 'stems',
      fertiliserSummary: 'Apply balanced fertiliser soon after establishment and again during early bulking if soil fertility is low.',
      otherInputs: <String>['Healthy stems', 'Mulch', 'Weed control'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 21, 45, 75, 120],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Use clean stems with several nodes and keep fields weed-free in the first 8-12 weeks.',
    ),
    CropAdviceProfile(
      name: 'Yam',
      aliases: <String>['yam'],
      seedRatePerHa: 2500,
      seedUnit: 'setts',
      fertiliserSummary: 'Apply basal fertiliser after sprouting and top dress around vine development if the crop is vigorous.',
      otherInputs: <String>['Stake or ridge support', 'Mulch', 'Trellis/peg labour'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 30, 60, 90, 120],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Yam does better with mounds/ridges and strong weed control early.',
    ),
    CropAdviceProfile(
      name: 'Sweet potato',
      aliases: <String>['sweet potato', 'sweetpotato'],
      seedRatePerHa: 40000,
      seedUnit: 'vines',
      fertiliserSummary: 'Use moderate fertiliser at planting and keep potassium in mind for root bulking.',
      otherInputs: <String>['Vine cuttings', 'Mulch', 'Weed control'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 14, 35, 60, 90],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Healthy vine cuttings and early mound coverage matter more than heavy fertiliser.',
    ),
    CropAdviceProfile(
      name: 'Potato',
      aliases: <String>['potato', 'irish potato'],
      seedRatePerHa: 2500,
      seedUnit: 'seed pieces',
      fertiliserSummary: 'Use basal fertiliser at planting and hill up with a follow-up nitrogen application before tuber initiation.',
      otherInputs: <String>['Certified seed tubers', 'Hilling', 'Disease scouting'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 21, 42, 63],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Maintain cool, loose soil and frequent disease checks.',
    ),
    CropAdviceProfile(
      name: 'Bean',
      aliases: <String>['bean', 'beans', 'common bean'],
      seedRatePerHa: 80,
      seedUnit: 'kg',
      fertiliserSummary: 'Use a light starter fertiliser and avoid excess nitrogen so flowering is not delayed.',
      otherInputs: <String>['Rhizobium inoculant', 'Staking for climbers', 'Weed control'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 12, 25, 40, 55],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Keep moisture steady at flowering and pod fill.',
    ),
    CropAdviceProfile(
      name: 'Cowpea',
      aliases: <String>['cowpea', 'beans', 'sitao'],
      seedRatePerHa: 25,
      seedUnit: 'kg',
      fertiliserSummary: 'Use a modest basal fertiliser and avoid too much nitrogen; phosphorus support is usually more helpful.',
      otherInputs: <String>['Seed dressing', 'Weed control', 'Pod borer scouting'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 10, 25, 35, 50],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Regular scouting for pod borers and aphids is important.',
    ),
    CropAdviceProfile(
      name: 'Groundnut',
      aliases: <String>['groundnut', 'peanut'],
      seedRatePerHa: 90,
      seedUnit: 'kg',
      fertiliserSummary: 'Apply phosphorus-rich fertiliser and avoid heavy nitrogen so nodulation and pegging stay strong.',
      otherInputs: <String>['Gypsum if available', 'Weed control', 'Aflatoxin prevention'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 14, 35, 55, 80],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Dry pods well and keep the field clean to reduce aflatoxin risk.',
    ),
    CropAdviceProfile(
      name: 'Soybean',
      aliases: <String>['soybean', 'soya'],
      seedRatePerHa: 70,
      seedUnit: 'kg',
      fertiliserSummary: 'Use starter fertiliser and inoculate seed to support nodulation.',
      otherInputs: <String>['Rhizobium inoculant', 'Weed control', 'Disease scouting'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 45, 60],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Avoid waterlogging and manage weeds early.',
    ),
    CropAdviceProfile(
      name: 'Tomato',
      aliases: <String>['tomato'],
      seedRatePerHa: 0.35,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use basal fertiliser at transplanting, then frequent light feeding during flowering and fruit set.',
      otherInputs: <String>['Nursery tray', 'Stake or trellis', 'Pest and disease scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 42, 56, 70],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Use raised nursery seedlings and keep calcium management steady.',
    ),
    CropAdviceProfile(
      name: 'Pepper',
      aliases: <String>['pepper', 'chilli', 'chili', 'hot pepper'],
      seedRatePerHa: 0.25,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use basal fertiliser and support fruiting with potassium-rich feeding later in the cycle.',
      otherInputs: <String>['Nursery', 'Mulch', 'Staking', 'Pest scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 18, 35, 50, 68],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Keep irrigation even to reduce blossom-end problems.',
    ),
    CropAdviceProfile(
      name: 'Onion',
      aliases: <String>['onion'],
      seedRatePerHa: 6,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use basal fertiliser and split feeding through bulb development, with emphasis on potassium.',
      otherInputs: <String>['Nursery', 'Weed control', 'Disease scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 14, 30, 50, 70, 90],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Bulb size is sensitive to day length and moisture stress.',
    ),
    CropAdviceProfile(
      name: 'Okra',
      aliases: <String>['okra'],
      seedRatePerHa: 8,
      seedUnit: 'kg',
      fertiliserSummary: 'Use basal fertiliser and keep a light top dressing during active picking.',
      otherInputs: <String>['Seed dressing', 'Weed control', 'Insect scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 10, 25, 40, 55],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Harvest frequently so pods stay tender and productive.',
    ),
    CropAdviceProfile(
      name: 'Cucumber',
      aliases: <String>['cucumber'],
      seedRatePerHa: 3,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use balanced fertiliser at planting, then potassium support when flowering begins.',
      otherInputs: <String>['Trellis', 'Mulch', 'Pollination support', 'Pest scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 40, 55],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Keep moisture steady and harvest often for quality fruit.',
    ),
    CropAdviceProfile(
      name: 'Watermelon',
      aliases: <String>['watermelon'],
      seedRatePerHa: 3,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use a balanced basal fertiliser and increase potassium during fruit fill.',
      otherInputs: <String>['Mulch', 'Bee activity or pollination', 'Pest scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 12, 30, 45, 60],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Good fruit set depends on pollination and moderate moisture control.',
    ),
    CropAdviceProfile(
      name: 'Melon',
      aliases: <String>['melon', 'egusi', 'cantaloupe'],
      seedRatePerHa: 4,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use basal fertiliser and avoid excess nitrogen close to fruiting.',
      otherInputs: <String>['Weed control', 'Pollination support', 'Drying mats'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 14, 32, 50, 70],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Fruit quality improves when moisture is even and vines are not overcrowded.',
    ),
    CropAdviceProfile(
      name: 'Cabbage',
      aliases: <String>['cabbage'],
      seedRatePerHa: 0.5,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use strong basal feeding and follow with nitrogen and potassium during head formation.',
      otherInputs: <String>['Nursery', 'Insect netting', 'Pest scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 42, 56],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Scouting for caterpillars and aphids is essential.',
    ),
    CropAdviceProfile(
      name: 'Lettuce',
      aliases: <String>['lettuce'],
      seedRatePerHa: 0.3,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use light, frequent feeding and avoid excess nitrogen late in the crop.',
      otherInputs: <String>['Nursery', 'Shade or netting', 'Water management'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 10, 20, 30, 40],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Cooler conditions and steady watering improve quality.',
    ),
    CropAdviceProfile(
      name: 'Carrot',
      aliases: <String>['carrot'],
      seedRatePerHa: 4,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use well-finished compost or basal fertiliser and avoid too much nitrogen, which can distort roots.',
      otherInputs: <String>['Fine seedbed', 'Thinning', 'Weed control'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 50, 75],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'A loose, stone-free seedbed matters more than heavy fertiliser.',
    ),
    CropAdviceProfile(
      name: 'Spinach',
      aliases: <String>['spinach', 'leafy vegetable', 'amaranth'],
      seedRatePerHa: 6,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use moderate basal fertiliser and light top dressing after each cutting.',
      otherInputs: <String>['Shallow beds', 'Water supply', 'Pest scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 10, 20, 30, 40],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Frequent harvesting improves regrowth and leaf quality.',
    ),
    CropAdviceProfile(
      name: 'Garden egg',
      aliases: <String>['garden egg', 'eggplant', 'aubergine'],
      seedRatePerHa: 0.4,
      seedUnit: 'kg seed',
      fertiliserSummary: 'Use basal feeding and increase potassium as fruiting starts.',
      otherInputs: <String>['Nursery', 'Staking', 'Pest scouting'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 45, 60],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Keep plants upright and harvest regularly to sustain production.',
    ),
    CropAdviceProfile(
      name: 'Pineapple',
      aliases: <String>['pineapple'],
      seedRatePerHa: 50000,
      seedUnit: 'suckers',
      fertiliserSummary: 'Use basal fertiliser at establishment and split feedings during vegetative growth.',
      otherInputs: <String>['Healthy suckers', 'Mulch', 'Weed control'],
      stageAdvice: _fruitAdvice,
      reminderOffsetsDays: <int>[0, 30, 90, 180],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Pineapple is a long-cycle crop that benefits from good weed suppression.',
    ),
    CropAdviceProfile(
      name: 'Plantain',
      aliases: <String>['plantain'],
      seedRatePerHa: 1600,
      seedUnit: 'suckers',
      fertiliserSummary: 'Use basal feeding at planting and repeat nutrition during vigorous vegetative growth.',
      otherInputs: <String>['Suckers', 'Mulch', 'Pest scouting'],
      stageAdvice: _fruitAdvice,
      reminderOffsetsDays: <int>[0, 30, 90, 150, 240],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Water and potassium management are key for bunch filling.',
    ),
    CropAdviceProfile(
      name: 'Banana',
      aliases: <String>['banana'],
      seedRatePerHa: 1600,
      seedUnit: 'suckers',
      fertiliserSummary: 'Use balanced fertiliser and increase potassium before fruit fill.',
      otherInputs: <String>['Suckers', 'Mulch', 'Wind support'],
      stageAdvice: _fruitAdvice,
      reminderOffsetsDays: <int>[0, 30, 90, 180, 270],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Mulching and drainage are especially important in wet areas.',
    ),
    CropAdviceProfile(
      name: 'Cocoa',
      aliases: <String>['cocoa', 'cacao'],
      seedRatePerHa: 1100,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use early basal feeding, then maintain a steady NPK program with shade management.',
      otherInputs: <String>['Shade trees', 'Pruning', 'Disease scouting'],
      stageAdvice: _treeAdvice,
      reminderOffsetsDays: <int>[0, 30, 90, 180],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Cocoa production depends on shade, drainage, and disease control.',
    ),
    CropAdviceProfile(
      name: 'Cashew',
      aliases: <String>['cashew'],
      seedRatePerHa: 100,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use basal feeding at establishment and annual top dressing during early rains.',
      otherInputs: <String>['Tree guards', 'Pruning', 'Weed control'],
      stageAdvice: _treeAdvice,
      reminderOffsetsDays: <int>[0, 30, 120, 240],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Tree spacing and early weed control strongly influence nut yield.',
    ),
    CropAdviceProfile(
      name: 'Oil palm',
      aliases: <String>['oil palm', 'palm'],
      seedRatePerHa: 143,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use establishment fertiliser and keep a regular potassium and magnesium program as palms mature.',
      otherInputs: <String>['Weed control', 'Mulch', 'Pruning'],
      stageAdvice: _treeAdvice,
      reminderOffsetsDays: <int>[0, 30, 120, 240],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'A long-term plantation responds well to soil nutrition and good field sanitation.',
    ),
    CropAdviceProfile(
      name: 'Cotton',
      aliases: <String>['cotton'],
      seedRatePerHa: 25,
      seedUnit: 'kg',
      fertiliserSummary: 'Use basal feeding and split nitrogen during vegetative growth and early flowering.',
      otherInputs: <String>['Seed dressing', 'Pest scouting', 'Weed control'],
      stageAdvice: _fiberAdvice,
      reminderOffsetsDays: <int>[0, 14, 28, 45, 60],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Good pest management is critical for boll retention.',
    ),
    CropAdviceProfile(
      name: 'Sesame',
      aliases: <String>['sesame', 'beniseed'],
      seedRatePerHa: 5,
      seedUnit: 'kg',
      fertiliserSummary: 'Use a light basal fertiliser and avoid excess nitrogen so flowering and pod set are not delayed.',
      otherInputs: <String>['Weed control', 'Bird control', 'Drying sheets'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 10, 25, 45, 65],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Harvest carefully because pods can shatter when over-dried.',
    ),
    CropAdviceProfile(
      name: 'Sugarcane',
      aliases: <String>['sugarcane'],
      seedRatePerHa: 12000,
      seedUnit: 'setts',
      fertiliserSummary: 'Use basal fertiliser at planting, then split nitrogen while cane is actively tillering and elongating.',
      otherInputs: <String>['Ratoon management', 'Weed control', 'Irrigation'],
      stageAdvice: _cerealAdvice,
      reminderOffsetsDays: <int>[0, 30, 60, 120, 180],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Good moisture and early weed control drive cane tonnage.',
    ),
    CropAdviceProfile(
      name: 'Ginger',
      aliases: <String>['ginger'],
      seedRatePerHa: 1500,
      seedUnit: 'kg rhizomes',
      fertiliserSummary: 'Use basal feeding, then split fertiliser during vegetative growth and rhizome bulking.',
      otherInputs: <String>['Mulch', 'Disease scouting', 'Shade'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 30, 60, 90, 150],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Ginger requires clean seed rhizomes and excellent drainage.',
    ),
    CropAdviceProfile(
      name: 'Turmeric',
      aliases: <String>['turmeric'],
      seedRatePerHa: 2000,
      seedUnit: 'kg rhizomes',
      fertiliserSummary: 'Use basal feeding with steady potassium support during rhizome development.',
      otherInputs: <String>['Mulch', 'Shade', 'Weed control'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 30, 60, 120, 180],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'A humid, shaded environment supports turmeric well.',
    ),
    CropAdviceProfile(
      name: 'Sunflower',
      aliases: <String>['sunflower'],
      seedRatePerHa: 6,
      seedUnit: 'kg',
      fertiliserSummary: 'Use balanced basal fertiliser and support flowering with potassium if soil tests are low.',
      otherInputs: <String>['Bird control', 'Weed control', 'Pollinator support'],
      stageAdvice: _oilseedAdvice,
      reminderOffsetsDays: <int>[0, 14, 30, 50, 70],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Sunflower benefits from good pollination and moderate nutrition.',
    ),
    CropAdviceProfile(
      name: 'Pigeon pea',
      aliases: <String>['pigeon pea', 'pigeonpea'],
      seedRatePerHa: 15,
      seedUnit: 'kg',
      fertiliserSummary: 'Use a light basal fertiliser; excessive nitrogen is usually not needed.',
      otherInputs: <String>['Weed control', 'Pest scouting', 'Drying area'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 14, 35, 60, 90],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Longer cycle legumes need regular weed checks in early growth.',
    ),
    CropAdviceProfile(
      name: 'Bambara nut',
      aliases: <String>['bambara', 'bambara nut'],
      seedRatePerHa: 45,
      seedUnit: 'kg',
      fertiliserSummary: 'Use light basal fertiliser and keep weeds low during early establishment.',
      otherInputs: <String>['Seed dressing', 'Weed control', 'Drying mats'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 12, 30, 50, 80],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'This crop is hardy but rewards clean seed and early weed control.',
    ),
    CropAdviceProfile(
      name: 'Lima bean',
      aliases: <String>['lima bean', 'lima beans'],
      seedRatePerHa: 70,
      seedUnit: 'kg',
      fertiliserSummary: 'Use a light starter fertiliser and keep nitrogen moderate.',
      otherInputs: <String>['Trellis', 'Weed control', 'Pest scouting'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 12, 28, 45, 65],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Staking helps if you are growing a climbing type.',
    ),
    CropAdviceProfile(
      name: 'Black-eyed pea',
      aliases: <String>['black-eyed pea', 'black eyed pea', 'cowpea'],
      seedRatePerHa: 25,
      seedUnit: 'kg',
      fertiliserSummary: 'Use moderate starter fertiliser and avoid too much nitrogen.',
      otherInputs: <String>['Seed dressing', 'Weed control', 'Pod borer scouting'],
      stageAdvice: _legumeAdvice,
      reminderOffsetsDays: <int>[0, 10, 25, 40, 55],
      hasPostEmergenceHerbicide: true,
      referenceNote: 'Timely harvesting and storage protect grain quality.',
    ),
    CropAdviceProfile(
      name: 'Okra leaf',
      aliases: <String>['okra leaf', 'jute mallow', 'ewedu'],
      seedRatePerHa: 10,
      seedUnit: 'kg',
      fertiliserSummary: 'Use light basal fertiliser and regular cut-and-come-again feeding.',
      otherInputs: <String>['Weed control', 'Watering', 'Cutting tools'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 10, 20, 30, 45],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Leafy harvests need repeated cutting and moisture management.',
    ),
    CropAdviceProfile(
      name: 'Amaranth',
      aliases: <String>['amaranth', 'leaf amaranth'],
      seedRatePerHa: 5,
      seedUnit: 'kg',
      fertiliserSummary: 'Use moderate nitrogen and harvest leaves early and often.',
      otherInputs: <String>['Weed control', 'Watering', 'Cutting tools'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 7, 14, 21, 30],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Short-cycle leafy production depends on repeated cuts.',
    ),
    CropAdviceProfile(
      name: 'Waterleaf',
      aliases: <String>['waterleaf'],
      seedRatePerHa: 4,
      seedUnit: 'kg',
      fertiliserSummary: 'Use light feeding and regular moisture for rapid leaf growth.',
      otherInputs: <String>['Watering', 'Weed control', 'Harvest knives'],
      stageAdvice: _vegetableAdvice,
      reminderOffsetsDays: <int>[0, 7, 14, 21, 30],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Waterleaf performs best under frequent harvesting.',
    ),
    CropAdviceProfile(
      name: 'Mango',
      aliases: <String>['mango'],
      seedRatePerHa: 100,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use establishment fertiliser and keep potassium steady during fruiting seasons.',
      otherInputs: <String>['Pruning', 'Weed control', 'Fruit fly control'],
      stageAdvice: _treeAdvice,
      reminderOffsetsDays: <int>[0, 30, 120, 240],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Fruit quality improves with pruning and sanitation.',
    ),
    CropAdviceProfile(
      name: 'Orange',
      aliases: <String>['orange', 'citrus'],
      seedRatePerHa: 200,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use basal fertiliser and repeat feeding as trees enter bearing.',
      otherInputs: <String>['Weed control', 'Pruning', 'Citrus pest scouting'],
      stageAdvice: _treeAdvice,
      reminderOffsetsDays: <int>[0, 30, 120, 240],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Citrus needs good drainage and regular sanitation.',
    ),
    CropAdviceProfile(
      name: 'Papaya',
      aliases: <String>['papaya', 'pawpaw'],
      seedRatePerHa: 1600,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use balanced fertiliser and maintain moisture through flowering and fruit set.',
      otherInputs: <String>['Weed control', 'Pest scouting', 'Wind protection'],
      stageAdvice: _fruitAdvice,
      reminderOffsetsDays: <int>[0, 30, 90, 180, 240],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Papaya is sensitive to waterlogging and strong wind.',
    ),
    CropAdviceProfile(
      name: 'Guava',
      aliases: <String>['guava'],
      seedRatePerHa: 400,
      seedUnit: 'seedlings',
      fertiliserSummary: 'Use basal feeding and prune to shape the canopy before heavy bearing.',
      otherInputs: <String>['Pruning', 'Weed control', 'Fruit fly control'],
      stageAdvice: _fruitAdvice,
      reminderOffsetsDays: <int>[0, 30, 120, 240],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Regular pruning improves airflow and fruit quality.',
    ),
    CropAdviceProfile(
      name: 'Garlic',
      aliases: <String>['garlic'],
      seedRatePerHa: 500,
      seedUnit: 'kg cloves',
      fertiliserSummary: 'Use a balanced basal fertiliser and top dress lightly while bulbs are expanding.',
      otherInputs: <String>['Fine seedbed', 'Weed control', 'Disease scouting'],
      stageAdvice: _rootAdvice,
      reminderOffsetsDays: <int>[0, 14, 30, 50, 70],
      hasPostEmergenceHerbicide: false,
      referenceNote: 'Bulb crops need good drainage and careful weed control.',
    ),
  ];

  static CropAdviceProfile? detect(String cropName) {
    final String normalized = cropName.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }
    for (final CropAdviceProfile profile in _profiles) {
      if (profile.name.toLowerCase() == normalized) {
        return profile;
      }
      if (profile.aliases.any((String alias) => normalized.contains(alias))) {
        return profile;
      }
    }
    return null;
  }

  static CropAdviceSummary summarize(Crop crop) {
    final CropAdviceProfile? profile = detect(crop.name);
    final CropAdviceProfile fallback = profile ?? _profiles.first;
    final double areaHa = crop.areaHa;
    final double seedRequirement = areaHa * fallback.seedRatePerHa;
    final List<CropReminderPlan> reminders = fallback.reminderOffsetsDays
        .map(
          (int offset) => CropReminderPlan(
            title: _reminderTitle(fallback.name, offset),
            dayOffset: offset,
            detail: _reminderDetail(fallback, crop.currentStage, offset),
          ),
        )
        .toList(growable: false);

    return CropAdviceSummary(
      profile: fallback,
      areaHa: areaHa,
      areaLabel: crop.landSizeLabel,
      seedRequirement: seedRequirement,
      fertiliserSummary: fallback.fertiliserSummary,
      otherInputs: fallback.otherInputs,
      stageAdvice: fallback.stageAdvice,
      reminders: reminders,
      referenceNote: fallback.referenceNote,
      matchConfidence: profile == null ? 0.45 : 1,
      hasPostEmergenceHerbicide: fallback.hasPostEmergenceHerbicide,
    );
  }

  static String _reminderTitle(String cropName, int offset) {
    if (offset == 0) {
      return 'Planting-day check';
    }
    if (offset <= 14) {
      return '$cropName early field check';
    }
    if (offset <= 45) {
      return '$cropName nutrition check';
    }
    if (offset <= 90) {
      return '$cropName protection check';
    }
    return '$cropName harvest prep';
  }

  static String _reminderDetail(CropAdviceProfile profile, CropStage stage, int offset) {
    if (offset == 0) {
      return 'Confirm seed quality, spacing, and moisture before setting up the crop.';
    }
    return profile.stageAdvice[stage] ?? profile.fertiliserSummary;
  }
}

const Map<CropStage, String> _cerealAdvice = <CropStage, String>{
  CropStage.seeding: 'Keep seedbed moisture steady and recheck spacing after emergence.',
  CropStage.germination: 'Scout for gaps, bird damage, and poor stand establishment.',
  CropStage.vegetative: 'This is the best time to weed, top dress, and correct nutrient stress.',
  CropStage.flowering: 'Reduce stress, keep moisture even, and watch for pests that affect grain set.',
  CropStage.fruiting: 'Protect grain fill or cob fill and begin harvest preparation.',
};

const Map<CropStage, String> _rootAdvice = <CropStage, String>{
  CropStage.seeding: 'Use healthy planting material and make sure ridges or beds drain well.',
  CropStage.germination: 'Check for sprouting success and replace missing stands quickly.',
  CropStage.vegetative: 'Keep weeds down early and support leaf growth before root bulking begins.',
  CropStage.flowering: 'Reduce moisture stress and monitor for pests and foliar diseases.',
  CropStage.fruiting: 'Focus on bulking, keeping foliage healthy, and preparing harvest logistics.',
};

const Map<CropStage, String> _legumeAdvice = <CropStage, String>{
  CropStage.seeding: 'Treat seed if possible and keep planting depth uniform for good emergence.',
  CropStage.germination: 'Watch for damping off and early insect pressure.',
  CropStage.vegetative: 'Use moderate nutrition and keep weeds down before canopy closure.',
  CropStage.flowering: 'Protect blooms and pods from moisture stress and pest pressure.',
  CropStage.fruiting: 'Drying and storage hygiene matter now so grain quality stays high.',
};

const Map<CropStage, String> _vegetableAdvice = <CropStage, String>{
  CropStage.seeding: 'Run a clean nursery or direct-seed into fine soil with even moisture.',
  CropStage.germination: 'Thin where needed and keep the bed weed-free.',
  CropStage.vegetative: 'This is where irrigation, foliar nutrition, and pest scouting pay off.',
  CropStage.flowering: 'Maintain moisture and potassium support for fruiting or head formation.',
  CropStage.fruiting: 'Harvest often and keep quality grading tight so returns stay high.',
};

const Map<CropStage, String> _fruitAdvice = <CropStage, String>{
  CropStage.seeding: 'Set healthy suckers or seedlings into well-prepared holes or beds.',
  CropStage.germination: 'Watch for establishment losses, pests, and water stress.',
  CropStage.vegetative: 'Build canopy strength with weed control and balanced feeding.',
  CropStage.flowering: 'Protect pollination, keep potassium adequate, and reduce stress.',
  CropStage.fruiting: 'Focus on size, colour, and timing for harvest and grading.',
};

const Map<CropStage, String> _treeAdvice = <CropStage, String>{
  CropStage.seeding: 'Check spacing, staking, and early root establishment.',
  CropStage.germination: 'Keep young trees watered, weed-free, and protected from pests.',
  CropStage.vegetative: 'Prune lightly, keep a nutrient rhythm, and maintain the basin or basin mulch.',
  CropStage.flowering: 'Support flowering with moisture balance and disease control.',
  CropStage.fruiting: 'Protect fruit set, improve sanitation, and plan harvest rounds.',
};

const Map<CropStage, String> _fiberAdvice = <CropStage, String>{
  CropStage.seeding: 'Use clean seed and good spacing for strong establishment.',
  CropStage.germination: 'Keep early weeds down to avoid weak stands.',
  CropStage.vegetative: 'This is the key nutrition and pest management window.',
  CropStage.flowering: 'Support square and boll formation with steady moisture.',
  CropStage.fruiting: 'Watch for boll opening, pest damage, and picking rounds.',
};

const Map<CropStage, String> _oilseedAdvice = <CropStage, String>{
  CropStage.seeding: 'Use a fine seedbed and accurate spacing.',
  CropStage.germination: 'Keep weeds low until the crop can close the rows.',
  CropStage.vegetative: 'A small boost of nutrition and weed control helps stem strength.',
  CropStage.flowering: 'Ensure pollinators have room and the crop is not moisture-stressed.',
  CropStage.fruiting: 'Protect seed fill and plan drying early.',
};
