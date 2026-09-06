import SwiftUI

/// The floor. A waiter glancing at it answers, without opening anything: who is free, who has
/// ordered, whose food is in the kitchen, who is waiting for a bill, who needs clearing.
/// Tapping a table opens its order over the floor rather than replacing it, because the joins
/// are where the taps go.
struct FloorSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var filter: TableState?

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                sectionBar
                Divider().overlay(theme.hairline)
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        theme.canvas
                        ForEach(store.tablesInSection) { table in
                            TableTile(table: table, dimmed: dimmed(table))
                                .frame(width: tileSize(geo).width, height: tileSize(geo).height)
                                .position(x: geo.size.width * table.x + tileSize(geo).width / 2,
                                          y: geo.size.height * table.y + tileSize(geo).height / 2)
                        }
                    }
                }
                Divider().overlay(theme.hairline)
                legend
            }
            .frame(maxWidth: .infinity)

            if store.currentOrder != nil {
                Divider().overlay(theme.hairline)
                CartPanel()
                    .frame(width: Metric.cartWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(Motion.panel, value: store.currentOrderID)
    }

    private func tileSize(_ geo: GeometryProxy) -> CGSize {
        let base = min(geo.size.width / 5.4, 176)
        return CGSize(width: base, height: base * 0.72)
    }

    private func dimmed(_ table: FloorTable) -> Bool {
        guard let filter else { return false }
        return store.state(of: table) != filter
    }

    private var sectionBar: some View {
        HStack(spacing: 10) {
            ForEach(store.sections) { section in
                let active = store.floorSectionID == section.id
                Button {
                    withAnimation(Motion.tap) { store.floorSectionID = section.id }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: section.glyph).font(.system(size: 13, weight: .semibold))
                        Text(section.name).font(.system(size: 14.5, weight: active ? .semibold : .medium))
                        let count = store.tables.filter { $0.sectionID == section.id }
                            .filter { store.state(of: $0).isOccupied }.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(active ? Color.white.opacity(0.28) : theme.hairline))
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 40)
                    .foregroundStyle(active ? .white : theme.ink)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                            .fill(active ? theme.accent : Color.clear)
                    }
                }
                .posPress()
            }
            Spacer()
            sectionStats
        }
        .padding(.horizontal, Metric.pad)
        .padding(.vertical, 9)
        .background(theme.raised)
    }

    private var sectionStats: some View {
        let live = store.liveOrders.filter { o in
            store.tablesInSection.contains { $0.id == o.tableID }
        }
        let covers = live.compactMap(\.guestCount).reduce(0, +)
        let value = live.map(\.total).total
        return HStack(spacing: 14) {
            stat("Tables", "\(live.count)")
            stat("Covers", "\(covers)")
            stat("On the floor", value.formatted())
            if let waiting = live.filter({ store.state(of: $0) == .ready }).first {
                Chip(text: "Food on the pass · \(waiting.tableLabel ?? "")",
                     glyph: "bell.fill", tint: Palette.warn, filled: true)
            }
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .moneyFigure()
                .foregroundStyle(theme.ink)
            Text(label).sectionLabelStyle(theme.inkSecondary)
        }
    }

    /// The legend counts and filters. Tapping "Bill requested" dims every other table.
    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(store.stateCounts(), id: \.0) { pair in
                    Button {
                        withAnimation(Motion.tap) { filter = filter == pair.0 ? nil : pair.0 }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: pair.0.glyph).font(.system(size: 10, weight: .bold))
                            Text(pair.0.word).font(.system(size: 12.5, weight: .medium))
                            Text("\(pair.1)").font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                        .foregroundStyle(filter == pair.0 ? .white : Palette.tint(for: pair.0))
                        .background {
                            Capsule().fill(filter == pair.0
                                           ? Palette.tint(for: pair.0)
                                           : Palette.tint(for: pair.0).opacity(theme.dark ? 0.22 : 0.12))
                        }
                    }
                    .posPress()
                }
                if filter != nil {
                    Button("Clear") { withAnimation(Motion.tap) { filter = nil } }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            .padding(.horizontal, Metric.pad)
            .padding(.vertical, 8)
        }
        .background(theme.raised)
    }
}

// MARK: - Table tile

