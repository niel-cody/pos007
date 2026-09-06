import SwiftUI

/// The make queue. Six coffees in flight, three with modifiers that matter, two for the same
/// name. The barista reads this from two metres away with wet hands, so the identifier is the
/// largest type on the screen and only the modifiers that change the make appear on the card.
struct QueueSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    private var inProgress: [Order] { store.queueOrders.filter { $0.derivedFulfilment != .ready } }
    private var ready: [Order] { store.queueOrders.filter { $0.derivedFulfilment == .ready } }

    var body: some View {
        HStack(spacing: 0) {
            column(title: "Making", detail: "\(inProgress.count) in flight", orders: inProgress, ready: false)
            Divider().overlay(theme.hairline)
            column(title: "Ready", detail: ready.isEmpty ? "nothing waiting" : "\(ready.count) waiting",
                   orders: ready, ready: true)
        }
    }

    private func column(title: String, detail: String, orders: [Order], ready: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                Text(detail).font(.system(size: 12.5)).foregroundStyle(theme.inkSecondary)
                Spacer()
                if ready && !orders.isEmpty {
                    SecondaryAction(title: "Call the next one", glyph: "megaphone.fill") {
                        if let first = orders.first { store.callOrder(first.id) }
                    }
                    .frame(width: 190)
                }
            }
            .padding(Metric.pad)
            .background(theme.raised)

            Divider().overlay(theme.hairline)

            if orders.isEmpty {
                EmptyHint(glyph: ready ? "checkmark.circle" : "cup.and.heat.waves",
                          title: ready ? "Nothing on the pass" : "Nothing being made",
                          detail: ready ? nil : "Orders arrive here the moment they are sent.")
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.gutter),
                                             count: 2), spacing: Metric.gutter) {
                        ForEach(orders) { QueueCard(order: $0, isReady: ready) }
                    }
                    .padding(Metric.pad)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct QueueCard: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    var isReady: Bool

    private var madeCount: Int { order.sentItems.filter(\.isReady).count }
    private var total: Int { order.sentItems.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(order.identifierLabel)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(waitLabel)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .moneyFigure()
                        .foregroundStyle(waitTint)
                    if order.channel != .pos {
                        Chip(text: order.channel.label, glyph: "antenna.radiowaves.left.and.right",
                             tint: Palette.info, small: true)
                    }
                }
            }

            if total > 1 {
                Text("\(madeCount) of \(total) made")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.inkSecondary)
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(order.sentItems) { item in
                    Button {
                        if item.isReady {
                            store.markServed(itemID: item.id, orderID: order.id)
                        } else {
                            store.markReady(itemID: item.id, orderID: order.id)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.isReady ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 17))
                                .foregroundStyle(item.isReady ? Palette.go : theme.inkSecondary.opacity(0.45))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(item.quantity)× \(item.displayName)")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(theme.ink)
                                    .strikethrough(item.isReady, color: theme.inkSecondary)
                                if !item.makeSummary.isEmpty {
                                    Text(item.makeSummary)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Palette.info)
                                }
                                if let n = item.note {
                                    Text(n).font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                    .posPress(scale: 0.995)
                }
            }

            if let due = order.dueAt, due > .now {
                Chip(text: "For \(due.hhmm)", glyph: "clock", tint: Palette.info)
            }

            Divider().overlay(theme.hairline)

            HStack(spacing: 7) {
                if isReady {
                    PrimaryAction(title: order.calledAt == nil ? "Call" : "Called \(order.calledAt!.hhmm)",
                                  glyph: "megaphone.fill",
                                  tint: order.calledAt == nil ? theme.accent : theme.inkSecondary.opacity(0.6)) {
                        store.callOrder(order.id)
                    }
                    PrimaryAction(title: "Hand over", glyph: "hand.raised.fill", tint: Palette.go) {
                        store.handOver(order.id)
                    }
                } else {
                    PrimaryAction(title: "All ready", glyph: "bell.fill", tint: Palette.warn) {
                        store.markOrderReady(order.id)
                    }
                    SecondaryAction(title: "Open", glyph: "chevron.right") {
                        store.openOrder(order.id)
                    }
                    .frame(width: 96)
                }
            }
        }
        .padding(Metric.pad)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(isReady ? Palette.warn.opacity(0.6) : theme.hairline,
                                      lineWidth: isReady ? 1.6 : 0.7)
                }
        }
    }

    /// Two timers, and the second one is the one that matters: how long it has been sitting.
    private var waitLabel: String {
        if isReady, let ready = order.sentItems.compactMap(\.readyAt).max() {
            return "waiting \(ready.elapsedShort)"
        }
        return order.createdAt.elapsedShort
    }

    private var waitTint: Color {
        let seconds = Date.now.timeIntervalSince(
            isReady ? (order.sentItems.compactMap(\.readyAt).max() ?? order.createdAt) : order.createdAt)
        if isReady { return seconds > 180 ? Palette.stop : Palette.warn }
        return seconds > 420 ? Palette.stop : (seconds > 240 ? Palette.warn : theme.inkSecondary)
    }
}
