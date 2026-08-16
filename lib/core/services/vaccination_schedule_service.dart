import 'package:uuid/uuid.dart';

import '../../domain/models/farm_activity.dart';
import '../../domain/models/livestock.dart';

/// A scheduled vaccination/dosing event for a livestock group.
class VaccinationScheduleItem {
  const VaccinationScheduleItem({
    required this.title,
    required this.detail,
    required this.suggestedDate,
    required this.vaccineType,
    required this.ageMonths,
    required this.priority,
  });

  final String title;
  final String detail;
  final DateTime suggestedDate;
  final VaccineType vaccineType;
  final int ageMonths;
  final FarmTodoPriority priority;

  String get vaccineEmoji {
    switch (vaccineType) {
      case VaccineType.core:
        return '\u{1F489}';
      case VaccineType.deworming:
        return '\u{1F9A0}';
      case VaccineType.booster:
        return '\u{1F48A}';
      case VaccineType.healthCheck:
        return '\u{1FA7A}';
      case VaccineType.vitamin:
        return '\u{1F33F}';
    }
  }

  FarmTodoItem toTodoItem() {
    return FarmTodoItem(
      id: const Uuid().v4(),
      title: title,
      notes: detail,
      dueDate: suggestedDate,
      priority: priority,
      dailyReminder: false,
      pushNotificationEnabled: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// Types of vaccines/health interventions.
enum VaccineType {
  core,
  deworming,
  booster,
  healthCheck,
  vitamin,
}

/// Service that generates a vaccination and health intervention schedule
/// for livestock groups based on species, age, purpose, and growth stage.
class VaccinationScheduleService {
  /// Generates a vaccination schedule for a livestock group.
  static List<VaccinationScheduleItem> generateSchedule(
    Livestock livestock,
  ) {
    final List<VaccinationScheduleItem> items = <VaccinationScheduleItem>[];
    final DateTime now = DateTime.now();
    final int ageMonths = livestock.averageAgeMonths;

    // Core vaccinations based on species
    items.addAll(_coreVaccinations(livestock.species, now, ageMonths));

    // Deworming schedule
    items.addAll(_dewormingSchedule(livestock.species, now, ageMonths));

    // Stage-specific health checks
    items.addAll(_stageHealthChecks(livestock, now));

    // Purpose-specific interventions
    items.addAll(_purposeInterventions(livestock, now));

    return items;
  }

  static List<VaccinationScheduleItem> _coreVaccinations(
    LivestockSpecies species,
    DateTime now,
    int ageMonths,
  ) {
    final List<VaccinationScheduleItem> items = <VaccinationScheduleItem>[];

    switch (species) {
      case LivestockSpecies.chicken:
        if (ageMonths <= 1) {
          items.add(VaccinationScheduleItem(
            title: 'Newcastle Disease (ND) vaccine',
            detail:
                'Administer ND vaccine via eye drop or drinking water. Essential for all poultry.',
            suggestedDate: now,
            vaccineType: VaccineType.core,
            ageMonths: ageMonths,
            priority: FarmTodoPriority.urgent,
          ));
          items.add(VaccinationScheduleItem(
            title: 'Gumboro (IBD) vaccine',
            detail:
                'Administer Infectious Bursal Disease vaccine at 2-3 weeks of age.',
            suggestedDate: now.add(const Duration(days: 14)),
            vaccineType: VaccineType.core,
            ageMonths: ageMonths,
            priority: FarmTodoPriority.high,
          ));
        }
        if (ageMonths >= 2) {
          items.add(VaccinationScheduleItem(
            title: 'Fowl Pox vaccine',
            detail:
                'Administer Fowl Pox vaccine via wing web stab, usually at 8-12 weeks.',
            suggestedDate: now.add(const Duration(days: 7)),
            vaccineType: VaccineType.core,
            ageMonths: ageMonths,
            priority: FarmTodoPriority.normal,
          ));
        }
        break;

      case LivestockSpecies.goat:
        items.add(VaccinationScheduleItem(
          title: 'PPR vaccine (Peste des Petits Ruminants)',
          detail:
              'Annual PPR vaccination recommended for all goats. Protects against devastating viral disease.',
          suggestedDate: now,
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.urgent,
        ));
        items.add(VaccinationScheduleItem(
          title: 'Anthrax vaccine',
          detail:
              'Annual anthrax vaccination, especially in endemic areas. Administer before rainy season.',
          suggestedDate: now.add(const Duration(days: 7)),
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.high,
        ));
        break;

      case LivestockSpecies.cattle:
        items.add(VaccinationScheduleItem(
          title: 'CBPP vaccine (Contagious Bovine Pleuropneumonia)',
          detail:
              'Annual CBPP vaccination is recommended for cattle in endemic regions.',
          suggestedDate: now,
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.urgent,
        ));
        items.add(VaccinationScheduleItem(
          title: 'Anthrax & Blackquarter vaccine',
          detail:
              'Combined anthrax and blackquarter vaccination. Boost annually before rainy season.',
          suggestedDate: now.add(const Duration(days: 14)),
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.high,
        ));
        break;

      case LivestockSpecies.pig:
        items.add(VaccinationScheduleItem(
          title: 'CSF vaccine (Classical Swine Fever)',
          detail:
              'Essential CSF vaccination for all pigs. Follow local veterinary guidelines.',
          suggestedDate: now,
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.urgent,
        ));
        break;

      case LivestockSpecies.sheep:
        items.add(VaccinationScheduleItem(
          title: 'PPR vaccine (Peste des Petits Ruminants)',
          detail:
              'Annual PPR vaccination recommended for all sheep.',
          suggestedDate: now,
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.urgent,
        ));
        break;

      case LivestockSpecies.rabbit:
        items.add(VaccinationScheduleItem(
          title: 'RVHD vaccine (Rabbit Viral Haemorrhagic Disease)',
          detail:
              'Essential RVHD vaccination for all rabbits, especially in commercial hutches. Repeat annually.',
          suggestedDate: now,
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.urgent,
        ));
        break;

      case LivestockSpecies.duck:
        items.add(VaccinationScheduleItem(
          title: 'Duck Viral Hepatitis vaccine',
          detail:
              'Protects young ducklings from viral hepatitis, given in the first week of life.',
          suggestedDate: now,
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.high,
        ));
        items.add(VaccinationScheduleItem(
          title: 'Duck Plague (Viral Enteritis) vaccine',
          detail:
              'Annual duck plague vaccination, important where ducks share water with wild birds.',
          suggestedDate: now.add(const Duration(days: 14)),
          vaccineType: VaccineType.core,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.normal,
        ));
        break;

      case LivestockSpecies.fish:
        items.add(VaccinationScheduleItem(
          title: 'Water quality and disease check',
          detail:
              'Test pond/tank water quality (pH, ammonia, oxygen) and inspect for parasites or fungal signs. '
              'Fish are not routinely vaccinated in smallholder ponds - water quality is the main defence.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.high,
        ));
        break;

      case LivestockSpecies.snail:
        items.add(VaccinationScheduleItem(
          title: 'Shell and pest health check',
          detail:
              'Check shell condition and calcium supply, and inspect the pen for ants, rodents, and mould. '
              'Snails are not vaccinated - housing hygiene and calcium feed are the main defence.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: ageMonths,
          priority: FarmTodoPriority.high,
        ));
        break;
    }

    return items;
  }

  static List<VaccinationScheduleItem> _dewormingSchedule(
    LivestockSpecies species,
    DateTime now,
    int ageMonths,
  ) {
    final int intervalWeeks = switch (species) {
      LivestockSpecies.chicken => 8,
      LivestockSpecies.goat => 6,
      LivestockSpecies.sheep => 6,
      LivestockSpecies.pig => 8,
      LivestockSpecies.cattle => 8,
      LivestockSpecies.rabbit => 8,
      LivestockSpecies.duck => 8,
      LivestockSpecies.fish => 12,
      LivestockSpecies.snail => 12,
    };

    final String animalLabel = _speciesLabel(species).toLowerCase();

    return <VaccinationScheduleItem>[
      VaccinationScheduleItem(
        title: 'Deworming treatment',
        detail:
            'Routine deworming for $animalLabel. Use broad-spectrum anthelmintic. Repeat every $intervalWeeks weeks.',
        suggestedDate: now,
        vaccineType: VaccineType.deworming,
        ageMonths: ageMonths,
        priority: FarmTodoPriority.high,
      ),
      VaccinationScheduleItem(
        title: 'Follow-up deworming',
        detail:
            'Second round of deworming. Rotate dewormer class to prevent resistance.',
        suggestedDate: now.add(Duration(days: intervalWeeks * 7)),
        vaccineType: VaccineType.deworming,
        ageMonths: ageMonths,
        priority: FarmTodoPriority.normal,
      ),
    ];
  }

  static List<VaccinationScheduleItem> _stageHealthChecks(
    Livestock livestock,
    DateTime now,
  ) {
    final List<VaccinationScheduleItem> items = <VaccinationScheduleItem>[];
    final String animal = _speciesLabel(livestock.species).toLowerCase();

    switch (livestock.growthStage) {
      case AnimalGrowthStage.starter:
        items.add(VaccinationScheduleItem(
          title: 'Starter health assessment',
          detail:
              'Conduct full health check on young $animal. Check for umbilical health, hydration, and early disease signs.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: livestock.averageAgeMonths,
          priority: FarmTodoPriority.high,
        ));
        break;
      case AnimalGrowthStage.grower:
        items.add(VaccinationScheduleItem(
          title: 'Grower health check',
          detail:
              'Mid-stage health assessment. Check weight gain trajectory, feed conversion, and disease pressure.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: livestock.averageAgeMonths,
          priority: FarmTodoPriority.normal,
        ));
        break;
      case AnimalGrowthStage.breeding:
        items.add(VaccinationScheduleItem(
          title: 'Pre-breeding health screening',
          detail:
              'Comprehensive health check before breeding. Test for brucellosis and other reproductive diseases.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: livestock.averageAgeMonths,
          priority: FarmTodoPriority.urgent,
        ));
        break;
      case AnimalGrowthStage.finishing:
        items.add(VaccinationScheduleItem(
          title: 'Pre-sale health certification',
          detail:
              'Final health check before sale. Ensure withdrawal periods for any medications are observed.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: livestock.averageAgeMonths,
          priority: FarmTodoPriority.high,
        ));
        break;
      case AnimalGrowthStage.mature:
        items.add(VaccinationScheduleItem(
          title: 'Routine mature health check',
          detail: 'Regular health monitoring for mature $animal. Check body condition, feet, eyes, and teeth.',
          suggestedDate: now,
          vaccineType: VaccineType.healthCheck,
          ageMonths: livestock.averageAgeMonths,
          priority: FarmTodoPriority.normal,
        ));
        break;
    }

    return items;
  }

  static List<VaccinationScheduleItem> _purposeInterventions(
    Livestock livestock,
    DateTime now,
  ) {
    final List<VaccinationScheduleItem> items = <VaccinationScheduleItem>[];

    if (livestock.purpose == LivestockPurpose.milk) {
      items.add(VaccinationScheduleItem(
        title: 'Mastitis prevention program',
        detail:
            'Implement teat dipping, clean milking hygiene, and monitor somatic cell counts.',
        suggestedDate: now,
        vaccineType: VaccineType.healthCheck,
        ageMonths: livestock.averageAgeMonths,
        priority: FarmTodoPriority.high,
      ));
    }

    if (livestock.purpose == LivestockPurpose.eggs) {
      items.add(VaccinationScheduleItem(
        title: 'Layer vitamin supplement',
        detail:
            'Provide calcium and vitamin D3 supplement in feed or water for strong eggshell quality.',
        suggestedDate: now,
        vaccineType: VaccineType.vitamin,
        ageMonths: livestock.averageAgeMonths,
        priority: FarmTodoPriority.normal,
      ));
    }

    if (livestock.purpose == LivestockPurpose.breeding) {
      items.add(VaccinationScheduleItem(
        title: 'Vitamin & mineral boost for breeding',
        detail:
            'Administer vitamin A, D, E, and selenium supplement to support fertility and pregnancy.',
        suggestedDate: now,
        vaccineType: VaccineType.vitamin,
        ageMonths: livestock.averageAgeMonths,
        priority: FarmTodoPriority.high,
      ));
    }

    return items;
  }

  static String _speciesLabel(LivestockSpecies species) {
    switch (species) {
      case LivestockSpecies.goat:
        return 'Goats';
      case LivestockSpecies.chicken:
        return 'Chickens';
      case LivestockSpecies.pig:
        return 'Pigs';
      case LivestockSpecies.cattle:
        return 'Cattle';
      case LivestockSpecies.sheep:
        return 'Sheep';
      case LivestockSpecies.rabbit:
        return 'Rabbits';
      case LivestockSpecies.duck:
        return 'Ducks';
      case LivestockSpecies.fish:
        return 'Fish';
      case LivestockSpecies.snail:
        return 'Snails';
    }
  }
}
