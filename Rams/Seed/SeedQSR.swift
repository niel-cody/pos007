import Foundation

/// Bolt Burger — a QSR outlet measured on speed of service, with combos, upsells, token
/// numbers and four kitchen screens. The combo is the interface here.
enum QSRSeed {
    static func build() -> SeedBundle {
        let burgers = Category(name: "Burgers", glyph: "flame.fill", accent: 0)
        let chicken = Category(name: "Chicken", glyph: "bird.fill", accent: 1)
        let sides = Category(name: "Sides", glyph: "takeoutbag.and.cup.and.straw.fill", accent: 2)
        let drinks = Category(name: "Drinks", glyph: "cup.and.straw.fill", accent: 6)
        let sweets = Category(name: "Sweet", glyph: "birthday.cake.fill", accent: 9)

        let cook = Seed.group("Cook", .single, min: 1, max: 1, [
            Seed.mod("Standard", def: true), Seed.mod("Well done"), Seed.mod("No pink")
        ])
        let remove = Seed.group("Hold", .multi, [
            Seed.mod("No pickles"), Seed.mod("No onion"), Seed.mod("No sauce"),
            Seed.mod("No cheese"), Seed.mod("No lettuce"), Seed.mod("No tomato")
        ])
        let addOns = Seed.group("Add", .multi, [
            Seed.mod("Extra patty", 4.50, pinned: true), Seed.mod("Bacon", 2.50, pinned: true),
            Seed.mod("Cheese slice", 1.20, pinned: true), Seed.mod("Jalapeños", 1.00),
            Seed.mod("Fried egg", 2.00, allergens: ["Egg"]), Seed.mod("Avocado", 3.00),
            Seed.mod("Onion rings", 2.50)
        ])
        let sauce = Seed.group("Sauce", .multi, max: 2, [
            Seed.mod("Bolt sauce", pinned: true), Seed.mod("BBQ", pinned: true),
            Seed.mod("Aioli"), Seed.mod("Chipotle"), Seed.mod("Mustard"), Seed.mod("Extra sauce", 0.80)
        ])
        let bun = Seed.group("Bun", .single, min: 1, max: 1, [
            Seed.mod("Milk bun", def: true), Seed.mod("Sesame"),
            Seed.mod("Gluten free", 2.00), Seed.mod("Lettuce wrap")
        ])

        var cheeseburger = Product(name: "Bolt Cheeseburger", price: Money(11.90), categoryID: burgers.id,
                                   station: "Grill", glyph: "flame.fill", accent: 0,
                                   groups: [bun, cook, sauce, addOns, remove],
                                   allergens: ["Gluten", "Dairy"], favourite: true)
        var doubleB = Product(name: "Double Bolt", price: Money(15.90), categoryID: burgers.id,
                              station: "Grill", glyph: "flame.circle.fill", accent: 0,
                              groups: [bun, cook, sauce, addOns, remove],
                              allergens: ["Gluten", "Dairy"], favourite: true)
        var chickenB = Product(name: "Crispy Chicken", price: Money(13.90), categoryID: chicken.id,
                               station: "Fryer", glyph: "bird.fill", accent: 1,
                               groups: [bun, sauce, addOns, remove], allergens: ["Gluten"], favourite: true)
        let veg = Product(name: "Garden Burger", price: Money(13.50), categoryID: burgers.id,
                          station: "Grill", glyph: "leaf.fill", accent: 4,
                          groups: [bun, sauce, addOns, remove], allergens: ["Gluten"])
        let wings = Product(name: "Wings 6pc", price: Money(12.50), categoryID: chicken.id,
                            station: "Fryer", glyph: "flame", accent: 1,
                            groups: [Seed.group("Toss", .single, min: 1, max: 1, [
                                Seed.mod("Buffalo", def: true), Seed.mod("BBQ"), Seed.mod("Salt & pepper"), Seed.mod("Hot honey")
                            ])])
        let tenders = Product(name: "Tenders 4pc", price: Money(11.00), categoryID: chicken.id,
                              station: "Fryer", glyph: "rectangle.stack.fill", accent: 2)

        let fries = Product(name: "Fries", price: Money(5.50), categoryID: sides.id, station: "Fryer",
                            glyph: "takeoutbag.and.cup.and.straw.fill", accent: 2,
                            variantAxisName: "Size",
                            variants: Seed.variants([("Regular", 0, true), ("Large", 1.60, false)]),
                            groups: [Seed.group("Style", .single, min: 0, max: 1, [
                                Seed.mod("Salted", def: true), Seed.mod("Chicken salt"), Seed.mod("Loaded", 4.00)
                            ])], favourite: true)
        let rings = Product(name: "Onion Rings", price: Money(6.50), categoryID: sides.id,
                            station: "Fryer", glyph: "circle.circle.fill", accent: 3)
        let slaw = Product(name: "Slaw", price: Money(4.50), categoryID: sides.id,
                           station: "Grill", glyph: "leaf.circle.fill", accent: 4)
        let nuggets = Product(name: "Nuggets 6pc", price: Money(7.50), categoryID: sides.id,
                              station: "Fryer", glyph: "square.grid.3x3.fill", accent: 1)

        let coke = Product(name: "Coke", price: Money(4.50), categoryID: drinks.id, station: "Drinks",
                           glyph: "takeoutbag.and.cup.and.straw.fill", accent: 6,
                           variantAxisName: "Size",
                           variants: Seed.variants([("Regular", 0, true), ("Large", 0.90, false)]),
                           isDrink: true, favourite: true)
        let coke0 = Product(name: "Coke No Sugar", price: Money(4.50), categoryID: drinks.id,
                            station: "Drinks", glyph: "cup.and.straw", accent: 6,
                            variantAxisName: "Size",
                            variants: Seed.variants([("Regular", 0, true), ("Large", 0.90, false)]), isDrink: true)
        let lemonade = Product(name: "Lemonade", price: Money(4.50), categoryID: drinks.id,
                               station: "Drinks", glyph: "cup.and.straw.fill", accent: 5, isDrink: true)
        let water = Product(name: "Water", price: Money(3.50), categoryID: drinks.id,
                            station: "Drinks", glyph: "waterbottle.fill", accent: 7, isDrink: true)
        let shake = Product(name: "Thick Shake", price: Money(8.50), categoryID: drinks.id,
                            station: "Drinks", glyph: "tornado", accent: 9,
                            groups: [Seed.group("Flavour", .single, min: 1, max: 1, [
                                Seed.mod("Chocolate", def: true), Seed.mod("Vanilla"),
                                Seed.mod("Strawberry"), Seed.mod("Salted caramel")
                            ])], isDrink: true)
        let sundae = Product(name: "Sundae", price: Money(6.00), categoryID: sweets.id,
                             station: "Drinks", glyph: "cone.fill", accent: 9,
                             groups: [Seed.group("Topping", .single, min: 1, max: 1, [
                                 Seed.mod("Chocolate", def: true), Seed.mod("Caramel"), Seed.mod("Strawberry")
                             ])])
        let cookie = Product(name: "Cookie", price: Money(4.00), categoryID: sweets.id,
                             station: "Drinks", glyph: "circle.fill", accent: 1)

        // The meal: a main slot, a side slot and a drink slot, with upgrade prices on the swaps.
        let mealCombo = Combo(name: "Make it a meal", kind: .meal,
                              slots: [
                                ComboSlot(name: "Burger",
                                          productIDs: [cheeseburger.id, doubleB.id, chickenB.id, veg.id],
                                          defaultProductID: cheeseburger.id,
                                          upgradePrices: [doubleB.id: Money(4.00),
                                                          chickenB.id: Money(2.00),
                                                          veg.id: Money(1.60)]),
                                ComboSlot(name: "Side",
                                          productIDs: [fries.id, rings.id, slaw.id, nuggets.id],
                                          defaultProductID: fries.id,
                                          upgradePrices: [rings.id: Money(1.50), nuggets.id: Money(2.00)]),
                                ComboSlot(name: "Drink",
                                          productIDs: [coke.id, coke0.id, lemonade.id, water.id, shake.id],
                                          defaultProductID: coke.id,
                                          upgradePrices: [shake.id: Money(3.50)])
                              ],
                              pricingRule: .fixed, fixedPrice: Money(18.90))

        cheeseburger.upsellComboIDs = [mealCombo.id]
        doubleB.upsellComboIDs = [mealCombo.id]
        chickenB.upsellComboIDs = [mealCombo.id]
        cheeseburger.upsellModifierNames = ["Bacon", "Cheese slice"]

        let comboTile = Product(name: "Bolt Meal", price: Money(18.90), categoryID: burgers.id,
                                station: "Expo", glyph: "square.stack.3d.up.fill", accent: 8,
                                comboID: mealCombo.id, favourite: true)

        let products = [cheeseburger, doubleB, chickenB, veg, comboTile, wings, tenders,
                        fries, rings, slaw, nuggets, coke, coke0, lemonade, water, shake, sundae, cookie]

        let promos = [
            Promotion(name: "2 for 1 Tuesdays", kind: .buyXGetY(buy: 1, free: 1),
                      productIDs: [cheeseburger.id], priority: 4),
            Promotion(name: "Spend $30, save $5", kind: .thresholdAmountOff(spend: Money(30), off: Money(5)),
                      priority: 2, stacks: true)
        ]

        let cat = Catalogue(categories: [burgers, chicken, sides, drinks, sweets],
                            products: products, combos: [mealCombo], promotions: promos)

        let staff = Seed.staffSet([
            ("Ryan Ellis", "RE", .cashier, "1111"),
            ("Mia Torres", "MT", .supervisor, "3333"),
            ("Dev Sharma", "DS", .manager, "9999")
        ])

        var bundle = SeedBundle(catalogue: cat, customers: [], staff: staff)
        bundle.hour = 12
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-7200), float: Money(400),
                             cashSales: Money(612.30), cardSales: Money(2_940.10),
                             orders: 208)

        // Lunch peak: a lane order, a counter order and two aggregator orders waiting.
        var counter = Order(number: 2201, token: 42, type: .takeaway)
        counter.status = .open
        counter.fulfilment = .inPreparation
        let noPickles = Seed.selected(remove, "No pickles")
        let extraBacon = Seed.selected(addOns, "Bacon")
        counter.items = [
            Seed.line(cheeseburger, 2, mods: [noPickles, extraBacon].compactMap { $0 }, sentAgo: 180),
            Seed.line(fries, 2, variant: "Large", sentAgo: 180),
            Seed.line(coke, 2, variant: "Regular", sentAgo: 180, ready: true)
        ]
        counter.payments = [PaymentLeg(kind: .card, amount: counter.total, staff: "RE")]
        counter.status = .completed
        counter.closedAt = .now.addingTimeInterval(-175)

        var lane = Order(number: 2202, token: 43, type: .driveThrough)
        lane.status = .open
        lane.fulfilment = .inPreparation
        lane.items = [Seed.line(chickenB, 1, sentAgo: 90), Seed.line(shake, 1, sentAgo: 90)]

        var ue = Order(number: 2203, type: .delivery)
        ue.status = .placed
        ue.channel = .uberEats
        ue.name = "Nadia"
        ue.partnerReference = "#8823"
        ue.fulfilment = .notStarted
        ue.dueAt = .now.addingTimeInterval(900)
        var ueItem = Seed.line(doubleB, 1, status: .unsent)
        ueItem.sendRecords = []
        var ueFries = Seed.line(fries, 1, status: .unsent)
        ueFries.sendRecords = []
        ue.items = [ueItem, ueFries]
        ue.payments = [PaymentLeg(kind: .other, amount: ue.total, staff: "Uber Eats", reference: "PREPAID")]

        var dd = Order(number: 2204, type: .delivery)
        dd.status = .placed
        dd.channel = .doorDash
        dd.name = "Ben"
        dd.partnerReference = "#4410"
        dd.fulfilment = .notStarted
        dd.dueAt = .now.addingTimeInterval(1200)
        var ddItem = Seed.line(wings, 2, status: .unsent)
        ddItem.sendRecords = []
        dd.items = [ddItem]
        dd.payments = [PaymentLeg(kind: .other, amount: dd.total, staff: "DoorDash", reference: "PREPAID")]

        // A kiosk order and a dine-in tray, so the board looks like a lunch peak rather than
        // a screenshot with two tickets on it.
        var kiosk = Order(number: 2205, token: 44, type: .dineIn)
        kiosk.status = .open
        kiosk.channel = .kiosk
        kiosk.fulfilment = .inPreparation
        kiosk.items = [
            Seed.line(comboTile, 1, sentAgo: 240),
            Seed.line(wings, 1, sentAgo: 240),
            Seed.line(shake, 2, sentAgo: 240)
        ]
        kiosk.payments = [PaymentLeg(kind: .card, amount: kiosk.total, staff: "Kiosk")]

        var tray = Order(number: 2206, token: 45, type: .dineIn)
        tray.status = .open
        tray.fulfilment = .inPreparation
        tray.items = [
            Seed.line(veg, 1, mods: [Seed.selected(remove, "No sauce")].compactMap { $0 }, sentAgo: 60),
            Seed.line(nuggets, 2, sentAgo: 60)
        ]

        bundle.orders = [counter, lane, ue, dd, kiosk, tray]
        bundle.tickets = [
            KitchenTicket(orderID: counter.id, orderLabel: "#42", typeLabel: "Take", station: "Grill",
                          lines: counter.items.prefix(1).map {
                              KitchenLine(itemID: $0.id, name: $0.name, quantity: $0.quantity,
                                          modifiers: [], removals: [], allergens: [])
                          }, state: .started, receivedAt: .now.addingTimeInterval(-180),
                          startedAt: .now.addingTimeInterval(-120)),
            KitchenTicket(orderID: lane.id, orderLabel: "#43", typeLabel: "Lane", station: "Fryer",
                          lines: lane.items.prefix(1).map {
                              KitchenLine(itemID: $0.id, name: $0.name, quantity: $0.quantity,
                                          modifiers: [], removals: [], allergens: [])
                          }, state: .waiting, receivedAt: .now.addingTimeInterval(-90), isRush: true),
            KitchenTicket(orderID: counter.id, orderLabel: "#42", typeLabel: "Take", station: "Fryer",
                          lines: [KitchenLine(itemID: counter.items[1].id, name: "Fries (Large)",
                                              quantity: 2, modifiers: ["Chicken salt"],
                                              removals: [], allergens: [])],
                          state: .started, receivedAt: .now.addingTimeInterval(-180),
                          startedAt: .now.addingTimeInterval(-150)),
            KitchenTicket(orderID: kiosk.id, orderLabel: "#44", typeLabel: "Dine", station: "Grill",
                          lines: [KitchenLine(itemID: kiosk.items[0].id, name: "Bolt Meal",
                                              quantity: 1,
                                              modifiers: ["Double Bolt", "Onion Rings", "Thick Shake"],
                                              removals: ["No onion"], allergens: ["Gluten", "Dairy"])],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-240),
                          channel: .kiosk),
            KitchenTicket(orderID: kiosk.id, orderLabel: "#44", typeLabel: "Dine", station: "Drinks",
                          lines: [KitchenLine(itemID: kiosk.items[2].id, name: "Thick Shake",
                                              quantity: 2, modifiers: ["Salted caramel"],
                                              removals: [], allergens: ["Dairy"])],
                          state: .started, receivedAt: .now.addingTimeInterval(-235),
                          startedAt: .now.addingTimeInterval(-200), channel: .kiosk),
            KitchenTicket(orderID: tray.id, orderLabel: "#45", typeLabel: "Dine", station: "Grill",
                          lines: [KitchenLine(itemID: tray.items[0].id, name: "Garden Burger",
                                              quantity: 1, modifiers: [], removals: ["No sauce"],
                                              allergens: ["Gluten"])],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-60)),
            KitchenTicket(orderID: tray.id, orderLabel: "#45", typeLabel: "Dine", station: "Fryer",
                          lines: [KitchenLine(itemID: tray.items[1].id, name: "Nuggets 6pc",
                                              quantity: 2, modifiers: [], removals: [], allergens: [])],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-58))
        ]
        return bundle
    }
}
