# Finance, Inventory & Sales remodel plan

Goal: one clear money-and-stock flow, **buy → store → use → harvest/produce → sell**,
where every quantity can be traced and "how much is left" is always visible.

## 1. What the audit found

| # | Finding | Impact |
|---|---------|--------|
| 1 | Inventory stores one overwritten `availableQuantity`; there is no history. | No record of *who used what, when*; stock-takes and losses invisible. |
| 2 | Feed, treatments and other inputs are never deducted when used (e.g. "Mark fed"). | Stock "left" is wrong the day after it is entered. |
| 3 | Sales can push stock below zero; the quantity is silently clamped to 0. | Over-selling goes unnoticed. |
| 4 | Livestock "ready for sale" books **income immediately** *and* puts the heads into inventory, where they can be sold again. | Income can be counted twice. |
| 5 | Inventory value uses the *selling* price only. | No cost basis, no margin. |
| 6 | Harvested crops, eggs and mature animals land in a generic stock list. | Farmer has no "what can I sell today and for how much" view. |
| 7 | Finance home has no entry point to inventory, usage or sellable stock; the stock card links to Procurement. | Features are hard to find. |
| 8 | Three places (finance sheet, workspace, sales desk) each adjust inventory with their own code. | Inconsistent behaviour, no shared audit trail. |

## 2. Target model

* **Stock ledger** (`StockMovement`): immutable rows - opening, purchase, harvest,
  production, transferIn, sale, usage, loss, adjustment. Each stores signed quantity,
  balance after, unit value, note and the linked crop / animal group / transaction / order.
  Stored on device first (per account), merged to the cloud in the background.
* **Inventory item** stays as is (no migration). Derived numbers come from the ledger:
  used in last 30 days, average daily burn, days of cover, peak level.
* **Item groups** (derived, no schema change): *Inputs* (feed, fertiliser, medicine, seed,
  tools), *Produce* (harvests, eggs, milk), *Animals* (unit = head).
* **One stock service** so every screen goes through the same rules: no overselling,
  weighted-average cost on restock, every change logged.

## 3. Screens

1. **Finance home** - business hub tiles (Inventory, Ready to sell, Sales desk, Procurement,
   Expenses, Contacts) with live numbers + one attention banner (out of stock, low stock,
   expiring, produce waiting to be sold).
2. **Inventory** (`/inventory`) - stock value (cost), low / expiring counts, group + search
   filters, item cards showing **left**, usage in 30 days and days of cover. Item sheet:
   Use, Restock, Count, Loss, Sell + full movement history. Second tab: activity log.
3. **Ready to sell** (`/for-sale`) - harvested produce and animals in stock with potential
   revenue and margin, crops about to be harvested, mature animals that can be moved to
   sale stock, and a **quick sale** sheet (quantity limited to stock left).
4. Existing sales desk, procurement and expenses stay, now posting to the same ledger.

## 4. Logic fixes

* Overselling blocked in quick sale; warned (with override) in the manual transaction form.
* "Mark fed" deducts feed from feed stock and says how much was used / that stock ran short.
* Harvest → `harvest` movement, egg collection → `production`, animals → `transferIn`.
* Moving animals to sale stock no longer books income; income is booked at the actual sale.
* Procurement delivery / purchases → `purchase` movement.

## 5. Phases

1. Ledger model + provider, hub provider methods (usage, restock, count, loss, consume).
2. Stock service (quick sale, feed deduction).
3. Inventory screen, Ready-to-sell screen, routes.
4. Finance home hub, quick-add menu, oversell guard, call-site wiring, livestock fix.
5. Next (not in this change): customer credit / part-payments, reorder suggestions to
   procurement, per-crop cost-of-production report, Cloud Function validation of ledgers.
