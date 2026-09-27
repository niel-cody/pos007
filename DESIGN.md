# The design system

The Goal document asks for three things the research folder said were still missing: the
interaction model, the information architecture, and the design system the flows are built
from. This is that, written from the built prototype rather than ahead of it.

## What the interface is asked to answer

The Goal lists the questions an operator has, in order: who am I serving, where are they, what
are they ordering, what has already been ordered, what has been sent, what is being prepared,
what has been served, what remains unpaid, what needs attention, what should I do next.

Every one of those is answered by something visible, not by memory:

| Question | Where it is answered |
|---|---|
| Who am I serving | Cart header: the identifier, then chips for the customer, member price, allergy, VIP, points, account |
| Where are they | The same header: table, typed table number, buzzer, covers, waiter, or the tab's name |
| What are they ordering | The cart, grouped by course or round, with the configuration under each line |
| What has already been ordered | Sent lines collapse into a summary that expands in one tap |
| What has been sent | A chip per line: Unsent, Held, Sending, Sent 19:42, Not confirmed, or the reason it did not print |
| What is being prepared | The kitchen board and, for a counter, the make queue with two timers per card |
| What has been served | A Served chip per line, a Served state on the course header and on the table tile |
| What remains unpaid | The amount due, at 40 pt, the largest text on the panel, in a position that never moves |
| What needs attention | The table's attention badge names its cause; the cart banner names a failed docket |
| What should I do next | Send and Pay are the two largest targets and are always in the same place |

## When to ask, and when to just add

The first version of this prototype asked every question up front, and it was too clicky. A
bacon and egg roll opened a sheet to confirm a sauce that has a default nobody changes four
times out of five.

The rule now is narrow, and it is the same rule everywhere:

> **Force only what cannot be made without an answer.**

Three policies, set per modifier group when the menu is authored:

| Policy | Meaning | Where it shows |
|---|---|---|
| **Forced** | No safe default exists. A steak cannot be cooked to "whatever". | Stops the sale and opens the sheet |
| **Offered** | Has a default, changed often. | One-tap chip on the line composer |
| **Quiet** | Has a default, changed rarely: glassware, garnish, base sauce. | The full sheet only |

A group whose minimum is already satisfied by its default is not a forced choice, however the
menu declares it. That single derivation removed most of the sheets in the product.

What still stops and asks: a pub steak's cooking temperature, a half-and-half pizza's sections,
a combo that has to be built from scratch, and an age-restricted sale.

## The composer

The guest does not speak in forms. They speak in changes, and the changes arrive after the
thing is already on the order:

> "Cheeseburger." · "Make it a meal." · "Large fries." · "No pickles." · "Actually a shake."

Selecting a cart line raises a bar under the product grid carrying that line's most common
changes, in the order that venue makes them. Every one is a single tap, applied in place. The
burger becomes a meal without being removed and re-added, and the "no pickles" said before the
meal was mentioned survives it. **More** opens the full sheet for the long tail.

Three kinds of chip:

- **Offer**, in green: the change worth the most, which is almost always the meal.
- **Swap**, in the venue's accent: replaces rather than adds. A premium spirit swaps out the
  house pour, reprices the line, and puts the brand on the docket. This is the single most
  valuable change a bartender makes and it is worth more than every modifier combined.
- **Neutral**: additions and removals, showing their price when they have one.

Each venue authors its own list, so the chips on a burger are the five things a Bolt cashier
actually hears, not the first five options in the menu.

## Logging in and out

A till is not one person's. Four people use the same screen in an hour, and the moment the
software cannot say which of them rang a line, took a void or opened the drawer, everything
built on top of that record is guesswork: the shift report, the variance, the wastage, the
conversation about the round that nobody remembers pouring.

So the till locks at the end of every sale. Not as a setting, as the model.

**The lock screen is tiles, not a keypad.** One per person on shift, each saying what that
tile can do, because a new starter should not have to be told which name is the supervisor.
Three tiers:

| Tier | Who | Getting in | What it carries |
|---|---|---|---|
| Standard | Bartender, barista, cashier, waiter, runner, host | One tap on the tile | Selling, removing unsent items, small discounts |
| Semi | Supervisor | Tile, then a four-digit PIN | Voids, comps, price overrides, unlocking an order |
| Full | Manager, administrator | Tile, then a four-digit PIN | Refunds, cash management, settings |

**The handover is three seconds.** What was paid, the change at 52 pt, and one decision on the
screen: receipt or not. Answering it ends the sale immediately; ignoring it lets the ring run
down and hands the till back anyway. The operator who is mid-queue loses one tap, which is the
price of the record being true.

