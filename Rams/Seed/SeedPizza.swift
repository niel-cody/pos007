import Foundation

/// Via Norma — a pizza shop. The hard part is the menu: sections, toppings priced by section,
/// and sizes that change every price in the group. Half-and-half is built on a portion combo
/// with the Australian pricing rule (the dearer half), stated in words on the builder.
enum PizzaSeed {
    static func build() -> SeedBundle {
        let pizzas = Category(name: "Pizza", glyph: "circle.grid.cross.fill", accent: 0)
        let build = Category(name: "Build", glyph: "circle.lefthalf.filled", accent: 5)
        let pasta = Category(name: "Pasta", glyph: "circle.hexagongrid.fill", accent: 1)
        let sides = Category(name: "Sides", glyph: "leaf.fill", accent: 4)
        let drinks = Category(name: "Drinks", glyph: "cup.and.straw.fill", accent: 6)
        let dolci = Category(name: "Dolci", glyph: "birthday.cake.fill", accent: 8)

        let crust = Seed.group("Crust", .single, min: 1, max: 1, [
            Seed.mod("Classic", def: true), Seed.mod("Thin"), Seed.mod("Thick"),
            Seed.mod("Gluten free", 4.00), Seed.mod("Stuffed crust", 5.00)
        ])
        let base = Seed.group("Base", .single, min: 1, max: 1, [
            Seed.mod("Tomato", def: true), Seed.mod("Garlic cream"), Seed.mod("BBQ"), Seed.mod("No base")
        ])
        let toppings = Seed.group("Toppings", .multi, [
            Seed.mod("Pepperoni", 3.50, pinned: true), Seed.mod("Mushroom", 2.50, pinned: true),
            Seed.mod("Olives", 2.50, pinned: true), Seed.mod("Anchovy", 3.00),
            Seed.mod("Prosciutto", 4.50), Seed.mod("Buffalo mozzarella", 5.00, allergens: ["Dairy"]),
            Seed.mod("Chilli", 1.50), Seed.mod("Onion", 2.00), Seed.mod("Capsicum", 2.00),
            Seed.mod("Pineapple", 2.50), Seed.mod("Rocket", 2.00), Seed.mod("Feta", 3.00, allergens: ["Dairy"]),
            Seed.mod("Salami", 3.50), Seed.mod("Egg", 2.50, allergens: ["Egg"]),
            Seed.mod("Extra cheese", 3.00, allergens: ["Dairy"]), Seed.mod("Truffle oil", 4.00)
        ])
        let removals = Seed.group("Hold", .multi, [
            Seed.mod("No cheese"), Seed.mod("Light cheese"), Seed.mod("No onion"),
            Seed.mod("Well done"), Seed.mod("Cut in squares"), Seed.mod("Uncut")
        ])
        let sizeAxis = Seed.variants([("11\"", 0, false), ("13\"", 4.00, true), ("16\"", 9.00, false)])

        func pizza(_ name: String, _ price: Double, accent: Int, allergens: [String] = ["Gluten"],
                   fav: Bool = false) -> Product {
            Product(name: name, price: Money(price), categoryID: pizzas.id, station: "Make line",
                    glyph: "circle.grid.cross.fill", accent: accent,
                    variantAxisName: "Size", variants: sizeAxis,
                    groups: [crust, base, toppings, removals],
                    allergens: allergens, favourite: fav)
        }

        let margherita = pizza("Margherita", 18.00, accent: 4, fav: true)
        let pepperoni = pizza("Pepperoni", 22.00, accent: 0, fav: true)
        let meatLovers = pizza("Meat Lovers", 24.00, accent: 0, fav: true)
        let capricciosa = pizza("Capricciosa", 23.00, accent: 1)
        let vegetariana = pizza("Vegetariana", 21.00, accent: 4)
        let hawaiian = pizza("Hawaiian", 21.00, accent: 3)
        let quattro = pizza("Quattro Formaggi", 25.00, accent: 2, allergens: ["Gluten", "Dairy"])
        let diavola = pizza("Diavola", 24.00, accent: 0)
        let prosciuttoFunghi = pizza("Prosciutto e Funghi", 25.00, accent: 1)
        let marinara = pizza("Marinara", 17.00, accent: 6)

        let pizzaIDs = [margherita, pepperoni, meatLovers, capricciosa, vegetariana,
                        hawaiian, quattro, diavola, prosciuttoFunghi, marinara].map(\.id)

        // Whole-pizza toppings print once, above the section blocks. Section toppings carry
        // a half portion and price at half.
        let halfCombo = Combo(name: "Half & Half",
                              kind: .portion,
                              slots: [ComboSlot(name: "Left half", productIDs: pizzaIDs),
                                      ComboSlot(name: "Right half", productIDs: pizzaIDs)],
                              addonPrice: Money(4.00),
                              pricingRule: .highest,
                              wholeGroups: [crust, base, removals],
                              sectionGroups: [toppings])

        let quarterCombo = Combo(name: "Four Quarters",
                                 kind: .portion,
                                 slots: [ComboSlot(name: "Quarter 1", productIDs: pizzaIDs),
                                         ComboSlot(name: "Quarter 2", productIDs: pizzaIDs),
                                         ComboSlot(name: "Quarter 3", productIDs: pizzaIDs),
                                         ComboSlot(name: "Quarter 4", productIDs: pizzaIDs)],
                                 addonPrice: Money(7.00),
                                 pricingRule: .highest,
                                 wholeGroups: [crust, base, removals],
                                 sectionGroups: [toppings])

        let halfTile = Product(name: "Half & Half 13\"", price: Money(4.00), categoryID: build.id,
                               station: "Make line", glyph: "circle.lefthalf.filled", accent: 5,
                               comboID: halfCombo.id, favourite: true)
        let quarterTile = Product(name: "Four Quarters 16\"", price: Money(7.00), categoryID: build.id,
                                  station: "Make line", glyph: "circle.grid.2x2.fill", accent: 7,
                                  comboID: quarterCombo.id)

        var products: [Product] = [margherita, pepperoni, meatLovers, capricciosa, vegetariana,
                                   hawaiian, quattro, diavola, prosciuttoFunghi, marinara,
                                   halfTile, quarterTile,
            Product(name: "Spaghetti Bolognese", price: Money(22.00), categoryID: pasta.id,
                    station: "Make line", glyph: "circle.hexagongrid.fill", accent: 0,
                    groups: [Seed.group("Add", .multi, [Seed.mod("Parmesan", 2.00), Seed.mod("Chilli", 1.00)])],
                    allergens: ["Gluten"], favourite: true),
            Product(name: "Lasagne", price: Money(24.00), categoryID: pasta.id, station: "Make line",
                    glyph: "square.stack.fill", accent: 1, allergens: ["Gluten", "Dairy"]),
            Product(name: "Gnocchi", price: Money(24.00), categoryID: pasta.id, station: "Make line",
                    glyph: "circle.fill", accent: 4, allergens: ["Gluten"]),
            Product(name: "Garlic Bread", price: Money(9.00), categoryID: sides.id, station: "Oven",
                    glyph: "square.stack.3d.up.fill", accent: 1,
                    groups: [Seed.group("Style", .single, min: 1, max: 1, [
                        Seed.mod("Classic", def: true), Seed.mod("Cheesy", 3.00), Seed.mod("Herb & cheese", 3.50)
                    ])], allergens: ["Gluten"], favourite: true),
            Product(name: "Wings", price: Money(14.00), categoryID: sides.id, station: "Fryer",
                    glyph: "flame.fill", accent: 0),
            Product(name: "Chips", price: Money(9.50), categoryID: sides.id, station: "Fryer",
                    glyph: "takeoutbag.and.cup.and.straw.fill", accent: 2, favourite: true),
            Product(name: "Greek Salad", price: Money(14.00), categoryID: sides.id, station: "Make line",
                    glyph: "leaf.fill", accent: 4, allergens: ["Dairy"]),
            Product(name: "Coke 1.25L", price: Money(6.50), categoryID: drinks.id, station: "Make line",
                    glyph: "waterbottle.fill", accent: 6, isDrink: true, favourite: true),
            Product(name: "Coke Can", price: Money(3.50), categoryID: drinks.id, station: "Make line",
                    glyph: "cup.and.straw.fill", accent: 6, isDrink: true),
            Product(name: "Lemon Squash", price: Money(6.50), categoryID: drinks.id, station: "Make line",
                    glyph: "waterbottle", accent: 5, isDrink: true),
            Product(name: "Water", price: Money(3.00), categoryID: drinks.id, station: "Make line",
                    glyph: "drop.fill", accent: 7, isDrink: true),
            Product(name: "Tiramisu", price: Money(11.00), categoryID: dolci.id, station: "Make line",
                    glyph: "square.stack.fill", accent: 1, allergens: ["Dairy", "Egg"]),
            Product(name: "Nutella Pizza", price: Money(16.00), categoryID: dolci.id, station: "Oven",
                    glyph: "circle.grid.cross.fill", accent: 1, allergens: ["Gluten", "Nuts"], favourite: true),
            Product(name: "Gelato", price: Money(8.00), categoryID: dolci.id, station: "Make line",
                    glyph: "cone.fill", accent: 8,
                    groups: [Seed.group("Flavour", .single, min: 1, max: 1, [
                        Seed.mod("Pistachio", def: true), Seed.mod("Chocolate"), Seed.mod("Lemon")
                    ])])
        ]

        for i in products.indices where products[i].name == "Pepperoni" {
            products[i].upsellModifierNames = ["Extra cheese", "Chilli"]
        }

        let promos = [
            Promotion(name: "Two large + garlic bread", kind: .thresholdAmountOff(spend: Money(55), off: Money(8)),
                      priority: 3)
        ]

        let cat = Catalogue(categories: [pizzas, build, pasta, sides, drinks, dolci],
                            products: products, combos: [halfCombo, quarterCombo], promotions: promos)

        let staff = Seed.staffSet([
            ("Norma Ricci", "NR", .cashier, "1111"),
            ("Luca Bianchi", "LB", .manager, "9999"),
            ("Tony Greco", "TG", .runner, "2222")
        ])

        let customers = [
            Customer(name: "The Delaneys", phone: "0412 776 004", loyaltyPoints: 190,
                     address: "14 Kestrel St, Brunswick", deliveryInstructions: "Blue door, dog in yard",
                     usualOrderProductNames: ["Pepperoni", "Garlic Bread", "Coke 1.25L"], visits: 87),
            Customer(name: "Ahmed Family", phone: "0433 220 118",
                     address: "3/88 Sydney Rd", deliveryInstructions: "Buzz 3",
                     usualOrderProductNames: ["Margherita", "Vegetariana"], visits: 41),
            Customer(name: "Chris Vale", phone: "0400 665 221",
                     address: "72 Albion St, Coburg", visits: 6)
        ]

        var bundle = SeedBundle(catalogue: cat, customers: customers, staff: staff)
        bundle.hour = 19
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-9000), float: Money(300),
                             cashSales: Money(740.00), cardSales: Money(1_980.00), orders: 68)

        // A delivery on the make line, a pickup waiting, and a phone order half built.
        var deliveryOrder = Order(number: 7701, type: .delivery)
        deliveryOrder.status = .open
        deliveryOrder.name = "Delaney"
        deliveryOrder.customerID = customers[0].id
        deliveryOrder.customerName = customers[0].name
        deliveryOrder.phone = customers[0].phone
        deliveryOrder.delivery = DeliveryDetails(address: customers[0].address ?? "",
                                                 instructions: customers[0].deliveryInstructions ?? "",
                                                 zone: "Zone 1", fee: Money(4.50))
        deliveryOrder.fulfilment = .inPreparation
        deliveryOrder.dueAt = .now.addingTimeInterval(1500)
        deliveryOrder.items = [
            Seed.line(pepperoni, 1, variant: "16\"",
                      mods: [Seed.selected(crust, "Classic"), Seed.selected(base, "Tomato"),
                             Seed.selected(toppings, "Extra cheese")].compactMap { $0 }, sentAgo: 400),
            Seed.line(products[15], 1, mods: [], sentAgo: 400),
            Seed.line(products[21], 1, sentAgo: 400)
        ]
        deliveryOrder.adjustments = [Adjustment(kind: .deliveryFee, name: "Delivery — Zone 1",
                                                amount: Money(4.50), automatic: true)]

        var pickup = Order(number: 7702, type: .takeaway)
        pickup.status = .open
        pickup.name = "Chris"
        pickup.phone = "0400 665 221"
        pickup.fulfilment = .ready
        pickup.dueAt = .now.addingTimeInterval(-120)
        var half = Seed.line(halfTile, 1, sentAgo: 900, ready: true)
        half.comboName = "Half & Half 13\""
        half.comboPricingRule = .highest
        half.portions = [
            PortionSelection(slotName: "Left half", productID: margherita.id,
                             productName: "Margherita", basePrice: Money(22.00)),
            PortionSelection(slotName: "Right half", productID: meatLovers.id,
                             productName: "Meat Lovers", basePrice: Money(28.00),
                             modifiers: [Seed.selected(toppings, "Chilli", portion: 0.5)].compactMap { $0 })
        ]
        half.unitPrice = Money(4.00)
        pickup.items = [half]
        pickup.payments = [PaymentLeg(kind: .card, amount: pickup.total, staff: "NR")]
        pickup.status = .completed
        pickup.closedAt = .now.addingTimeInterval(-880)

        var phoneOrder = Order(number: 7703, type: .delivery)
        phoneOrder.status = .placed
        phoneOrder.channel = .phone
        phoneOrder.name = "Ahmed"
        phoneOrder.customerID = customers[1].id
        phoneOrder.customerName = customers[1].name
        phoneOrder.phone = customers[1].phone
        phoneOrder.delivery = DeliveryDetails(address: customers[1].address ?? "",
                                              instructions: "Buzz 3", zone: "Zone 2", fee: Money(7.50))
        phoneOrder.fulfilment = .notStarted
        phoneOrder.dueAt = .now.addingTimeInterval(2400)
        var pi1 = Seed.line(margherita, 2, variant: "13\"", status: .unsent)
        pi1.sendRecords = []
        phoneOrder.items = [pi1]

        bundle.orders = [deliveryOrder, pickup, phoneOrder]
        bundle.tickets = [
            KitchenTicket(orderID: deliveryOrder.id, orderLabel: "Delaney", typeLabel: "Deliver",
                          station: "Make line",
                          lines: [KitchenLine(itemID: deliveryOrder.items[0].id, name: "Pepperoni 16\"",
                                              quantity: 1, modifiers: ["Classic", "Tomato", "Extra cheese"],
                                              removals: [], allergens: ["Gluten", "Dairy"])],
                          state: .started, receivedAt: .now.addingTimeInterval(-400),
                          startedAt: .now.addingTimeInterval(-330))
        ]
        return bundle
    }
}
