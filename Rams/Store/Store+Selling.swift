import SwiftUI

extension POSStore {

    // MARK: - Starting an order

    @discardableResult
    func newOrder(type: OrderType? = nil, table: FloorTable? = nil,
                  name: String? = nil, covers: Int? = nil) -> Order {
        var o = Order(number: nextOrderNumber,
                      type: type ?? profile.defaultOrderType)
        nextOrderNumber += 1
        o.openedBy = operatorStaff.initials
        o.waiter = profile.waiterAssignment ? operatorStaff.initials : nil
        o.name = name
        o.guestCount = covers
        o.courses = defaultCourses()
        if let t = table {
            o.tableID = t.id
            o.tableLabel = t.label
        }
        if profile.identifier == .token { o.token = nextToken; nextToken += 1 }
        if o.type.tracksFulfilment { o.fulfilment = .notStarted }
        o.timeline.append(AuditEntry(actor: operatorStaff.initials,
                                     text: "Order started", glyph: "plus.circle.fill"))
        orders.append(o)
        currentOrderID = o.id
        keypadPrefix = ""
        courseFilterID = o.courses.first?.id
        return o
    }

    func defaultCourses() -> [Course] {
        guard profile.coursesEnabled else { return [] }
        return profile.coursePlan.enumerated().map { i, name in
            Course(name: name, index: i,
                   autoFire: profile.autoFireCourses.contains(name),
                   isDessert: name.lowercased().contains("dessert"))
        }
    }

    func ensureOrder() -> Order {
        if let o = currentOrder, o.status.isEditable { return o }
        return newOrder()
    }

    func openOrder(_ id: UUID) {
        currentOrderID = id
        if let o = order(id) {
            courseFilterID = o.courses.first(where: { !o.items(inCourse: $0.id).isEmpty })?.id
                ?? o.courses.first?.id
        }
        surface = .sell
    }

    func closeCart() {
        currentOrderID = nil
        surface = profile.postSaleSurface
    }

    // MARK: - Adding

    /// The one entry point for putting something in the cart. Everything else calls this.
    func add(product: Product,
             variant: VariantOption? = nil,
             modifiers: [SelectedModifier] = [],
             quantity: Int = 1,
             note: String? = nil,
             seat: Int? = nil,
             courseID: UUID? = nil,
             portions: [PortionSelection] = [],
             comboName: String? = nil,
             comboChildren: [OrderItem] = [],
             comboRule: ComboPricingRule? = nil,
             openPrice: Money? = nil,
             weight: Double? = nil,
             source: String = "manual") {

        var order = ensureOrder()
        let priced = PricingEngine.price(product, variant: variant,
                                         in: catalogue, context: pricingContext)
        let course = courseID ?? defaultCourse(for: product, in: order)
        let unit = openPrice ?? priced.price

        var item = OrderItem(productID: product.id,
                             name: product.name,
                             kitchenName: product.kitchenName,
                             unitPrice: unit,
                             listPrice: priced.listPrice,
                             quantity: quantity,
                             variantLabel: variant?.label,
                             modifiers: modifiers,
                             portions: portions,
                             comboName: comboName,
                             comboChildren: comboChildren,
                             comboPricingRule: comboRule,
                             note: note,
                             seat: seat,
                             courseID: course,
                             station: product.station,
                             addedBy: operatorStaff.initials,
                             isDrink: product.isDrink,
                             ageRestricted: product.ageRestricted,
                             allergens: product.allergens + modifiers.flatMap { m in
                                 catalogue.products.first { $0.id == product.id }?
                                     .groups.flatMap(\.modifiers)
                                     .first { $0.id == m.modifierID }?.allergens ?? []
                             },
                             weight: weight,
                             source: source)

        // A course whose auto-fire is off lands the item Held, not Unsent. (Canonical §2.1)
        if let c = order.course(course), !c.autoFire {
            item.status = .held
        }
        // The pub rule: drinks are poured now, food goes to the kitchen.
        if profile.mapsDrinksToNow, product.isDrink,
           let drinks = order.courses.first(where: { $0.name == "Drinks" }) {
            item.courseID = drinks.id
            item.status = .unsent
        }
        if let reason = priced.reason {
            item.adjustments.append(Adjustment(kind: .promotion, name: reason,
                                               amount: priced.price - priced.listPrice,
                                               automatic: true))
            item.unitPrice = priced.listPrice
        }
        if order.status == .draft { order.status = .draft }

        // Identical unsent lines merge. Adding the same drink twice in two seconds is
        // quantity two on one line, not two lines.
        if let idx = order.items.firstIndex(where: {
            $0.mergeKey == item.mergeKey && $0.status == item.status && $0.isLive && !$0.isSentOrLater
        }) {
            order.items[idx].quantity += quantity
        } else {
            item.roundID = currentRoundID(for: order)
            order.items.append(item)
        }
        currentOrder = order
        rememberRecent(item)
        applyAutomaticAdjustments()
        if quantity >= profile.largeQuantityThreshold {
            toast(.warn, "Added \(quantity)× \(product.name)", detail: "Tap undo if that was a slip", undo: "Undo")
            undoStack.append((order: order, label: "\(quantity)× \(product.name)"))
        }
    }

