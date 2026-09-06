import SwiftUI

/// One line. Everything the operator needs to know about it is on it: what was chosen, what
/// it cost, whether the kitchen has it, whose seat it is on, and whether anything is wrong.
/// Swipe is an accelerator; every action also has a tap route in the menu.
struct CartLineRow: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    var item: OrderItem

    private var sendState: ItemSendState { item.sendState }
    private var soldOutMod: Bool { item.modifiers.contains(where: \.soldOut) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 9) {
                quantityControl

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.cartLine)
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                        if let seat = item.seat, store.profile.seatsEnabled {
                            Chip(text: "S\(seat)", tint: theme.accent, small: true)
                        }
                    }

                    if !item.configurationSummary.isEmpty {
                        Text(item.configurationSummary)
                            .font(.cartDetail)
                            .foregroundStyle(theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !item.portions.isEmpty {
                        ForEach(item.portions) { p in
                            HStack(spacing: 5) {
                                Image(systemName: "circle.lefthalf.filled")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(theme.accent)
                                Text("\(p.slotName): \(p.productName)"
                                     + (p.modifiers.isEmpty ? "" : " · " + p.modifiers.map(\.name).joined(separator: ", ")))
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.inkSecondary)
                            }
                        }
                    }

                    if !item.comboChildren.isEmpty {
                        ForEach(item.comboChildren) { child in
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.turn.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(theme.inkSecondary.opacity(0.6))
                                Text(child.name + (child.modifiers.isEmpty ? "" : " · " + child.modifiers.map(\.label).joined(separator: ", ")))
                                    .font(.system(size: 12))
                                    .foregroundStyle(theme.inkSecondary)
                            }
                        }
                    }

                    chips
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(item.lineTotal.formatted())
                        .font(.money)
                        .moneyFigure()
                        .foregroundStyle(item.adjustmentTotal.isNegative ? Palette.go : theme.ink)
                    if item.adjustmentTotal.isNegative {
                        Text(item.gross.formatted())
                            .font(.system(size: 11.5))
                            .strikethrough()
                            .foregroundStyle(theme.inkSecondary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 9)
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                    .fill(background)
            }
            .overlay(alignment: .leading) {
                if item.isSentOrLater {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.tint(for: sendState))
                        .frame(width: 3)
                        .padding(.vertical, 10)
                }
            }
        }
        .contentShape(.rect)
        .onTapGesture { openEditor() }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                store.removeItem(item.id)
            } label: {
                Label(item.isSentOrLater ? "Void" : "Remove", systemImage: "trash")
            }
        }
        .contextMenu { menu }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.quantity) \(item.name), \(item.configurationSummary), \(item.lineTotal.formatted()), \(sendState.label)")
    }

    private var title: String {
        var t = item.displayName
        if let v = item.variantLabel { t = "\(v) \(t)" }
        if let c = item.comboName { t = c }
        return t
    }

    private var background: Color {
        if soldOutMod { return Palette.stop.opacity(theme.dark ? 0.16 : 0.07) }
        if sendState.needsAttention { return Palette.stop.opacity(theme.dark ? 0.14 : 0.06) }
        if item.status == .held { return Palette.warn.opacity(theme.dark ? 0.14 : 0.07) }
        if case .unsent = sendState { return theme.accentSoft.opacity(theme.dark ? 1 : 0.7) }
        return theme.dark ? Color.white.opacity(0.03) : Color.black.opacity(0.022)
    }

    private var quantityControl: some View {
        VStack(spacing: 1) {
            Button {
                store.bump(item.id, by: 1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: Metric.denseTarget, height: 22)
                    .foregroundStyle(theme.accent)
            }
            .posPress()

            Text("\(item.quantity)")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .moneyFigure()
                .foregroundStyle(theme.ink)
                .frame(width: Metric.denseTarget)

            Button {
                store.bump(item.id, by: -1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: Metric.denseTarget, height: 22)
                    .foregroundStyle(theme.accent)
            }
            .posPress()
            .help(item.quantity == 1 ? "Remove the line" : "One fewer")
        }
    }

    @ViewBuilder private var chips: some View {
        let items = chipData
        if !items.isEmpty {
            HStack(spacing: 4) {
                ForEach(items, id: \.0) { c in
                    Chip(text: c.0, glyph: c.1, tint: c.2, filled: c.3, small: true)
                }
            }
            .padding(.top, 2)
        }
    }

    private var chipData: [(String, String, Color, Bool)] {
        var out: [(String, String, Color, Bool)] = []
        switch sendState {
        case .unsent:
            out.append(("Unsent", "circle.dashed", Palette.tint(for: sendState), false))
        case .held:
            out.append(("Held", "pause.fill", Palette.warn, true))
        case .sending:
            out.append(("Sending", "arrow.up.circle", Palette.info, false))
        case .sent(let at):
            out.append(("Sent \(at.hhmm)", "checkmark", Palette.go, false))
        case .notConfirmed:
            out.append(("Not confirmed", "questionmark.circle.fill", Palette.warn, true))
        case .notSent(let reason):
            out.append((reason, "printer.trianglebadge.exclamationmark.fill", Palette.stop, true))
        }
        if item.isServed {
            out.append(("Served", "checkmark.circle.fill", Palette.go, false))
        } else if item.isReady {
            out.append(("Ready", "bell.fill", Palette.warn, true))
        }
        if soldOutMod {
            out.append(("Option sold out", "exclamationmark.triangle.fill", Palette.stop, true))
        }
        if !item.allergens.isEmpty, store.profile.allergensEnabled {
            out.append((item.allergens.joined(separator: ", "), "exclamationmark.shield.fill", Palette.stop, false))
        }
        if item.source == "repeat_round" {
            out.append(("Repeat", "arrow.trianglehead.2.clockwise.rotate.90", theme.inkSecondary, false))
        }
        if item.ageRestricted {
            out.append(("18+", "person.badge.shield.checkmark", Palette.warn, false))
        }
        for adj in item.adjustments {
            out.append((adj.explanation, adj.kind == .comp ? "gift.fill" : "tag.fill",
                        adj.isReduction ? Palette.go : theme.inkSecondary, false))
        }
        return out
    }

    private func openEditor() {
        guard let product = store.catalogue.product(item.productID) else { return }
        if !item.portions.isEmpty, let combo = store.catalogue.combos.first(where: { $0.kind == .portion }) {
            store.route = .portions(comboID: combo.id, editing: item.id)
        } else if !item.comboChildren.isEmpty, let cid = product.comboID {
            store.route = .combo(comboID: cid, productID: product.id, editing: item.id)
        } else if product.hasChoices {
            store.route = .configure(productID: product.id, editing: item.id)
        } else {
            store.route = .note(itemID: item.id)
        }
    }

    @ViewBuilder private var menu: some View {
        Button { openEditor() } label: { Label("Edit", systemImage: "slider.horizontal.3") }
        Button { store.route = .note(itemID: item.id) } label: {
            Label("Note", systemImage: "text.bubble")
        }
        if store.profile.seatsEnabled {
            Button { store.route = .seats(itemID: item.id) } label: {
                Label("Seat", systemImage: "chair.lounge")
            }
        }
        if store.profile.coursesEnabled {
            Menu("Course") {
                ForEach(order.courses) { c in
                    Button {
                        store.setCourse(item.id, c.id)
                    } label: {
                        Label(c.name, systemImage: item.courseID == c.id ? "checkmark" : c.glyph)
                    }
                }
            }
        }
        if item.quantity > 1 {
            Button {
                store.splitQuantity(item.id, take: item.quantity / 2)
            } label: { Label("Split this line", systemImage: "arrow.triangle.branch") }
        }
        Divider()
        Button { store.route = .discountItem(itemID: item.id) } label: {
            Label("Discount", systemImage: "tag")
        }
        Button {
            store.requireApproval(.comp, what: "Comp \(item.name)",
                                  reasons: ["Service recovery", "Wrong item made",
                                            "Staff meal", "Manager’s discretion"]) { approver, reason in
                store.comp(item.id, reason: reason ?? "Manager’s discretion", approvedBy: approver.initials)
            }
        } label: { Label("Complimentary", systemImage: "gift") }
        if item.isSentOrLater {
            Divider()
            Button { store.refire(item.id) } label: {
                Label("Re-fire as a rush", systemImage: "flame")
            }
            if case .notSent = sendState {
                Button { store.reprint(item.id) } label: {
                    Label("Reprint", systemImage: "printer")
                }
                ForEach(store.profile.stations.filter { $0 != item.station }, id: \.self) { st in
                    Button { store.reprint(item.id, to: st) } label: {
                        Label("Redirect to \(st)", systemImage: "arrow.turn.up.right")
                    }
                }
            }
            if !item.isReady {
                Button { store.markReady(itemID: item.id, orderID: order.id) } label: {
                    Label("Mark ready", systemImage: "bell")
                }
            }
            if !item.isServed {
                Button { store.markServed(itemID: item.id, orderID: order.id) } label: {
                    Label("Mark served", systemImage: "checkmark.circle")
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            store.removeItem(item.id)
        } label: {
            Label(item.isSentOrLater ? "Void with a reason" : "Remove", systemImage: "trash")
        }
    }
}
