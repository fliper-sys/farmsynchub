import 'package:uuid/uuid.dart';

import '../../data/services/crop_advice_catalog.dart';
import '../../domain/models/crop.dart';
import '../../domain/models/farm_activity.dart';

/// A pre-built schedule item for a crop, generated from the advice catalog.
class CropScheduleItem {
  const CropScheduleItem({
    required this.title,
    required this.detail,
    required this.dayOffset,
    required this.suggestedDate,
    required this.actionType,
    required this.priority,
  });

  final String title;
  final String detail;
  final int dayOffset;
  final DateTime suggestedDate;
  final CropScheduleActionType actionType;
  final FarmTodoPriority priority;

  String get actionEmoji {
    switch (actionType) {
      case CropScheduleActionType.planting:
        return '\u{1F331}';
      case CropScheduleActionType.fertilizer:
        return '\u{1F9EA}';
      case CropScheduleActionType.pesticide:
        return '\u{1F9F4}';
      case CropScheduleActionType.irrigation:
        return '\u{1F4A7}';
      case CropScheduleActionType.weeding:
        return '\u{1F33F}';
      case CropScheduleActionType.scouting:
        return '\u{1F50D}';
      case CropScheduleActionType.harvest:
        return '\u{1F33E}';
      case CropScheduleActionType.general:
        return '\u{1F4CB}';
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

/// Action type for crop schedule items.
enum CropScheduleActionType {
  planting,
  fertilizer,
  pesticide,
  irrigation,
  weeding,
  scouting,
  harvest,
  general,
}

/// Service that generates a complete crop calendar schedule from
/// the advice catalog's reminder offsets, customized per crop.
class CropScheduleService {
  /// Generates a list of schedule items for a given crop.
  static List<CropScheduleItem> generateSchedule(Crop crop) {
    final CropAdviceSummary advice = CropAdviceCatalog.summarize(crop);
    final DateTime plantingDate = crop.plantingDate;

    return advice.reminders.map((CropReminderPlan reminder) {
      final DateTime suggestedDate =
          plantingDate.add(Duration(days: reminder.dayOffset));
      final CropScheduleActionType actionType =
          _detectActionType(reminder.title, reminder.detail);
      final FarmTodoPriority priority =
          _detectPriority(reminder.dayOffset, crop.currentStage);

      return CropScheduleItem(
        title: reminder.title,
        detail: reminder.detail,
        dayOffset: reminder.dayOffset,
        suggestedDate: suggestedDate,
        actionType: actionType,
        priority: priority,
      );
    }).toList(growable: false);
  }

  /// Batch-converts all schedule items to FarmTodoItems for one-tap scheduling.
  static List<FarmTodoItem> scheduleToTodoItems(
      List<CropScheduleItem> schedule) {
    return schedule
        .map((CropScheduleItem item) => item.toTodoItem())
        .toList();
  }

  /// Groups schedule items by week offset for week-by-week display.
  static Map<String, List<CropScheduleItem>> groupByWeek(
      List<CropScheduleItem> schedule) {
    final Map<String, List<CropScheduleItem>> grouped =
        <String, List<CropScheduleItem>>{};

    for (final CropScheduleItem item in schedule) {
      final int weekNumber = (item.dayOffset ~/ 7) + 1;
      final String weekLabel = weekNumber == 1
          ? 'Week 1 (Days 0-6)'
          : 'Week $weekNumber (Days ${(weekNumber - 1) * 7}-${weekNumber * 7 - 1})';
      grouped.putIfAbsent(weekLabel, () => <CropScheduleItem>[]).add(item);
    }

    for (final List<CropScheduleItem> items in grouped.values) {
      items.sort(
          (CropScheduleItem a, CropScheduleItem b) => a.dayOffset.compareTo(b.dayOffset));
    }

    return grouped;
  }

  /// Provides a summary text of the schedule for display.
  static String scheduleSummary(
      List<CropScheduleItem> schedule, String cropName) {
    if (schedule.isEmpty) return 'No schedule items generated for $cropName.';

    final int fertilizerCount = schedule
        .where((CropScheduleItem s) =>
            s.actionType == CropScheduleActionType.fertilizer)
        .length;
    final int pesticideCount = schedule
        .where((CropScheduleItem s) =>
            s.actionType == CropScheduleActionType.pesticide)
        .length;
    final int total = schedule.length;

    return '$cropName has $total scheduled actions: $fertilizerCount fertilizer applications, $pesticideCount pest/disease treatments, and ${total - fertilizerCount - pesticideCount} other tasks.';
  }

  static CropScheduleActionType _detectActionType(
      String title, String detail) {
    final String lower = '$title $detail'.toLowerCase();

    if (lower.contains('plant') ||
        lower.contains('seed') ||
        lower.contains('sow')) {
      return CropScheduleActionType.planting;
    }
    if (lower.contains('fertil') ||
        lower.contains('nutri') ||
        lower.contains('top dress') ||
        lower.contains('basal')) {
      return CropScheduleActionType.fertilizer;
    }
    if (lower.contains('pest') ||
        lower.contains('insect') ||
        lower.contains('fung') ||
        lower.contains('herbic') ||
        lower.contains('chemical')) {
      return CropScheduleActionType.pesticide;
    }
    if (lower.contains('water') ||
        lower.contains('irrig') ||
        lower.contains('moisture')) {
      return CropScheduleActionType.irrigation;
    }
    if (lower.contains('weed')) {
      return CropScheduleActionType.weeding;
    }
    if (lower.contains('scout') ||
        lower.contains('check') ||
        lower.contains('inspect') ||
        lower.contains('monitor')) {
      return CropScheduleActionType.scouting;
    }
    if (lower.contains('harvest') || lower.contains('picking')) {
      return CropScheduleActionType.harvest;
    }

    return CropScheduleActionType.general;
  }

  static FarmTodoPriority _detectPriority(
      int dayOffset, CropStage currentStage) {
    if (dayOffset <= 3) return FarmTodoPriority.urgent;
    if (dayOffset >= 75) return FarmTodoPriority.high;

    if (currentStage == CropStage.flowering ||
        currentStage == CropStage.fruiting) {
      if (dayOffset >= 40 && dayOffset <= 60) return FarmTodoPriority.high;
    }

    return FarmTodoPriority.normal;
  }
}
