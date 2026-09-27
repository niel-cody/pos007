import SwiftUI

/// A one-tap change to the line that is currently selected.
struct QuickChip: Identifiable, Equatable {
    enum Kind: Equatable {
        case variant(String)
        case modifier(groupID: UUID, modifierID: UUID)
        case swapIn(groupID: UUID, modifierID: UUID)
        case makeItAMeal(comboID: UUID)
        case revertMeal
        case swapSlot(index: Int)
        case upsizeSlot(index: Int, productID: UUID)
        case more
    }

    enum Tone { case neutral, on, offer, swap }

    var id: String
    var title: String
    var detail: String?
    var kind: Kind
    var tone: Tone = .neutral
    var glyph: String?
}

extension POSStore {

    // MARK: - Selection
    //
    // Adding a line selects it, so the next thing the guest says has somewhere to land.

    func select(_ itemID: UUID?) {
        selectedLineID = itemID
    }

    var selectedLine: OrderItem? {
        guard let id = selectedLineID else { return nil }
        return currentOrder?.liveItems.first { $0.id == id }
    }

    // MARK: - The chips
    //
    // "Cheeseburger. Make it a meal. Large fries. No pickles. Shake instead of the coke."
    // Every sentence in that is one tap, in place, with nothing reopened and nothing rebuilt.

    func quickChips(for item: OrderItem) -> [QuickChip] {
        guard let product = catalogue.product(item.productID) else { return [] }
        var chips: [QuickChip] = []

        // The meal comes first, because it is the change worth the most and the one the guest
        // asks for most often.
        if item.comboChildren.isEmpty, let comboID = product.upsellComboIDs.first,
           let combo = catalogue.combo(comboID) {
            let extra = combo.fixedPrice - product.price
            chips.append(QuickChip(id: "meal",
                                   title: "Make it a meal",
                                   detail: extra.formatted(showsSign: true),
                                   kind: .makeItAMeal(comboID: comboID),
                                   tone: .offer,
                                   glyph: "takeoutbag.and.cup.and.straw.fill"))
        }

        // Once it is a meal, the slots become the conversation: upsize the side, swap the drink.
        if !item.comboChildren.isEmpty, let combo = comboForMeal(item) {
            for (index, slot) in combo.slots.enumerated() where index > 0 {
                guard item.comboChildren.indices.contains(index) else { continue }
                chips.append(QuickChip(id: "swap\(index)",
                                       title: "Swap \(slot.name.lowercased())",
                                       detail: item.comboChildren[index].name,
                                       kind: .swapSlot(index: index),
                                       tone: .swap,
                                       glyph: "arrow.left.arrow.right"))
            }
            for (index, _) in combo.slots.enumerated() where index > 0 {
                guard item.comboChildren.indices.contains(index),
                      item.comboChildren[index].variantLabel == nil,
                      let child = catalogue.product(item.comboChildren[index].productID),
                      let large = child.variants.first(where: { !$0.isDefault && $0.priceDelta.cents > 0 })
                else { continue }
                chips.append(QuickChip(id: "up\(index)",
                                       title: "\(large.label) \(child.name.lowercased())",
                                       detail: large.priceDelta.formatted(showsSign: true),
                                       kind: .upsizeSlot(index: index, productID: child.id),
                                       glyph: "arrow.up.right"))
            }
            chips.append(QuickChip(id: "unmeal",
                                   title: "Just the \(product.name.split(separator: " ").last.map(String.init)?.lowercased() ?? "item")",
                                   detail: (product.price - item.unitPrice).formatted(showsSign: true),
                                   kind: .revertMeal,
                                   glyph: "arrow.uturn.backward"))
        }

        // A swap group replaces the house pour and reprices, so it reads as an upgrade.
        for group in product.groups where group.isSwap {
            for mod in group.modifiers where !mod.isDefault {
                let on = item.modifiers.contains { $0.modifierID == mod.id }
                chips.append(QuickChip(id: "swap-\(mod.id)",
                                       title: mod.name,
                                       detail: mod.price.formatted(showsSign: true),
                                       kind: .swapIn(groupID: group.id, modifierID: mod.id),
                                       tone: on ? .on : .swap,
                                       glyph: on ? "checkmark" : nil))
            }
        }

        // Size, where the venue does not force it at add time.
        if !product.variants.isEmpty {
            for variant in product.variants where variant.label != (item.variantLabel ?? "") {
                chips.append(QuickChip(id: "v-\(variant.id)",
                                       title: variant.label,
                                       detail: (variant.priceDelta - currentVariantDelta(item, product)).formatted(showsSign: true),
                                       kind: .variant(variant.label)))
            }
        }

        // Then the changes this venue actually makes, in the order it makes them.
        chips.append(contentsOf: authoredChips(product: product, item: item))

        chips.append(QuickChip(id: "more", title: "More", kind: .more,
                               glyph: "slider.horizontal.3"))
        return chips
    }

    private func currentVariantDelta(_ item: OrderItem, _ product: Product) -> Money {
        product.variants.first { $0.label == item.variantLabel }?.priceDelta ?? .zero
    }

