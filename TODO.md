# Crop & Livestock Enhancement Implementation Plan

## Branch: `blackboxai/crop-livestock-enhancements`

## Phase 1: Model & Service Layer - COMPLETE

### 1.1 GrowthTimelineEntry model
- File: `lib/domain/models/growth_timeline_entry.dart`
- Fields: id, cropId, stage, recordedAt, photoBase64, notes, heightCm, leafCount

### 1.2 FeedCalculatorService
- File: `lib/core/services/feed_calculator_service.dart`
- Reusable feed/water/maturity calcs for all livestock species/stages/purposes

### 1.3 CropScheduleService
- File: `lib/core/services/crop_schedule_service.dart`
- CropScheduleItem, CropScheduleActionType, week-by-week grouping, batch todo conversion
- Auto-detects fertilizer, pesticide, irrigation, weeding, scouting actions from advice text

### 1.4 VaccinationScheduleService
- File: `lib/core/services/vaccination_schedule_service.dart`
- Species-specific core vaccines (ND, PPR, CBPP, CSF, Anthrax, Blackquarter, Fowl Pox)
- Deworming schedules (interval-based), stage health checks, purpose-specific interventions
- Converts to FarmTodoItem for push notification scheduling

## Phase 2: UI Widgets - COMPLETE

### 2.1 Growth Timeline Widget + Form Sheet
- `lib/presentation/common/widgets/growth_timeline_widget.dart`
- Visual timeline with 5 growth stage markers, progress bar
- Bottom sheet form with photo picker (gallery/camera), height, leaf count, notes
- Saves entries to crop intelligence notes via CropNotifier.updateCrop()

### 2.2 Calendar Schedule Widget
- `lib/presentation/common/widgets/crop_calendar_schedule_widget.dart`
- Week-by-week grouped schedule viewer with action emoji badges
- "Create all" batch scheduling converts all to FarmTodoItems
- Individual tap-to-schedule per action
- Color-coded by action type (fertilizer=orange, pesticide=red, irrigation=blue, etc.)

### 2.3 Feeding Plan Widget
- `lib/presentation/common/widgets/feeding_plan_widget.dart`
- Daily feed/water per animal + per group metric cards
- Current vs suggested comparison with variance alerts (over/under feeding)
- Maturity projection countdown based on species/purpose
- Toggleable feeding advice section

### 2.4 Vaccination Health Calendar Widget
- `lib/presentation/common/widgets/vaccination_calendar_widget.dart`
- Species-specific vaccine, deworming, health check, vitamin schedules
- "Schedule all" batch + individual add buttons
- Age and due date display per intervention

## Phase 3: Screen Integration (PENDING)

### 3.1 Integrate into CropDetailScreen
- Add GrowthTimelineWidget + CropCalendarScheduleWidget sections
- Show before the field tasks and recent inputs sections

### 3.2 Integrate into LivestockDetailScreen
- Add FeedingPlanWidget + VaccinationCalendarWidget sections
- Show before the care tasks and production log sections

### 3.3 Weight Gain Chart from production logs
- Plot weight-over-time from existing productionLogs
- Target vs actual comparison per growth stage

### 3.4 AI-powered recommendations integration with GeminiService
### 3.5 Photo Journal enhancement for both screens
