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
        // Only a genuinely forced choice stops the sale. Everything else is added with its
        // defaults and changed on the line, which is where the guest's change actually arrives.
        if product.requiresChoice {
            route = .configure(productID: product.id, editing: nil)
            return
        }
        add(product: product,
            variant: product.variants.first(where: \.isDefault) ?? product.variants.first,
            modifiers: defaultModifiers(for: product),
            quantity: qty)
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
                                             wasDefault: true,
                                             changesTheMake: m.changesTheMake))
            }
        }
        return mods
    }

    // MARK: - Cart grouping
    //
    // A round is what the customer thinks in; a course is what the kitchen thinks in. The
    // cart groups by whichever the venue runs, and by nothing at all where it runs neither.

    /// The venue's default view of the cart, and the pivots it offers. Fine dining reads by
    /// seat when the bill is split and by course when the meal is paced; a QSR packs by
    /// bundle; a bar thinks in rounds.
    var defaultGrouping: CartGrouping {
        if profile.seatsEnabled { return .course }
        if profile.coursesEnabled { return .course }
        if profile.roundsEnabled { return .round }
        if catalogue.combos.contains(where: { $0.kind == .meal }) { return .bundle }
        return .order
    }

    var availableGroupings: [CartGrouping] {
        var out: [CartGrouping] = [.order]
        if profile.coursesEnabled { out.insert(.course, at: 0) }
        if profile.seatsEnabled { out.append(.seat) }
        if profile.roundsEnabled { out.insert(.round, at: 0) }
        if catalogue.combos.contains(where: { $0.kind == .meal }) { out.append(.bundle) }
        return out
    }

    var grouping: CartGrouping {
        get { cartGrouping ?? defaultGrouping }
        set { cartGrouping = newValue }
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