    /// The venue's own list first; otherwise the offered groups' non-default options.
    private func authoredChips(product: Product, item: OrderItem) -> [QuickChip] {
        var out: [QuickChip] = []
        var seen = Set<UUID>()

        func chip(_ group: ModifierGroup, _ mod: Modifier) -> QuickChip {
            let on = item.modifiers.contains { $0.modifierID == mod.id && !$0.isRemoval }
            let quantity = item.modifiers.first { $0.modifierID == mod.id }?.quantity ?? 0
            return QuickChip(id: "m-\(mod.id)",
                             title: quantity > 1 ? "\(quantity)× \(mod.name)" : mod.name,
                             detail: mod.price.isZero ? nil : mod.price.formatted(showsSign: true),
                             kind: .modifier(groupID: group.id, modifierID: mod.id),
                             tone: on ? .on : .neutral,
                             glyph: on ? "checkmark" : nil)
        }

        if !product.quickActions.isEmpty {
            for name in product.quickActions {
                for group in product.groups where !group.isSwap {
                    guard let mod = group.modifiers.first(where: { $0.name == name }),
                          !seen.contains(mod.id) else { continue }
                    seen.insert(mod.id)
                    out.append(chip(group, mod))
                }
            }
            return out
        }

        for group in product.groups where group.policy == .offered && !group.isSwap {
            let candidates = group.modifiers.filter { !$0.isDefault && !$0.soldOut }
            for mod in candidates.prefix(group.selection == .quantity ? 1 : 3) {
                guard !seen.contains(mod.id) else { continue }
                seen.insert(mod.id)
                out.append(chip(group, mod))
            }
            if out.count >= 6 { break }
        }
        return out
    }

    func comboForMeal(_ item: OrderItem) -> Combo? {
        guard let name = item.comboName else { return nil }
        return catalogue.combos.first { $0.name == name }
    }

    // MARK: - Applying a chip

    func apply(_ chip: QuickChip, to itemID: UUID) {
        switch chip.kind {
        case .variant(let label):
            setVariant(itemID, label: label)
        case .modifier(let groupID, let modifierID):
            toggleModifier(itemID, groupID: groupID, modifierID: modifierID)
        case .swapIn(let groupID, let modifierID):
            swapIn(itemID, groupID: groupID, modifierID: modifierID)
        case .makeItAMeal(let comboID):
            makeItAMeal(itemID, comboID: comboID)
        case .revertMeal:
            revertMeal(itemID)
        case .upsizeSlot(let index, _):
            upsizeSlot(itemID, index: index)
        case .swapSlot:
            break   // the view opens a menu for this one
        case .more:
            openConfiguration(for: itemID)
        }
    }

    func openConfiguration(for itemID: UUID) {
        guard let item = currentOrder?.liveItems.first(where: { $0.id == itemID }),
              let product = catalogue.product(item.productID) else { return }
        if !item.portions.isEmpty, let combo = catalogue.combos.first(where: { $0.kind == .portion }) {
            route = .portions(comboID: combo.id, editing: item.id)
        } else if let combo = comboForMeal(item) {
            route = .combo(comboID: combo.id, productID: product.id, editing: item.id)
        } else {
            route = .configure(productID: product.id, editing: item.id)
        }
    }

    // MARK: - The individual changes

