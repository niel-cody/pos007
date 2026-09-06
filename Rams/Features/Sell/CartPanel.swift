import SwiftUI

struct CartPanel: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            if let order = store.currentOrder {
                CartHeader(order: order)
                Divider().overlay(theme.hairline)
                if let lock = order.lock, lock.isLive, lock.device != store.profile.deviceName {
                    LockBanner(order: order, lock: lock)
                }
                CartBody(order: order)
                CartTotals(order: order)
                CartActions(order: order)
            } else {
                emptyCart
            }
        }
        .background(theme.surface)
    }

    private var emptyCart: some View {
        VStack(spacing: 14) {
            Spacer()
            EmptyHint(glyph: "cart",
                      title: "No order open",
                      detail: startHint)
            Spacer()
            VStack(spacing: 8) {
                PrimaryAction(title: "New order", glyph: "plus") {
                    _ = store.newOrder()
                }
                if store.profile.tabsEnabled {
                    SecondaryAction(title: "Open a tab", glyph: "person.badge.key.fill") {
                        store.route = .openTab
                    }
                }
                if !store.repeatableOrders.isEmpty {
                    SecondaryAction(title: "Repeat the last order", glyph: "arrow.trianglehead.2.clockwise.rotate.90") {
                        if let last = store.repeatableOrders.first { store.repeatOrder(last.id) }
                    }
                }
            }
            .padding(Metric.pad)
        }
    }

    private var startHint: String {
        switch store.mode {
        case .fullService, .fineDining: "Tap a table on the floor, or tap a product to start a walk-up."
        case .bar: "Tap a drink to start, or open a named tab."
        default: "Tap a product to start. The order type is already \(store.profile.defaultOrderType.label.lowercased())."
        }
    }
}

// MARK: - Header
//
// Recognition over recall: who this order is for, where they are, and what is attached to
// them, at the top of the thing you are building.

struct CartHeader: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    store.route = .orderDetails
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: order.type.glyph)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(order.identifierLabel)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                            Text(subtitle)
                                .font(.system(size: 11.5))
                                .foregroundStyle(theme.inkSecondary)
                                .lineLimit(1)
                        }
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(theme.inkSecondary.opacity(0.6))
                    }
                }
                .posPress()

                Spacer(minLength: 4)

                Menu {
                    Button { store.route = .customers } label: {
                        Label(order.customerName == nil ? "Attach a customer" : "Change customer",
                              systemImage: "person.crop.circle")
                    }
                    Button { store.route = .note(itemID: nil) } label: {
                        Label("Order note", systemImage: "text.bubble")
                    }
                    if store.profile.coursesEnabled {
                        Button { store.route = .courses } label: {
                            Label("Courses", systemImage: "list.number")
                        }
                    }
                    Button { store.printBill(order.id) } label: {
                        Label("Print the bill", systemImage: "doc.text")
                    }
                    Button { store.route = .timeline(orderID: order.id) } label: {
                        Label("Timeline", systemImage: "clock.arrow.circlepath")
                    }
                    Divider()
                    Button { store.holdOrder(order.id) } label: {
                        Label("Park this order", systemImage: "pause.circle")
                    }
                    Button(role: .destructive) {
                        store.requireApproval(.voidSent, what: "Void the whole order",
                                              detail: order.identifierLabel,
                                              reasons: VoidReasons.order) { approver, reason in
                            store.voidOrder(order.id, reason: reason ?? "No reason",
                                            approvedBy: approver.initials)
                        }
                    } label: {
                        Label("Void the order", systemImage: "xmark.bin")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                        }
                }

                Button {
                    store.closeCart()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 36, height: 36)
                        .foregroundStyle(theme.inkSecondary)
                }
                .posPress()
            }

            if !chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) { ForEach(chips, id: \.0) { chipView($0) } }
                }
            }
        }
        .padding(.horizontal, Metric.pad)
        .padding(.vertical, 10)
    }

    private var subtitle: String {
        var parts: [String] = [order.type.label]
        if let c = order.guestCount { parts.append("\(c) cover\(c == 1 ? "" : "s")") }
        if let w = order.waiter, store.profile.waiterAssignment { parts.append(w) }
        if let b = order.buzzer { parts.append("buzzer \(b)") }
        if let due = order.dueAt { parts.append("for \(due.hhmm)") }
        parts.append(order.createdAt.elapsedShort)
        return parts.joined(separator: " · ")
    }

    private var chips: [(String, String, Color)] {
        var out: [(String, String, Color)] = []
        if let name = order.customerName {
            out.append((name, "person.crop.circle.fill", theme.accent))
        }
        if let cid = order.customerID, let c = store.customers.first(where: { $0.id == cid }) {
            if c.isMember { out.append(("Member price", "checkmark.seal.fill", Palette.go)) }
            if let a = c.allergyNote { out.append((a, "exclamationmark.triangle.fill", Palette.stop)) }
            if c.isVIP { out.append(("VIP", "star.fill", Palette.warn)) }
            if c.loyaltyPoints > 0 { out.append(("\(c.loyaltyPoints) pts", "star.circle", Palette.info)) }
            if c.houseAccountBalance != nil { out.append(("House account", "building.columns.fill", Palette.info)) }
        }
        if let auth = order.tabAuth {
            out.append(("\(auth.scheme) ···\(auth.last4) · \(auth.state.label)",
                        "creditcard.fill",
                        auth.state == .authorised ? Palette.go : Palette.warn))
        }
        if let limit = order.spendLimit {
            out.append(("Limit \(limit.formatted())", "gauge.with.needle", Palette.warn))
        }
        if order.unsynced {
            out.append(("Not synced", "arrow.triangle.2.circlepath", Palette.warn))
        }
        if order.billRequested {
            out.append(("Bill requested", "doc.text.fill", Palette.warn))
        }
        if let note = order.orderNote {
            out.append((note, "text.bubble.fill", theme.inkSecondary))
        }
        return out
    }

    private func chipView(_ c: (String, String, Color)) -> some View {
        Chip(text: c.0, glyph: c.1, tint: c.2, filled: c.2 == Palette.stop)
    }
}

// MARK: - Lock banner

struct LockBanner: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    var lock: OrderLock

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Palette.warn)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(lock.holder) is paying on \(lock.device)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("You can still add items and send. Frees itself in \(lock.freesIn).")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.inkSecondary)
            }
            Spacer(minLength: 6)
            Button("Override") { store.overrideLock(order.id) }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, Metric.pad)
        .padding(.vertical, 9)
        .background(Palette.warn.opacity(theme.dark ? 0.18 : 0.11))
    }
}
