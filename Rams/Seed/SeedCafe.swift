import Foundation

/// Prospect & Grind — an Australian café doing 340 coffees a day, most of them before 9:30.
/// The coffee matrix is the whole interface here, so it is authored exactly as the research
/// describes it: size as a variant, milk as a single-select with a default, strength as a
/// quantity, sugar as a quantity, syrup as a searchable list with pinned favourites.
enum CafeSeed {
    static func build() -> SeedBundle {
        let coffee = Category(name: "Coffee", glyph: "cup.and.saucer.fill", accent: 1)
        let cold = Category(name: "Cold", glyph: "snowflake", accent: 6)
        let food = Category(name: "Kitchen", glyph: "fork.knife", accent: 4)
        let bakery = Category(name: "Bakery", glyph: "birthday.cake.fill", accent: 2)
        let retail = Category(name: "Retail", glyph: "bag.fill", accent: 8)

        // The seven axes of an Australian coffee order.
        let milk = Seed.group("Milk", .single, min: 1, max: 1, [
            Seed.mod("Full cream", def: true),
            Seed.mod("Skim"),
            Seed.mod("Oat", 0.70, pinned: true),
            Seed.mod("Almond", 0.70, allergens: ["Nuts"]),
            Seed.mod("Soy", 0.70, allergens: ["Soy"]),
            Seed.mod("Lactose free", 0.70),
            Seed.mod("No milk")
        ])
        let strength = Seed.group("Strength", .single, min: 0, max: 1, [
            Seed.mod("Standard", def: true),
            Seed.mod("Half strength"),
            Seed.mod("Decaf", 0.50),
            Seed.mod("Three quarter")
        ])
        let shots = Seed.group("Shots", .quantity, [
            Seed.mod("Extra shot", 0.60, maxPer: 3)
        ])
        let temp = Seed.group("Temperature", .single, min: 0, max: 1, [
            Seed.mod("Standard", def: true),
            Seed.mod("Extra hot"),
            Seed.mod("Warm"),
            Seed.mod("Bone dry")
        ])
        let sugar = Seed.group("Sugar", .quantity, [
            Seed.mod("Sugar", maxPer: 4, makes: false),
            Seed.mod("Raw sugar", maxPer: 4, makes: false),
            Seed.mod("Honey", 0.30, maxPer: 2)
        ])
        let syrup = Seed.group("Syrup", .multi, [
            Seed.mod("Vanilla", 0.70, pinned: true),
            Seed.mod("Caramel", 0.70, pinned: true),
            Seed.mod("Hazelnut", 0.70, pinned: true),
            Seed.mod("Chai", 0.70), Seed.mod("Gingerbread", 0.70),
            Seed.mod("Peppermint", 0.70), Seed.mod("Coconut", 0.70),
            Seed.mod("Maple", 0.70), Seed.mod("Salted caramel", 0.70),
            Seed.mod("Cinnamon", 0.50), Seed.mod("Rose", 0.70),
            Seed.mod("Lavender", 0.70)
        ])
        let cup = Seed.group("Cup", .single, min: 1, max: 1, [
            Seed.mod("Takeaway cup", def: true),
            Seed.mod("Dine in cup"),
            Seed.mod("Own cup", -0.50),
            Seed.mod("Large takeaway", 0.20)
        ])

        func espressoDrink(_ name: String, _ price: Double, glyph: String = "cup.and.saucer.fill",
                           accent: Int = 1, favourite: Bool = false) -> Product {
            Product(name: name, price: Money(price), categoryID: coffee.id, station: "Coffee",
                    glyph: glyph, accent: accent,
                    variantAxisName: "Size",
                    variants: Seed.variants([("Small", 0, false), ("Regular", 0.60, true), ("Large", 1.20, false)]),
                    groups: [milk, strength, shots, temp, sugar, syrup, cup],
                    upsellModifierNames: ["Vanilla", "Extra shot"],
                    isDrink: true, favourite: favourite)
        }

        var products: [Product] = [
            espressoDrink("Flat White", 4.20, favourite: true),
            espressoDrink("Latte", 4.20, favourite: true),
            espressoDrink("Cappuccino", 4.20, favourite: true),
            espressoDrink("Long Black", 4.00),
            espressoDrink("Piccolo", 3.80),
            espressoDrink("Espresso", 3.50, glyph: "cup.and.saucer"),
            espressoDrink("Magic", 4.40),
            espressoDrink("Mocha", 4.80),
            Product(name: "Chai Latte", price: Money(4.80), categoryID: coffee.id, station: "Coffee",
                    glyph: "leaf.fill", accent: 2,
                    variantAxisName: "Size",
                    variants: Seed.variants([("Regular", 0, true), ("Large", 0.80, false)]),
                    groups: [milk, temp, sugar, cup], isDrink: true),
            Product(name: "Hot Chocolate", price: Money(4.60), categoryID: coffee.id, station: "Coffee",
                    glyph: "mug.fill", accent: 0,
                    variantAxisName: "Size",
                    variants: Seed.variants([("Regular", 0, true), ("Large", 0.80, false)]),
                    groups: [milk, temp, sugar, Seed.group("Extras", .multi, [
                        Seed.mod("Marshmallows", 0.60), Seed.mod("Whipped cream", 0.80)
                    ]), cup], isDrink: true),
            Product(name: "Matcha Latte", price: Money(5.40), categoryID: coffee.id, station: "Coffee",
                    glyph: "leaf.circle.fill", accent: 3,
                    groups: [milk, temp, sugar, cup], isDrink: true),
            Product(name: "Tea", price: Money(3.80), categoryID: coffee.id, station: "Coffee",
                    glyph: "cup.and.heat.waves.fill", accent: 4,
                    groups: [Seed.group("Leaf", .single, min: 1, max: 1, [
                        Seed.mod("English breakfast", def: true), Seed.mod("Earl grey"),
                        Seed.mod("Green"), Seed.mod("Peppermint"), Seed.mod("Chamomile")
                    ]), Seed.group("Add", .multi, [Seed.mod("Milk on the side"), Seed.mod("Lemon"), Seed.mod("Honey", 0.30)]), cup],
                    isDrink: true),

            Product(name: "Iced Latte", price: Money(5.60), categoryID: cold.id, station: "Coffee",
                    glyph: "cup.and.saucer.fill", accent: 6,
                    groups: [milk, shots, syrup, Seed.group("Ice", .single, min: 1, max: 1,
                        [Seed.mod("Standard ice", def: true), Seed.mod("Light ice"), Seed.mod("No ice")])],
                    isDrink: true, favourite: true),
            Product(name: "Cold Brew", price: Money(5.80), categoryID: cold.id, station: "Coffee",
                    glyph: "drop.fill", accent: 7, groups: [milk, syrup], isDrink: true),
            Product(name: "Iced Long Black", price: Money(5.20), categoryID: cold.id, station: "Coffee",
                    glyph: "drop.circle.fill", accent: 6, groups: [shots], isDrink: true),
            Product(name: "Smoothie", price: Money(9.50), categoryID: cold.id, station: "Coffee",
                    glyph: "tornado", accent: 3,
                    groups: [Seed.group("Base", .single, min: 1, max: 1, [
                        Seed.mod("Mango", def: true), Seed.mod("Berry"), Seed.mod("Banana"), Seed.mod("Green")
                    ]), milk, Seed.group("Boost", .multi, [
                        Seed.mod("Protein", 1.50), Seed.mod("Chia", 1.00), Seed.mod("Peanut butter", 1.50, allergens: ["Nuts"])
                    ])], isDrink: true),
            Product(name: "Orange Juice", price: Money(6.00), categoryID: cold.id,
                    station: "Coffee", glyph: "waterbottle.fill", accent: 1, isDrink: true),
            Product(name: "Sparkling Water", price: Money(4.50), categoryID: cold.id,
                    station: "Coffee", glyph: "waterbottle", accent: 6, isDrink: true),

            Product(name: "Bacon & Egg Roll", price: Money(12.50), categoryID: food.id, station: "Kitchen",
                    glyph: "takeoutbag.and.cup.and.straw.fill", accent: 0,
                    groups: [Seed.group("Sauce", .single, min: 1, max: 1, [
                        Seed.mod("BBQ", def: true), Seed.mod("Tomato"), Seed.mod("Aioli"), Seed.mod("Chilli jam"), Seed.mod("No sauce")
                    ]), Seed.group("Add", .multi, [
                        Seed.mod("Avocado", 3.50), Seed.mod("Extra bacon", 4.00), Seed.mod("Hash brown", 2.50), Seed.mod("Cheese", 1.50)
                    ]), Seed.group("Remove", .multi, [Seed.mod("No egg"), Seed.mod("No bacon")])],
                    allergens: ["Gluten", "Egg"], courseHint: "Food", favourite: true),
            Product(name: "Avo Smash", price: Money(19.50), categoryID: food.id, station: "Kitchen",
                    glyph: "leaf.fill", accent: 4,
                    groups: [Seed.group("Bread", .single, min: 1, max: 1, [
                        Seed.mod("Sourdough", def: true), Seed.mod("Rye"), Seed.mod("Gluten free", 1.50), Seed.mod("Turkish")
                    ]), Seed.group("Add", .multi, [
                        Seed.mod("Poached egg", 3.00), Seed.mod("Feta", 2.50), Seed.mod("Smoked salmon", 6.00), Seed.mod("Halloumi", 4.00)
                    ])], allergens: ["Gluten"], favourite: true),
            Product(name: "Big Brekky", price: Money(26.00), categoryID: food.id, station: "Kitchen",
                    glyph: "sun.horizon.fill", accent: 1,
                    groups: [Seed.group("Eggs", .single, min: 1, max: 1, [
                        Seed.mod("Poached", def: true), Seed.mod("Scrambled"), Seed.mod("Fried")
                    ]), Seed.group("Sides", .multi, max: 2, [
                        Seed.mod("Mushrooms"), Seed.mod("Spinach"), Seed.mod("Tomato"), Seed.mod("Beans")
                    ])], allergens: ["Gluten", "Egg"]),
            Product(name: "Granola Bowl", price: Money(15.00), categoryID: food.id, station: "Kitchen",
                    glyph: "bowl.fill", accent: 2, allergens: ["Nuts", "Dairy"]),
            Product(name: "Toast & Jam", price: Money(8.50), categoryID: food.id, station: "Kitchen",
                    glyph: "square.stack.3d.up.fill", accent: 1, allergens: ["Gluten"]),

            Product(name: "Almond Croissant", price: Money(6.50), categoryID: bakery.id, station: "Coffee",
                    glyph: "croissant.fill", accent: 1, allergens: ["Nuts", "Gluten"], favourite: true),
            Product(name: "Ham & Cheese Croissant", price: Money(7.50), categoryID: bakery.id,
                    station: "Coffee", glyph: "croissant.fill", accent: 0, allergens: ["Gluten", "Dairy"]),
            Product(name: "Banana Bread", price: Money(6.00), categoryID: bakery.id, station: "Coffee",
                    glyph: "rectangle.fill", accent: 1,
                    groups: [Seed.group("Serve", .single, min: 1, max: 1, [
                        Seed.mod("As is", def: true), Seed.mod("Toasted with butter", 1.00)
                    ])], allergens: ["Gluten"], favourite: true),
            Product(name: "Muffin", price: Money(5.50), categoryID: bakery.id, station: "Coffee",
                    glyph: "cone.fill", accent: 3, trackedQuantity: 4),
            Product(name: "Lamington", price: Money(5.00), categoryID: bakery.id, station: "Coffee",
                    glyph: "cube.fill", accent: 0),

            Product(name: "Beans 250g", price: Money(22.00), categoryID: retail.id, station: "Coffee",
                    glyph: "bag.fill", accent: 8,
                    variantAxisName: "Roast",
                    variants: Seed.variants([("House", 0, true), ("Single origin", 6.00, false), ("Decaf", 2.00, false)]),
                    barcode: "9312345678900"),
            Product(name: "Keep Cup", price: Money(28.00), categoryID: retail.id, station: "Coffee",
                    glyph: "cup.and.saucer.fill", accent: 9, barcode: "9312345678917")
        ]

        // The 3pm pastry promotion the research describes, plus a member's discount.
        let promos = [
            Promotion(name: "Afternoon pastries", kind: .percentOff(30),
                      categoryIDs: [bakery.id], fromHour: 15, toHour: 18, priority: 5),
            Promotion(name: "Coffee & croissant", kind: .bundleFixed(productNames: ["Flat White", "Almond Croissant"],
                                                                    price: Money(9.50)),
                      priority: 8)
        ]

        for i in products.indices where products[i].name == "Muffin" {
            products[i].trackedQuantity = 4
        }

        let cat = Catalogue(categories: [coffee, cold, food, bakery, retail],
                            products: products, combos: [], promotions: promos)

        let staff = Seed.staffSet([
            ("Nina Alvarez", "NA", .barista, "1111"),
            ("Kofi Mensah", "KM", .cashier, "2222"),
            ("Dana Petrov", "DP", .manager, "9999")
        ])

        let customers = [
            Customer(name: "Sam Whitfield", phone: "0412 887 220", loyaltyPoints: 240,
                     note: "Every weekday around 7:40",
                     usualOrderProductNames: ["Flat White"], visits: 214,
                     lastVisit: .now.addingTimeInterval(-86400)),
            Customer(name: "Sarah Kim", phone: "0433 110 908", loyaltyPoints: 80,
                     usualOrderProductNames: ["Latte", "Almond Croissant"], visits: 61),
            Customer(name: "Sarah Nguyen", phone: "0455 662 100", loyaltyPoints: 20,
                     usualOrderProductNames: ["Cappuccino"], visits: 12),
            Customer(name: "Marcus Boyd", phone: "0400 221 553", loyaltyPoints: 610,
                     isMember: true, memberNumber: "PG-4410", isVIP: true,
                     usualOrderProductNames: ["Long Black", "Avo Smash"], visits: 340),
            Customer(name: "Priya Rao", phone: "0466 900 411", allergyNote: "Severe nut allergy",
                     usualOrderProductNames: ["Chai Latte"], visits: 44)
        ]

        // Six coffees in flight at 8:12am, which is what the make queue exists for.
        var bundle = SeedBundle(catalogue: cat, customers: customers, staff: staff)
        bundle.hour = 8
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-5400), float: Money(300),
                             cashSales: Money(184.40), cardSales: Money(1_226.80),
                             otherSales: Money(42.00), paidOut: Money(38.00),
                             covers: 0, orders: 141)

        func latte(_ name: String, size: String, milkChoice: String, extras: [String] = [],
                   ago: TimeInterval, ready: Bool = false, product: String = "Latte") -> Order {
            var o = Order(number: 0, type: .takeaway)
            o.status = .completed
            o.name = name
            o.channel = .pos
            o.closedAt = .now.addingTimeInterval(-ago)
            o.fulfilment = ready ? .ready : .inPreparation
            guard let p = cat.product(named: product) else { return o }
            var mods: [SelectedModifier] = []
            if let m = Seed.selected(milk, milkChoice) { mods.append(m) }
            for e in extras {
                if let m = Seed.selected(strength, e) { mods.append(m) }
                else if let m = Seed.selected(temp, e) { mods.append(m) }
                else if let m = Seed.selected(shots, e) { mods.append(m) }
                else if let m = Seed.selected(syrup, e) { mods.append(m) }
                else if let m = Seed.selected(sugar, e) { mods.append(m) }
            }
            var item = Seed.line(p, 1, variant: size, mods: mods, sentAgo: ago, ready: ready)
            item.status = .sent
            o.items = [item]
            o.payments = [PaymentLeg(kind: .card, amount: item.lineTotal, staff: "KM")]
            return o
        }

        var q: [Order] = [
            latte("Sam", size: "Regular", milkChoice: "Full cream", ago: 260, ready: true, product: "Flat White"),
            latte("Priya", size: "Large", milkChoice: "Oat", extras: ["Extra shot", "Extra hot"], ago: 190),
            latte("Josh", size: "Regular", milkChoice: "Skim", extras: ["Decaf"], ago: 140, product: "Cappuccino"),
            latte("Sarah", size: "Regular", milkChoice: "Full cream", ago: 96, product: "Latte"),
            latte("Sarah 2", size: "Large", milkChoice: "Soy", extras: ["Vanilla"], ago: 74, product: "Latte"),
            latte("Marcus", size: "Regular", milkChoice: "Full cream", ago: 30, product: "Long Black")
        ]
        for i in q.indices { q[i].number = 1020 + i }

        // One web order that jumped the queue, prepaid.
        var web = Order(number: 1027, type: .takeaway)
        web.status = .placed
        web.channel = .ownWeb
        web.name = "Alice"
        web.customerName = "Alice Trent"
        web.phone = "0477 221 004"
        web.fulfilment = .notStarted
        web.dueAt = .now.addingTimeInterval(420)
        if let p = cat.product(named: "Iced Latte") {
            var it = Seed.line(p, 2, mods: [Seed.selected(milk, "Almond")].compactMap { $0 }, status: .unsent)
            it.sendRecords = []
            web.items = [it]
        }
        web.payments = [PaymentLeg(kind: .other, amount: web.total, staff: "Web", reference: "PREPAID")]
        q.append(web)

        bundle.orders = q
        bundle.tickets = []

        // Recents are what makes a repeat order three taps instead of twelve.
        if let flat = cat.product(named: "Flat White") {
            var r1 = Seed.line(flat, 1, variant: "Regular",
                               mods: [Seed.selected(milk, "Full cream")].compactMap { $0 }, status: .unsent)
            r1.sendRecords = []
            var r2 = Seed.line(flat, 1, variant: "Large",
                               mods: [Seed.selected(milk, "Oat"), Seed.selected(shots, "Extra shot"),
                                      Seed.selected(strength, "Half strength"), Seed.selected(temp, "Extra hot"),
                                      Seed.selected(sugar, "Sugar"), Seed.selected(syrup, "Vanilla")].compactMap { $0 },
                               status: .unsent)
            r2.sendRecords = []
            bundle.recents = [r1, r2]
        }
        if let latteP = cat.product(named: "Latte") {
            var r = Seed.line(latteP, 1, variant: "Regular",
                              mods: [Seed.selected(milk, "Skim"), Seed.selected(strength, "Decaf")].compactMap { $0 },
                              status: .unsent)
            r.sendRecords = []
            bundle.recents.append(r)
        }
        return bundle
    }
}
