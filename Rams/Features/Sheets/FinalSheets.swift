import SwiftUI

// MARK: - Courses

struct CoursesSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var newCourse = ""

    private var order: Order? { store.currentOrder }

    var body: some View {
        if let order {
            SheetFrame(title: "Courses",
                       subtitle: "pacing is the floor's job, so a course can be held, fired, called and uncalled",
                       glyph: "list.number") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(order.courses) { course in
                            let items = order.items(inCourse: course.id)
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: course.glyph)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.accent)
                                    Text(course.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(theme.ink)
                                    if course.calledAt != nil {
                                        Chip(text: "Called \(course.calledAt!.hhmm)", glyph: "bell.fill",
                                             tint: Palette.info, filled: true, small: true)
                                    }
                                    Spacer()
                                    Text("\(items.reduce(0) { $0 + $1.quantity }) items")
                                        .font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                                }
                                Text(items.isEmpty ? "Nothing in this course yet"
                                     : items.map { "\($0.quantity)× \($0.name)" }.joined(separator: ", "))
                                    .font(.system(size: 13))
                                    .foregroundStyle(theme.inkSecondary)

                                HStack(spacing: 7) {
                                    Toggle(isOn: Binding(
                                        get: { course.autoFire },
                                        set: { on in
                                            store.mutateCurrent { o in
                                                if let i = o.courses.firstIndex(where: { $0.id == course.id }) {
                                                    o.courses[i].autoFire = on
                                                }
                                            }
                                            if !on { store.holdCourse(course.id) }
                                        })) {
                                        Text("Fires as it is added").font(.system(size: 13))
                                    }
                                    .toggleStyle(.switch)
                                    Spacer()
                                    SecondaryAction(title: course.calledAt == nil ? "Call" : "Uncall",
                                                    glyph: "bell") {
                                        store.callCourse(course.id)
                                    }
                                    .frame(width: 110)
                                    SecondaryAction(title: "Fire", glyph: "flame.fill",
                                                    tint: Palette.fire) {
                                        store.fireCourse(course.id)
                                    }
                                    .frame(width: 110)
                                }
                            }
                            .padding(Metric.pad)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .fill(theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                    }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("A course of your own — “Cheese”, “Wine 2”", text: $newCourse)
                                .font(.system(size: 15)).textFieldStyle(.plain)
                                .padding(12)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(theme.surface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                                        }
                                }
                            SecondaryAction(title: "Add", glyph: "plus", enabled: !newCourse.isEmpty) {
                                store.addCourse(newCourse)
                                newCourse = ""
                            }
                            .frame(width: 110)
                        }
                    }
                    .padding(Metric.padLarge)
                }
            } footer: {
                PrimaryAction(title: "Done", glyph: "checkmark") { store.route = nil }
            }
        }
    }
}

// MARK: - Seats

struct SeatSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var itemID: UUID

    private var order: Order? { store.currentOrder }
    private var item: OrderItem? { order?.liveItems.first { $0.id == itemID } }

    var body: some View {
        SheetFrame(title: "Seat",
                   subtitle: "\(item?.name ?? "") · a seat lives on the item, so a guest can move",
                   glyph: "chair.lounge.fill") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                    ForEach(1...max(8, order?.guestCount ?? 8), id: \.self) { s in
                        Button {
                            store.setSeat(itemID, s)
                            store.route = nil
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(s)").font(.system(size: 22, weight: .bold, design: .rounded))
                                if let count = order?.liveItems.filter({ $0.seat == s }).count, count > 0 {
                                    Text("\(count) item\(count == 1 ? "" : "s")").font(.system(size: 11))
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 68)
                            .foregroundStyle(item?.seat == s ? .white : theme.ink)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .fill(item?.seat == s ? theme.accent : theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                    }
                            }
                        }
                        .posPress()
                    }
                }
                SecondaryAction(title: "Shared — no seat", glyph: "person.3") {
                    store.setSeat(itemID, nil)
                    store.route = nil
                }
                Text("Seats may outnumber covers and covers may outnumber seats. Reducing covers never moves an item off a seat.")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary)
                Spacer()
            }
            .padding(Metric.padLarge)
        } footer: {
            EmptyView()
        }
    }
}

// MARK: - Notes

