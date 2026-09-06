import SwiftUI

/// The combo builder. Slots side by side, the swap price on the tile that costs more, and a
/// visible saving, because a combo where the customer swaps the drink and the side and still
/// expects the combo price is the QSR's most common awkward moment.
struct ComboSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var combo: Combo
    var seedProductID: UUID
    var editingItemID: UUID?

    @State private var chosen: [UUID: UUID] = [:]       // slot id -> product id
    @State private var childMods: [UUID: [SelectedModifier]] = [:]
    @State private var quantity = 1
    @State private var note = ""
    @State private var activeSlot: UUID?

    var body: some View {
        SheetFrame(title: combo.name,
                   subtitle: "\(combo.slots.count) choices · \(savingLine)",
                   glyph: "square.stack.3d.up.fill") {
            HStack(alignment: .top, spacing: 0) {
                slotColumn
                Divider().overlay(theme.hairline)
                choiceColumn
            }
        } footer: {
            footer
        }
        .onAppear(perform: prime)
    }

    private var slotColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(combo.slots) { slot in
                let pid = chosen[slot.id]
                let product = pid.flatMap(store.catalogue.product)
                let active = activeSlot == slot.id
                Button {
                    withAnimation(Motion.tap) { activeSlot = slot.id }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: product?.glyph ?? "questionmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(active ? .white : theme.accent)
                            .frame(width: 32, height: 32)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(active ? Color.white.opacity(0.2) : theme.accentSoft)
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(slot.name)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(active ? .white.opacity(0.85) : theme.inkSecondary)
                            Text(product?.name ?? "Choose")
                                .font(.system(size: 14.5, weight: .semibold))
                                .foregroundStyle(active ? .white : theme.ink)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        if let pid, let extra = slot.upgradePrices[pid], !extra.isZero {
                            Text(extra.formatted(showsSign: true))
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .moneyFigure()
                                .foregroundStyle(active ? .white : Palette.warn)
                        }
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .fill(active ? theme.accent : theme.surface)
                            .overlay {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .strokeBorder(active ? .clear : theme.hairline, lineWidth: 0.7)
                            }
                    }
                }
                .posPress()
            }

            Panel(padding: 11) {
                VStack(alignment: .leading, spacing: 5) {
                    MoneyRow(label: "Bought separately", amount: separateTotal)
                    MoneyRow(label: combo.name, amount: comboTotal, emphasis: true)
                    if saving.cents > 0 {
                        MoneyRow(label: "Saving", amount: -saving, reduction: true)
                    }
                }
            }
            Spacer()
        }
        .padding(Metric.padLarge)
        .frame(width: 320)
    }

    private var choiceColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let slot = combo.slots.first(where: { $0.id == activeSlot }) {
                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader(slot.name, detail: "swaps show what they add")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3),
                                  spacing: 7) {
                            ForEach(slot.productIDs, id: \.self) { pid in
                                if let p = store.catalogue.product(pid) {
                                    let on = chosen[slot.id] == pid
                                    let extra = slot.upgradePrices[pid] ?? .zero
                                    Button {
                                        pick(slot, p)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Image(systemName: p.glyph)
                                                .font(.system(size: 14, weight: .semibold))
                                                .opacity(0.9)
                                            Text(p.name)
                                                .font(.system(size: 13.5, weight: on ? .semibold : .regular))
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Text(extra.isZero ? "included" : extra.formatted(showsSign: true))
                                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                                .moneyFigure()
                                                .opacity(0.8)
                                        }
                                        .padding(10)
                                        .frame(height: 88, alignment: .topLeading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(on ? .white : theme.ink)
                                        .background {
                                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                                .fill(on ? theme.accent : theme.surface)
                                                .overlay {
                                                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                                        .strokeBorder(on ? .clear : theme.hairline, lineWidth: 0.7)
                                                }
                                        }
                                        .opacity(p.isAvailable ? 1 : 0.5)
                                    }
                                    .posPress()
                                }
                            }
                        }
                    }

                    // The chosen item's own modifiers, in place, so "no pickles on the burger
                    // in the meal" does not need a second sheet.
                    if let pid = chosen[slot.id], let p = store.catalogue.product(pid), !p.groups.isEmpty {
                        ForEach(p.groups.prefix(3)) { group in
                            VStack(alignment: .leading, spacing: 7) {
                                PanelHeader("\(group.name) · \(p.name)")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4),
                                          spacing: 7) {
                                    ForEach(group.modifiers.prefix(8)) { mod in
                                        let on = (childMods[slot.id] ?? []).contains { $0.modifierID == mod.id }
                                        Button {
                                            toggleChild(slot, group, mod)
                                        } label: {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(mod.name)
                                                    .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                                                    .lineLimit(1)
                                                if !mod.price.isZero {
                                                    Text(mod.price.formatted(showsSign: true))
                                                        .font(.system(size: 11, design: .rounded))
                                                        .moneyFigure().opacity(0.8)
                                                }
                                            }
                                            .padding(.horizontal, 9)
                                            .frame(height: 42, alignment: .leading)
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
            }
            .padding(Metric.padLarge)
        }
        .frame(maxWidth: .infinity)
    }

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
                Text((comboTotal * quantity).formatted())
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .moneyFigure().foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
                Text(complete ? savingLine : "Every slot needs a choice")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(complete ? theme.inkSecondary : Palette.warn)
            }
            .animation(Motion.quick, value: comboTotal.cents)
            Spacer(minLength: 6)
            PrimaryAction(title: editingItemID == nil ? "Add" : "Save",
                          glyph: editingItemID == nil ? "plus" : "checkmark",
                          enabled: complete) { commit() }
                .frame(width: 220)
        }
    }

    private var complete: Bool { chosen.count == combo.slots.count }

    private var separateTotal: Money {
        combo.slots.compactMap { slot -> Money? in
            chosen[slot.id].flatMap { store.catalogue.product($0)?.price }
        }.total + childModTotal
    }

    private var comboTotal: Money {
        let upgrades = combo.slots.compactMap { slot -> Money? in
            chosen[slot.id].flatMap { slot.upgradePrices[$0] }
        }.total
        return combo.fixedPrice + upgrades + childModTotal
    }

    private var childModTotal: Money {
        childMods.values.flatMap { $0 }.map(\.total).total
    }

    private var saving: Money { max(.zero, separateTotal - comboTotal) }

    private var savingLine: String {
        saving.cents > 0 ? "save \(saving.formatted())" : "combo price"
    }

    private func prime() {
        if let id = editingItemID, let item = store.currentOrder?.items.first(where: { $0.id == id }) {
            for (i, slot) in combo.slots.enumerated() where item.comboChildren.indices.contains(i) {
                chosen[slot.id] = item.comboChildren[i].productID
                childMods[slot.id] = item.comboChildren[i].modifiers
            }
            quantity = item.quantity
            note = item.note ?? ""
        } else {
            for slot in combo.slots {
                if slot.productIDs.contains(seedProductID) {
                    chosen[slot.id] = seedProductID
                } else if let def = slot.defaultProductID {
                    chosen[slot.id] = def
                }
                if let pid = chosen[slot.id], let p = store.catalogue.product(pid) {
                    childMods[slot.id] = store.defaultModifiers(for: p)
                }
            }
        }
        activeSlot = combo.slots.first { chosen[$0.id] == nil }?.id ?? combo.slots.first?.id
    }

    private func pick(_ slot: ComboSlot, _ p: Product) {
        withAnimation(Motion.tap) {
            chosen[slot.id] = p.id
            childMods[slot.id] = store.defaultModifiers(for: p)
            if let next = combo.slots.first(where: { chosen[$0.id] == nil }) {
                activeSlot = next.id
            }
        }
    }

    private func toggleChild(_ slot: ComboSlot, _ group: ModifierGroup, _ mod: Modifier) {
        var mods = childMods[slot.id] ?? []
        if group.selection == .single { mods.removeAll { $0.groupID == group.id } }
        if let i = mods.firstIndex(where: { $0.modifierID == mod.id }) {
            mods.remove(at: i)
        } else {
            mods.append(SelectedModifier(groupID: group.id, groupName: group.name,
                                         modifierID: mod.id, name: mod.name, unitPrice: mod.price))
        }
        childMods[slot.id] = mods
    }

    private func commit() {
        guard let tile = store.catalogue.products.first(where: { $0.comboID == combo.id })
                ?? store.catalogue.product(seedProductID) else { return }
        let children: [OrderItem] = combo.slots.compactMap { slot in
            guard let pid = chosen[slot.id], let p = store.catalogue.product(pid) else { return nil }
            return OrderItem(productID: p.id, name: p.name, kitchenName: p.kitchenName,
                             unitPrice: slot.upgradePrices[pid] ?? .zero,
                             listPrice: p.price,
                             modifiers: childMods[slot.id] ?? [],
                             station: p.station, isDrink: p.isDrink)
        }
        if let id = editingItemID {
            store.mutateCurrent { o in
                guard let i = o.items.firstIndex(where: { $0.id == id }) else { return }
                o.items[i].comboChildren = children
                o.items[i].quantity = quantity
                if o.items[i].isSentOrLater {
                    o.items[i].sendRecords = []
                    o.items[i].status = .unsent
                }
            }
        } else {
            var seed = tile
            seed.price = combo.fixedPrice
            store.add(product: seed, quantity: quantity,
                      note: note.isEmpty ? nil : note,
                      comboName: combo.name,
                      comboChildren: children,
                      comboRule: combo.pricingRule)
        }
        store.route = nil
    }
}