    func defaultCourse(for product: Product, in order: Order) -> UUID? {
        guard profile.coursesEnabled, !order.courses.isEmpty else { return nil }
        if let hint = product.courseHint,
           let c = order.courses.first(where: { $0.name.lowercased() == hint.lowercased() }) {
            return c.id
        }
        if product.isDrink, let d = order.courses.first(where: { $0.name == "Drinks" }) {
            return d.id
        }
        if let filtered = courseFilterID, order.courses.contains(where: { $0.id == filtered }) {
            return filtered
        }
        return order.courses.first?.id
    }

    /// A round is derived from the Add-to-tab boundary, not stored as an entity. (A-W06-01)
    func currentRoundID(for order: Order) -> UUID? {
        guard profile.roundsEnabled else { return nil }
        if let open = order.liveItems.first(where: { !$0.isSentOrLater })?.roundID { return open }
        return UUID()
    }

    // MARK: - Editing a line

    func setQuantity(_ itemID: UUID, _ q: Int) {
        guard let id = currentOrderID else { return }
        if q <= 0 { removeItem(itemID); return }
        update(id) { o in
            guard let i = o.items.firstIndex(where: { $0.id == itemID }) else { return }
            o.items[i].quantity = q
        }
        applyAutomaticAdjustments()
    }

    func bump(_ itemID: UUID, by delta: Int) {
        guard let o = currentOrder, let item = o.items.first(where: { $0.id == itemID }) else { return }
        // Reducing a sent item is a void, and a void has a reason.
        if item.isSentOrLater && delta < 0 {
            route = .voidItem(itemID: itemID)
            return
        }
        setQuantity(itemID, item.quantity + delta)
    }

    /// Removing an unsent line is routine and undoable, so it is not confirmed. (W01.05)
    func removeItem(_ itemID: UUID) {
        guard let o = currentOrder, let item = o.items.first(where: { $0.id == itemID }) else { return }
        if item.isSentOrLater {
            route = .voidItem(itemID: itemID)
            return
        }
        snapshot("Removed \(item.name)")
        update(o.id) { ord in
            if let i = ord.items.firstIndex(where: { $0.id == itemID }) {
                ord.items[i].status = .cancelled
            }
        }
        applyAutomaticAdjustments()
        toast(.info, "Removed \(item.name)", undo: "Undo")
    }

    /// Voiding a sent item takes a reason and tells the kitchen. (W10.02, W10.03)
    func voidItem(_ itemID: UUID, reason: String, approvedBy: String?) {
        guard let o = currentOrder, let item = o.items.first(where: { $0.id == itemID }) else { return }
        update(o.id) { ord in
            if let i = ord.items.firstIndex(where: { $0.id == itemID }) {
                ord.items[i].status = .voided
                ord.items[i].voidReason = reason
            }
        }
        shift.voids = shift.voids + item.lineTotal
        raiseVoidDocket(order: o, item: item, reason: reason)
        log(o.id, "Voided \(item.quantity)× \(item.name) — \(reason)",
            glyph: "xmark.bin.fill", approvedBy: approvedBy, notable: true)
        applyAutomaticAdjustments()
        toast(.warn, "Voided \(item.name)", detail: "\(reason) · void docket to \(item.station)")
    }

    func setNote(_ itemID: UUID?, _ text: String) {
        guard let id = currentOrderID else { return }
        update(id) { o in
            if let itemID, let i = o.items.firstIndex(where: { $0.id == itemID }) {
                o.items[i].note = text.isEmpty ? nil : text
                // A note on a sent item is a change the kitchen has to be told about.
                if o.items[i].isSentOrLater { o.items[i].sendRecords = [] ; o.items[i].status = .unsent }
            } else {
                o.orderNote = text.isEmpty ? nil : text
            }
        }
    }

