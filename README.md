# Rams

A native iPad point of sale for hospitality, built as a working prototype rather than a set of
screens. One device runs eight kinds of venue, and switching between them changes the
workflow, the catalogue, the tenders, the kitchen stations and the working surfaces — not the
labels on the buttons.

It is built from the `rams_pos` research: the Canonical Model's state machine, the workflow
catalogue's happy paths and edge cases, the venue profiles' configurations, and the
accessibility baseline's floors for touch targets, contrast and timing.

![The café configuration sheet](screenshots/01-cafe-configuration.png)

*Every axis of an Australian coffee order on one sheet, with a running price. On a legacy till
this is twenty-four taps across eleven screens.*

## Run it

```bash
git clone https://github.com/niel-cody/pos007.git
cd pos007
./run.sh
```

`run.sh` builds it, finds an iPad simulator, installs and launches. Rotate the simulator to
landscape with ⌘←: the app is landscape-only, because a till is.

To open it on a particular moment, pass a demo script: `./run.sh fs-split`.

Or open `Rams.xcodeproj` in Xcode, pick an iPad simulator, and press ⌘R.

Requires Xcode 26 and the iOS 26 SDK, because the chrome uses Liquid Glass. No dependencies,
no network, no accounts, no signing.

## The eight venues

Tap the venue chip at top left, or press ⌘K. Each row in the palette says what changes.

| Mode | Venue | What actually changes |
|---|---|---|
| Café | Prospect & Grind | Seven-axis coffee sheet, names on cups, a make queue, recents |
| QSR | Bolt Burger | Meals built in place from the line, swap prices, token numbers, four kitchen stations |
| Bar | The Lantern | Dark, dense, tabs, rounds, premium spirit swaps, a lock screen between sales |
| Pub bistro | The Royal Exchange | Typed table numbers, buzzers, drinks poured now while food goes to the kitchen, member pricing |
| Full service | Marlowe | Floor plan first, covers, courses with hold and fire, split bills, service charge |
| Fine dining | Aster | Seats, pacing with call and uncall, allergens by seat, wine routed to the cellar |
| Pizza | Via Norma | Half-and-half sections with the pricing rule in words, whole-pizza toppings, delivery |
| Takeaway | Sesame St Kitchen | The inbox is the home screen, three aggregators, prep time, handover and failure |

## What to try

The venue chip menu has a "What to try" item for whichever venue is open. In short:

- **Café.** Tap a Bacon & Egg Roll. It goes straight on the order, because the sauce has a
  default and nothing is unanswerable. The composer under the grid offers the five changes a
  counter actually hears. Then tap Latte and use More for the full seven-axis sheet.
- **QSR.** Tap Bolt Cheeseburger, then "Make it a meal" on the composer. The line becomes a
  meal in place, keeping any changes already made to the burger. Then "Swap drink", "Large
  fries", "No pickles" — each one tap, nothing reopened. Switch the cart to Bundle to see it
  as bags to pack.
- **Bar.** Tap Espresso Martini, then Grey Goose or Belvedere on the composer: the house pour
  is swapped out, the line reprices and the docket says which spirit. Type 4 on the keypad
  and tap Pale Ale for a round of four with no sheet. Pay a tab in cash and watch the
  three-second handover: the change, the receipt question, then back to the lock screen. The
  Shift surface then shows what each bartender took.
- **Full service.** The floor is the home screen. Table 4 has its mains held: open it and tap
  Fire on the Mains header. Table 2 asked for the bill: Split, Equal, 3, then re-split what
  is left when the guests change their minds.
- **Pizza.** Tap Half & Half. Pick a pizza per section, add a topping to one half, and read
  the pricing rule stated in words.
- **Takeaway.** Two aggregator orders are waiting. Accept all takes both.
- **Anything.** Open the presenter panel (the slider icon, or ⌘.) to take a printer offline,
  make a card decline, make an order arrive, or have another till take the order you are on.

Keyboard: ⌘K business type · ⌘S send · ⌘P pay · ⌘D split · ⌘N new order · ⌘Z undo ·
⌘. presenter · ⌘L lock · ⌘1…8 surfaces · Esc close.

To open the app directly on a particular moment, pass a demo script:

```bash
xcrun simctl launch "iPad Pro 13-inch (M5)" com.oolio.rams --demo fs-split
```