    func setVariant(_ itemID: UUID, label: String) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              let product = catalogue.product(item.productID),
              let variant = product.variants.first(where: { $0.label == label }) else { return }
        let priced = PricingEngine.price(product, variant: variant, in: catalogue, context: pricingContext)
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].variantLabel = label
            ord.items[i].unitPrice = priced.price
            ord.items[i].listPrice = priced.listPrice
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
    }

    func toggleModifier(_ itemID: UUID, groupID: UUID, modifierID: UUID) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              let product = catalogue.product(item.productID),
              let group = product.groups.first(where: { $0.id == groupID }),
              let mod = group.modifiers.first(where: { $0.id == modifierID }) else { return }

        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            if let existing = ord.items[i].modifiers.firstIndex(where: { $0.modifierID == modifierID }) {
                switch group.selection {
                case .quantity where ord.items[i].modifiers[existing].quantity < mod.maxPerOption:
                    ord.items[i].modifiers[existing].quantity += 1
                default:
                    if mod.isDefault {
                        ord.items[i].modifiers[existing].isRemoval.toggle()
                    } else {
                        ord.items[i].modifiers.remove(at: existing)
                    }
                }
            } else {
                if group.selection == .single {
                    ord.items[i].modifiers.removeAll { $0.groupID == groupID }
                }
                ord.items[i].modifiers.append(
                    SelectedModifier(groupID: groupID, groupName: group.name,
                                     modifierID: mod.id, name: mod.name,
                                     unitPrice: mod.price, soldOut: mod.soldOut,
                                     changesTheMake: mod.changesTheMake))
            }
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
    }

    /// A swap replaces the house pour rather than adding to it, and the line renames itself so
    /// the bartender and the docket both say what is actually going in the glass.
    func swapIn(_ itemID: UUID, groupID: UUID, modifierID: UUID) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              let product = catalogue.product(item.productID),
              let group = product.groups.first(where: { $0.id == groupID }),
              let mod = group.modifiers.first(where: { $0.id == modifierID }) else { return }
        let alreadyOn = item.modifiers.contains { $0.modifierID == modifierID }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].modifiers.removeAll { $0.groupID == groupID }
            if !alreadyOn {
                ord.items[i].modifiers.append(
                    SelectedModifier(groupID: groupID, groupName: group.name,
                                     modifierID: mod.id, name: mod.name, unitPrice: mod.price))
            }
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
        if !alreadyOn {
            toast(.done, "\(mod.name) \(product.name.lowercased())",
                  detail: "\(mod.price.formatted(showsSign: true)) · the docket says which spirit")
        }
    }

    /// The burger becomes a meal without leaving the order. Its own modifiers survive, because
    /// "no pickles" was said before "make it a meal" and the guest should not have to repeat it.
    func makeItAMeal(_ itemID: UUID, comboID: UUID) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              let combo = catalogue.combo(comboID) else { return }

        var children: [OrderItem] = []
        for (index, slot) in combo.slots.enumerated() {
            if index == 0 {
                // The first slot is the thing already on the line.
                children.append(OrderItem(productID: item.productID, name: item.name,
                                          unitPrice: .zero, listPrice: item.listPrice,
                                          station: item.station))
                continue
            }
            guard let pid = slot.defaultProductID, let p = catalogue.product(pid) else { continue }
            children.append(OrderItem(productID: p.id, name: p.name, kitchenName: p.kitchenName,
                                      unitPrice: slot.upgradePrices[pid] ?? .zero,
                                      listPrice: p.price,
                                      modifiers: defaultModifiers(for: p),
                                      station: p.station, isDrink: p.isDrink))
        }

        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].comboName = combo.name
            ord.items[i].comboChildren = children
            ord.items[i].comboPricingRule = combo.pricingRule
            ord.items[i].unitPrice = combo.fixedPrice
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
        let side = children.dropFirst().map(\.name).joined(separator: " and ")
        toast(.done, "Made it a meal", detail: side.isEmpty ? nil : "with \(side)", undo: "Undo")
        undoStack.append((order: o, label: "Make it a meal"))
    }

    func revertMeal(_ itemID: UUID) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              let product = catalogue.product(item.productID) else { return }
        let priced = PricingEngine.price(product,
                                         variant: product.variants.first { $0.label == item.variantLabel },
                                         in: catalogue, context: pricingContext)
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].comboName = nil
            ord.items[i].comboChildren = []
            ord.items[i].comboPricingRule = nil
            ord.items[i].unitPrice = priced.price
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
        toast(.info, "Back to just the \(product.name.lowercased())", undo: "Undo")
        undoStack.append((order: o, label: "Revert the meal"))
    }

    func swapSlot(_ itemID: UUID, index: Int, to productID: UUID) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              let combo = comboForMeal(item),
              combo.slots.indices.contains(index),
              let p = catalogue.product(productID) else { return }
        let slot = combo.slots[index]
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }),
                  ord.items[i].comboChildren.indices.contains(index) else { return }
            ord.items[i].comboChildren[index] = OrderItem(
                productID: p.id, name: p.name, kitchenName: p.kitchenName,
                unitPrice: slot.upgradePrices[productID] ?? .zero,
                listPrice: p.price,
                modifiers: defaultModifiers(for: p),
                station: p.station, isDrink: p.isDrink)
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
        let extra = slot.upgradePrices[productID] ?? .zero
        toast(.done, "\(p.name) instead",
              detail: extra.isZero ? "No change to the price" : extra.formatted(showsSign: true))
    }

    func upsizeSlot(_ itemID: UUID, index: Int) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }),
              item.comboChildren.indices.contains(index),
              let p = catalogue.product(item.comboChildren[index].productID),
              let large = p.variants.first(where: { !$0.isDefault && $0.priceDelta.cents > 0 }) else { return }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }),
                  ord.items[i].comboChildren.indices.contains(index) else { return }
            ord.items[i].comboChildren[index].variantLabel = large.label
            ord.items[i].comboChildren[index].unitPrice =
                ord.items[i].comboChildren[index].unitPrice + large.priceDelta
            markChanged(&ord.items[i])
        }
        applyAutomaticAdjustments()
        toast(.done, "\(large.label) \(p.name.lowercased())", detail: large.priceDelta.formatted(showsSign: true))
    }

    /// A change to something the kitchen already has means the kitchen has to be told again.
    private func markChanged(_ item: inout OrderItem) {
        if item.isSentOrLater {
            item.sendRecords = []
            item.status = .unsent
        }
    }

    /// Options for a slot, for the swap menu.
    func slotOptions(_ item: OrderItem, index: Int) -> [(Product, Money)] {
        guard let combo = comboForMeal(item), combo.slots.indices.contains(index) else { return [] }
        let slot = combo.slots[index]
        return slot.productIDs.compactMap { pid in
            guard let p = catalogue.product(pid) else { return nil }
            return (p, slot.upgradePrices[pid] ?? .zero)
        }
    }
}
