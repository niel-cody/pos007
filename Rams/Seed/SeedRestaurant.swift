import Foundation

/// Marlowe — a casual full-service restaurant. Floor first, covers, courses, hold and fire,
/// and a bill that is very often split.
enum FullServiceSeed {
    static func build() -> SeedBundle {
        let starters = Category(name: "Starters", glyph: "leaf.fill", accent: 4)
        let mains = Category(name: "Mains", glyph: "fork.knife", accent: 0)
        let sides = Category(name: "Sides", glyph: "carrot.fill", accent: 2)
        let desserts = Category(name: "Dessert", glyph: "birthday.cake.fill", accent: 8)
        let drinks = Category(name: "Drinks", glyph: "wineglass.fill", accent: 9)

        let temp = Seed.group("Cooked", .single, min: 1, max: 1, [
            Seed.mod("Rare"), Seed.mod("Medium rare", def: true), Seed.mod("Medium"),
            Seed.mod("Medium well"), Seed.mod("Well done")
        ])
        let dietary = Seed.group("Dietary", .multi, [
            Seed.mod("Gluten free"), Seed.mod("Dairy free"), Seed.mod("Vegetarian"),
            Seed.mod("Nut allergy"), Seed.mod("Shellfish allergy")
        ])

        let products: [Product] = [
            Product(name: "Burrata", price: Money(24.00), categoryID: starters.id, station: "Larder",
                    glyph: "circle.fill", accent: 4, groups: [dietary],
                    allergens: ["Dairy"], courseHint: "Starters", favourite: true),
            Product(name: "Kingfish Crudo", price: Money(28.00), categoryID: starters.id, station: "Larder",
                    glyph: "fish.fill", accent: 6, groups: [dietary], allergens: ["Fish"], courseHint: "Starters"),
            Product(name: "Wood Fired Bread", price: Money(12.00), categoryID: starters.id, station: "Larder",
                    glyph: "square.stack.3d.up.fill", accent: 1, allergens: ["Gluten"],
                    courseHint: "Starters", favourite: true),
            Product(name: "Grilled Octopus", price: Money(29.00), categoryID: starters.id, station: "Grill",
                    glyph: "water.waves", accent: 7, courseHint: "Starters"),
            Product(name: "Beef Tartare", price: Money(26.00), categoryID: starters.id, station: "Larder",
                    glyph: "circle.hexagongrid.fill", accent: 0, allergens: ["Egg"], courseHint: "Starters"),

            Product(name: "Dry Aged Sirloin", price: Money(58.00), categoryID: mains.id, station: "Grill",
                    glyph: "flame.fill", accent: 0, groups: [temp, dietary],
                    courseHint: "Mains", favourite: true),
            Product(name: "Market Fish", price: Money(46.00), categoryID: mains.id, station: "Grill",
                    glyph: "fish.fill", accent: 6, groups: [dietary], allergens: ["Fish"],
                    courseHint: "Mains", favourite: true),
            Product(name: "Duck Ragu", price: Money(38.00), categoryID: mains.id, station: "Larder",
                    glyph: "circle.hexagongrid.fill", accent: 1, groups: [dietary],
                    allergens: ["Gluten"], courseHint: "Mains", favourite: true),
            Product(name: "Roast Chicken (to share)", price: Money(72.00), categoryID: mains.id,
                    station: "Grill", glyph: "bird.fill", accent: 2, groups: [dietary],
                    courseHint: "Mains"),
            Product(name: "Mushroom Risotto", price: Money(34.00), categoryID: mains.id, station: "Larder",
                    glyph: "leaf.circle.fill", accent: 4, groups: [dietary], courseHint: "Mains"),
            Product(name: "Lamb Shoulder (to share)", price: Money(88.00), categoryID: mains.id,
                    station: "Grill", glyph: "flame.circle.fill", accent: 0, courseHint: "Mains"),

            Product(name: "Fat Chips", price: Money(14.00), categoryID: sides.id, station: "Grill",
                    glyph: "takeoutbag.and.cup.and.straw.fill", accent: 2, courseHint: "Mains", favourite: true),
            Product(name: "Green Salad", price: Money(13.00), categoryID: sides.id, station: "Larder",
                    glyph: "leaf.fill", accent: 4, courseHint: "Mains"),
            Product(name: "Broccolini", price: Money(15.00), categoryID: sides.id, station: "Grill",
                    glyph: "carrot.fill", accent: 3, courseHint: "Mains"),

            Product(name: "Tiramisu", price: Money(18.00), categoryID: desserts.id, station: "Pass",
                    glyph: "square.stack.fill", accent: 1, courseHint: "Dessert", favourite: true),
            Product(name: "Lemon Tart", price: Money(17.00), categoryID: desserts.id, station: "Pass",
                    glyph: "circle.fill", accent: 1, courseHint: "Dessert"),
            Product(name: "Affogato", price: Money(15.00), categoryID: desserts.id, station: "Pass",
                    glyph: "cup.and.saucer.fill", accent: 0, courseHint: "Dessert"),
            Product(name: "Cheese Plate", price: Money(26.00), categoryID: desserts.id, station: "Larder",
                    glyph: "square.grid.2x2.fill", accent: 2, allergens: ["Dairy"], courseHint: "Dessert"),

            Product(name: "Sparkling", price: Money(14.00), categoryID: drinks.id, station: "Bar",
                    glyph: "sparkles", accent: 1, ageRestricted: true, isDrink: true, courseHint: "Drinks"),
            Product(name: "Shiraz", price: Money(16.00), categoryID: drinks.id, station: "Bar",
                    glyph: "wineglass.fill", accent: 9,
                    groups: [Seed.group("Serve", .single, min: 1, max: 1,
                                        [Seed.mod("Glass", def: true), Seed.mod("Bottle", 58.00)])],
                    ageRestricted: true, isDrink: true, courseHint: "Drinks", favourite: true),
            Product(name: "Sauv Blanc", price: Money(15.00), categoryID: drinks.id, station: "Bar",
                    glyph: "wineglass", accent: 4,
                    groups: [Seed.group("Serve", .single, min: 1, max: 1,
                                        [Seed.mod("Glass", def: true), Seed.mod("Bottle", 54.00)])],
                    ageRestricted: true, isDrink: true, courseHint: "Drinks"),
            Product(name: "Tap Beer", price: Money(11.00), categoryID: drinks.id, station: "Bar",
                    glyph: "drop.fill", accent: 2, ageRestricted: true, isDrink: true, courseHint: "Drinks"),
            Product(name: "Negroni", price: Money(22.00), categoryID: drinks.id, station: "Bar",
                    glyph: "sparkles", accent: 5, ageRestricted: true, isDrink: true, courseHint: "Drinks"),
            Product(name: "Sparkling Water", price: Money(6.00), categoryID: drinks.id, station: "Bar",
                    glyph: "waterbottle.fill", accent: 6, isDrink: true, courseHint: "Drinks"),
            Product(name: "Espresso", price: Money(4.50), categoryID: drinks.id, station: "Bar",
                    glyph: "cup.and.saucer.fill", accent: 0, isDrink: true, courseHint: "Dessert")
        ]

        let cat = Catalogue(categories: [starters, mains, sides, desserts, drinks], products: products)

        let inside = FloorSection(name: "Dining room", glyph: "house.fill")
        let terrace = FloorSection(name: "Terrace", glyph: "sun.max.fill")
        let barArea = FloorSection(name: "Bar", glyph: "wineglass.fill")

        var tables = Seed.tableGrid(section: inside.id,
                                    labels: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12"],
                                    columns: 4, seats: [2, 4, 4, 6],
                                    originX: 0.07, originY: 0.09, stepX: 0.235, stepY: 0.215)
        tables += Seed.tableGrid(section: terrace.id, labels: ["T1", "T2", "T3", "T4", "T5", "T6"],
                                 columns: 3, seats: [4, 4, 2], shape: .round,
                                 originX: 0.10, originY: 0.14, stepX: 0.28, stepY: 0.30)
        tables += Seed.tableGrid(section: barArea.id, labels: ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8"],
                                 columns: 8, seats: [1], shape: .barStool,
                                 originX: 0.045, originY: 0.24, stepX: 0.118, stepY: 0.3)

        let staff = Seed.staffSet([
            ("Lena Hart", "LH", .waiter, "1111"),
            ("Owen Blake", "OB", .waiter, "2222"),
            ("Mari Sato", "MS", .supervisor, "3333"),
            ("Paul Rees", "PR", .manager, "9999"),
            ("Ivy Chen", "IC", .host, "4444")
        ])

        let customers = [
            Customer(name: "Danielle Cross", phone: "0412 553 990", loyaltyPoints: 340,
                     allergyNote: "Shellfish", isVIP: true, visits: 28),
            Customer(name: "Hugh Patel", phone: "0433 118 220", note: "Anniversary in March", visits: 12)
        ]

        var bundle = SeedBundle(catalogue: cat, sections: [inside, terrace, barArea],
                                tables: tables, customers: customers, staff: staff)
        bundle.hour = 19
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-10800), float: Money(400),
                             cashSales: Money(320.00), cardSales: Money(5_180.00),
                             covers: 88, orders: 34)

        func courses() -> [Course] {
            [Course(name: "Drinks", index: 0, autoFire: true),
             Course(name: "Starters", index: 1, autoFire: true),
             Course(name: "Mains", index: 2, autoFire: false),
             Course(name: "Dessert", index: 3, autoFire: false, isDessert: true)]
        }

        func table(_ label: String) -> FloorTable? { tables.first { $0.label == label } }

        // Table 4: starters served, mains held and ready to fire. The demo's opening move.
        var t4 = Order(number: 5501, type: .dineIn)
        t4.status = .open
        t4.tableID = table("4")?.id
        t4.tableLabel = "4"
        t4.guestCount = 4
        t4.waiter = "LH"
        t4.courses = courses()
        let c4 = t4.courses
        t4.items = [
            Seed.line(products[19], 2, variant: nil, course: c4[0].id, sentAgo: 1500, served: true),
            Seed.line(products[22], 2, course: c4[0].id, sentAgo: 1500, served: true),
            Seed.line(products[0], 2, course: c4[1].id, sentAgo: 1200, ready: true, served: true),
            Seed.line(products[2], 1, course: c4[1].id, sentAgo: 1200, ready: true, served: true),
            Seed.line(products[5], 2, mods: [Seed.selected(temp, "Medium rare")].compactMap { $0 },
                      course: c4[2].id, status: .held, sentAgo: 900),
            Seed.line(products[7], 2, course: c4[2].id, status: .held, sentAgo: 900),
            Seed.line(products[12], 1, course: c4[2].id, status: .held, sentAgo: 900)
        ]
        t4.timeline = [
            AuditEntry(at: .now.addingTimeInterval(-1560), actor: "LH", text: "Table 4 opened, 4 covers", glyph: "person.2.fill"),
            AuditEntry(at: .now.addingTimeInterval(-1500), actor: "LH", text: "Sent 4 drinks to Bar", glyph: "paperplane.fill"),
            AuditEntry(at: .now.addingTimeInterval(-1200), actor: "LH", text: "Sent 3 starters to Larder", glyph: "paperplane.fill"),
            AuditEntry(at: .now.addingTimeInterval(-900), actor: "LH", text: "Mains held", glyph: "pause.fill")
        ]

        // Table 7: mains cooking, a big party with the service charge already on.
        var t7 = Order(number: 5502, type: .dineIn)
        t7.status = .open
        t7.tableID = table("7")?.id
        t7.tableLabel = "7"
        t7.guestCount = 8
        t7.waiter = "OB"
        t7.courses = courses()
        let c7 = t7.courses
        t7.items = [
            Seed.line(products[8], 2, course: c7[2].id, sentAgo: 420),
            Seed.line(products[10], 1, course: c7[2].id, sentAgo: 420),
            Seed.line(products[12], 3, course: c7[2].id, sentAgo: 420),
            Seed.line(products[20], 2, mods: [], course: c7[0].id, sentAgo: 700, served: true)
        ]
        t7.adjustments = [Adjustment(kind: .serviceCharge, name: "Service charge 10%",
                                     amount: t7.subtotal.percent(10), percent: 10, automatic: true)]

        // Table 2: bill requested, splitting three ways.
        var t2 = Order(number: 5503, type: .dineIn)
        t2.status = .open
        t2.tableID = table("2")?.id
        t2.tableLabel = "2"
        t2.guestCount = 3
        t2.waiter = "LH"
        t2.courses = courses()
        let c2 = t2.courses
        t2.items = [
            Seed.line(products[6], 1, course: c2[2].id, sentAgo: 2400, served: true),
            Seed.line(products[7], 2, course: c2[2].id, sentAgo: 2400, served: true),
            Seed.line(products[20], 3, course: c2[0].id, sentAgo: 2700, served: true),
            Seed.line(products[15], 2, course: c2[3].id, sentAgo: 600, served: true)
        ]
        t2.billRequested = true
        t2.billPrintedAt = .now.addingTimeInterval(-240)

        // Table 9: seated, nothing ordered. Table 11: paid, waiting to be cleared.
        var t9 = Order(number: 5504, type: .dineIn)
        t9.status = .placed
        t9.tableID = table("9")?.id
        t9.tableLabel = "9"
        t9.guestCount = 2
        t9.waiter = "OB"
        t9.courses = courses()

        bundle.orders = [t4, t7, t2, t9]

        if let i = tables.firstIndex(where: { $0.label == "11" }) {
            bundle.tables[i].resetSince = .now.addingTimeInterval(-90)
        }
        if let i = tables.firstIndex(where: { $0.label == "6" }) {
            bundle.tables[i].reservation = Reservation(name: "Okafor", partySize: 4,
                                                       at: .now.addingTimeInterval(1800),
                                                       notes: "Window if possible")
        }
        if let i = tables.firstIndex(where: { $0.label == "12" }) {
            bundle.tables[i].blockedReason = "Wobbly leg"
        }
        if let i = tables.firstIndex(where: { $0.label == "3" }) {
            bundle.tables[i].note = "Regulars — Danielle, shellfish allergy"
        }

        bundle.tickets = [
            KitchenTicket(orderID: t7.id, orderLabel: "T7", typeLabel: "Dine", station: "Grill",
                          courseName: "Mains",
                          lines: [KitchenLine(itemID: t7.items[0].id, name: "Roast Chicken (to share)",
                                              quantity: 2, modifiers: [], removals: [], allergens: [])],
                          state: .started, receivedAt: .now.addingTimeInterval(-420),
                          startedAt: .now.addingTimeInterval(-360), tableLabel: "T7", covers: 8),
            KitchenTicket(orderID: t7.id, orderLabel: "T7", typeLabel: "Dine", station: "Larder",
                          courseName: "Mains",
                          lines: [KitchenLine(itemID: t7.items[1].id, name: "Mushroom Risotto",
                                              quantity: 1, modifiers: [], removals: [], allergens: [])],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-420),
                          tableLabel: "T7", covers: 8)
        ]
        return bundle
    }
}

