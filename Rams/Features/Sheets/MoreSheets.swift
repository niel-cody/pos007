import SwiftUI

// MARK: - Refund
//
// A refund is a new order that settles against a closed one. The original stays Completed,
// and nothing about a refund reopens a sale.

struct RefundSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var orderID: UUID

    @State private var picked: [UUID: Int] = [:]
    @State private var reason: String?
    @State private var tender: TenderKind = .card
    @State private var byAmount = false
    @State private var pad = ""

    private var order: Order? { store.order(orderID) }

    var body: some View {
        if let order {
            SheetFrame(title: "Refund \(order.identifierLabel)",
                       subtitle: "\(order.total.formatted()) paid \(order.closedAt?.hhmm ?? "") · \(order.payments.filter { $0.state == .complete }.map(\.kind.label).joined(separator: ", "))",
                       glyph: "arrow.uturn.left.circle.fill") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        POSSegments(options: [(false, "By item", "list.bullet"), (true, "By amount", "dollarsign")],
                                    selection: $byAmount)

                        if byAmount {
                            NumberPad(value: $pad, style: .money,
                                      quickAmounts: [order.total, Money(cents: order.total.cents / 2)],
                                      confirmTitle: "Refund \(Money(cents: Int(pad) ?? 0).formatted())",
                                      confirmEnabled: (Int(pad) ?? 0) > 0 && reason != nil) {
                                commit(order, amount: Money(cents: Int(pad) ?? 0))
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("What is coming back", detail: "part of a line is fine")
                                ForEach(order.items.filter { $0.quantity > $0.refundedQuantity }) { item in
                                    itemRow(item)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            PanelHeader("Reason")
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                                ForEach(VoidReasons.refund, id: \.self) { r in
                                    Button {
                                        reason = r
                                    } label: {
                                        Text(r)
                                            .font(.system(size: 13.5, weight: reason == r ? .semibold : .regular))
                                            .frame(maxWidth: .infinity).frame(height: 44)
                                            .foregroundStyle(reason == r ? .white : theme.ink)
                                            .background {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .fill(reason == r ? theme.accent : theme.surface)
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

                        VStack(alignment: .leading, spacing: 7) {
                            PanelHeader("Back to", detail: "the original tender where policy allows")
                            HStack(spacing: 7) {
                                ForEach([TenderKind.card, .cash, .giftCard]) { t in
                                    Button {
                                        tender = t
                                    } label: {
                                        VStack(spacing: 3) {
                                            Image(systemName: t.glyph).font(.system(size: 15, weight: .semibold))
                                            Text(t.label).font(.system(size: 13, weight: tender == t ? .semibold : .regular))
                                        }
                                        .frame(maxWidth: .infinity).frame(height: 56)
                                        .foregroundStyle(tender == t ? .white : theme.ink)
                                        .background {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .fill(tender == t ? theme.accent : theme.surface)
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
                    .padding(Metric.padLarge)
                }
            } footer: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(refundTotal(order).formatted())
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .moneyFigure()
                            .foregroundStyle(Palette.stop)
                        Text("Stock returns and the audit log records who approved it.")
                            .font(.system(size: 11.5)).foregroundStyle(theme.inkSecondary)
                    }
                    Spacer()
                    SecondaryAction(title: "Cancel") { store.route = nil }
                        .frame(width: 140)
                    PrimaryAction(title: "Refund", glyph: "arrow.uturn.left", tint: Palette.stop,
                                  enabled: reason != nil && refundTotal(order).cents > 0) {
                        commit(order, amount: nil)
                    }
                    .frame(width: 200)
                }
            }
            .onAppear { tender = order.payments.first { $0.state == .complete }?.kind ?? .card }
        }
    }

    private func itemRow(_ item: OrderItem) -> some View {
        let n = picked[item.id] ?? 0
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.quantity)× \(item.name)")
                    .font(.system(size: 14.5, weight: .medium)).foregroundStyle(theme.ink)
                if !item.configurationSummary.isEmpty {
                    Text(item.configurationSummary).font(.system(size: 11.5)).foregroundStyle(theme.inkSecondary)
                }
                if !item.adjustments.isEmpty {
                    Text("Discounted — refunded at what was actually paid")
                        .font(.system(size: 11)).foregroundStyle(Palette.warn)
                }
            }
            Spacer()
            HStack(spacing: 0) {
                Button {
                    picked[item.id] = max(0, n - 1)
                } label: {
                    Image(systemName: "minus").font(.system(size: 12, weight: .bold))
                        .frame(width: 36, height: 40).foregroundStyle(theme.ink)
                }
                Text("\(n)").font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(width: 32).foregroundStyle(n > 0 ? Palette.stop : theme.inkSecondary)
                Button {
                    picked[item.id] = min(item.quantity - item.refundedQuantity, n + 1)
                } label: {
                    Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                        .frame(width: 36, height: 40).foregroundStyle(theme.ink)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                    }
            }
            Text(Money(cents: item.eachTotal.cents * max(n, 0)).formatted())
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .moneyFigure()
                .frame(width: 72, alignment: .trailing)
                .foregroundStyle(theme.ink)
        }
        .padding(.horizontal, 11)
        .frame(height: 56)
        .background {
            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                .fill(n > 0 ? Palette.stop.opacity(0.07) : Color.clear)
        }
    }

    private func refundTotal(_ order: Order) -> Money {
        if byAmount { return Money(cents: Int(pad) ?? 0) }
        return picked.reduce(Money.zero) { acc, entry in
            guard let item = order.items.first(where: { $0.id == entry.key }) else { return acc }
            return acc + Money(cents: item.eachTotal.cents * entry.value)
        }
    }

    private func commit(_ order: Order, amount: Money?) {
        guard let reason else { return }
        store.requireApproval(.refund, what: "Refund \(refundTotal(order).formatted())",
                              detail: reason) { approver, _ in
            store.refund(orderID: orderID,
                         items: picked.filter { $0.value > 0 }.map { (itemID: $0.key, quantity: $0.value) },
                         amount: amount ?? (byAmount ? refundTotal(order) : nil),
                         reason: reason, tender: tender, approvedBy: approver.initials)
            store.route = nil
        }
    }
}

// MARK: - Timeline

struct TimelineSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var orderID: UUID

    private var order: Order? { store.order(orderID) }

    var body: some View {
        if let order {
            SheetFrame(title: "Timeline",
                       subtitle: "\(order.identifierLabel) · every event, who did it, when",
                       glyph: "clock.arrow.circlepath") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(entries(order)) { entry in
                            HStack(alignment: .top, spacing: 11) {
                                VStack(spacing: 0) {
                                    Image(systemName: entry.glyph)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(entry.isNotable ? .white : theme.inkSecondary)
                                        .frame(width: 26, height: 26)
                                        .background {
                                            Circle().fill(entry.isNotable ? Palette.warn : theme.hairline)
                                        }
                                    Rectangle().fill(theme.hairline).frame(width: 1.2)
                                        .frame(minHeight: 18)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.text)
                                        .font(.system(size: 14.5, weight: entry.isNotable ? .semibold : .regular))
                                        .foregroundStyle(theme.ink)
                                    HStack(spacing: 6) {
                                        Text(entry.at.hhmm)
                                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                        Text(entry.actor).font(.system(size: 11.5))
                                        if let a = entry.approvedBy {
                                            Chip(text: "Approved by \(a)", glyph: "person.badge.key.fill",
                                                 tint: Palette.warn, small: true)
                                        }
                                    }
                                    .foregroundStyle(theme.inkSecondary)
                                }
                                .padding(.bottom, 14)
                                Spacer()
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

    private func entries(_ order: Order) -> [AuditEntry] {
        var all = order.timeline
        for item in order.items {
            if let sent = item.sendRecords.first(where: { $0.state == .confirmed }) {
                all.append(AuditEntry(at: sent.at, actor: item.addedBy,
                                      text: "\(item.quantity)× \(item.name) confirmed at \(sent.station)",
                                      glyph: "printer.fill"))
            }
            if let failed = item.sendRecords.first(where: { $0.state == .failed }) {
                all.append(AuditEntry(at: failed.at, actor: item.addedBy,
                                      text: failed.failureReason ?? "Docket failed",
                                      glyph: "printer.trianglebadge.exclamationmark.fill", isNotable: true))
            }
            if let ready = item.readyAt {
                all.append(AuditEntry(at: ready, actor: "Kitchen",
                                      text: "\(item.name) ready", glyph: "bell.fill"))
            }
            if let served = item.servedAt {
                all.append(AuditEntry(at: served, actor: "Floor",
                                      text: "\(item.name) served", glyph: "checkmark.circle.fill"))
            }
        }
        for leg in order.payments {
            all.append(AuditEntry(at: leg.at, actor: leg.staff,
                                  text: "\(leg.kind.label) \(leg.amount.formatted()) — \(leg.state.label)",
                                  glyph: leg.kind.glyph,
                                  isNotable: leg.state == .reversed || leg.state == .rejected))
        }
        return all.sorted { $0.at < $1.at }
    }
}

// MARK: - Table sheet

struct TableSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var tableID: UUID
    @State private var note = ""

    private var table: FloorTable? { store.table(tableID) }
    private var orders: [Order] { store.orders(onTable: tableID) }

    var body: some View {
        if let table {
            SheetFrame(title: "Table \(table.label)",
                       subtitle: "\(store.state(of: table).word) · \(table.seats) seats",
                       glyph: "table.furniture.fill") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let a = store.attention(for: table) {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(Palette.stop)
                                Text(a).font(.system(size: 14, weight: .semibold)).foregroundStyle(theme.ink)
                                Spacer()
                            }
                            .padding(11)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                    .fill(Palette.stop.opacity(0.09))
                            }
                        }

                        if orders.count > 1 {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("This table has \(orders.count) orders",
                                            detail: "choose one — no modal, it is on the tile")
                                ForEach(orders) { o in
                                    Button {
                                        store.openOrder(o.id)
                                        store.route = nil
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("#\(o.number) · \(o.itemCount) items")
                                                    .font(.system(size: 14.5, weight: .semibold))
                                                    .foregroundStyle(theme.ink)
                                                Text("\(store.state(of: o).word) · \(o.openedBy)")
                                                    .font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                                            }
                                            Spacer()
                                            Text(o.amountDue.formatted())
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
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

                        if let o = orders.first {
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("Covers")
                                HStack(spacing: 6) {
                                    ForEach(1...10, id: \.self) { n in
                                        Button {
                                            store.setCovers(o.id, n)
                                        } label: {
                                            Text("\(n)")
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .frame(maxWidth: .infinity).frame(height: 44)
                                                .foregroundStyle(o.guestCount == n ? .white : theme.ink)
                                                .background {
                                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                        .fill(o.guestCount == n ? theme.accent : theme.surface)
                                                        .overlay {
                                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                                                        }
                                                }
                                        }
                                        .posPress()
                                    }
                                }
                                if store.profile.waiterAssignment {
                                    PanelHeader("Waiter")
                                    HStack(spacing: 6) {
                                        ForEach(store.staff) { s in
                                            Button {
                                                store.assignWaiter(o.id, to: s.initials)
                                            } label: {
                                                Text(s.initials)
                                                    .font(.system(size: 13, weight: .bold))
                                                    .frame(width: 44, height: 40)
                                                    .foregroundStyle(o.waiter == s.initials ? .white : theme.ink)
                                                    .background {
                                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                            .fill(o.waiter == s.initials ? theme.accent : theme.surface)
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
                        }

                        VStack(alignment: .leading, spacing: 7) {
                            PanelHeader("Table note", detail: "the whole floor sees it")
                            TextField(table.note ?? "Regulars, birthday, wobbly leg", text: $note)
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
                        }
                    }
                    .padding(Metric.padLarge)
                }
            } footer: {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        if let o = orders.first {
                            PrimaryAction(title: "Open", glyph: "cart") {
                                store.openOrder(o.id)
                                store.route = nil
                            }
                            PrimaryAction(title: "Pay", glyph: "creditcard.fill") {
                                store.openOrder(o.id)
                                store.takeLock(o.id)
                                store.route = .payment
                            }
                        } else {
                            PrimaryAction(title: "Seat \(table.seats)", glyph: "person.2.fill") {
                                store.openTable(table, covers: table.seats)
                                store.route = nil
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        SecondaryAction(title: "Save note", glyph: "text.bubble") {
                            store.setTableNote(tableID, note)
                            store.route = nil
                        }
                        SecondaryAction(title: table.blockedReason == nil ? "Block" : "Unblock",
                                        glyph: "xmark.circle") {
                            store.blockTable(tableID, reason: table.blockedReason == nil ? "Out of service" : nil)
                        }
                        SecondaryAction(title: "Cleared", glyph: "sparkles") {
                            store.clearTable(tableID)
                            store.route = nil
                        }
                    }
                }
            }
            .onAppear { note = table.note ?? "" }
        }
    }
}

// MARK: - Open a tab

struct OpenTabSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var name = ""
    @State private var limit: Money?
    @State private var holdCard = false

    var body: some View {
        SheetFrame(title: "Open a tab",
                   subtitle: "a tab is an order with a name — it can be split, moved and reported like any other",
                   glyph: "person.badge.key.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader("Name it")
                        TextField("Dave, Booth 4, the black Amex", text: $name)
                            .font(.system(size: 18)).textFieldStyle(.plain)
                            .padding(14)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                    .fill(theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                    }
                            }
                        let clash = store.openTabs.contains { ($0.name ?? "").lowercased() == name.lowercased() }
                        if clash {
                            Text("There is already a tab called that. It will be numbered so the bar can tell them apart.")
                                .font(.system(size: 12)).foregroundStyle(Palette.warn)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(["Booth 1", "Booth 2", "Booth 3", "Booth 4", "The corner", "Birthday"], id: \.self) { s in
                                    Button {
                                        name = s
                                    } label: {
                                        Text(s).font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 13).frame(height: 38)
                                            .foregroundStyle(theme.ink)
                                            .background(Capsule().fill(theme.accentSoft))
                                    }
                                    .posPress()
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader("Spend limit", detail: "optional, warns the bar before it is passed")
                        HStack(spacing: 7) {
                            ForEach([Money(100), Money(200), Money(500)], id: \.cents) { m in
                                Button {
                                    limit = limit == m ? nil : m
                                } label: {
                                    Text(m.tileLabel)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .frame(maxWidth: .infinity).frame(height: 48)
                                        .foregroundStyle(limit == m ? .white : theme.ink)
                                        .background {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .fill(limit == m ? theme.accent : theme.surface)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                                                }
                                        }
                                }
                                .posPress()
                            }
                            Button("No limit") { limit = nil }
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(theme.inkSecondary)
                        }
                    }

                    if store.profile.cardHoldsEnabled {
                        VStack(alignment: .leading, spacing: 7) {
                            PanelHeader("Hold a card", detail: "an authorisation is not a payment until it is captured")
                            Toggle(isOn: $holdCard) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Take a card hold").font(.system(size: 15, weight: .medium))
                                    Text("Amber at 80% of the hold, and the bar is told before the guest is promised anything.")
                                        .font(.system(size: 11.5)).foregroundStyle(theme.inkSecondary)
                                }
                            }
                            .toggleStyle(.switch)
                        }
                    }
                }
                .padding(Metric.padLarge)
            }
        } footer: {
            HStack(spacing: 10) {
                SecondaryAction(title: "Cancel") { store.route = nil }
                PrimaryAction(title: "Open the tab", glyph: "plus", enabled: !name.isEmpty) {
                    _ = store.openTab(name: store.disambiguate(name),
                                      limit: limit,
                                      card: holdCard ? ("4417", "Visa") : nil)
                    store.route = nil
                }
            }
        }
    }
}
