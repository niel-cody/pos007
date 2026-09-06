import SwiftUI

/// The totals block. Amount due is the largest text on the screen and it never moves.
struct CartTotals: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order

    var body: some View {
        VStack(spacing: 7) {
            if order.subtotal != order.total {
                MoneyRow(label: "Items", amount: order.subtotal)
            }
            if order.paidTotal.cents > 0 {
                MoneyRow(label: "Paid so far", amount: order.paidTotal, reduction: true)
            }
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(order.paidTotal.cents > 0 ? "Remaining" : "Total")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.inkSecondary)
                    Text("includes \(order.gstIncluded.formatted()) GST")
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.inkSecondary.opacity(0.8))
                }
                Spacer()
                Text(order.amountDue.formatted())
                    .font(.amountDue)
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
                    .animation(Motion.quick, value: order.amountDue.cents)
            }
            if let limit = order.spendLimit, order.total > limit {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle").font(.system(size: 11, weight: .bold))
                    Text("Past the \(limit.formatted()) spend limit")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Palette.stop)
            }
            if let pressure = store.authPressure(order), let warning = pressure.warning {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.trianglebadge.exclamationmark")
                        .font(.system(size: 11, weight: .bold))
                    Text(warning).font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Palette.warn)
            }
        }
        .padding(.horizontal, Metric.pad)
        .padding(.vertical, 11)
        .background(theme.raised)
        .overlay(alignment: .top) { Divider().overlay(theme.hairline) }
    }
}

/// The action bar. Send and Pay are the two things a hand reaches for, so they are the two
/// largest targets on the panel and they are always in the same place.
struct CartActions: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order

    private var sendable: Int { order.sendableCount }
    private var canPay: Bool { store.canPay(order) }

    var body: some View {
        VStack(spacing: 8) {
            if store.profile.identifier == .customerName,
               (order.name ?? "").isEmpty, !order.liveItems.isEmpty {
                NameStrip(order: order)
                    .padding(.bottom, 2)
            }
            if store.profile.coursesEnabled || store.profile.kdsEnabled || !store.profile.stations.isEmpty {
                HStack(spacing: 8) {
                    PrimaryAction(title: sendable > 0 ? "Send \(sendable)" : "Sent",
                                  subtitle: sendable > 0 ? sendTargets : nil,
                                  glyph: "paperplane.fill",
                                  tint: sendable > 0 ? theme.accent : theme.inkSecondary.opacity(0.5),
                                  enabled: sendable > 0) {
                        store.send()
                    }
                    if store.profile.tabsEnabled && order.isTab {
                        PrimaryAction(title: "Add to tab", glyph: "person.badge.key.fill",
                                      tint: Palette.info) {
                            store.send()
                            store.closeCart()
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(store.profile.quickTenders) { kind in
                    PrimaryAction(title: kind.label,
                                  subtitle: quickSubtitle(kind),
                                  glyph: kind.glyph,
                                  tint: kind == .cash ? Palette.go : theme.accent,
                                  enabled: canPay && order.total.cents > 0) {
                        quickTender(kind)
                    }
                }
                Button {
                    if canPay {
                        store.takeLock(order.id)
                        store.route = .payment
                    } else {
                        store.overrideLock(order.id)
                    }
                } label: {
                    Image(systemName: canPay ? "ellipsis" : "lock.fill")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 56, height: theme.primaryTarget)
                        .foregroundStyle(theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                .fill(theme.dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
                        }
                }
                .posPress()
                .help(canPay ? "More tenders and splitting" : "Locked by another till")
            }

            HStack(spacing: 8) {
                if !store.profile.hideSplitByItem || !store.profile.hideSplitBySeat {
                    SecondaryAction(title: "Split", glyph: "divide") {
                        store.takeLock(order.id)
                        store.route = .split
                    }
                }
                SecondaryAction(title: "Discount", glyph: "tag") {
                    store.route = .discountOrder
                }
                if order.total.isZero && !order.liveItems.isEmpty {
                    SecondaryAction(title: "Close at $0", glyph: "checkmark") {
                        store.completeZero()
                    }
                }
            }
        }
        .padding(Metric.pad)
        .background(theme.raised)
    }

    private var sendTargets: String {
        let stations = Set(order.unsentItems.map { store.station(for: $0) })
        return stations.sorted().joined(separator: " · ")
    }

    private func quickSubtitle(_ kind: TenderKind) -> String? {
        guard order.total.cents > 0 else { return nil }
        switch kind {
        case .cash:
            let rounded = order.amountDue.roundedForCash(to: store.profile.cashRounding)
            return rounded == order.amountDue ? order.amountDue.formatted() : "\(rounded.formatted()) rounded"
        case .card:
            let sur = PricingEngine.cardSurcharge(on: order.amountDue, profile: store.profile)
            return sur.isZero ? order.amountDue.formatted() : "\((order.amountDue + sur).formatted()) with surcharge"
        default:
            return order.amountDue.formatted()
        }
    }

    /// A quick tender is the venue's routine tender taken in one tap. Cash still opens the
    /// pad, because change is the number an operator most often misreads.
    private func quickTender(_ kind: TenderKind) {
        store.takeLock(order.id)
        switch kind {
        case .cash:
            store.route = .payment
        default:
            store.tender(kind, amount: order.amountDue)
        }
    }
}

/// The name row. Forty names recur every morning, so typing one is a waste of five taps.
/// It shows only while the order has no identifier and the venue calls orders by name.
struct NameStrip: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelHeader("Name on the cup", detail: "or open details to type one")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.recentNames.prefix(8), id: \.self) { name in
                        Button {
                            store.setName(name)
                        } label: {
                            Text(name)
                                .font(.system(size: 15, weight: .semibold))
                                .padding(.horizontal, 15)
                                .frame(height: 42)
                                .foregroundStyle(theme.ink)
                                .background(Capsule().fill(theme.accentSoft))
                        }
                        .posPress()
                    }
                    Button {
                        store.route = .orderDetails
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "keyboard").font(.system(size: 13, weight: .semibold))
                            Text("Type").font(.system(size: 14, weight: .medium))
                        }
                        .padding(.horizontal, 13)
                        .frame(height: 42)
                        .foregroundStyle(theme.inkSecondary)
                        .background {
                            Capsule().strokeBorder(theme.hairline, lineWidth: 1)
                        }
                    }
                    .posPress()
                }
            }
        }
    }
}
