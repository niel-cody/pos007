import SwiftUI

/// Launch-argument scripts that put the app straight into a named moment. Used to capture
/// screenshots and to open a demo on the exact screen you want to talk about:
///
///     xcrun simctl launch <device> com.oolio.rams --demo cafe-configure
extension POSStore {

    static func requestedScript() -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--demo"), args.count > i + 1 else { return nil }
        return args[i + 1]
    }

    func runScript(_ name: String) {
        switch name {

        case "cafe-configure":
            switchMode(.cafe)
            if let latte = catalogue.product(named: "Latte") {
                route = .configure(productID: latte.id, editing: nil)
            }

        case "cafe-cart":
            switchMode(.cafe)
            buildCafeOrder()

        case "cafe-payment":
            switchMode(.cafe)
            buildCafeOrder()
            if let id = currentOrderID { takeLock(id) }
            route = .payment

        case "cafe-queue":
            switchMode(.cafe)
            surface = .queue

        case "cafe-customer":
            switchMode(.cafe)
            _ = ensureOrder()
            route = .customers

        case "qsr-combo":
            switchMode(.qsr)
            if let combo = catalogue.combos.first,
               let tile = catalogue.products.first(where: { $0.comboID == combo.id }) {
                route = .combo(comboID: combo.id, productID: tile.id, editing: nil)
            }

        case "qsr-upsell":
            switchMode(.qsr)
            if let burger = catalogue.product(named: "Bolt Cheeseburger") {
                tapProduct(burger)
            }

        case "qsr-kitchen":
            switchMode(.qsr)
            surface = .kitchen

        case "pizza-half":
            switchMode(.pizza)
            if let combo = catalogue.combos.first(where: { $0.slots.count == 2 }) {
                route = .portions(comboID: combo.id, editing: nil)
            }

        case "pizza-half-built":
            switchMode(.pizza)
            buildHalfAndHalf()

        case "pizza-details":
            switchMode(.pizza)
            _ = ensureOrder()
            if let id = currentOrderID { setOrderType(id, .delivery) }
            route = .orderDetails

        case "bar-tabs":
            switchMode(.bar)
            surface = .tabs

        case "bar-round":
            switchMode(.bar)
            if let tab = openTabs.first(where: { $0.name == "Dave" }) ?? openTabs.first {
                openOrder(tab.id)
                if let round = order(tab.id)?.rounds.first { repeatRound(round.id) }
            }

        case "bar-round-build":
            switchMode(.bar)
            keypadPrefix = "4"
            if let ale = catalogue.product(named: "Pale Ale") { tapProduct(ale) }
            if let confirm = pendingConfirm { _ = confirm; resolveConfirm(true) }
            keypadPrefix = "2"
            if let red = catalogue.product(named: "House Rosé") { tapProduct(red) }

        case "bar-age":
            switchMode(.bar)
            if let ale = catalogue.product(named: "Pale Ale") {
                tapProduct(ale)
            }

        case "bar-open-tab":
            switchMode(.bar)
            route = .openTab

        case "pub-cart":
            switchMode(.pub)
            if let o = liveOrders.first(where: { $0.typedTableNumber == "24" }) {
                openOrder(o.id)
            }

        case "pub-steak":
            switchMode(.pub)
            if let steak = catalogue.product(named: "Rump Steak 300g") {
                route = .configure(productID: steak.id, editing: nil)
            }

        case "fs-floor":
            switchMode(.fullService)
            surface = .floor

        case "fs-fire":
            switchMode(.fullService)
            if let t4 = liveOrders.first(where: { $0.tableLabel == "4" }) {
                openOrder(t4.id)
                surface = .floor
            }

        case "fs-split":
            switchMode(.fullService)
            if let t2 = liveOrders.first(where: { $0.tableLabel == "2" }) {
                openOrder(t2.id)
                takeLock(t2.id)
                startSplit(.equal, count: 3)
                route = .split
            }

        case "fs-split-items":
            switchMode(.fullService)
            if let t2 = liveOrders.first(where: { $0.tableLabel == "2" }) {
                openOrder(t2.id)
                takeLock(t2.id)
                startSplit(.items)
                route = .split
            }

        case "fd-floor":
            switchMode(.fineDining)
            surface = .floor

        case "fd-courses":
            switchMode(.fineDining)
            if let t3 = liveOrders.first(where: { $0.tableLabel == "3" }) {
                openOrder(t3.id)
            }

        case "fd-kitchen":
            switchMode(.fineDining)
            surface = .kitchen

        case "takeaway-inbox":
            switchMode(.takeaway)
            surface = .online

        case "takeaway-shift":
            switchMode(.takeaway)
            surface = .shift

        case "orders":
            switchMode(.cafe)
            surface = .orders

        case "modes":
            route = .modes

        case "approval":
            switchMode(.pub)
            operatorStaff = staff.first { $0.role == .cashier } ?? operatorStaff
            if let o = liveOrders.first {
                openOrder(o.id)
                if let item = o.liveItems.first {
                    requireApproval(.voidSent, what: "Void \(item.name)",
                                    detail: "Sent to the grill 10 minutes ago",
                                    reasons: VoidReasons.sent) { _, _ in }
                }
            }

        case "printer-down":
            switchMode(.pub)
            if let i = stationDevices.firstIndex(where: { $0.name == "Grill" }) {
                stationDevices[i].online = false
            }
            if let steak = catalogue.product(named: "Rump Steak 300g") {
                _ = ensureOrder()
                add(product: steak, modifiers: defaultModifiers(for: steak))
                send()
            }

        case "lock":
            switchMode(.fullService)
            if let t4 = liveOrders.first(where: { $0.tableLabel == "4" }) {
                openOrder(t4.id)
                takeLockAsOther(t4.id)
            }

        case "help":
            route = .help

        default:
            break
        }
        toasts.removeAll()
    }

    private func buildCafeOrder() {
        _ = newOrder(type: .takeaway)
        guard let latte = catalogue.product(named: "Latte") else { return }
        var mods: [SelectedModifier] = []
        for group in latte.groups {
            switch group.name {
            case "Milk":
                if let m = Seed.selected(group, "Oat") { mods.append(m) }
            case "Shots":
                if let m = Seed.selected(group, "Extra shot") { mods.append(m) }
            case "Strength":
                if let m = Seed.selected(group, "Half strength") { mods.append(m) }
            case "Temperature":
                if let m = Seed.selected(group, "Extra hot") { mods.append(m) }
            case "Sugar":
                if let m = Seed.selected(group, "Sugar") { mods.append(m) }
            case "Syrup":
                if let m = Seed.selected(group, "Vanilla") { mods.append(m) }
            case "Cup":
                if let m = Seed.selected(group, "Takeaway cup") { mods.append(m) }
            default: break
            }
        }
        add(product: latte, variant: latte.variants.first { $0.label == "Large" },
            modifiers: mods)
        if let croissant = catalogue.product(named: "Almond Croissant") {
            add(product: croissant, quantity: 2)
        }
        if let roll = catalogue.product(named: "Bacon & Egg Roll") {
            add(product: roll, modifiers: defaultModifiers(for: roll), note: "no sauce")
        }
        upsell = nil
    }

    private func buildHalfAndHalf() {
        _ = newOrder(type: .delivery, name: "Delaney")
        guard let combo = catalogue.combos.first(where: { $0.slots.count == 2 }),
              let tile = catalogue.products.first(where: { $0.comboID == combo.id }),
              let margherita = catalogue.product(named: "Margherita"),
              let meat = catalogue.product(named: "Meat Lovers") else { return }
        let toppings = combo.sectionGroups.first
        var right = PortionSelection(slotName: "Right half", productID: meat.id,
                                     productName: meat.name,
                                     basePrice: meat.price + Money(4))
        if let g = toppings, var chilli = Seed.selected(g, "Chilli", portion: 0.5) {
            chilli.unitPrice = Money(cents: chilli.unitPrice.cents / 2)
            right.modifiers = [chilli]
        }
        let left = PortionSelection(slotName: "Left half", productID: margherita.id,
                                    productName: margherita.name,
                                    basePrice: margherita.price + Money(4))
        var whole: [SelectedModifier] = []
        for g in combo.wholeGroups {
            if let m = g.modifiers.first(where: \.isDefault) {
                whole.append(SelectedModifier(groupID: g.id, groupName: g.name,
                                              modifierID: m.id, name: m.name, unitPrice: m.price))
            }
        }
        add(product: tile, modifiers: whole, portions: [left, right],
            comboName: "Half & Half 13\"", comboRule: .highest)
        if let bread = catalogue.product(named: "Garlic Bread") {
            add(product: bread, modifiers: defaultModifiers(for: bread))
        }
        if let coke = catalogue.product(named: "Coke 1.25L") {
            add(product: coke)
        }
        upsell = nil
    }
}
