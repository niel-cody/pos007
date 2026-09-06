import SwiftUI

struct PaymentSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var kind: TenderKind = .cash
    @State private var pad = ""
    @State private var tip: Money = .zero

    private var order: Order? { store.currentOrder }

    var body: some View {
        if let order {
            SheetFrame(title: "Payment",
                       subtitle: "\(order.identifierLabel) · \(order.itemCount) items",
                       glyph: "creditcard.fill") {
                VStack(spacing: 0) {
                    // The four figures sit across the top in a fixed position, and stay put
                    // through the tender, the pad and the terminal.
                    FiguresPanel(order: order)
                        .padding(.horizontal, Metric.padLarge)
                        .padding(.vertical, 13)
                    Divider().overlay(theme.hairline)
                    HStack(alignment: .top, spacing: 0) {
                        tenderColumn(order)
                        Divider().overlay(theme.hairline)
                        detailColumn(order)
                    }
                }
            } footer: {
                HStack(spacing: 10) {
                    SecondaryAction(title: "Split this bill", glyph: "divide") {
                        store.route = .split
                    }
                    .frame(width: 220)
                    SecondaryAction(title: "Print the bill", glyph: "doc.text") {
                        store.printBill(order.id)
                    }
                    .frame(width: 200)
                    Spacer()
                    if order.amountDue.cents <= 1 {
                        PrimaryAction(title: "Close the sale", glyph: "checkmark") {
                            store.completeZero()
                        }
                        .frame(width: 240)
                    }
                }
            }
            .onAppear {
                // The sheet exists mostly for cash and for anything unusual: the venue's
                // routine tender is already one tap on the cart.
                kind = .cash
                pad = String(order.amountDue.cents)
            }
        }
    }

    // MARK: - Tenders

    private func tenderColumn(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelHeader("Tender", detail: store.offline ? "offline — cash and account only" : nil)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(store.profile.allTenders) { t in
                    let usable = !store.offline || t.worksOffline
                    Button {
                        kind = t
                        pad = String(order.amountDue.cents)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.glyph).font(.system(size: 16, weight: .semibold))
                            Text(t.label).font(.system(size: 12.5, weight: kind == t ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .foregroundStyle(kind == t ? .white : theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                .fill(kind == t ? theme.accent : theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                        .strokeBorder(kind == t ? .clear : theme.hairline, lineWidth: 0.7)
                                }
                        }
                        .opacity(usable ? 1 : 0.35)
                    }
                    .disabled(!usable)
                    .posPress()
                }
            }

            if store.profile.tipsEnabled && kind == .card {
                PanelHeader("Tip")
                HStack(spacing: 7) {
                    ForEach(store.profile.tipPresets, id: \.self) { pct in
                        let amount = order.amountDue.percent(pct)
                        Button {
                            tip = tip == amount ? .zero : amount
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(Int(pct))%").font(.system(size: 14, weight: .semibold))
                                Text(amount.formatted())
                                    .font(.system(size: 11, design: .rounded)).moneyFigure().opacity(0.8)
                            }
                            .frame(maxWidth: .infinity).frame(height: 46)
                            .foregroundStyle(tip == amount ? .white : theme.ink)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                    .fill(tip == amount ? Palette.go : theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                    }
                            }
                        }
                        .posPress()
                    }
                    Button("No tip") { tip = .zero }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(theme.inkSecondary)
                }
            }

            Divider().overlay(theme.hairline).padding(.vertical, 2)

            PanelHeader("What they are paying for")
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(order.liveItems) { item in
                        MoneyRow(label: "\(item.quantity)× \(item.name)",
                                 amount: item.lineTotal,
                                 note: item.configurationSummary.isEmpty ? nil : item.configurationSummary)
                    }
                    ForEach(order.adjustments) { adj in
                        MoneyRow(label: adj.explanation, amount: adj.amount, reduction: adj.isReduction)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Metric.padLarge)
        .frame(width: 440)
    }

    // MARK: - The pad or the terminal

    private func detailColumn(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if order.hasPendingLeg {
                pendingBlock(order)
            }

            if !order.payments.filter({ $0.state != .cancelled }).isEmpty {
                legsBlock(order)
            }

            switch kind {
            case .cash:
                NumberPad(value: $pad,
                          style: .money,
                          quickAmounts: quickCash(order),
                          confirmTitle: "Cash \(padMoney.formatted())",
                          confirmDetail: changeLine(order),
                          confirmEnabled: padMoney.cents > 0) {
                    let due = order.amountDue.roundedForCash(to: store.profile.cashRounding)
                    store.tender(.cash, amount: min(padMoney, due), tendered: padMoney)
                    pad = String(max(0, order.amountDue.cents - padMoney.cents))
                }
            case .card, .giftCard, .voucher, .loyalty, .manualCard, .houseAccount, .roomCharge, .other:
                terminalBlock(order)
            }
            Spacer(minLength: 0)
        }
        .padding(Metric.padLarge)
        .frame(maxWidth: .infinity)
    }

    private var padMoney: Money { Money(cents: Int(pad) ?? 0) }

    private func quickCash(_ order: Order) -> [Money] {
        let due = order.amountDue.roundedForCash(to: store.profile.cashRounding)
        var out: [Money] = [due]
        for note in [Money(20), Money(50), Money(100)] where note > due {
            out.append(note)
        }
        let nextTen = Money(cents: ((due.cents / 1000) + 1) * 1000)
        if !out.contains(nextTen) && nextTen > due { out.insert(nextTen, at: 1) }
        return Array(out.prefix(4))
    }

    private func changeLine(_ order: Order) -> String? {
        let due = order.amountDue.roundedForCash(to: store.profile.cashRounding)
        guard padMoney > due else { return nil }
        return "Change \((padMoney - due).formatted())"
    }

    private func terminalBlock(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Panel {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: kind.glyph)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.accent)
                        Text(kind.label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        Spacer()
                        if kind == .card, let pct = store.profile.surchargePercent {
                            Chip(text: "Surcharge \(String(format: "%.1f", pct))%", glyph: "plus", tint: Palette.warn)
                        }
                    }
                    MoneyRow(label: "To charge", amount: chargeAmount(order), emphasis: true)
                    if kind == .card, let pct = store.profile.surchargePercent {
                        MoneyRow(label: "Card surcharge \(Int(pct))%",
                                 amount: PricingEngine.cardSurcharge(on: order.amountDue, profile: store.profile))
                    }
                    if tip.cents > 0 {
                        MoneyRow(label: "Tip", amount: tip)
                    }
                    if kind == .houseAccount {
                        Text("The order closes as Completed and the money is a settlement on the account, not an unpaid order.")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.inkSecondary)
                    }
                    if kind == .manualCard {
                        Text("Recorded as a manual card record with no terminal. Reconciled at close.")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.inkSecondary)
                    }
                }
            }

            PrimaryAction(title: "Charge \(chargeAmount(order).formatted())",
                          subtitle: kind == .card ? "Terminal \(store.cardOutcome.label.lowercased())" : nil,
                          glyph: kind.glyph) {
                store.tender(kind, amount: order.amountDue, tip: tip)
                if kind == .card { pad = "0" }
            }

            SecondaryAction(title: "Amount other than the full balance", glyph: "keyboard") {
                kind = .cash
            }
        }
    }

    private func chargeAmount(_ order: Order) -> Money {
        var a = order.amountDue + tip
        if kind == .card { a = a + PricingEngine.cardSurcharge(on: order.amountDue, profile: store.profile) }
        return a
    }

    /// A hung payment is verified, never retried. That is how a double charge starts.
    private func pendingBlock(_ order: Order) -> some View {
        let pending = order.payments.filter { $0.state == .pending }
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(pending) { leg in
                Panel(padding: 12) {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(leg.kind.label) \(leg.amount.formatted()) is pending")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.ink)
                            Text("Do not retry. Verify the outcome instead.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.inkSecondary)
                        }
                        Spacer()
                        Button {
                            store.verify(legID: leg.id, orderID: order.id)
                        } label: {
                            Text("Verify")
                                .font(.system(size: 14, weight: .semibold))
                                .padding(.horizontal, 16).frame(height: 40)
                                .foregroundStyle(.white)
                                .background(Capsule().fill(Palette.warn))
                        }
                        .posPress()
                        Button("Cancel") { store.cancelLeg(legID: leg.id, orderID: order.id) }
                            .font(.system(size: 13))
                            .foregroundStyle(theme.inkSecondary)
                    }
                }
            }
        }
    }

    private func legsBlock(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            PanelHeader("Taken so far")
            ForEach(order.payments.filter { $0.state != .cancelled }) { leg in
                HStack(spacing: 8) {
                    Image(systemName: leg.kind.glyph)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(legTint(leg))
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(leg.kind.label) · \(leg.state.label)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.ink)
                        if let r = leg.reference {
                            Text(r).font(.system(size: 11)).foregroundStyle(theme.inkSecondary)
                        }
                    }
                    Spacer()
                    if leg.surcharge.cents > 0 || leg.tip.cents > 0 || leg.rounding.cents != 0 {
                        Text(extras(leg))
                            .font(.system(size: 11))
                            .foregroundStyle(theme.inkSecondary)
                    }
                    Text(leg.amount.formatted())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .moneyFigure()
                        .foregroundStyle(theme.ink)
                    if leg.state == .complete {
                        Button {
                            store.reverse(legID: leg.id, orderID: order.id)
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(theme.inkSecondary)
                        }
                        .help("Reverse this tender")
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private func extras(_ leg: PaymentLeg) -> String {
        var parts: [String] = []
        if leg.surcharge.cents > 0 { parts.append("+\(leg.surcharge.formatted()) surcharge") }
        if leg.tip.cents > 0 { parts.append("+\(leg.tip.formatted()) tip") }
        if leg.rounding.cents != 0 { parts.append("\(leg.rounding.formatted(showsSign: true)) rounding") }
        if leg.change.cents > 0 { parts.append("\(leg.change.formatted()) change") }
        return parts.joined(separator: " · ")
    }

    private func legTint(_ leg: PaymentLeg) -> Color {
        switch leg.state {
        case .complete: Palette.go
        case .pending: Palette.warn
        case .rejected: Palette.stop
        case .reversed, .cancelled: theme.inkSecondary
        }
    }
}

// MARK: - The four figures
//
// Total, allocated, paid, remaining. In a fixed position, visible through tender screens,
// processing screens and receipts, and every one of them expandable.

struct FiguresPanel: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    @State private var expanded: String?

    var body: some View {
        let f = store.figures(for: order)
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                figure("Total", f.total, key: "total")
                divider
                figure("Allocated", f.allocated, key: "allocated",
                       muted: order.splitPlan == nil)
                divider
                figure("Paid", f.paid, key: "paid")
                divider
                figure(f.isOverpaid ? "Overpaid" : "Remaining",
                       f.isOverpaid ? -f.remaining : f.remaining,
                       key: "remaining",
                       tint: f.isOverpaid ? Palette.stop : theme.ink, big: true)
            }
            .padding(.vertical, 11)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                    }
            }

            if f.surcharges.cents > 0 || f.rounding.cents != 0 || f.tips.cents > 0 {
                HStack(spacing: 12) {
                    if f.surcharges.cents > 0 { extra("Card surcharges", f.surcharges) }
                    if f.rounding.cents != 0 { extra("Rounding", f.rounding) }
                    if f.tips.cents > 0 { extra("Tips", f.tips) }
                }
            }

            if let key = expanded { expansion(key) }
        }
        .animation(Motion.quick, value: expanded)
    }

    private var divider: some View {
        Rectangle().fill(theme.hairline).frame(width: 0.7, height: 34)
    }

    private func figure(_ label: String, _ amount: Money, key: String,
                        tint: Color? = nil, muted: Bool = false, big: Bool = false) -> some View {
        Button {
            expanded = expanded == key ? nil : key
        } label: {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10.5, weight: .semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(theme.inkSecondary)
                Text(amount.formatted())
                    .font(.system(size: big ? 22 : 18, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(muted ? theme.inkSecondary.opacity(0.6) : (tint ?? theme.ink))
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
        }
        .posPress(scale: 0.99)
    }

    private func extra(_ label: String, _ amount: Money) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(theme.inkSecondary)
            Text(amount.formatted(showsSign: true))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .moneyFigure()
                .foregroundStyle(theme.ink)
        }
    }

    @ViewBuilder private func expansion(_ key: String) -> some View {
        Panel(padding: 11) {
            VStack(alignment: .leading, spacing: 5) {
                switch key {
                case "total":
                    ForEach(order.liveItems) { item in
                        MoneyRow(label: "\(item.quantity)× \(item.name)", amount: item.lineTotal)
                    }
                    ForEach(order.adjustments) { adj in
                        MoneyRow(label: adj.explanation, amount: adj.amount, reduction: adj.isReduction)
                    }
                case "allocated":
                    if let plan = order.splitPlan {
                        ForEach(plan.portions) { p in
                            MoneyRow(label: "\(p.label) · \(p.state.label)", amount: p.amount)
                        }
                    } else {
                        Text("No split plan: the whole bill is allocated to one payer.")
                            .font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                    }
                case "paid":
                    if order.payments.isEmpty {
                        Text("Nothing taken yet.").font(.system(size: 12)).foregroundStyle(theme.inkSecondary)
                    }
                    ForEach(order.payments.filter { $0.state == .complete }) { leg in
                        MoneyRow(label: "\(leg.kind.label) · \(leg.at.hhmm) · \(leg.staff)", amount: leg.amount)
                    }
                default:
                    let unallocated = order.splitPlan.map { plan in
                        order.liveItems.filter { item in
                            !plan.portions.flatMap(\.shares).contains { $0.itemID == item.id }
                        }
                    } ?? []
                    if unallocated.isEmpty {
                        MoneyRow(label: "Left to pay", amount: order.amountDue, emphasis: true)
                    } else {
                        Text("Not allocated to anyone yet")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.inkSecondary)
                        ForEach(unallocated) { item in
                            MoneyRow(label: "\(item.quantity)× \(item.name)", amount: item.lineTotal)
                        }
                    }
                }
            }
        }
    }
}
