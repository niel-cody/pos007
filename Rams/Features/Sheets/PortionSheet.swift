import SwiftUI

/// Half-and-half. A diagram, a pizza list under each section, that section's own toppings,
/// a whole-pizza group above them, and the pricing rule stated in words so the operator can
/// answer "why is it that much" while the customer is still on the phone.
struct PortionSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var combo: Combo
    var editingItemID: UUID?

    @State private var sections: [PortionSelection] = []
    @State private var wholeSelections: [SelectedModifier] = []
    @State private var activeSection = 0
    @State private var quantity = 1
    @State private var note = ""

    private var slots: [ComboSlot] { combo.slots }

    var body: some View {
        SheetFrame(title: combo.name,
                   subtitle: "\(combo.pricingRule.explanation) · \(slots.count) sections",
                   glyph: "circle.lefthalf.filled") {
            HStack(alignment: .top, spacing: 0) {
                diagramColumn
                Divider().overlay(theme.hairline)
                buildColumn
            }
        } footer: {
            footer
        }
        .onAppear(perform: prime)
    }

    // MARK: - Diagram
    //
    // The pizza is drawn, because a list of two sections named "Left" and "Right" is a worse
    // description of a pizza than a picture of one.

    private var diagramColumn: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(theme.raised)
                    .overlay { Circle().strokeBorder(theme.hairline, lineWidth: 1) }

                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    PortionWedge(index: index, count: slots.count)
                        .fill(index == activeSection
                              ? theme.accent.opacity(0.24)
                              : Palette.productTint(index).opacity(0.13))
                        .overlay {
                            PortionWedge(index: index, count: slots.count)
                                .stroke(index == activeSection ? theme.accent : theme.hairline,
                                        lineWidth: index == activeSection ? 2 : 1)
                        }
                        .onTapGesture { withAnimation(Motion.tap) { activeSection = index } }
                }

                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let filled = sections.indices.contains(index) && !sections[index].productName.isEmpty
                    Text(filled ? sections[index].productName : "Choose")
                        .font(.system(size: slots.count > 2 ? 11 : 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(filled ? theme.ink : theme.inkSecondary)
                        .frame(width: slots.count > 2 ? 70 : 92)
                        .offset(labelOffset(index: index, count: slots.count))
                        .allowsHitTesting(false)
                }
            }
            .frame(width: 250, height: 250)

            VStack(spacing: 5) {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    Button {
                        withAnimation(Motion.tap) { activeSection = index }
                    } label: {
                        HStack(spacing: 7) {
                            Circle()
                                .fill(index == activeSection ? theme.accent : Palette.productTint(index).opacity(0.5))
                                .frame(width: 8, height: 8)
                            Text(slot.name)
                                .font(.system(size: 13, weight: index == activeSection ? .semibold : .regular))
                                .foregroundStyle(theme.ink)
                            Spacer()
                            if sections.indices.contains(index), !sections[index].productName.isEmpty {
                                Text(sections[index].basePrice.formatted())
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .moneyFigure()
                                    .foregroundStyle(theme.inkSecondary)
                            } else {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Palette.warn)
                            }
                        }
                        .padding(.horizontal, 10)
                        .frame(height: 36)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                .fill(index == activeSection ? theme.accentSoft : Color.clear)
                        }
                    }
                    .posPress()
                }
            }

            Panel(padding: 11) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(combo.pricingRule.explanation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text(priceExplanation)
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(Metric.padLarge)
        .frame(width: 320)
    }

    private func labelOffset(index: Int, count: Int) -> CGSize {
        let mid = Double(index) * (360.0 / Double(count)) + (180.0 / Double(count)) - 90
        let r = count > 2 ? 72.0 : 62.0
        return CGSize(width: cos(mid * .pi / 180) * r, height: sin(mid * .pi / 180) * r)
    }

    private var priceExplanation: String {
        let bases = sections.map(\.basePrice).filter { $0.cents > 0 }
        guard !bases.isEmpty else { return "Choose each section to see the price." }
        switch combo.pricingRule {
        case .highest:
            let dearest = bases.max() ?? .zero
            return "\(combo.addonPrice.formatted()) base plus the dearest half at \(dearest.formatted())."
        case .proRata:
            return "Half of each: " + bases.map { Money(cents: $0.cents / 2).formatted() }.joined(separator: " + ")
        case .fixed:
            return "\(combo.fixedPrice.formatted()) fixed, plus any priced toppings."
        }
    }

    // MARK: - Build column

    private var buildColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pizzaChoice
                if sections.indices.contains(activeSection),
                   !sections[activeSection].productName.isEmpty {
                    sectionToppings
                }
                wholePizzaGroups
                noteBlock
            }
            .padding(Metric.padLarge)
        }
        .frame(maxWidth: .infinity)
    }

    private var pizzaChoice: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader(slots[activeSection].name, detail: "which pizza on this section")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                ForEach(slots[activeSection].productIDs, id: \.self) { pid in
                    if let p = store.catalogue.product(pid) {
                        let chosen = sections.indices.contains(activeSection)
                            && sections[activeSection].productID == pid
                        Button {
                            choose(p)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.name)
                                    .font(.system(size: 13.5, weight: chosen ? .semibold : .regular))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(sectionPrice(p).formatted())
                                    .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                    .moneyFigure()
                                    .opacity(0.8)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 54, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(chosen ? .white : theme.ink)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                    .fill(chosen ? theme.accent : theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                            .strokeBorder(chosen ? .clear : theme.hairline, lineWidth: 0.7)
                                    }
                            }
                        }
                        .posPress()
                    }
                }
            }
        }
    }

    private func sectionPrice(_ p: Product) -> Money {
        p.price + (p.variants.first(where: \.isDefault)?.priceDelta ?? .zero)
    }

    private var sectionToppings: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(combo.sectionGroups) { group in
                PanelHeader("\(group.name) on \(slots[activeSection].name.lowercased())",
                            detail: "priced at half")
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                    ForEach(group.modifiers) { mod in
                        let on = sections[activeSection].modifiers.contains { $0.modifierID == mod.id }
                        Button {
                            toggleSectionTopping(group, mod)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mod.name).font(.system(size: 13, weight: on ? .semibold : .regular)).lineLimit(1)
                                Text(Money(cents: mod.price.cents / 2).formatted(showsSign: true))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .moneyFigure()
                                    .opacity(0.8)
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 46, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(on ? .white : theme.ink)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                    .fill(on ? theme.accent : theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .strokeBorder(on ? .clear : theme.hairline, lineWidth: 0.7)
                                    }
                            }
                        }
                        .posPress()
                    }
                }
            }
        }
    }

    /// A whole-pizza group prints once, above the section blocks, so the make line does not
    /// have to work out that both halves said "thin crust".
    private var wholePizzaGroups: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(combo.wholeGroups) { group in
                VStack(alignment: .leading, spacing: 7) {
                    PanelHeader("\(group.name) — whole pizza", detail: "prints once, above the halves")
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 7) {
                        ForEach(group.modifiers) { mod in
                            let on = wholeSelections.contains { $0.modifierID == mod.id }
                            Button {
                                toggleWhole(group, mod)
                            } label: {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mod.name).font(.system(size: 13, weight: on ? .semibold : .regular)).lineLimit(1)
                                    if !mod.price.isZero {
                                        Text(mod.price.formatted(showsSign: true))
                                            .font(.system(size: 11, weight: .medium, design: .rounded))
                                            .moneyFigure().opacity(0.8)
                                    }
                                }
                                .padding(.horizontal, 9)
                                .frame(height: 46, alignment: .leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(on ? .white : theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(on ? theme.accent : theme.surface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .strokeBorder(on ? .clear : theme.hairline, lineWidth: 0.7)
                                        }
                                }
                            }
                            .posPress()
                        }
                    }
                }
            }
        }
    }

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Note")
            TextField("Cut in squares, well done, deliver to the back door", text: $note)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                        .fill(theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                        }
                }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Button { quantity = max(1, quantity - 1) } label: {
                    Image(systemName: "minus").font(.system(size: 14, weight: .bold))
                        .frame(width: 46, height: 52).foregroundStyle(theme.ink)
                }
                Text("\(quantity)").font(.system(size: 20, weight: .bold, design: .rounded))
                    .frame(width: 40).foregroundStyle(theme.ink)
                Button { quantity += 1 } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        .frame(width: 46, height: 52).foregroundStyle(theme.ink)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                    }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(total.formatted())
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
                Text(complete ? combo.pricingRule.explanation : "Every section needs a choice")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(complete ? theme.inkSecondary : Palette.warn)
            }
            .animation(Motion.quick, value: total.cents)

            Spacer(minLength: 6)

            PrimaryAction(title: editingItemID == nil ? "Add" : "Save",
                          glyph: editingItemID == nil ? "plus" : "checkmark",
                          enabled: complete) { commit() }
                .frame(width: 220)
        }
    }

    private var complete: Bool {
        sections.count == slots.count && sections.allSatisfy { !$0.productName.isEmpty }
    }

    private var total: Money {
        let bases = sections.map(\.basePrice)
        var base: Money
        switch combo.pricingRule {
        case .highest: base = combo.addonPrice + (bases.max() ?? .zero)
        case .proRata: base = combo.addonPrice + Money(cents: bases.map { $0.cents / 2 }.reduce(0, +))
        case .fixed: base = combo.fixedPrice
        }
        let sectionMods = sections.flatMap(\.modifiers).map(\.total).total
        let whole = wholeSelections.map(\.total).total
        return (base + sectionMods + whole) * quantity
    }

    // MARK: - Editing

    private func prime() {
        if let id = editingItemID, let item = store.currentOrder?.items.first(where: { $0.id == id }) {
            sections = item.portions
            wholeSelections = item.modifiers
            quantity = item.quantity
            note = item.note ?? ""
        } else {
            sections = slots.map { PortionSelection(slotName: $0.name, productID: UUID(),
                                                    productName: "", basePrice: .zero) }
            wholeSelections = combo.wholeGroups.flatMap { g in
                g.modifiers.filter(\.isDefault).map {
                    SelectedModifier(groupID: g.id, groupName: g.name, modifierID: $0.id,
                                     name: $0.name, unitPrice: $0.price)
                }
            }
        }
    }

    private func choose(_ p: Product) {
        guard sections.indices.contains(activeSection) else { return }
        withAnimation(Motion.tap) {
            sections[activeSection].productID = p.id
            sections[activeSection].productName = p.name
            sections[activeSection].basePrice = sectionPrice(p)
            // Move on by itself: the operator does not have to say "now the other half".
            if activeSection < slots.count - 1,
               sections[activeSection + 1].productName.isEmpty {
                activeSection += 1
            }
        }
    }

    private func toggleSectionTopping(_ group: ModifierGroup, _ mod: Modifier) {
        guard sections.indices.contains(activeSection) else { return }
        if let i = sections[activeSection].modifiers.firstIndex(where: { $0.modifierID == mod.id }) {
            sections[activeSection].modifiers.remove(at: i)
        } else {
            sections[activeSection].modifiers.append(
                SelectedModifier(groupID: group.id, groupName: group.name, modifierID: mod.id,
                                 name: mod.name, unitPrice: Money(cents: mod.price.cents / 2),
                                 portion: 0.5))
        }
    }

    private func toggleWhole(_ group: ModifierGroup, _ mod: Modifier) {
        if group.selection == .single {
            wholeSelections.removeAll { $0.groupID == group.id }
        }
        if let i = wholeSelections.firstIndex(where: { $0.modifierID == mod.id }) {
            wholeSelections.remove(at: i)
        } else {
            wholeSelections.append(SelectedModifier(groupID: group.id, groupName: group.name,
                                                    modifierID: mod.id, name: mod.name,
                                                    unitPrice: mod.price))
        }
    }

    private func commit() {
        guard let tile = store.catalogue.products.first(where: { $0.comboID == combo.id }) else { return }
        if let id = editingItemID {
            store.mutateCurrent { o in
                guard let i = o.items.firstIndex(where: { $0.id == id }) else { return }
                o.items[i].portions = sections
                o.items[i].modifiers = wholeSelections
                o.items[i].quantity = quantity
                o.items[i].note = note.isEmpty ? nil : note
                if o.items[i].isSentOrLater {
                    o.items[i].sendRecords = []
                    o.items[i].status = .unsent
                }
            }
        } else {
            store.add(product: tile, modifiers: wholeSelections, quantity: quantity,
                      note: note.isEmpty ? nil : note,
                      portions: sections, comboName: combo.name + " " + (tile.name.contains("16") ? "16\"" : "13\""),
                      comboRule: combo.pricingRule)
        }
        store.route = nil
    }
}

/// A wedge of the pizza. Two sections is a half; four is a quarter. Five is not a real product.
struct PortionWedge: Shape {
    var index: Int
    var count: Int

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let sweep = 360.0 / Double(count)
        let start = Angle(degrees: Double(index) * sweep - 90)
        let end = Angle(degrees: Double(index + 1) * sweep - 90)
        var p = Path()
        p.move(to: centre)
        p.addArc(center: centre, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}
