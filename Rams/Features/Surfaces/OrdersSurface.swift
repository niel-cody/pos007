import SwiftUI

/// Order recall. Open, parked and closed, with the void and refund routes where they belong:
/// a void before payment, a refund after it, and never a dead end that says only "cannot".
struct OrdersSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    enum Filter: String, CaseIterable, Identifiable {
        case live, parked, closed
        var id: String { rawValue }
        var label: String {
            switch self {
            case .live: "Open"
            case .parked: "Parked"
            case .closed: "Closed"
            }
        }
    }

    @State private var filter: Filter = .live
    @State private var query = ""

    private var rows: [Order] {
        let base: [Order]
        switch filter {
        case .live: base = store.liveOrders.filter { $0.status != .held }
        case .parked: base = store.orders.filter { $0.status == .held }
        case .closed: base = store.completedOrders
        }
        guard !query.isEmpty else { return base }
        let q = query.lowercased()
        return base.filter {
            $0.identifierLabel.lowercased().contains(q)
            || String($0.number).contains(q)
            || ($0.customerName?.lowercased().contains(q) ?? false)
            || ($0.phone?.contains(q) ?? false)
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider().overlay(theme.hairline)
                if rows.isEmpty {
                    EmptyHint(glyph: "list.bullet.rectangle.portrait",
                              title: "Nothing here",
                              detail: filter == .parked
                                ? "Parked orders keep their configuration exactly as you left them."
                                : nil)
                } else {
                    ScrollView {
                        VStack(spacing: 7) {
                            ForEach(rows) { OrderRow(order: $0, filter: filter) }
                        }
                        .padding(Metric.pad)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if store.currentOrder != nil {
                Divider().overlay(theme.hairline)
                CartPanel().frame(width: Metric.cartWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(Motion.panel, value: store.currentOrderID)
    }

    private var header: some View {
        HStack(spacing: 10) {
            POSSegments(options: Filter.allCases.map { ($0, "\($0.label) \(count($0))", nil) },
                        selection: $filter, height: 40)
                .frame(width: 380)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.inkSecondary)
                TextField("Name, number, phone", text: $query)
                    .font(.system(size: 15))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .frame(maxWidth: 260)
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                    .fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
            }
            Spacer()
            PrimaryAction(title: "New order", glyph: "plus") { _ = store.newOrder() }
                .frame(width: 180)
        }
        .padding(Metric.pad)
        .background(theme.raised)
    }

    private func count(_ f: Filter) -> String {
        switch f {
        case .live: "\(store.liveOrders.filter { $0.status != .held }.count)"
        case .parked: "\(store.orders.filter { $0.status == .held }.count)"
        case .closed: "\(store.completedOrders.count)"
        }
    }
}

struct OrderRow: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    var filter: OrdersSurface.Filter

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(order.identifierLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Chip(text: order.type.short, glyph: order.type.glyph, small: true)
                    if order.channel != .pos {
                        Chip(text: order.channel.label, tint: Palette.info, small: true)
                    }
                    if order.isRefund {
                        Chip(text: "Refund", glyph: "arrow.uturn.left", tint: Palette.stop, filled: true, small: true)
                    }
                    if let f = order.derivedFulfilment, f != .notStarted {
                        Chip(text: f.label,
                             glyph: f == .ready ? "bell.fill" : "clock",
                             tint: f == .ready ? Palette.warn : theme.inkSecondary, small: true)
                    }
                    if order.hasAttention {
                        Chip(text: "Docket failed", glyph: "printer.trianglebadge.exclamationmark",
                             tint: Palette.stop, filled: true, small: true)
                    }
                    if order.unsynced {
                        Chip(text: "Unsynced", glyph: "arrow.triangle.2.circlepath", tint: Palette.warn, small: true)
                    }
                }
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.inkSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 1) {
                Text(order.total.formatted())
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                Text(order.paymentState.label)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(order.paymentState == .paid ? Palette.go
                                     : (order.paymentState == .partPaid ? Palette.warn : theme.inkSecondary))
            }

            actions
        }
        .padding(.horizontal, Metric.pad)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                }
        }
    }

    private var detail: String {
        var parts: [String] = []
        parts.append("#\(order.number)")
        if let n = order.customerName { parts.append(n) }
        parts.append("\(order.itemCount) items")
        if let table = order.tableLabel ?? order.typedTableNumber { parts.append("Table \(table)") }
        if let d = order.dueAt { parts.append("for \(d.hhmm)") }
        if let closed = order.closedAt { parts.append("closed \(closed.hhmm)") }
        else { parts.append(order.updatedAt.elapsedShort) }
        parts.append(order.openedBy)
        return parts.joined(separator: " · ")
    }

    @ViewBuilder private var actions: some View {
        HStack(spacing: 7) {
            switch filter {
            case .live:
                SecondaryAction(title: "Open", glyph: "chevron.right") { store.openOrder(order.id) }
                    .frame(width: 110)
                PrimaryAction(title: "Pay", glyph: "creditcard.fill") {
                    store.openOrder(order.id)
                    store.takeLock(order.id)
                    store.route = .payment
                }
                .frame(width: 130)
            case .parked:
                PrimaryAction(title: "Recall", glyph: "arrow.up.circle.fill") {
                    store.recallOrder(order.id)
                }
                .frame(width: 150)
            case .closed:
                SecondaryAction(title: "Receipt", glyph: "doc.text") {
                    store.toast(.done, "Receipt reprinted", detail: order.identifierLabel)
                }
                .frame(width: 120)
                PrimaryAction(title: "Refund", glyph: "arrow.uturn.left",
                              tint: Palette.stop,
                              enabled: !order.isRefund && order.status != .refunded) {
                    store.route = .refund(orderID: order.id)
                }
                .frame(width: 130)
            }
            Menu {
                Button { store.route = .timeline(orderID: order.id) } label: {
                    Label("Timeline", systemImage: "clock.arrow.circlepath")
                }
                if order.status.isLive {
                    Button { store.holdOrder(order.id) } label: {
                        Label("Park it", systemImage: "pause.circle")
                    }
                    Button { store.route = .transfer(orderID: order.id) } label: {
                        Label("Move or merge", systemImage: "arrow.left.arrow.right")
                    }
                    Button(role: .destructive) {
                        store.requireApproval(.voidSent, what: "Void \(order.identifierLabel)",
                                              reasons: VoidReasons.order) { approver, reason in
                            store.voidOrder(order.id, reason: reason ?? "No reason",
                                            approvedBy: approver.initials)
                        }
                    } label: { Label("Void", systemImage: "xmark.bin") }
                }
                if order.status == .completed && !order.isRefund {
                    Button { store.route = .refund(orderID: order.id) } label: {
                        Label("Refund", systemImage: "arrow.uturn.left")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 40, height: Metric.standardTarget)
                    .foregroundStyle(theme.ink)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                            .fill(theme.dark ? Color.white.opacity(0.08) : Color.black.opacity(0.045))
                    }
            }
        }
    }
}