    func setSeat(_ itemID: UUID, _ seat: Int?) {
        guard let id = currentOrderID else { return }
        update(id) { o in
            if let i = o.items.firstIndex(where: { $0.id == itemID }) { o.items[i].seat = seat }
            o.seatCount = max(o.seatCount, seat ?? 0)
        }
    }

    func setCourse(_ itemID: UUID, _ courseID: UUID) {
        guard let id = currentOrderID, let o = order(id) else { return }
        let auto = o.course(courseID)?.autoFire ?? true
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].courseID = courseID
            if !ord.items[i].isSentOrLater {
                ord.items[i].status = auto ? .unsent : .held
            }
        }
    }

    /// Split a quantity off a line so two of the four can be modified. (W06.02.a)
    func splitQuantity(_ itemID: UUID, take: Int) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.items.first(where: { $0.id == itemID }), take < item.quantity else { return }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].quantity -= take
            var copy = item
            copy.id = UUID()
            copy.quantity = take
            copy.addedAt = .now
            ord.items.insert(copy, at: i + 1)
        }
        toast(.done, "Split \(take) off", detail: "Modify the new line on its own")
    }

    // MARK: - Recents and repeats

    private func rememberRecent(_ item: OrderItem) {
        guard profile.recentsEnabled else { return }
        var snap = item
        snap.id = UUID()
        snap.quantity = 1
        snap.status = .unsent
        snap.sendRecords = []
        snap.roundID = nil
        snap.adjustments = []
        recents.removeAll { $0.mergeKey == snap.mergeKey }
        recents.insert(snap, at: 0)
        if recents.count > 12 { recents.removeLast() }
    }

    /// One tap reproduces a whole configured drink. (W01.24, and the café's real speed win)
    func addRecent(_ snapshot: OrderItem) {
        guard let product = catalogue.product(snapshot.productID) else { return }
        var mods = snapshot.modifiers
        for i in mods.indices {
            let soldOut = product.groups.flatMap(\.modifiers)
                .first { $0.id == mods[i].modifierID }?.soldOut ?? false
            mods[i].soldOut = soldOut
        }
        add(product: product,
            variant: product.variants.first { $0.label == snapshot.variantLabel },
            modifiers: mods,
            note: snapshot.note,
            source: "recent")
        if mods.contains(where: \.soldOut) {
            toast(.warn, "One option is sold out", detail: "The line is marked; replace or keep it")
        }
    }

    /// "Same again." Repeat a round at today's prices, with discounts and comps not copied. (W06.03)
    func repeatRound(_ roundID: UUID) {
        guard let o = currentOrder else { return }
        let items = o.liveItems.filter { $0.roundID == roundID }
        guard !items.isEmpty else { return }
        let newRound = UUID()
        var changed = false
        var unavailable: [String] = []
        for item in items {
            guard let product = catalogue.product(item.productID) else { continue }
            if !product.isAvailable { unavailable.append(product.name); continue }
            let priced = PricingEngine.price(product,
                                             variant: product.variants.first { $0.label == item.variantLabel },
                                             in: catalogue, context: pricingContext)
            if priced.price != item.unitPrice { changed = true }
            var copy = item
            copy.id = UUID()
            copy.unitPrice = priced.price
            copy.listPrice = priced.listPrice
            copy.adjustments = []
            copy.status = .unsent
            copy.sendRecords = []
            copy.readyAt = nil
            copy.servedAt = nil
            copy.addedAt = .now
            copy.roundID = newRound
            copy.source = "repeat_round"
            mutateCurrent { $0.items.append(copy) }
        }
        lastRoundID = newRound
        var detail: [String] = []
        if changed { detail.append("Prices have changed since that round") }
        if !unavailable.isEmpty { detail.append("Sold out: \(unavailable.joined(separator: ", "))") }
        detail.append("Discounts and comps are not repeated")
        toast(.done, "Round repeated", detail: detail.joined(separator: " · "), undo: "Undo")
        snapshot("Repeat round")
        applyAutomaticAdjustments()
    }

    /// The last three completed orders on this device, for a walk-up with no tab. (W06.03)
    var repeatableOrders: [Order] {
        completedOrders.filter { !$0.liveItems.isEmpty }.prefix(3).map { $0 }
    }

    func repeatOrder(_ id: UUID) {
        guard let source = order(id) else { return }
        _ = ensureOrder()
        for item in source.liveItems {
            guard let product = catalogue.product(item.productID), product.isAvailable else { continue }
            add(product: product,
                variant: product.variants.first { $0.label == item.variantLabel },
                modifiers: item.modifiers,
                quantity: item.quantity,
                note: item.note,
                source: "repeat_order")
        }
        toast(.done, "Repeated \(source.identifierLabel)", detail: "Priced at today's prices")
    }

    /// A regular's usual, attached without an eight-second search. (W13.24)
    func addUsual(for customer: Customer) {
        _ = ensureOrder()
        mutateCurrent {
            $0.customerID = customer.id
            $0.customerName = customer.name
            if $0.name == nil, profile.identifier == .customerName { $0.name = customer.name.firstWord }
        }
        for name in customer.usualOrderProductNames {
            guard let p = catalogue.product(named: name) else { continue }
            var mods: [SelectedModifier] = []
            for g in p.groups where g.selection == .single {
                if let def = g.modifiers.first(where: \.isDefault) {
                    mods.append(SelectedModifier(groupID: g.id, groupName: g.name,
                                                 modifierID: def.id, name: def.name,
                                                 unitPrice: def.price,
                                                 changesTheMake: def.changesTheMake))
                }
            }
            add(product: p, variant: p.variants.first(where: \.isDefault), modifiers: mods, source: "usual")
        }
        toast(.done, "\(customer.name.firstWord)’s usual", detail: customer.usualOrderProductNames.joined(separator: " · "))
    }

    // MARK: - Automatic adjustments

    /// Order-level promotions, service charges and delivery fees are recomputed on every change,
    /// so the operator never has to remember to re-apply one.
    func applyAutomaticAdjustments() {
        guard let id = currentOrderID, let o = order(id) else { return }
        var manual = o.adjustments.filter { !$0.automatic }
        manual += PricingEngine.orderPromotions(for: o, catalogue: catalogue, context: pricingContext)
        if let sc = PricingEngine.serviceCharge(for: o, profile: profile),
           !o.adjustments.contains(where: { $0.kind == .serviceCharge && !$0.automatic }) {
            manual.append(sc)
        }
        if o.type == .delivery, let d = o.delivery, d.fee.cents > 0 {
            manual.append(Adjustment(kind: .deliveryFee, name: "Delivery — \(d.zone)",
                                     amount: d.fee, automatic: true))
        }
        update(id) { $0.adjustments = manual }
    }

    // MARK: - Search

    func searchResults() -> [Product] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        // A scanner is a keyboard wedge: an exact barcode match wins outright. (W21.08)
        if let exact = catalogue.products.first(where: { $0.barcode == q }) { return [exact] }
        return catalogue.products.filter {
            $0.name.lowercased().contains(q)
            || ($0.kitchenName?.lowercased().contains(q) ?? false)
            || (catalogue.category($0.categoryID)?.name.lowercased().contains(q) ?? false)
            || $0.groups.contains { g in g.modifiers.contains { $0.name.lowercased().contains(q) } }
        }
    }

    // MARK: - Availability

    func setSoldOut(_ productID: UUID, _ soldOut: Bool) {
        guard let i = catalogue.products.firstIndex(where: { $0.id == productID }) else { return }
        catalogue.products[i].soldOut = soldOut
        let name = catalogue.products[i].name
        // Unsent lines carrying it are marked rather than silently dropped. (W01.13)
        var affected = 0
        for o in orders where o.status.isLive {
            for item in o.liveItems where item.productID == productID && !item.isSentOrLater {
                affected += 1
            }
        }
        toast(soldOut ? .warn : .done,
              soldOut ? "\(name) sold out" : "\(name) back on",
              detail: affected > 0 ? "\(affected) line\(affected == 1 ? "" : "s") in flight are marked" : "Every device within the sync window")
    }

    func setModifierSoldOut(_ groupID: UUID, _ modifierID: UUID, _ soldOut: Bool) {
        for pi in catalogue.products.indices {
            for gi in catalogue.products[pi].groups.indices where catalogue.products[pi].groups[gi].id == groupID {
                for mi in catalogue.products[pi].groups[gi].modifiers.indices
                where catalogue.products[pi].groups[gi].modifiers[mi].id == modifierID {
                    catalogue.products[pi].groups[gi].modifiers[mi].soldOut = soldOut
                }
            }
        }
        // Mark every unsent line that carries it, on every order.
        for oi in orders.indices where orders[oi].status.isLive {
            for ii in orders[oi].items.indices where !orders[oi].items[ii].isSentOrLater {
                for mi in orders[oi].items[ii].modifiers.indices
                where orders[oi].items[ii].modifiers[mi].modifierID == modifierID {
                    orders[oi].items[ii].modifiers[mi].soldOut = soldOut
                }
            }
        }
    }
}

extension String {
    var firstWord: String { split(separator: " ").first.map(String.init) ?? self }
}