struct NoteSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var itemID: UUID?
    @State private var text = ""

    private var item: OrderItem? {
        itemID.flatMap { id in store.currentOrder?.liveItems.first { $0.id == id } }
    }

    var body: some View {
        SheetFrame(title: itemID == nil ? "Order note" : "Note on \(item?.name ?? "")",
                   subtitle: itemID == nil ? "the whole order, on every docket"
                                           : "prints on the docket for this line only",
                   glyph: "text.bubble.fill") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Type the note", text: $text, axis: .vertical)
                    .font(.system(size: 17)).textFieldStyle(.plain)
                    .padding(14)
                    .frame(minHeight: 100, alignment: .top)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                            .fill(theme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                    .strokeBorder(theme.hairline, lineWidth: 0.7)
                            }
                    }
                PanelHeader("Common notes")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 2), spacing: 7) {
                    ForEach(quick, id: \.self) { q in
                        Button {
                            text = text.isEmpty ? q : text + ", " + q
                        } label: {
                            Text(q)
                                .font(.system(size: 14))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12).frame(height: 44)
                                .foregroundStyle(theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(theme.accentSoft)
                                }
                        }
                        .posPress()
                    }
                }
                Spacer()
            }
            .padding(Metric.padLarge)
        } footer: {
            HStack(spacing: 10) {
                SecondaryAction(title: "Cancel") { store.route = nil }
                PrimaryAction(title: "Save the note", glyph: "checkmark") {
                    store.setNote(itemID, text)
                    if item?.isSentOrLater == true {
                        store.toast(.warn, "The kitchen already has this line",
                                    detail: "Send again so they see the note")
                    }
                    store.route = nil
                }
            }
        }
        .onAppear {
            text = itemID == nil ? (store.currentOrder?.orderNote ?? "") : (item?.note ?? "")
        }
    }

    private var quick: [String] {
        if itemID == nil {
            return ["Allergy — see the line notes", "Birthday", "In a hurry",
                    "Split the bill later", "Regulars", "Wedding anniversary"]
        }
        return ["No onion", "Extra hot", "Well done", "Allergy — nuts",
                "On the side", "Cut in half", "Kids portion", "No garnish"]
    }
}

// MARK: - Open price

struct OpenPriceSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var productID: UUID
    @State private var pad = ""

    private var product: Product? { store.catalogue.product(productID) }

    var body: some View {
        SheetFrame(title: product?.name ?? "Open price",
                   subtitle: "type what the guest is paying",
                   glyph: "dollarsign.circle") {
            VStack(spacing: 12) {
                NumberPad(value: $pad, style: .money,
                          quickAmounts: [Money(5), Money(10), Money(20), Money(50)],
                          confirmTitle: "Add at \(Money(cents: Int(pad) ?? 0).formatted())",
                          confirmEnabled: (Int(pad) ?? 0) > 0) {
                    if let p = product {
                        store.add(product: p, openPrice: Money(cents: Int(pad) ?? 0))
                    }
                    store.route = nil
                }
            }
            .padding(Metric.padLarge)
        } footer: {
            EmptyView()
        }
    }
}

// MARK: - Move or merge