/// Aster — twenty-two seats, two sittings, a floor team that must never be seen operating a
/// computer. Seats are real, courses are paced, and a wine goes to the cellar and never to
/// the kitchen board.
enum FineDiningSeed {
    static func build() -> SeedBundle {
        let tasting = Category(name: "Menus", glyph: "sparkles", accent: 9)
        let ala = Category(name: "À la carte", glyph: "fork.knife", accent: 0)
        let cellar = Category(name: "Cellar", glyph: "wineglass.fill", accent: 8)
        let cheese = Category(name: "Cheese", glyph: "square.grid.2x2.fill", accent: 2)
        let digestif = Category(name: "Digestif", glyph: "flask.fill", accent: 7)

        let dietary = Seed.group("Dietary", .multi, [
            Seed.mod("No shellfish"), Seed.mod("No dairy"), Seed.mod("No gluten"),
            Seed.mod("Vegetarian"), Seed.mod("Pescatarian"), Seed.mod("No pork")
        ])

        let products: [Product] = [
            Product(name: "Tasting Menu", price: Money(215.00), categoryID: tasting.id, station: "Pass",
                    glyph: "sparkles", accent: 9, groups: [dietary], courseHint: "First", favourite: true),
            Product(name: "Vegetable Menu", price: Money(195.00), categoryID: tasting.id, station: "Pass",
                    glyph: "leaf.fill", accent: 4, groups: [dietary], courseHint: "First", favourite: true),
            Product(name: "Wine Pairing", price: Money(145.00), categoryID: tasting.id, station: "Cellar",
                    glyph: "wineglass.fill", accent: 8, isDrink: true, courseHint: "Aperitif", favourite: true),
            Product(name: "Non-alc Pairing", price: Money(85.00), categoryID: tasting.id, station: "Cellar",
                    glyph: "leaf.circle.fill", accent: 4, isDrink: true, courseHint: "Aperitif"),

            Product(name: "Oyster", price: Money(9.50), categoryID: ala.id, station: "Garde manger",
                    glyph: "circle.fill", accent: 6, allergens: ["Shellfish"], courseHint: "First"),
            Product(name: "Caviar Service", price: Money(180.00), categoryID: ala.id, station: "Garde manger",
                    glyph: "circle.grid.3x3.fill", accent: 7, courseHint: "First"),
            Product(name: "Scallop", price: Money(38.00), categoryID: ala.id, station: "Sauce",
                    glyph: "water.waves", accent: 6, allergens: ["Shellfish"], courseHint: "Second"),
            Product(name: "Aged Duck", price: Money(76.00), categoryID: ala.id, station: "Sauce",
                    glyph: "bird.fill", accent: 0,
                    groups: [Seed.group("Cooked", .single, min: 1, max: 1,
                                        [Seed.mod("Pink", def: true), Seed.mod("Medium")]), dietary],
                    courseHint: "Main"),
            Product(name: "Wagyu", price: Money(120.00), categoryID: ala.id, station: "Sauce",
                    glyph: "flame.fill", accent: 0,
                    groups: [Seed.group("Cooked", .single, min: 1, max: 1,
                                        [Seed.mod("Rare"), Seed.mod("Medium rare", def: true)]), dietary],
                    courseHint: "Main"),

            Product(name: "Champagne", price: Money(38.00), categoryID: cellar.id, station: "Cellar",
                    glyph: "sparkles", accent: 1, ageRestricted: true, isDrink: true, courseHint: "Aperitif", favourite: true),
            Product(name: "Burgundy Blanc", price: Money(32.00), categoryID: cellar.id, station: "Cellar",
                    glyph: "wineglass", accent: 4, ageRestricted: true, isDrink: true, courseHint: "First"),
            Product(name: "Barolo", price: Money(180.00), categoryID: cellar.id, station: "Cellar",
                    glyph: "wineglass.fill", accent: 9, ageRestricted: true, isDrink: true, courseHint: "Main"),
            Product(name: "Sake", price: Money(26.00), categoryID: cellar.id, station: "Cellar",
                    glyph: "flask.fill", accent: 6, ageRestricted: true, isDrink: true, courseHint: "Second"),

            Product(name: "Cheese Trolley", price: Money(42.00), categoryID: cheese.id, station: "Pass",
                    glyph: "square.grid.2x2.fill", accent: 2, courseHint: "Cheese", favourite: true),
            Product(name: "Petit Fours", price: Money(18.00), categoryID: cheese.id, station: "Pastry",
                    glyph: "circle.grid.2x2.fill", accent: 1, courseHint: "Dessert"),
            Product(name: "Soufflé", price: Money(28.00), categoryID: cheese.id, station: "Pastry",
                    glyph: "cone.fill", accent: 1, courseHint: "Dessert", favourite: true),

            Product(name: "Cognac", price: Money(34.00), categoryID: digestif.id, station: "Cellar",
                    glyph: "flask.fill", accent: 1, ageRestricted: true, isDrink: true, courseHint: "Dessert"),
            Product(name: "Amaro", price: Money(19.00), categoryID: digestif.id, station: "Cellar",
                    glyph: "flask", accent: 5, ageRestricted: true, isDrink: true, courseHint: "Dessert"),
            Product(name: "Tea Service", price: Money(14.00), categoryID: digestif.id, station: "Pass",
                    glyph: "cup.and.heat.waves.fill", accent: 4, isDrink: true, courseHint: "Dessert")
        ]

        let cat = Catalogue(categories: [tasting, ala, cellar, cheese, digestif], products: products)

        let room = FloorSection(name: "Dining room", glyph: "sparkles")
        let chefs = FloorSection(name: "Chef’s counter", glyph: "flame.fill")

        var tables = Seed.tableGrid(section: room.id, labels: ["1", "2", "3", "4", "5", "6"],
                                    columns: 3, seats: [2, 2, 4], shape: .round,
                                    originX: 0.12, originY: 0.14, stepX: 0.28, stepY: 0.30)
        tables += Seed.tableGrid(section: chefs.id, labels: ["C1", "C2", "C3", "C4", "C5", "C6"],
                                 columns: 6, seats: [1], shape: .barStool,
                                 originX: 0.08, originY: 0.26, stepX: 0.145, stepY: 0.3)

        let staff = Seed.staffSet([
            ("Claude Rousseau", "CR", .waiter, "1111"),
            ("Junko Mori", "JM", .waiter, "2222"),
            ("Etienne Roux", "ER", .manager, "9999"),
            ("Sylvie Bourne", "SB", .host, "4444")
        ])

        let customers = [
            Customer(name: "Dr Amara Osei", phone: "0412 900 771",
                     allergyNote: "No shellfish — seat 2", note: "Third visit this year; likes Barolo",
                     isVIP: true, visits: 9),
            Customer(name: "Nikolai Frank", phone: "0400 118 552", note: "Birthday tonight", visits: 3)
        ]

        var bundle = SeedBundle(catalogue: cat, sections: [room, chefs],
                                tables: tables, customers: customers, staff: staff)
        bundle.hour = 20
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-9000), float: Money(200),
                             cardSales: Money(4_120.00), covers: 22, orders: 6)

        func courses() -> [Course] {
            ["Aperitif", "First", "Second", "Main", "Cheese", "Dessert"].enumerated().map { i, n in
                Course(name: n, index: i, autoFire: i == 0, isDessert: n == "Dessert")
            }
        }

        // Table 3: four guests on the tasting menu, second course called, third held.
        var t3 = Order(number: 6601, type: .dineIn)
        t3.status = .open
        t3.tableID = tables.first { $0.label == "3" }?.id
        t3.tableLabel = "3"
        t3.guestCount = 4
        t3.seatCount = 4
        t3.waiter = "CR"
        t3.customerID = customers[0].id
        t3.customerName = customers[0].name
        t3.courses = courses()
        var cs = t3.courses
        cs[1].calledAt = .now.addingTimeInterval(-1800)
        cs[2].calledAt = .now.addingTimeInterval(-420)
        t3.courses = cs
        t3.items = [
            Seed.line(products[9], 4, course: cs[0].id, seat: nil, sentAgo: 2700, served: true),
            Seed.line(products[0], 3, course: cs[1].id, seat: 1, sentAgo: 2400, ready: true, served: true),
            Seed.line(products[1], 1, course: cs[1].id, seat: 2, sentAgo: 2400, ready: true, served: true,
                      note: "No shellfish — allergy"),
            Seed.line(products[6], 3, course: cs[2].id, seat: 1, sentAgo: 400),
            Seed.line(products[4], 4, course: cs[2].id, seat: 3, sentAgo: 400),
            Seed.line(products[11], 1, course: cs[3].id, seat: nil, status: .held, sentAgo: 200),
            Seed.line(products[8], 2, course: cs[3].id, seat: 1, status: .held, sentAgo: 200)
        ]
        for i in t3.items.indices where t3.items[i].seat != nil {
            t3.items[i].seat = (i % 4) + 1
        }
        t3.timeline = [
            AuditEntry(at: .now.addingTimeInterval(-2760), actor: "SB", text: "Seated — booking Osei, 4", glyph: "calendar"),
            AuditEntry(at: .now.addingTimeInterval(-2750), actor: "CR", text: "Allergy noted on seat 2: shellfish", glyph: "exclamationmark.triangle.fill", isNotable: true),
            AuditEntry(at: .now.addingTimeInterval(-1800), actor: "CR", text: "Called First", glyph: "bell.fill"),
            AuditEntry(at: .now.addingTimeInterval(-420), actor: "CR", text: "Called Second", glyph: "bell.fill")
        ]

        // Chef's counter: two seats, paced by the kitchen.
        var c1 = Order(number: 6602, type: .dineIn)
        c1.status = .open
        c1.tableID = tables.first { $0.label == "C1" }?.id
        c1.tableLabel = "C1"
        c1.guestCount = 2
        c1.seatCount = 2
        c1.waiter = "JM"
        c1.courses = courses()
        let cc = c1.courses
        c1.items = [
            Seed.line(products[0], 2, course: cc[1].id, seat: 1, sentAgo: 900, ready: true),
            Seed.line(products[2], 2, course: cc[0].id, seat: 1, sentAgo: 1000, served: true)
        ]
        c1.items[0].seat = 1
        c1.items[1].seat = 2

        bundle.orders = [t3, c1]

        if let i = tables.firstIndex(where: { $0.label == "5" }) {
            bundle.tables[i].reservation = Reservation(name: "Frank", partySize: 2,
                                                       at: .now.addingTimeInterval(1200),
                                                       notes: "Birthday — candle with dessert")
        }
        bundle.tickets = [
            KitchenTicket(orderID: t3.id, orderLabel: "T3", typeLabel: "Dine", station: "Sauce",
                          courseName: "Second",
                          lines: [KitchenLine(itemID: t3.items[3].id, name: "Scallop", quantity: 3,
                                              modifiers: [], removals: [], allergens: ["Shellfish"], seat: 1)],
                          state: .started, receivedAt: .now.addingTimeInterval(-400),
                          startedAt: .now.addingTimeInterval(-300), tableLabel: "T3", covers: 4),
            KitchenTicket(orderID: t3.id, orderLabel: "T3", typeLabel: "Dine", station: "Garde manger",
                          courseName: "Second",
                          lines: [KitchenLine(itemID: t3.items[4].id, name: "Oyster", quantity: 4,
                                              modifiers: [], removals: [], allergens: ["Shellfish"], seat: 3)],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-400),
                          tableLabel: "T3", covers: 4)
        ]
        return bundle
    }
}
