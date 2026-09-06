import SwiftUI

extension POSStore {

    /// Tapping a tile. One tap adds a product with no choices; a product with choices opens
    /// one sheet with every group on it. Nothing takes two taps that could take one.
    func tapProduct(_ product: Product, skipUpsell: Bool = false) {
        let qty = Int(keypadPrefix) ?? 1
        keypadPrefix = ""

        // Age-restricted stock is confirmed once per order: asking on every round is how a
        // confirmation stops being read.
        if product.ageRestricted, !(currentOrder?.ageChecked ?? false) {
            let o = ensureOrder()
            confirm(ConfirmRequest(title: "Check ID",
                                   message: "\(product.name) is age restricted. Confirm the guest is over 18 — this is recorded against the order.",
                                   confirmTitle: "Over 18, add it",
                                   glyph: "person.badge.shield.checkmark.fill")) { [weak self] in
                guard let self else { return }
                self.update(o.id) { $0.ageChecked = true }
                self.log(o.id, "ID checked for age-restricted sale", glyph: "person.badge.shield.checkmark.fill")
                self.keypadPrefix = String(qty == 1 ? "" : "\(qty)")
                self.tapProduct(product, skipUpsell: skipUpsell)
            }
            return
        }

        guard product.isAvailable else {
            // Sold out is a choice, not a wall: add anyway, or pick something else.
            toast(.warn, "\(product.name) is sold out",
                  detail: "Long press to add anyway if the kitchen says yes")
            return
        }

        if let comboID = product.comboID, let combo = catalogue.combo(comboID) {
            route = combo.kind == .portion
                ? .portions(comboID: comboID, editing: nil)
                : .combo(comboID: comboID, productID: product.id, editing: nil)
            return
        }
        if product.openPriced {
            route = .openPrice(productID: product.id)
            return
        }
        // A required choice always opens the sheet. An optional one opens it only where the
        // venue's modifiers are the interface.
        if product.requiresChoice || (product.hasChoices && profile.tapConfigures) {
            route = .configure(productID: product.id, editing: nil)
            return
        }
        add(product: product,
            variant: product.variants.first(where: \.isDefault) ?? product.variants.first,
            modifiers: defaultModifiers(for: product),
            quantity: qty)
        if !skipUpsell { offerUpsell(for: product) }
    }

    /// Long press is an accelerator and never the only route: it adds with defaults and
    /// skips the upsell for an operator who already knows the answer.
    func longPressProduct(_ product: Product) {
        let qty = Int(keypadPrefix) ?? 1
        keypadPrefix = ""
        add(product: product,
            variant: product.variants.first(where: \.isDefault) ?? product.variants.first,
            modifiers: defaultModifiers(for: product),
            quantity: qty)
        if !product.isAvailable {
            toast(.warn, "Added \(product.name) while sold out", detail: "Tell the kitchen")
        }
    }

    func defaultModifiers(for product: Product) -> [SelectedModifier] {
        var mods: [SelectedModifier] = []
        for g in product.groups {
            for m in g.modifiers where m.isDefault {
                mods.append(SelectedModifier(groupID: g.id, groupName: g.name, modifierID: m.id,
                                             name: m.name, unitPrice: m.price,
                                             changesTheMake: m.changesTheMake))
            }
        }
        return mods
    }

    /// The offer is a strip, never a dialog: it disappears the moment the operator moves on.
    func offerUpsell(for product: Product) {
        guard profile.upsellEnabled else { return }
        if let comboID = product.upsellComboIDs.first, let combo = catalogue.combo(comboID) {
            let single = product.price
            let sides = combo.slots.dropFirst().compactMap { slot -> Money? in
                slot.defaultProductID.flatMap { catalogue.product($0)?.price }
            }.total
            let saving = (single + sides) - combo.fixedPrice
            upsell = UpsellOffer(title: combo.name,
                                 detail: "\((combo.fixedPrice - single).formatted()) more, save \(saving.formatted())",
                                 comboID: comboID, productID: product.id)
        } else if let modName = product.upsellModifierNames.first,
                  let group = product.groups.first(where: { $0.modifiers.contains { $0.name == modName } }),
                  let mod = group.modifiers.first(where: { $0.name == modName }) {
            upsell = UpsellOffer(title: "Add \(mod.name)",
                                 detail: mod.price.isZero ? "No charge" : "+\(mod.price.formatted())",
                                 comboID: nil, productID: product.id,
                                 groupID: group.id, modifierID: mod.id,
                                 modifierName: mod.name, modifierPrice: mod.price)
        }
        clearUpsellSoon()
    }

    func clearUpsellSoon() {
        let token = upsell?.id
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(7))
            if upsell?.id == token { upsell = nil }
        }
    }

    func acceptUpsell() {
        guard let offer = upsell else { return }
        upsell = nil
        if let comboID = offer.comboID {
            route = .combo(comboID: comboID, productID: offer.productID, editing: nil)
            return
        }
        guard let id = currentOrderID, let o = order(id),
              let last = o.liveItems.last(where: { $0.productID == offer.productID }),
              let gid = offer.groupID, let mid = offer.modifierID else { return }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == last.id }) else { return }
            ord.items[i].modifiers.append(SelectedModifier(groupID: gid, groupName: "Add",
                                                           modifierID: mid,
                                                           name: offer.modifierName ?? "",
                                                           unitPrice: offer.modifierPrice ?? .zero))
        }
        toast(.done, "Added \(offer.modifierName ?? "")")
    }

    // MARK: - Cart grouping
    //
    // A round is what the customer thinks in; a course is what the kitchen thinks in. The
    // cart groups by whichever the venue runs, and by nothing at all where it runs neither.

    enum CartGrouping { case flat, courses, rounds }

    var grouping: CartGrouping {
        if profile.coursesEnabled { return .courses }
        if profile.roundsEnabled { return .rounds }
        return .flat
    }

    // MARK: - Favourites and quick adds

    var favourites: [Product] {
        catalogue.products.filter(\.favourite)
    }

    var gridProducts: [Product] {
        if !searchText.isEmpty { return searchResults() }
        guard let cid = selectedCategoryID else { return catalogue.products }
        return catalogue.products(in: cid)
    }
}

struct UpsellOffer: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var detail: String
    var comboID: UUID?
    var productID: UUID
    var groupID: UUID?
    var modifierID: UUID?
    var modifierName: String?
    var modifierPrice: Money?
}
