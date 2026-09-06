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

1. **No long press is the only route to anything.** Long press adds with defaults; the same
   thing is on the tile as a control and in the line's menu.
2. **No swipe is the only route.** Swipe to remove exists; so does the minus, and so does the
   menu.
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