struct TransferSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var orderID: UUID

    private var order: Order? { store.order(orderID) }

    var body: some View {
        if let order {
            SheetFrame(title: "Move or merge",
                       subtitle: "\(order.identifierLabel) · the kitchen gets a transfer docket either way",
                       glyph: "arrow.left.arrow.right") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if store.profile.floorEnabled {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("Move to a table")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 5),
                                          spacing: 7) {
                                    ForEach(store.tables.filter { $0.id != order.tableID && $0.isActive }) { t in
                                        let free = store.state(of: t) == .vacant
                                        Button {
                                            store.moveOrder(orderID, to: t)
                                            store.route = nil
                                        } label: {
                                            VStack(spacing: 1) {
                                                Text(t.label).font(.system(size: 16, weight: .bold))
                                                Text(free ? "free" : store.state(of: t).word)
                                                    .font(.system(size: 10.5))
                                            }
                                            .frame(maxWidth: .infinity).frame(height: 52)
                                            .foregroundStyle(free ? theme.ink : theme.inkSecondary)
                                            .background {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .fill(theme.surface)
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                            .strokeBorder(free ? theme.hairline : Palette.warn.opacity(0.5),
                                                                          lineWidth: 0.8)
                                                    }
                                            }
                                        }
                                        .posPress()
                                    }
                                }
                            }
                        }

                        let others = store.liveOrders.filter { $0.id != orderID }
                        if !others.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("Merge into another order",
                                            detail: "this order's items move across and it closes as Merged")
                                ForEach(others.prefix(6)) { o in
                                    Button {
                                        store.mergeOrders(orderID, into: o.id)
                                        store.route = nil
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(o.identifierLabel)
                                                    .font(.system(size: 14.5, weight: .semibold))
                                                    .foregroundStyle(theme.ink)
                                                Text("\(o.itemCount) items · \(o.openedBy)")
                                                    .font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                                            }
                                            Spacer()
                                            Text(o.total.formatted())
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .moneyFigure().foregroundStyle(theme.ink)
                                        }
                                        .padding(12)
                                        .background {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .fill(theme.surface)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                                                }
                                        }
                                    }
                                    .posPress()
                                }
                            }
                        }

                        if store.profile.waiterAssignment || store.profile.tabsEnabled {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("Hand it to someone else")
                                HStack(spacing: 7) {
                                    ForEach(store.staff) { s in
                                        Button {
                                            store.transferTab(orderID, to: s.initials)
                                            store.route = nil
                                        } label: {
                                            VStack(spacing: 1) {
                                                Text(s.initials).font(.system(size: 15, weight: .bold))
                                                Text(s.role.label).font(.system(size: 10))
                                            }
                                            .frame(maxWidth: .infinity).frame(height: 52)
                                            .foregroundStyle(order.waiter == s.initials ? .white : theme.ink)
                                            .background {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .fill(order.waiter == s.initials ? theme.accent : theme.surface)
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                                    }
                                            }
                                        }
                                        .posPress()
                                    }
                                }
                            }
                        }

                        if order.liveItems.count > 1 {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("Split this table into two bills",
                                            detail: "half the party is leaving early")
                                SecondaryAction(title: "Move the last \(order.liveItems.count / 2) items to a new bill",
                                                glyph: "arrow.triangle.branch") {
                                    let ids = order.liveItems.suffix(order.liveItems.count / 2).map(\.id)
                                    store.splitTable(orderID, itemIDs: ids)
                                    store.route = nil
                                }
                            }
                        }
                    }
                    .padding(Metric.padLarge)
                }
            } footer: {
                EmptyView()
            }
        }
    }
}

// MARK: - Shift close

struct ShiftCloseSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var counted = ""

    var body: some View {
        let expected = store.shift.expectedCash
        let countedMoney = Money(cents: Int(counted) ?? 0)
        let variance = countedMoney - expected
        SheetFrame(title: "Count and close",
                   subtitle: "\(store.profile.deviceName) · opened \(store.shift.openedAt.hhmm)",
                   glyph: "lock.fill") {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    PanelHeader("Expected")
                    MoneyRow(label: "Opening float", amount: store.shift.float)
                    MoneyRow(label: "Cash sales", amount: store.shift.cashSales)
                    MoneyRow(label: "Paid in", amount: store.shift.paidIn)
                    MoneyRow(label: "Paid out", amount: -store.shift.paidOut, reduction: true)
                    MoneyRow(label: "Drops", amount: -store.shift.drops, reduction: true)
                    Divider().overlay(theme.hairline)
                    MoneyRow(label: "Expected in the drawer", amount: expected, emphasis: true)
                    if !counted.isEmpty {
                        MoneyRow(label: variance.isNegative ? "Short" : "Over",
                                 amount: variance, emphasis: true,
                                 note: explanation(variance))
                    }
                    Spacer()
                }
                .padding(Metric.padLarge)
                .frame(width: 360)

                Divider().overlay(theme.hairline)

                VStack(spacing: 12) {
                    NumberPad(value: $counted, style: .money,
                              quickAmounts: [expected],
                              confirmTitle: counted.isEmpty ? "Enter the count" : "Close the shift",
                              confirmDetail: counted.isEmpty ? nil
                                : (variance.isZero ? "Balanced" : "Variance \(variance.formatted(showsSign: true))"),
                              confirmEnabled: !counted.isEmpty) {
                        store.toast(.done, "Shift closed",
                                    detail: variance.isZero ? "Balanced · report printed"
                                        : "Variance \(variance.formatted(showsSign: true)) recorded with a reason")
                        store.route = nil
                    }
                }
                .padding(Metric.padLarge)
                .frame(maxWidth: .infinity)
            }
        } footer: {
            EmptyView()
        }
    }

    /// A variance nobody can explain is a variance nobody acts on, so the till offers what it
    /// already knows.
    private func explanation(_ variance: Money) -> String? {
        guard !variance.isZero else { return "Balanced" }
        if store.shift.paidOut.cents > 0 && abs(variance.cents) == store.shift.paidOut.cents {
            return "Matches the paid out of \(store.shift.paidOut.formatted())"
        }
        if abs(variance.cents) < 500 { return "Within the rounding the venue accepts" }
        return "Needs a reason before the shift closes"
    }
}

// MARK: - What to try

