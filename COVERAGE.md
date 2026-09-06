# Coverage and tap counts

Two questions this answers: which of the research's workflow families this prototype actually
demonstrates, and how the taps compare with the UX Performance Matrix.

## Tap counts

Counted by walking this implementation control by control, using the research's own counting
rules: a tap is one discrete touch that advances the task; a screen is a route change or a
blocking sheet; scrolling and swiping to reveal do not count; the guest's taps on a terminal
are not the operator's.

**Nobody has been timed.** The current-state figures are the research's, restated. The target
figures are the research's targets. The built column is what this app costs today.

| Workflow | Taps now | Target | Built | Screens now | Built |
|---|---|---|---|---|---|
| W02.20 The café coffee matrix, end to end (large oat latte, extra shot, half strength, extra hot, one sugar, vanilla, takeaway cup, named, card) | 24 | 12 | **11** | 11 | **1** |
| The same drink again from Recents, named, card | — | 3 | **3** | — | **0** |
| W01.02 Add a single item | 2 | 1 | **1** | 1 | **1** |
| W06.02 Four schooners and two wines as a round | 5 | 3 | **4** | 2 | **0** |
| W06.03 Repeat the last round, from the tab list | 12 | 2 | **2** | 2 | **0** |
| W05.05 Fire a held course from the floor | 4 | 2 | **2** | 2 | **0** |
| W09.01 Split equally three ways | 6 | 3 | **4** | 3 | **1** |
| W01.16 Name the order | 5 | 1 | **1** | 2 | **0** |
| W12.02 Accept an online order | 5 | 1 | **1** | 3 | **0** |
| W12.06 Mark ready and hand over | 5 | 2 | **2** | 3 | **0** |
| W02.14 Half-and-half pizza with a topping on one side | — | — | **6** | — | **1** |
| W02.12 Make it a meal from a burger | — | — | **2** | — | **1** |

Where the built figure is above the target, the reason is stated rather than hidden. The equal
split costs one tap more than the target because choosing the basis and the count are two
decisions, and collapsing them would guess. The bar round costs one more than the target
because a keypad prefix is two taps for two different drinks, and the research's three-tap
figure assumed one product.

## What the prototype demonstrates, by workflow family

| Family | Demonstrated |
|---|---|
| W01 Sale basics | Add, quantity, keypad prefix, repeat, remove with undo, void with a reason, notes, order name with disambiguation, park and recall, open price, sold out at add and in the cart, recents and favourites, the make queue, the order lock |
| W02 Product configuration | One-sheet configuration, required and optional groups, minimum and maximum, defaults kept and removed, modifier quantities, priced modifiers, variants, preparation options, allergens, pinned modifiers and search, combos, half-and-half sections, editing in the cart, the whole café matrix |
| W03 Order types | Type per venue with defaults, dine in with and without a floor, typed table numbers, buzzers, takeaway, pickup with a time, delivery with address, zone and fee, drive-through as its own type, changing type mid-order, name and token identifiers, duplicate names |
| W04 Tables and floor | Sixteen derived states with words and glyphs, the legend as a filter, covers, waiter assignment, notes, multi-order tables, move, merge, split, reset, block, attention badges with named causes, section stats, the lock and its override |
| W05 Courses, seats, kitchen send | Send per course, station routing, hold and fire, call and uncall, re-fire as a rush, seats on items, drinks now and food to the kitchen, ready and served as separate acts, sent state derived from station confirmation |
| W06 Bars, tabs, rounds | Named tabs, spend limits, card holds with an amber threshold, rounds as cart blocks, repeat the round, retrieval by name, card and bartender, duplicate-name warning, transfer to a table or a colleague, capture, the last-drinks sweep |
| W07 Discounts and pricing | Item and order discounts by percent and amount, set-the-total, named venue discounts, comps, price override, happy hour on a schedule, member and seniors price lists, automatic promotions (threshold, buy-one-get-one, bundle, fixed price), reasons and approvals, and the "why the price changed" block |
| W08 Payments | Quick tenders, cash with quick amounts and change, rounding on the cash leg only, card with surcharge, decline, timeout and verify, gift card, voucher, points, house account with settlement pending, room charge, manual card, multiple tenders, tips, reversal, zero balance |
| W09 Split bills | Five bases that mix, equal with an exact last portion, keyed amounts, percentage, by item with sharing by value, by seat with a shared portion, re-split the remainder, merge the unpaid, per-leg tenders, and the four-figure panel in a fixed position |
| W10 Refunds and voids | Void before send, void after send with a docket and a reason, void the order, refund by item, by quantity and by amount, refund to a chosen tender, approvals, and the audit trail |
| W11 Kitchen and printing | Station routing, dockets with modifiers, removals, allergens, notes and seats, section blocks for a half-and-half, course calls, void dockets, additions, rush, start, bump and recall, printer offline with the reason on the line, reprint and redirect |
| W12 Online, takeaway, delivery | The inbox as a home surface, accept, accept all, reject with a reason, prepaid and pay at venue, scheduled orders, prep time, channel pausing, ready, call, handover to a guest or a driver, failed delivery with a resolution |
| W13 Customers and loyalty | Search by name, phone or member number, attach and detach, duplicate detection on create, the usual order in one tap, loyalty points and redemption, member pricing, allergy and VIP flags, house accounts |
| W14 Staff and permissions | Roles with permission sets, permission-gated actions, approval on the operator's device with a reason, the operator staying logged in, and the audit line naming the approver |
| W15 Shifts and cash | Float, cash and card sales, paid in and out, drops, expected drawer, count and close with a variance the till explains, drawer open with a reason, shift report |
| W17 Degraded operation | Offline as a mode, tenders that need a third party refused with a local alternative, unsynced counts, station offline with the reason on the line, redirect and reprint |
| W18 Concurrency | The lock on payment, transfer, merge and whole-order void only; reading and item editing never blocked; the banner naming the holder and the time it frees itself; the override with an audit line; the pending-card-leg warning |
| W21 Accessibility and ergonomics | Target and spacing floors, word-plus-glyph state, tabular money, primary actions in the bottom band, no long-press-only or swipe-only routes, no double tap, repeat protection, haptic confirmation, reduced-motion-safe timings |

Not demonstrated, and named in the README as such: W16 device and settings, W19 reservations
beyond seating a booking, W20 customer display, kiosk and pay at table.
