import Foundation

/// The Royal Exchange — the Australian suburban pub. Order food at the counter with a table
/// number, take a buzzer, drink at the bar. Drinks are poured now; food goes to the kitchen
/// on the same order. Member and seniors pricing are price lists, not discounts.
enum PubSeed {
    static func build() -> SeedBundle {
        let mains = Category(name: "Bistro", glyph: "fork.knife", accent: 0)
        let pubFav = Category(name: "Favourites", glyph: "star.fill", accent: 1)
        let sides = Category(name: "Sides", glyph: "leaf.fill", accent: 4)
        let kids = Category(name: "Kids", glyph: "figure.child", accent: 3)
        let taps = Category(name: "Tap", glyph: "drop.fill", accent: 2)
        let wines = Category(name: "Wine & Spirits", glyph: "wineglass.fill", accent: 9)
        let desserts = Category(name: "Dessert", glyph: "birthday.cake.fill", accent: 8)

        let cookingTemp = Seed.group("Cooked", .single, min: 1, max: 1, [
            Seed.mod("Rare"), Seed.mod("Medium rare"), Seed.mod("Medium", def: true),
            Seed.mod("Medium well"), Seed.mod("Well done")
        ])
        let steakSauce = Seed.group("Sauce", .single, min: 1, max: 1, [
            Seed.mod("Gravy", def: true), Seed.mod("Mushroom"), Seed.mod("Pepper"),
            Seed.mod("Garlic butter"), Seed.mod("Dianne"), Seed.mod("No sauce")
        ])
        let sideChoice = Seed.group("Side", .single, min: 1, max: 1, [
            Seed.mod("Chips & salad", def: true), Seed.mod("Mash & veg"),
            Seed.mod("Roast veg"), Seed.mod("Salad only"), Seed.mod("Chips only")
        ])
        let dietary = Seed.group("Dietary", .multi, [
            Seed.mod("Gluten free", 2.00), Seed.mod("No dairy"), Seed.mod("No onion"), Seed.mod("Nut allergy")
        ])
        let glassSize = Seed.variants([("Schooner", 0, true), ("Pint", 2.00, false), ("Jug", 11.00, false)])

        let steak = Product(name: "Rump Steak 300g", price: Money(32.00), categoryID: mains.id,
                            station: "Grill", glyph: "flame.fill", accent: 0,
                            groups: [cookingTemp, steakSauce, sideChoice, dietary],
                            courseHint: "Food", favourite: true)
        let scotch = Product(name: "Scotch Fillet 350g", price: Money(44.00), categoryID: mains.id,
                             station: "Grill", glyph: "flame.circle.fill", accent: 0,
                             groups: [cookingTemp, steakSauce, sideChoice, dietary], courseHint: "Food")
        let parma = Product(name: "Chicken Parma", price: Money(28.00), categoryID: pubFav.id,
                            station: "Grill", glyph: "square.stack.fill", accent: 1,
                            groups: [sideChoice, Seed.group("Style", .single, min: 0, max: 1, [
                                Seed.mod("Classic", def: true), Seed.mod("Hawaiian", 2.00), Seed.mod("Mexican", 2.00)
                            ]), dietary], allergens: ["Gluten", "Dairy"], courseHint: "Food", favourite: true)
        let fish = Product(name: "Fish & Chips", price: Money(26.00), categoryID: pubFav.id,
                           station: "Larder", glyph: "fish.fill", accent: 6,
                           groups: [Seed.group("Fish", .single, min: 1, max: 1, [
                               Seed.mod("Beer battered", def: true), Seed.mod("Grilled"), Seed.mod("Crumbed")
                           ]), dietary], allergens: ["Gluten", "Fish"], courseHint: "Food", favourite: true)
        let burger = Product(name: "Pub Burger", price: Money(24.00), categoryID: pubFav.id,
                             station: "Grill", glyph: "circle.grid.2x2.fill", accent: 2,
                             groups: [Seed.group("Add", .multi, [
                                 Seed.mod("Bacon", 3.00), Seed.mod("Egg", 2.00), Seed.mod("Cheese", 2.00)
                             ]), dietary], allergens: ["Gluten"], courseHint: "Food", favourite: true)
        let salad = Product(name: "Caesar Salad", price: Money(22.00), categoryID: mains.id,
                            station: "Larder", glyph: "leaf.fill", accent: 4,
                            groups: [Seed.group("Add", .multi, [
                                Seed.mod("Chicken", 6.00), Seed.mod("Prawns", 9.00)
                            ]), dietary], courseHint: "Food")
        let roast = Product(name: "Roast of the Day", price: Money(25.00), categoryID: mains.id,
                            station: "Larder", glyph: "oven.fill", accent: 1,
                            groups: [dietary], courseHint: "Food")
        let schnitty = Product(name: "Chicken Schnitzel", price: Money(24.00), categoryID: pubFav.id,
                               station: "Grill", glyph: "rectangle.fill", accent: 1,
                               groups: [sideChoice, dietary], allergens: ["Gluten"], courseHint: "Food")
        let ribs = Product(name: "Pork Ribs", price: Money(36.00), categoryID: mains.id,
                           station: "Grill", glyph: "flame", accent: 0,
                           groups: [sideChoice, dietary], courseHint: "Food")

        let chips = Product(name: "Bowl of Chips", price: Money(11.00), categoryID: sides.id,
                            station: "Larder", glyph: "takeoutbag.and.cup.and.straw.fill", accent: 2, courseHint: "Food")
        let veg = Product(name: "Seasonal Veg", price: Money(9.00), categoryID: sides.id,
                          station: "Larder", glyph: "carrot.fill", accent: 4, courseHint: "Food")
        let garlicBread = Product(name: "Garlic Bread", price: Money(9.50), categoryID: sides.id,
                                  station: "Larder", glyph: "square.stack.3d.up.fill", accent: 1,
                                  allergens: ["Gluten"], courseHint: "Food")
        let onionRings = Product(name: "Onion Rings", price: Money(10.00), categoryID: sides.id,
                                 station: "Larder", glyph: "circle.circle.fill", accent: 3, courseHint: "Food")

        let kidsNuggets = Product(name: "Kids Nuggets", price: Money(12.00), categoryID: kids.id,
                                  station: "Larder", glyph: "figure.child", accent: 3,
                                  groups: [Seed.group("With", .single, min: 1, max: 1, [
                                      Seed.mod("Chips", def: true), Seed.mod("Salad"), Seed.mod("Veg")
                                  ])], courseHint: "Food")
        let kidsFish = Product(name: "Kids Fish", price: Money(12.00), categoryID: kids.id,
                               station: "Larder", glyph: "fish", accent: 6, courseHint: "Food")
        let kidsPasta = Product(name: "Kids Pasta", price: Money(12.00), categoryID: kids.id,
                                station: "Larder", glyph: "circle.hexagongrid.fill", accent: 1, courseHint: "Food")

        func beer(_ name: String, _ price: Double, accent: Int, fav: Bool = false) -> Product {
            Product(name: name, price: Money(price), categoryID: taps.id, station: "Bar",
                    glyph: "drop.fill", accent: accent, variantAxisName: "Glass", variants: glassSize,
                    ageRestricted: true, isDrink: true, courseHint: "Drinks", favourite: fav)
        }

        let drinks = [
            beer("Carlton Draught", 7.80, accent: 1, fav: true),
            beer("Great Northern", 8.20, accent: 2, fav: true),
            beer("Pale Ale", 9.20, accent: 3, fav: true),
            beer("Guinness", 10.50, accent: 0),
            beer("Cider", 9.00, accent: 4),
            beer("Light", 6.80, accent: 6),
            Product(name: "House Red", price: Money(9.50), categoryID: wines.id, station: "Bar",
                    glyph: "wineglass.fill", accent: 9, ageRestricted: true, isDrink: true, courseHint: "Drinks", favourite: true),
            Product(name: "House White", price: Money(9.50), categoryID: wines.id, station: "Bar",
                    glyph: "wineglass", accent: 4, ageRestricted: true, isDrink: true, courseHint: "Drinks"),
            Product(name: "Spirit & Mixer", price: Money(11.00), categoryID: wines.id, station: "Bar",
                    glyph: "flask.fill", accent: 7,
                    groups: [Seed.group("Spirit", .single, min: 1, max: 1, [
                        Seed.mod("Vodka", def: true), Seed.mod("Gin"), Seed.mod("Bourbon"), Seed.mod("Rum"), Seed.mod("Scotch")
                    ]), Seed.group("Pour", .single, min: 1, max: 1, [
                        Seed.mod("Single", def: true), Seed.mod("Double", 4.00)
                    ]), Seed.group("Mixer", .single, min: 0, max: 1, [
                        Seed.mod("Coke", pinned: true), Seed.mod("Soda"), Seed.mod("Tonic"), Seed.mod("Dry"), Seed.mod("No mixer")
                    ])], ageRestricted: true, isDrink: true, courseHint: "Drinks"),
            Product(name: "Soft Drink", price: Money(4.50), categoryID: wines.id, station: "Bar",
                    glyph: "cup.and.straw.fill", accent: 6, isDrink: true, courseHint: "Drinks"),
            Product(name: "Lemon Lime Bitters", price: Money(5.50), categoryID: wines.id, station: "Bar",
                    glyph: "cup.and.straw", accent: 4, isDrink: true, courseHint: "Drinks"),
            Product(name: "Coffee", price: Money(4.50), categoryID: wines.id, station: "Bar",
                    glyph: "cup.and.saucer.fill", accent: 1, isDrink: true, courseHint: "Drinks"),
            Product(name: "Function deposit", price: .zero, categoryID: wines.id, station: "Bar",
                    glyph: "square.dashed", accent: 5, openPriced: true, courseHint: "Drinks")
        ]

        let sticky = Product(name: "Sticky Date Pudding", price: Money(14.00), categoryID: desserts.id,
                             station: "Larder", glyph: "birthday.cake.fill", accent: 1, courseHint: "Food")
        let iceCream = Product(name: "Ice Cream Sundae", price: Money(11.00), categoryID: desserts.id,
                               station: "Larder", glyph: "cone.fill", accent: 8, courseHint: "Food")

        var products = [steak, scotch, parma, fish, burger, salad, roast, schnitty, ribs,
                        chips, veg, garlicBread, onionRings, kidsNuggets, kidsFish, kidsPasta,
                        sticky, iceCream]
        products.append(contentsOf: drinks)

        let promos = [
            Promotion(name: "Parma Tuesday", kind: .fixedPrice(Money(20.00)),
                      productIDs: [parma.id], priority: 6),
            Promotion(name: "Members’ tap price", kind: .percentOff(10),
                      categoryIDs: [taps.id], priority: 5, memberOnly: true),
            Promotion(name: "Members’ bistro price", kind: .percentOff(10),
                      categoryIDs: [mains.id, pubFav.id], priority: 5, memberOnly: true),
            Promotion(name: "Seniors price", kind: .percentOff(15),
                      categoryIDs: [mains.id, pubFav.id, sides.id], priority: 6,
                      groups: ["Seniors"])
        ]

        let cat = Catalogue(categories: [pubFav, mains, sides, kids, taps, wines, desserts],
                            products: products, promotions: promos)

        let staff = Seed.staffSet([
            ("Bree Callahan", "BC", .cashier, "1111"),
            ("Sione Tui", "ST", .bartender, "2222"),
            ("Rachel Ong", "RO", .supervisor, "3333"),
            ("Gary Fields", "GF", .manager, "9999")
        ])

        let customers = [
            Customer(name: "Ken Barlow", phone: "0412 000 118", loyaltyPoints: 120,
                     isMember: true, memberNumber: "RE-2201", group: "Seniors", visits: 512),
            Customer(name: "Lorraine Webb", phone: "0455 221 903", isMember: true,
                     memberNumber: "RE-8834", group: "Seniors", visits: 288),
            Customer(name: "Function — Reilly 21st", phone: "0400 776 221",
                     houseAccountBalance: Money(340), houseAccountLimit: Money(2000))
        ]

        var bundle = SeedBundle(catalogue: cat, customers: customers, staff: staff)
        bundle.hour = 18
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-25200), float: Money(600),
                             cashSales: Money(1_880.00), cardSales: Money(6_240.00),
                             covers: 214, orders: 176)

        // Table 24, buzzer 12: four meals and three drinks on one order, drinks already poured.
        var t24 = Order(number: 4401, token: 61, type: .dineIn)
        t24.status = .open
        t24.typedTableNumber = "24"
        t24.buzzer = "12"
        t24.guestCount = 4
        let drinksCourse = Course(name: "Drinks", index: 0, autoFire: true)
        let foodCourse = Course(name: "Food", index: 1, autoFire: true)
        t24.courses = [drinksCourse, foodCourse]
        t24.items = [
            Seed.line(steak, 1, mods: [Seed.selected(cookingTemp, "Medium rare"),
                                        Seed.selected(steakSauce, "Mushroom"),
                                        Seed.selected(sideChoice, "Chips & salad")].compactMap { $0 },
                      course: foodCourse.id, sentAgo: 620),
            Seed.line(parma, 2, mods: [Seed.selected(sideChoice, "Chips & salad")].compactMap { $0 },
                      course: foodCourse.id, sentAgo: 620),
            Seed.line(kidsNuggets, 1, course: foodCourse.id, sentAgo: 620, ready: true),
            Seed.line(drinks[0], 2, variant: "Schooner", course: drinksCourse.id, sentAgo: 640, served: true),
            Seed.line(drinks[6], 1, course: drinksCourse.id, sentAgo: 640, served: true)
        ]
        t24.timeline = [AuditEntry(at: .now.addingTimeInterval(-660), actor: "BC",
                                   text: "Order started", glyph: "plus.circle.fill"),
                        AuditEntry(at: .now.addingTimeInterval(-640), actor: "BC",
                                   text: "Sent 3 drinks to Bar", glyph: "paperplane.fill"),
                        AuditEntry(at: .now.addingTimeInterval(-620), actor: "BC",
                                   text: "Sent 4 items to Grill, Larder", glyph: "paperplane.fill")]

        // A member's order waiting to be paid, with the member price already applied.
        var member = Order(number: 4402, token: 62, type: .dineIn)
        member.status = .open
        member.typedTableNumber = "9"
        member.buzzer = "4"
        member.guestCount = 2
        member.customerID = customers[0].id
        member.customerName = customers[0].name
        member.courses = [drinksCourse, foodCourse]
        member.items = [
            Seed.line(fish, 2, course: foodCourse.id, sentAgo: 300),
            Seed.line(drinks[1], 2, variant: "Schooner", course: drinksCourse.id, sentAgo: 320, served: true)
        ]
        member.billRequested = true

        bundle.orders = [t24, member]
        bundle.tickets = [
            KitchenTicket(orderID: t24.id, orderLabel: "#61", typeLabel: "Dine", station: "Grill",
                          courseName: "Food",
                          lines: [KitchenLine(itemID: t24.items[0].id, name: "Rump Steak 300g", quantity: 1,
                                              modifiers: ["Medium rare", "Mushroom", "Chips & salad"],
                                              removals: [], allergens: []),
                                  KitchenLine(itemID: t24.items[1].id, name: "Chicken Parma", quantity: 2,
                                              modifiers: ["Chips & salad"], removals: [], allergens: ["Gluten"])],
                          state: .started, receivedAt: .now.addingTimeInterval(-620),
                          startedAt: .now.addingTimeInterval(-540), tableLabel: "T24", covers: 4, buzzer: "12"),
            KitchenTicket(orderID: member.id, orderLabel: "#62", typeLabel: "Dine", station: "Larder",
                          courseName: "Food",
                          lines: [KitchenLine(itemID: member.items[0].id, name: "Fish & Chips", quantity: 2,
                                              modifiers: ["Beer battered"], removals: [], allergens: ["Fish"])],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-300),
                          tableLabel: "T9", covers: 2, buzzer: "4")
        ]
        return bundle
    }
}