**The record is then visible, not just stored.** A cart line rung by someone else carries their
initials. The shift surface breaks takings down by operator with their order counts. The
timeline names who did what and who approved it.

## The cart pivots

The same order reads differently depending on what the operator is about to do with it, so the
cart header carries a pivot. Which pivots appear is per venue.

| Pivot | Reads as | Where it is the default |
|---|---|---|
| Course | Paced by the floor | Full service, fine dining, pub bistro |
| Seat | Who is having what | Fine dining, and any venue about to split by seat |
| Round | What was poured together | Bar |
| Bundle | Meals as bags, extras after | QSR |
| As rung | The order it was taken in | Café, pizza, takeaway |

## Information architecture

**Surfaces, not screens.** Eight surfaces exist; each venue exposes only the ones it runs. A
café has Sell, Queue, Orders, Inbox, Shift. A full-service restaurant opens on Floor. A bar has
Tabs. The chrome is one line of glass at the top: venue, surfaces, status, operator, presenter.

**The cart is a panel, not a page.** It sits beside the working surface on Sell, Floor, Tabs,
Orders and Inbox, so opening an order never costs the context it came from.

**Three tiers, as the research defines them.** Primary actions are on the working surface in
one or two taps. Secondary actions are one contextual step away: the line menu, the course
header, the table sheet. Advanced actions are deliberate: behind a reason, an approval, or
both. Nothing consequential is one accidental contact away from happening.

**Sheets are sized to their content** and never stack. A sheet that would hide the cart shows
the four figures instead, so money is still readable while a tender is taken.

## Metrics

Converted from the research's millimetre baseline at roughly 4 pt per millimetre on a
ten-inch terminal.

| Class | Size | Where |
|---|---|---|
| Primary action | 52 pt, 60 pt in wet venues | Send, Pay, tenders, Add, Fire, Bump |
| Standard control | 40 pt | Category rail, secondary actions, chips with actions |
| Dense accelerator | 30 pt | Quantity steppers only, and never the only route |
| Destructive | Primary size, isolated by 32 pt | Void, Remove, Discard |
| Gap between independent targets | 8 pt minimum | Everywhere |

Type is one scale. Money is always tabular, so a changing total does not shuffle its own
digits: amount due 40 pt, change due 52 pt, cart line names 16 pt, nothing below 11 pt except
metadata that never carries a decision alone.

## Colour and material

Two layers, and the split is the whole rule.

**The navigation layer is Liquid Glass.** The top chrome, the surface tabs, the operator chip
and the floating upsell strip. This is where Apple's material belongs: it floats above content
and tells you it is chrome.

**The content layer is opaque.** Product tiles, the cart, the totals block, kitchen tickets,
dockets. A POS is read at a sunlit window and under a heat lamp, and the research asks for a
7:1 contrast ratio on any figure the operator acts on. Glass cannot promise that, so it is not
used there.

Each venue carries a hue. It tints the canvas, the accent and the soft fills, so switching
business type is felt before it is read. Semantic colour is fixed across venues — go, warn,
stop, info, fire — and is always paired with a word and an SF Symbol, because colour is never
the only indicator of state.

## Interaction rules

Taken from the research's wet-hands and one-handed sections, and applied throughout.

1. **Swipe on lists, never on the grid.** A cart line is a list row, and lists are swiped
   everywhere, so pulling one aside reveals quantity, rush, note and remove, with a long pull
   committing the first action rather than demanding an aim. The product grid is a scanning
   surface and a swipe there would be finicky and ambiguous, so there is none.
2. **No swipe and no long press is the only route.** Every swipe action is also in the line's
   menu; long press adds with defaults and the same thing is a visible control on the tile.
3. **No double tap anywhere, ever.**
4. **Repeat protection.** A second tap on a primary action inside 300 ms is treated as one
   contact from a wet finger and ignored.
5. **Every tap is acknowledged inside 100 ms** with a visible state change, plus a haptic,
   because a venue is too loud to rely on sound.
6. **Routine actions are not confirmed, they are undoable.** Removing an unsent line is a toast
   with Undo. Voiding a sent line is a reason and, for most roles, an approval.
7. **Motion is fast and purposeful** — 0.16 to 0.34 seconds — and nothing moves that the
   operator was about to touch.

## Components

Fifteen components carry the whole app, which is the point: `ProductTile`, `CartLineRow`,
`CourseBlock`, `Chip`, `StateBadge`, `PanelHeader`, `MoneyRow`, `PrimaryAction`,
`SecondaryAction`, `DestructiveAction`, `NumberPad`, `POSSegments`, `Panel`, `SheetFrame`,
`FiguresPanel`. A new surface is assembled from these, and that is why eight venues do not
mean eight designs.
