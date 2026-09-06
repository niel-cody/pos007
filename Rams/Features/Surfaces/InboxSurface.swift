import SwiftUI

/// The inbox. On a ninety second aggregator clock, an order that has to be found through a
/// drawer is an order that gets reassigned to another venue. Accept is on the row, Accept all
/// is on the header, and prep time and channel pausing are one tap each.
struct InboxSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var prep = 15

    private var waiting: [Order] { store.onlineInbox }
    private var live: [Order] {
        store.orders.filter { $0.channel != .pos && $0.status == .open }
            .sorted { ($0.dueAt ?? $0.createdAt) < ($1.dueAt ?? $1.createdAt) }
    }
    private var ready: [Order] {
        store.orders.filter { $0.channel != .pos && $0.derivedFulfilment == .ready }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                controls
                Divider().overlay(theme.hairline)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !waiting.isEmpty {
                            section("Waiting to be accepted", waiting, accepting: true)
                        }
                        if !ready.isEmpty {
                            section("Ready for collection or a driver", ready, accepting: false)
                        }
                        if !live.isEmpty {
                            section("In the kitchen", live.filter { $0.derivedFulfilment != .ready },
                                    accepting: false)
                        }
                        if waiting.isEmpty && live.isEmpty && ready.isEmpty {
                            EmptyHint(glyph: "tray", title: "Nothing waiting",
                                      detail: "Orders from every channel land here. Use the presenter panel to make one arrive.")
                                .frame(height: 320)
                        }
                    }
                    .padding(Metric.pad)
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

    private var controls: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Prep time").sectionLabelStyle(theme.inkSecondary)
                HStack(spacing: 6) {
                    ForEach([10, 15, 25, 35], id: \.self) { m in
                        Button {
                            prep = m
                            store.setPrepTime(m)
                        } label: {
                            Text("\(m)m")
                                .font(.system(size: 14, weight: prep == m ? .semibold : .medium))
                                .padding(.horizontal, 12).frame(height: 38)
                                .foregroundStyle(prep == m ? .white : theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(prep == m ? theme.accent : theme.surface)
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

            Divider().frame(height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Pause a channel").sectionLabelStyle(theme.inkSecondary)
                HStack(spacing: 6) {
                    ForEach(store.profile.channels.filter { $0 != .pos }, id: \.self) { c in
                        Button {
                            store.pauseChannel(c, minutes: 10)
                        } label: {
                            Text(c.label)
                                .font(.system(size: 13.5, weight: .medium))
                                .padding(.horizontal, 11).frame(height: 38)
                                .foregroundStyle(theme.ink)
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

            Spacer()

            if waiting.count > 1 {
                PrimaryAction(title: "Accept all \(waiting.count)", glyph: "checkmark.circle.fill") {
                    store.acceptAll()
                }
                .frame(width: 220)
            }
        }
        .padding(Metric.pad)
        .background(theme.raised)
    }

    private func section(_ title: String, _ orders: [Order], accepting: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader(title, detail: "\(orders.count)")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.gutter),
                                     count: 3), spacing: Metric.gutter) {
                ForEach(orders) { InboxCard(order: $0, accepting: accepting) }
            }
        }
    }
}

struct InboxCard: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    var accepting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text(order.identifierLabel)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Chip(text: order.channel.label,
                     glyph: order.channel.isPartner ? "bicycle" : "globe",
                     tint: order.channel.isPartner ? Palette.info : Palette.go, filled: true, small: true)
            }

            HStack(spacing: 6) {
                Chip(text: order.type.short, glyph: order.type.glyph, small: true)
                if let ref = order.partnerReference { Chip(text: ref, small: true) }
                if let due = order.dueAt {
                    Chip(text: "for \(due.hhmm)", glyph: "clock",
                         tint: due.timeIntervalSince(.now) < 600 ? Palette.warn : theme.inkSecondary,
                         small: true)
                }
                if order.paymentState == .paid {
                    Chip(text: "Prepaid", glyph: "checkmark.seal.fill", tint: Palette.go, small: true)
                } else {
                    Chip(text: "Pay at venue", glyph: "dollarsign", tint: Palette.warn, small: true)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                ForEach(order.liveItems) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(item.quantity)×")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.accent)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.name).font(.system(size: 14)).foregroundStyle(theme.ink)
                            if !item.configurationSummary.isEmpty {
                                Text(item.configurationSummary)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(theme.inkSecondary)
                            }
                        }
                        Spacer()
                    }
                }
            }

            if let d = order.delivery, !d.address.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    Text(d.address).font(.system(size: 12.5, weight: .medium)).foregroundStyle(theme.ink)
                    if !d.instructions.isEmpty {
                        Text(d.instructions).font(.system(size: 11.5)).foregroundStyle(theme.inkSecondary)
                    }
                }
            }
            if let phone = order.phone {
                Text(phone).font(.system(size: 12, design: .rounded)).foregroundStyle(theme.inkSecondary)
            }

            Divider().overlay(theme.hairline)

            HStack(alignment: .lastTextBaseline) {
                Text(order.total.formatted())
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(order.createdAt.elapsedShort + " ago")
                    .font(.system(size: 11.5)).foregroundStyle(theme.inkSecondary)
            }

            if accepting {
                HStack(spacing: 7) {
                    PrimaryAction(title: "Accept", glyph: "checkmark") { store.accept(order.id) }
                    Menu {
                        ForEach(["Item unavailable", "Kitchen too busy", "Closing", "Outside delivery zone"], id: \.self) { r in
                            Button(r) { store.reject(order.id, reason: r) }
                        }
                    } label: {
                        Text("Reject")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 92, height: Metric.primaryTarget)
                            .foregroundStyle(Palette.stop)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .fill(Palette.stop.opacity(0.1))
                            }
                    }
                }
            } else if order.derivedFulfilment == .ready {
                HStack(spacing: 7) {
                    PrimaryAction(title: order.type == .delivery ? "To a driver" : "Handed over",
                                  glyph: order.type == .delivery ? "bicycle" : "hand.raised.fill",
                                  tint: Palette.go) {
                        store.handOver(order.id, type: order.type == .delivery ? .driver : .guest,
                                       driver: order.type == .delivery ? "Tony" : nil)
                    }
                    Menu {
                        ForEach(VoidReasons.deliveryFailure, id: \.self) { r in
                            Button(r) { store.markFailed(order.id, reason: r) }
                        }
                    } label: {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 52, height: Metric.primaryTarget)
                            .foregroundStyle(Palette.warn)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .fill(Palette.warn.opacity(0.12))
                            }
                    }
                }
            } else {
                HStack(spacing: 7) {
                    SecondaryAction(title: "Open", glyph: "chevron.right") { store.openOrder(order.id) }
                    PrimaryAction(title: "Ready", glyph: "bell.fill", tint: Palette.warn) {
                        store.markOrderReady(order.id)
                    }
                }
            }

            if order.derivedFulfilment == .failed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Failed: \(order.delivery?.failureReason ?? "")")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Palette.stop)
                    HStack(spacing: 6) {
                        ForEach(["Refund", "Re-deliver", "Retain"], id: \.self) { r in
                            Button(r) { store.resolveFailed(order.id, resolution: r) }
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(theme.accent)
                        }
                    }
                }
            }
        }
        .padding(Metric.pad)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(accepting ? Palette.info.opacity(0.55) : theme.hairline,
                                      lineWidth: accepting ? 1.6 : 0.7)
                }
        }
    }
}
