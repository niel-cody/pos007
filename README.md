# Rams

A native iPad point of sale for hospitality, built as a working prototype rather than a set of
screens. One device runs eight kinds of venue, and switching between them changes the
workflow, the catalogue, the tenders, the kitchen stations and the working surfaces — not the
labels on the buttons.

It is built from the `rams_pos` research: the Canonical Model's state machine, the workflow
catalogue's happy paths and edge cases, the venue profiles' configurations, and the
accessibility baseline's floors for touch targets, contrast and timing.

## Run it

```bash
./build.sh
```

Then install and launch on a booted iPad simulator:

```bash
xcrun simctl boot "iPad Pro 13-inch (M5)"; open -a Simulator
xcrun simctl install "iPad Pro 13-inch (M5)" .build/Build/Products/Debug-iphonesimulator/Rams.app
xcrun simctl launch "iPad Pro 13-inch (M5)" com.oolio.rams
```

Rotate the simulator to landscape (⌘←). The app is landscape-only, because a till is.

Requires Xcode 26 and the iOS 26 SDK. No dependencies, no network, no accounts.

## The eight venues

Tap the venue chip at top left, or press ⌘K. Each row in the palette says what changes.

| Mode | Venue | What actually changes |
|---|---|---|
| Café | Prospect & Grind | Seven-axis coffee sheet, names on cups, a make queue, recents |
| QSR | Bolt Burger | Combos with swap prices, upsell strip, token numbers, four kitchen stations |
| Bar | The Lantern | Dark, dense, tabs, rounds with Repeat, card holds, a tap adds without a sheet |
| Pub bistro | The Royal Exchange | Typed table numbers, buzzers, drinks poured now while food goes to the kitchen, member pricing |
| Full service | Marlowe | Floor plan first, covers, courses with hold and fire, split bills, service charge |
| Fine dining | Aster | Seats, pacing with call and uncall, allergens by seat, wine routed to the cellar |
| Pizza | Via Norma | Half-and-half sections with the pricing rule in words, whole-pizza toppings, delivery |
| Takeaway | Sesame St Kitchen | The inbox is the home screen, three aggregators, prep time, handover and failure |

## What to try

The venue chip menu has a "What to try" item for whichever venue is open. In short:

- **Café.** Tap Latte. Size, milk, strength, temperature, sugar, syrup and cup are on one
  sheet with a running price. Add it, tap a name from the row above the tenders, tap Card.
  Then look at Just made: one tap rebuilds that exact drink.
- **Bar.** Type 4 on the keypad and tap Pale Ale: one line of four, no sheet. The cart groups
  it as Round 1 with a Repeat control. Go to Tabs and use Same again on any tab.
- **Full service.** The floor is the home screen. Table 4 has its mains held: open it and tap
  Fire on the Mains header. Table 2 asked for the bill: Split, Equal, 3, then re-split what
  is left when the guests change their minds.
- **Pizza.** Tap Half & Half. Pick a pizza per section, add a topping to one half, and read
  the pricing rule stated in words.
- **Takeaway.** Two aggregator orders are waiting. Accept all takes both.
- **Anything.** Open the presenter panel (the slider icon, or ⌘.) to take a printer offline,
  make a card decline, make an order arrive, or have another till take the order you are on.

Keyboard: ⌘K business type · ⌘S send · ⌘P pay · ⌘D split · ⌘N new order · ⌘Z undo ·
⌘. presenter · ⌘1…8 surfaces · Esc close.

To open the app directly on a particular moment, pass a demo script:

```bash
xcrun simctl launch "iPad Pro 13-inch (M5)" com.oolio.rams --demo fs-split
```

Scripts include `cafe-configure`, `cafe-cart`, `cafe-queue`, `qsr-combo`, `qsr-kitchen`,
`bar-tabs`, `bar-round-build`, `bar-age`, `pub-cart`, `fs-floor`, `fs-split`, `fs-split-items`,
`fd-courses`, `pizza-half`, `pizza-half-built`, `takeaway-inbox`, `printer-down`, `lock`,
`approval`, `modes`, `help`. They are listed in `Rams/Store/Store+Demo.swift`.

## The mental model

Five ideas hold the whole interface together.

**One working surface, and the order opens over it.** A waiter reads the floor, taps a table
and the order appears beside it. The floor never goes away. The same is true of the tabs list
and the inbox. Route changes are what make joined-up work feel slow, so there are almost none.

**The cart is the order, and it is grouped the way the venue thinks.** Courses in a restaurant,
rounds at a bar, a flat list at a counter. Sent lines collapse so a table that has ordered three
times is still readable.

**State is shown, never remembered.** Sent, held, sending, not confirmed, not printed, ready,
served, part paid, locked, unsynced: all of it is on the line or the tile where the decision is
made, always as a word and a glyph, never as a colour alone. "Sent" waits for a station to
confirm; the tap is acknowledged in under a tenth of a second by the line leaving Unsent and
the button changing to "Sending 4".

**Approval comes to the operator.** A manager taps a PIN on the operator's own device, picks a
reason, and the action is audited against them. Nobody is logged out and nobody walks anywhere.

**Offline is a mode, not an error.** Cash, accounts and manual card records keep trading. Sends
queue with the reason visible on the line. The order is never the thing that is lost.

## Architecture

```
Rams/
  Domain/      Money, the canonical state machine, catalogue, order, pricing, kitchen
  Store/       POSStore (@Observable) plus one extension per area of behaviour
  Seed/        Eight venues: catalogue, floor, staff, customers, live orders, tickets
  Design/      Tokens, type scale, metrics, and the shared components
  Features/    Shell, Sell, Surfaces, Sheets
```

`POSStore` is the single source of truth. Views read it and call intents on it; no view mutates
an order directly. Every state name in `Domain/States.swift` is the one the Canonical Model
uses, so a workflow identifier in the research maps onto a type here without translation.

Adding a venue is one file in `Seed/` plus a case in `VenueProfile.profile(for:)`. Nothing in
`Features/` needs to change: every surface, tender, station and grouping decision reads the
profile.

## Deliberately not built

Named so nobody has to discover it in a demo.

- No back office. Menus, prices, promotions, floors, roles and devices are seeded in code.
- No customer display, kiosk or QR pay-at-table. The research covers them; they are separate
  surfaces, not this one.
- No real payment terminal, printer, scale or scanner. The terminal is simulated so a decline,
  a timeout and a verify can be demonstrated on cue.
- No server. Multi-device concurrency is modelled — the lock, the override, the audit line —
  but the second device is simulated from the presenter panel.
- No persistence between launches. Every launch is a fresh service.
- Reservations exist on the floor as bookings that can be seated. There is no booking system.

## Honesty about the numbers

`COVERAGE.md` compares tap counts with the research's UX Performance Matrix. Those counts were
made by walking this implementation, control by control. Nobody has been timed. The research
says the same thing about its own figures, and it is worth repeating: the relative numbers are
worth something, the absolute ones are worth very little until an operator is standing at a
counter with a stopwatch.
