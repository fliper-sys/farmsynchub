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

