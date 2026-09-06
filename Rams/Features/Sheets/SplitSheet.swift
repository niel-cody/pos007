import SwiftUI

/// Splitting. Five bases, mixable, with the mode lock removed: allocate two items to one
/// guest and split the rest equally between three, and when the guests change their minds
/// re-split what is left rather than refunding and starting again.
struct SplitSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var mode: SplitMode = .equal
    @State private var count = 2
    @State private var activePortion: UUID?
    @State private var pad = ""
    @State private var tendering: UUID?

    private var order: Order? { store.currentOrder }

    var body: some View {
        if let order {
            SheetFrame(title: "Split the bill",
                       subtitle: subtitle(order),
                       glyph: "divide") {
                VStack(spacing: 0) {
                    FiguresPanel(order: order)
                        .padding(Metric.padLarge)
                    Divider().overlay(theme.hairline)
                    HStack(alignment: .top, spacing: 0) {
                        modeColumn(order)
                        Divider().overlay(theme.hairline)
                        portionColumn(order)
                    }
                }
            } footer: {
                footer(order)
            }
            .onAppear {
                mode = order.splitPlan?.mode ?? .equal
                if order.splitPlan == nil { store.startSplit(.equal, count: 2) }
                if let n = store.currentOrder?.splitPlan?.portions.count { count = n }
                activePortion = store.currentOrder?.splitPlan?.portions.first { $0.state != .paid }?.id
            }
        }
    }

    private func subtitle(_ order: Order) -> String {
        var parts = [order.tableLabel.map { "Table \($0)" } ?? order.identifierLabel]
        if let plan = order.splitPlan, plan.modesUsed.count > 1 {
            parts.append("mixed: " + plan.modesUsed.map(\.label).sorted().joined(separator: " + "))
        }
        parts.append("up to \(store.profile.maxSplitPayments) ways on this device")
        return parts.joined(separator: " · ")
    }

    // MARK: - Modes

    private func modeColumn(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader("How they are splitting")
            VStack(spacing: 6) {
                ForEach(available) { m in
                    Button {
                        mode = m
                        store.startSplit(m, count: count)
                        activePortion = store.currentOrder?.splitPlan?.portions.first { $0.state != .paid }?.id
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: m.glyph).font(.system(size: 14, weight: .semibold))
                            Text(m.label).font(.system(size: 15, weight: mode == m ? .semibold : .regular))
                            Spacer()
                            Text(hint(m)).font(.system(size: 11.5)).opacity(0.8)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .foregroundStyle(mode == m ? .white : theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                .fill(mode == m ? theme.accent : theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                        .strokeBorder(mode == m ? .clear : theme.hairline, lineWidth: 0.7)
                                }
                        }
                    }
                    .posPress()
                }
            }

            if mode == .equal || mode == .percentage {
                PanelHeader("How many")
                HStack(spacing: 6) {
                    ForEach(2...min(6, store.profile.maxSplitPayments), id: \.self) { n in
                        Button {
                            count = n
                            store.startSplit(mode, count: n)
                            activePortion = store.currentOrder?.splitPlan?.portions.first { $0.state != .paid }?.id
                        } label: {
                            Text("\(n)")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 48)
                                .foregroundStyle(count == n ? .white : theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(count == n ? theme.accent : theme.surface)
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

            if order.paidTotal.cents > 0 {
                PanelHeader("The plan changed")
                VStack(spacing: 6) {
                    SecondaryAction(title: "Re-split what is left", glyph: "arrow.triangle.branch") {
                        store.resplitRemaining(count)
                    }
                    SecondaryAction(title: "Pay the rest together", glyph: "arrow.triangle.merge") {
                        store.mergeUnpaidPortions()
                    }
                }
            }

            Spacer(minLength: 0)

            SecondaryAction(title: "Cancel the split", glyph: "xmark") {
                store.clearSplit()
                store.route = .payment
            }
        }
        .padding(Metric.padLarge)
        .frame(width: 340)
    }

    private var available: [SplitMode] {
        SplitMode.allCases.filter {
            if $0 == .seats { return !store.profile.hideSplitBySeat && !(order?.seatsUsed.isEmpty ?? true) }
            if $0 == .items { return !store.profile.hideSplitByItem }
            return true
        }
    }

    private func hint(_ m: SplitMode) -> String {
        switch m {
        case .equal: "same each"
        case .amount: "keyed amounts"
        case .percentage: "by share"
        case .items: "drag or tap items"
        case .seats: "\(order?.seatsUsed.count ?? 0) seats"
        }
    }

    // MARK: - Portions

    private func portionColumn(_ order: Order) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let plan = order.splitPlan {
                    VStack(spacing: 7) {
                        ForEach(plan.portions) { portion in
                            portionRow(order, portion)
                        }
                    }
                    if mode == .amount || mode == .items {
                        SecondaryAction(title: "Add another payer", glyph: "plus") {
                            store.addPortion()
                        }
                    }
                    if mode == .items {
                        itemAllocation(order, plan)
                    }
                    if mode == .amount, let active = activePortion {
                        amountPad(order, active)
                    }
                }
            }
            .padding(Metric.padLarge)
        }
        .frame(maxWidth: .infinity)
    }

    private func portionRow(_ order: Order, _ portion: SplitPortion) -> some View {
        let active = activePortion == portion.id
        let paid = portion.state == .paid
        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: paid ? "checkmark.circle.fill" : "person.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(paid ? Palette.go : (active ? theme.accent : theme.inkSecondary))
                VStack(alignment: .leading, spacing: 1) {
                    Text(portion.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    if !portion.shares.isEmpty {
                        Text(shareSummary(order, portion))
                            .font(.system(size: 11.5))
                            .foregroundStyle(theme.inkSecondary)
                            .lineLimit(1)
                    } else if paid {
                        Text("Paid \(portion.paid.formatted())")
                            .font(.system(size: 11.5)).foregroundStyle(Palette.go)
                    }
                }
                Spacer()
                Text(portion.amount.formatted())
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(paid ? theme.inkSecondary : theme.ink)
                    .strikethrough(paid)
            }
            .padding(11)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(active ? theme.accentSoft : theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .strokeBorder(active ? theme.accent : theme.hairline,
                                          lineWidth: active ? 1.4 : 0.7)
                    }
            }
            .contentShape(.rect)
            .onTapGesture { if !paid { activePortion = portion.id } }

            if active && !paid && portion.amount.cents > 0 {
                HStack(spacing: 7) {
                    ForEach(store.profile.quickTenders) { t in
                        PrimaryAction(title: "\(t.label) \(portion.remaining.formatted())",
                                      glyph: t.glyph,
                                      tint: t == .cash ? Palette.go : theme.accent) {
                            store.tender(t, amount: portion.remaining,
                                         tendered: t == .cash ? portion.remaining : nil,
                                         portionID: portion.id)
                            advance(order)
                        }
                    }
                }
            }
        }
    }

    private func shareSummary(_ order: Order, _ portion: SplitPortion) -> String {
        portion.shares.compactMap { share in
            guard let item = order.liveItems.first(where: { $0.id == share.itemID }) else { return nil }
            return share.fraction < 1 ? "½ \(item.name)" : "\(share.quantity)× \(item.name)"
        }.joined(separator: ", ")
    }

    private func advance(order: Order) { advance(order) }

    private func advance(_ order: Order) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            activePortion = store.currentOrder?.splitPlan?.portions.first { $0.state != .paid }?.id
        }
    }

    /// Allocation by tapping: choose a payer, tap the items that are theirs. A shared bottle
    /// is divided by value across the payers who want it.
    private func itemAllocation(_ order: Order, _ plan: SplitPlan) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Items", detail: activePortion == nil ? "choose a payer first"
                        : "tap to move to \(plan.portions.first { $0.id == activePortion }?.label ?? "")")
            ForEach(order.liveItems) { item in
                let owner = plan.portions.first { p in p.shares.contains { $0.itemID == item.id } }
                Button {
                    guard let active = activePortion else { return }
                    if owner?.id == active {
                        store.allocate(itemID: item.id, quantity: item.quantity, to: nil)
                    } else {
                        store.allocate(itemID: item.id, quantity: item.quantity, to: active)
                    }
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: owner == nil ? "circle" : "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(owner == nil ? theme.inkSecondary.opacity(0.5) : theme.accent)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(item.quantity)× \(item.name)")
                                .font(.system(size: 14))
                                .foregroundStyle(theme.ink)
                            if let owner {
                                Text(owner.label).font(.system(size: 11)).foregroundStyle(theme.accent)
                            }
                        }
                        Spacer()
                        do {
                            Button {
                                store.share(itemID: item.id, across: plan.portions.filter { $0.state != .paid }.map(\.id))
                            } label: {
                                Text("Share")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 9).frame(height: 28)
                                    .foregroundStyle(theme.accent)
                                    .background(Capsule().fill(theme.accentSoft))
                            }
                        }
                        Text(item.lineTotal.formatted())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .moneyFigure()
                            .foregroundStyle(theme.inkSecondary)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 46)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                            .fill(theme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                    .strokeBorder(theme.hairline, lineWidth: 0.7)
                            }
                    }
                }
                .posPress(scale: 0.995)
            }
        }
    }

    private func amountPad(_ order: Order, _ portionID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Keyed amount")
            NumberPad(value: $pad, style: .money,
                      quickAmounts: [order.amountDue, Money(cents: order.amountDue.cents / 2),
                                     Money(20), Money(50)],
                      confirmTitle: "Set \(Money(cents: Int(pad) ?? 0).formatted())",
                      confirmDetail: "Then take the tender on that payer",
                      confirmEnabled: (Int(pad) ?? 0) > 0) {
                store.setPortionAmount(portionID, Money(cents: Int(pad) ?? 0))
                pad = ""
            }
        }
    }

    // MARK: - Footer

    private func footer(_ order: Order) -> some View {
        HStack(spacing: 12) {
            if let plan = order.splitPlan {
                let unpaid = plan.portions.filter { $0.state != .paid }.count
                VStack(alignment: .leading, spacing: 1) {
                    Text(unpaid == 0 ? "Every portion is paid" : "\(unpaid) still to pay")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("The last payer is charged exactly what is left, whatever the rounding did.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.inkSecondary)
                }
            }
            Spacer()
            SecondaryAction(title: "Per-guest receipts", glyph: "doc.on.doc") {
                store.toast(.done, "Receipt printed for this leg",
                            detail: "Shows their share, their tender and what is left")
            }
            .frame(width: 200)
            PrimaryAction(title: "Back to payment", glyph: "creditcard") {
                store.route = .payment
            }
            .frame(width: 220)
        }
    }
}
