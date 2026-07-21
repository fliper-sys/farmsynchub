# Console Error Fixes

- [X] **Error 1: "Bad state: Tried to use NotificationsNotifier after dispose was called"**
  - Fixed in `lib/providers/notification_provider.dart` — Added `mounted` check after `SharedPreferences.getInstance()` await in `_loadNotifications()`.

- [X] **Error 2: "Navigator operation requested with a context that does not include a Navigator"**
  - Fixed in `lib/app.dart` — Added `GlobalKey<NavigatorState>` to GoRouter and used `_rootNavigatorKey.currentContext` in `showDialog` calls within `_maybeShowPrompt()` and `_maybeShowFunFactPopup()` of `_StartupResumePromptState`.

- [X] **Minor: Helvetica/Helvetica-Bold Unicode warning** — Informational only, from `dart_pdf` library; not blocking.

---

# UI Modification Plan - Farm Screens

## Phase 1: Farms Screen (`farms_screen.dart`)
- [ ] 1a. Structure Overview Chips - Replace with card-based design with icons
- [ ] 1b. Farm Management Card - Reduce artwork height (170→150), name font (28→24), improve footer
- [ ] 1c. Process Cards & Documentation - Visual polish

## Phase 2: Farm Detail Screen (`farm_detail_screen.dart`) - UI Refinements
- [ ] 2a. Operating Focus - Redesign with colored status badge
- [ ] 2b. Quick Stats/Capacity Cards - Add progress indicator bars
- [ ] 2c. Action Buttons - Redesign as 2×2 grid with cards
- [ ] 2d. Linked Crops & Livestock - Add status badges, improve spacing
- [ ] 2e. Farm Suggestions - Minor improvements

## Phase 3: Farm Detail Screen - Collapsible Sections + Menu Navigation
- [ ] 3a. Create `_CollapsibleSection` reusable widget
- [ ] 3b. Create section navigation menu (triggered by AppBar button → bottom sheet)
- [ ] 3c. Refactor build method: wrap each section in `_CollapsibleSection` with scroll keys
- [ ] 3d. Add scroll-to-section logic in navigation sheet