Scripts include `cafe-roll`, `cafe-configure`, `cafe-cart`, `cafe-queue`, `qsr-compose`,
`qsr-meal`, `qsr-bundle`, `qsr-combo`, `qsr-kitchen`, `bar-premium`, `bar-tabs`,
`bar-round-build`, `bar-paid`, `lock-screen`, `bar-age`, `pub-cart`, `fs-floor`, `fs-split`,
`fs-split-items`, `fd-courses`, `fd-seats`, `pizza-half`, `pizza-half-built`,
`takeaway-inbox`, `printer-down`, `lock`, `approval`, `modes`, `help`. They are listed in
`Rams/Store/Store+Demo.swift`.

## Screens

| | |
|---|---|
| ![Cart](screenshots/02-cafe-cart.png) | ![Queue](screenshots/03-cafe-queue.png) |
| The cart, with the name row above the tenders | The make queue: two timers a card, only the modifiers that change the make |
| ![Bar round](screenshots/04-bar-round.png) | ![Tabs](screenshots/05-bar-tabs.png) |
| Four schooners and two wines in four taps, grouped as a round | Tabs, with Same again on every one and a card hold running out |
| ![Floor](screenshots/07-full-service-floor.png) | ![Split](screenshots/08-split-by-item.png) |
| Sixteen table states, each a word and a glyph, and a legend that filters | Split by item, mixable with the other four bases |
| ![Courses](screenshots/06-pub-courses.png) | ![Seats](screenshots/09-fine-dining-seats.png) |
| Drinks poured now, food to the kitchen, on one order | Seats, pacing, and an allergy that reaches the ticket |
| ![Pizza](screenshots/10-pizza-halves.png) | ![Combo](screenshots/11-qsr-combo-sheet.png) |
| Half-and-half with the pricing rule in words | The combo, with swap prices on the tiles that cost more |
| ![Kitchen](screenshots/12-kitchen-board.png) | ![Inbox](screenshots/13-takeaway-inbox.png) |
| Four stations, allergens, rush, and bump meaning Ready | Three aggregators, prep time, and Accept all |
| ![Business type](screenshots/14-business-type.png) | ![Lock](screenshots/15-order-lock.png) |
| The switcher: one chip, ⌘K, and it says what changes | Another till is paying. You can still add and send. |
| ![Composer](screenshots/17-composer-cafe.png) | ![Meal](screenshots/18-composer-meal.png) |
| A roll goes on in one tap; the composer holds the changes a counter hears | The burger became a meal in place, and the slots are now the conversation |
| ![Premium](screenshots/19-premium-swap.png) | ![Bundle](screenshots/20-cart-bundle.png) |
| The house pour swapped for a premium vodka, repriced, on the docket | The same order as bags to pack |
| ![Lock screen](screenshots/22-lock-screen.png) | ![Sale complete](screenshots/23-sale-complete.png) |
| Three access tiers. Operators tap in, supervisors and managers use a PIN | Three seconds: the change, the receipt question, then the till hands itself back |
| ![Who took what](screenshots/24-who-took-what.png) | ![Seats](screenshots/21-cart-seats.png) |
| The reason everyone logs in: takings by operator, with order counts | The cart pivoted to seats for a bill that is about to be split |

## The mental model

Five ideas hold the whole interface together.

**A tap adds. The line is the editor.** The till only stops to ask when the kitchen genuinely
cannot proceed without an answer: a steak has to be cooked to something. Everything with a
sensible default goes straight on the order, and the guest's changes land on the line
afterwards, which is when they actually arrive. Selecting a line raises a composer of one-tap
changes — make it a meal, swap the gin, no pickles — applied in place.

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

**Every sale belongs to somebody.** Four people use the same screen in an hour, so the till
returns to a lock screen when a sale ends. Every line, void, discount and drawer opening
carries the initials of whoever was logged in, the shift report breaks takings down by
operator, and a line somebody else rang says so on the line.

The cost of that is one tap per sale, and the design spends its effort making that tap cheap:
the sale-complete beat is three seconds with the change at 52 pt and one decision on it
(receipt or not), answering it ends the sale early, and the tiles sit in fixed positions so
getting back in is muscle memory rather than a search.

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