struct HelpSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        SheetFrame(title: "What to try in \(store.profile.venueName)",
                   subtitle: store.mode.promise,
                   glyph: "sparkles") {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(scenarios, id: \.0) { s in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.0).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                            Text(s.1).font(.system(size: 13)).foregroundStyle(theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Divider().overlay(theme.hairline)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Keyboard").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                        Text("⌘K business type · ⌘S send · ⌘P pay · ⌘D split · ⌘N new order · ⌘Z undo · ⌘. presenter · ⌘1…8 surfaces")
                            .font(.system(size: 13)).foregroundStyle(theme.inkSecondary)
                    }
                }
                .padding(Metric.padLarge)
            }
        } footer: {
            PrimaryAction(title: "Start", glyph: "arrow.right") { store.route = nil }
        }
    }

    private var scenarios: [(String, String)] {
        switch store.mode {
        case .cafe:
            [("The coffee matrix", "Tap Latte. Size, milk, strength, temperature, sugar, syrup and cup are all on one sheet with a running price. Eight taps for a drink that takes twenty-four on a legacy till."),
             ("The regular", "Tap the customer chip, find Sam, tap The usual. Their whole order, one tap."),
             ("Just made", "Any configured drink appears in Just made. One tap reproduces it exactly."),
             ("The queue", "Go to Queue. Six coffees in flight, only the modifiers that change the make, two timers per card."),
             ("Milk runs out", "Long press Oat inside a drink, or mark a product sold out from its tile. Lines already in flight are marked, not silently changed.")]
        case .qsr:
            [("Make it a meal", "Tap Bolt Cheeseburger. The upsell strip offers the meal with the real saving. It vanishes the moment you move on."),
             ("The combo", "Tap Bolt Meal. Slots side by side, swap prices on the tiles that cost more."),
             ("Two channels at once", "Inbox has Uber Eats and DoorDash waiting. Accept all takes both."),
             ("The board", "Kitchen shows four stations. Bump raises Ready, never Served.")]
        case .bar:
            [("Same again", "Open the tab Dave. Every round has a Repeat control. One tap rebuilds the round at today's prices."),
             ("Rounds", "Type 4 on the keypad, tap Pale Ale. One line of four, not four lines."),
             ("Card holds", "Booth 4 has a hold on a Visa. The bar sees 80% of the hold used before the guest is promised anything."),
             ("Two Daves", "Two tabs under the same first name are flagged, and a new one is numbered so nobody closes the wrong tab.")]
        case .pub:
            [("Drinks now, food to the kitchen", "Build a table order with meals and drinks. One Send: the bar pours, the kitchen cooks."),
             ("Table and buzzer", "Order details takes the typed table number and the buzzer in one sheet."),
             ("The member", "Attach Ken Barlow. Member pricing applies to the taps and the receipt says why."),
             ("Steak came out wrong", "Void the line with a wastage reason. A void docket goes to the grill and it re-fires as a rush.")]
        case .fullService:
            [("Read the floor", "Sixteen states, each with a word and a glyph. Tap a legend chip to dim everything else."),
             ("Fire the mains", "Table 4 has mains held. Fire on the course header sends them in one tap."),
             ("Split three ways", "Table 2 asked for the bill. Split, Equal, 3 — then re-split what is left when they change their minds."),
             ("Another till takes the table", "Presenter panel, \"Another till takes this order\". You can still add and send; only payment waits.")]
        case .fineDining:
            [("Seats are real", "Table 3 has four seats with an allergy on seat 2. It reaches the kitchen ticket."),
             ("Pacing", "Courses can be called and uncalled. Nothing fires twice."),
             ("The cellar", "Wine routes to the Cellar station and never appears on the kitchen board."),
             ("Split by seat", "Split, Seats. Shared items go to a shared portion you allocate.")]
        case .pizza:
            [("Half and half", "Tap Half & Half. A diagram, a list under each section, and the pricing rule in words: priced at the dearer half."),
             ("Whole pizza toppings", "The crust and base apply to the whole pizza and print once, above the halves."),
             ("Phone order", "Order details takes the name, the phone, the address, the zone and the time in one sheet."),
             ("Four quarters", "The same builder does two, three or four sections. Not five.")]
        case .takeaway:
            [("The inbox is home", "Three aggregators and the venue's own channel. Accept on the row."),
             ("Prep time", "One tap pushes a new prep time to every channel. Pausing a channel beats rejecting orders one at a time."),
             ("Handover", "A ready order goes to a driver or a guest, and a failed delivery gets a reason and a resolution."),
             ("Account customer", "The Level 4 office charges to a house account: the order closes and the money is a settlement.")]
        }
    }
}