struct TableTile: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var table: FloorTable
    var dimmed: Bool

    private var state: TableState { store.state(of: table) }
    private var orders: [Order] { store.orders(onTable: table.id) }
    private var attention: String? { store.attention(for: table) }
    /// A course waiting to be fired is the most common thing a waiter comes back for.
    private var heldCount: Int? {
        let n = orders.flatMap(\.heldItems).reduce(0) { $0 + $1.quantity }
        return n > 0 ? n : nil
    }
    private var tint: Color { Palette.tint(for: state) }

    var body: some View {
        Button {
            store.openTable(table, covers: store.profile.promptGuestCount ? nil : table.seats)
            if store.profile.promptGuestCount, orders.isEmpty {
                store.route = .orderDetails
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(table.label)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(theme.ink)
                    if orders.count > 1 {
                        Chip(text: "\(orders.count) orders", tint: theme.accent, filled: true, small: true)
                    }
                    Spacer(minLength: 0)
                    if let o = orders.first, let lock = o.lock, lock.isLive {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Palette.warn)
                    }
                    if table.note != nil {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(theme.inkSecondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: state.glyph).font(.system(size: 9, weight: .bold))
                    Text(state.word).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                    if let held = heldCount, held > 0 {
                        Chip(text: "\(held) held", glyph: "pause.fill",
                             tint: Palette.warn, filled: true, small: true)
                    }
                }
                .foregroundStyle(tint)

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    if let o = orders.first {
                        Label("\(o.guestCount ?? table.seats)", systemImage: "person.2.fill")
                            .font(.system(size: 10.5, weight: .medium))
                            .labelStyle(.titleAndIcon)
                        Text(o.createdAt.elapsedShort)
                            .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        if let w = o.waiter, store.profile.waiterAssignment {
                            Text(w).font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 3).padding(.vertical, 0.5)
                                .background(RoundedRectangle(cornerRadius: 3).fill(theme.hairline))
                        }
                        Spacer(minLength: 0)
                        Text(o.amountDue.tileLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .moneyFigure()
                            .lineLimit(1)
                    } else if let res = table.reservation, !res.seated {
                        Text("\(res.name) · \(res.at.hhmm) · \(res.partySize)")
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                    } else if let blocked = table.blockedReason {
                        Text(blocked).font(.system(size: 10.5)).lineLimit(1)
                    } else {
                        Label("\(table.seats)", systemImage: "chair.lounge.fill")
                            .font(.system(size: 10.5, weight: .medium))
                        Spacer(minLength: 0)
                    }
                }
                .foregroundStyle(theme.inkSecondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .strokeBorder(state == .vacant ? theme.hairline : tint.opacity(0.65),
                                          lineWidth: state == .vacant ? 0.8 : 1.6)
                    }
                    .overlay(alignment: .bottom) {
                        if state != .vacant {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint)
                                .frame(height: 3)
                                .padding(.horizontal, 8)
                                .padding(.bottom, 3)
                        }
                    }
            }
            .overlay(alignment: .topTrailing) {
                if attention != nil {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Palette.stop)
                        .background(Circle().fill(theme.surface).frame(width: 14, height: 14))
                        .offset(x: 5, y: -5)
                }
            }
            .opacity(dimmed ? 0.26 : 1)
        }
        .posPress()
        .contextMenu { menu }
        .help(attention ?? state.word)
        .accessibilityLabel("Table \(table.label), \(state.word)\(attention.map { ", \($0)" } ?? "")")
    }

    @ViewBuilder private var menu: some View {
        Button { store.route = .tableSheet(tableID: table.id) } label: {
            Label("Table info and actions", systemImage: "info.circle")
        }
        if let o = orders.first {
            Button { store.openOrder(o.id) } label: { Label("Open the order", systemImage: "cart") }
            Button { store.printBill(o.id) } label: { Label("Print the bill", systemImage: "doc.text") }
            Button {
                store.openOrder(o.id)
                store.takeLock(o.id)
                store.route = .payment
            } label: { Label("Pay", systemImage: "creditcard") }
            if store.state(of: o) == .ready || store.state(of: o) == .partlyServed {
                Button { store.markServedAll(orderID: o.id) } label: {
                    Label("All served", systemImage: "checkmark.circle")
                }
            }
            Button { store.route = .transfer(orderID: o.id) } label: {
                Label("Move or merge", systemImage: "arrow.left.arrow.right")
            }
            Button { store.route = .timeline(orderID: o.id) } label: {
                Label("Timeline", systemImage: "clock.arrow.circlepath")
            }
        } else {
            Button { store.openTable(table, covers: table.seats) } label: {
                Label("Seat \(table.seats)", systemImage: "person.2")
            }
            Button {
                store.blockTable(table.id, reason: table.blockedReason == nil ? "Out of service" : nil)
            } label: {
                Label(table.blockedReason == nil ? "Block this table" : "Back in service",
                      systemImage: table.blockedReason == nil ? "xmark.circle" : "checkmark.circle")
            }
        }
        if store.state(of: table) == .reset || store.state(of: table) == .paid {
            Button { store.clearTable(table.id) } label: {
                Label("Cleared", systemImage: "sparkles")
            }
        }
    }
}
