import Foundation

/// Sesame St Kitchen — more than half of revenue arrives through aggregators. The inbox is
/// the home screen, prep time and channel pausing are one tap, and the counter keeps trading
/// while three channels shout at once.
enum TakeawaySeed {
    static func build() -> SeedBundle {
        let rice = Category(name: "Rice", glyph: "bowl.fill", accent: 1)
        let noodles = Category(name: "Noodles", glyph: "circle.hexagongrid.fill", accent: 0)
        let dumplings = Category(name: "Dumplings", glyph: "circle.grid.2x2.fill", accent: 3)
        let sides = Category(name: "Sides", glyph: "leaf.fill", accent: 4)
        let drinks = Category(name: "Drinks", glyph: "cup.and.straw.fill", accent: 6)

        let spice = Seed.group("Spice", .single, min: 1, max: 1, [
            Seed.mod("Mild", def: true), Seed.mod("Medium"), Seed.mod("Hot"), Seed.mod("Extra hot")
        ])
        let protein = Seed.group("Protein", .single, min: 1, max: 1, [
            Seed.mod("Chicken", def: true), Seed.mod("Beef", 2.00), Seed.mod("Pork"),
            Seed.mod("Prawn", 4.00, allergens: ["Shellfish"]), Seed.mod("Tofu"), Seed.mod("Vegetable")
        ])
        let extras = Seed.group("Add", .multi, [
            Seed.mod("Fried egg", 2.00, pinned: true, allergens: ["Egg"]),
            Seed.mod("Extra rice", 3.50, pinned: true),
            Seed.mod("Peanuts", 1.50, allergens: ["Nuts"]),
            Seed.mod("Extra sauce", 1.00), Seed.mod("Coriander"), Seed.mod("No coriander")
        ])

        func dish(_ name: String, _ price: Double, cat: UUID, station: String,
                  glyph: String, accent: Int, fav: Bool = false,
                  groups: [ModifierGroup]) -> Product {
            Product(name: name, price: Money(price), categoryID: cat, station: station,
                    glyph: glyph, accent: accent, groups: groups, favourite: fav)
        }

        let products: [Product] = [
            dish("Nasi Goreng", 19.50, cat: rice.id, station: "Grill", glyph: "bowl.fill",
                 accent: 1, fav: true, groups: [protein, spice, extras]),
            dish("Chicken Rice", 18.50, cat: rice.id, station: "Grill", glyph: "bowl.fill",
                 accent: 2, fav: true, groups: [spice, extras]),
            dish("Beef Rendang", 22.50, cat: rice.id, station: "Grill", glyph: "flame.fill",
                 accent: 0, groups: [spice, extras]),
            dish("Char Siu Rice", 20.50, cat: rice.id, station: "Grill", glyph: "square.stack.fill",
                 accent: 0, groups: [extras]),
            dish("Pad Thai", 20.50, cat: noodles.id, station: "Grill", glyph: "circle.hexagongrid.fill",
                 accent: 0, fav: true, groups: [protein, spice, extras]),
            dish("Hokkien Mee", 21.00, cat: noodles.id, station: "Grill", glyph: "circle.hexagongrid.fill",
                 accent: 1, groups: [protein, spice, extras]),
            dish("Laksa", 21.50, cat: noodles.id, station: "Grill", glyph: "drop.fill",
                 accent: 3, fav: true, groups: [protein, spice, extras]),
            dish("Singapore Noodles", 20.00, cat: noodles.id, station: "Grill",
                 glyph: "circle.hexagongrid.fill", accent: 2, groups: [protein, spice, extras]),
            dish("Pork Dumplings 8pc", 14.50, cat: dumplings.id, station: "Fryer",
                 glyph: "circle.grid.2x2.fill", accent: 3, fav: true,
                 groups: [Seed.group("Style", .single, min: 1, max: 1,
                                     [Seed.mod("Steamed", def: true), Seed.mod("Fried")])]),
            dish("Prawn Dumplings 8pc", 16.50, cat: dumplings.id, station: "Fryer",
                 glyph: "circle.grid.2x2.fill", accent: 6,
                 groups: [Seed.group("Style", .single, min: 1, max: 1,
                                     [Seed.mod("Steamed", def: true), Seed.mod("Fried")])]),
            dish("Veg Gyoza 8pc", 13.50, cat: dumplings.id, station: "Fryer",
                 glyph: "circle.grid.2x2.fill", accent: 4, groups: []),
            Product(name: "Spring Rolls 4pc", price: Money(9.50), categoryID: sides.id,
                    station: "Fryer", glyph: "capsule.fill", accent: 1, favourite: true),
            Product(name: "Prawn Crackers", price: Money(5.50), categoryID: sides.id,
                    station: "Pack", glyph: "circle.fill", accent: 3, allergens: ["Shellfish"]),
            Product(name: "Steamed Rice", price: Money(4.50), categoryID: sides.id,
                    station: "Grill", glyph: "bowl", accent: 2, favourite: true),
            Product(name: "Asian Greens", price: Money(11.50), categoryID: sides.id,
                    station: "Grill", glyph: "leaf.fill", accent: 4),
            Product(name: "Roti", price: Money(6.00), categoryID: sides.id,
                    station: "Fryer", glyph: "circle.dashed", accent: 1, allergens: ["Gluten"]),
            Product(name: "Iced Tea", price: Money(5.50), categoryID: drinks.id,
                    station: "Pack", glyph: "cup.and.straw.fill", accent: 6, isDrink: true),
            Product(name: "Coconut Water", price: Money(6.00), categoryID: drinks.id,
                    station: "Pack", glyph: "waterbottle.fill", accent: 4, isDrink: true),
            Product(name: "Coke Can", price: Money(3.50), categoryID: drinks.id,
                    station: "Pack", glyph: "cup.and.straw.fill", accent: 6, isDrink: true, favourite: true),
            Product(name: "Water", price: Money(3.00), categoryID: drinks.id,
                    station: "Pack", glyph: "drop.fill", accent: 7, isDrink: true)
        ]

        let promos = [
            Promotion(name: "Family bundle", kind: .thresholdAmountOff(spend: Money(70), off: Money(10)),
                      priority: 3)
        ]

        let cat = Catalogue(categories: [rice, noodles, dumplings, sides, drinks],
                            products: products, promotions: promos)

        let staff = Seed.staffSet([
            ("Mei Lin", "ML", .cashier, "1111"),
            ("Andre Costa", "AC", .supervisor, "3333"),
            ("Hana Yusuf", "HY", .manager, "9999")
        ])

        let customers = [
            Customer(name: "Jess Moran", phone: "0412 118 900", loyaltyPoints: 60,
                     address: "22 Lygon St", usualOrderProductNames: ["Pad Thai", "Spring Rolls 4pc"], visits: 33),
            Customer(name: "Office — Level 4", phone: "0400 900 118",
                     houseAccountBalance: Money(820), houseAccountLimit: Money(3000),
                     address: "Level 4, 210 Queen St", visits: 96)
        ]

        var bundle = SeedBundle(catalogue: cat, customers: customers, staff: staff)
        bundle.hour = 19
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-7200), float: Money(250),
                             cashSales: Money(160.00), cardSales: Money(1_140.00),
                             otherSales: Money(2_880.00), orders: 132)

        func partner(_ channel: SalesChannel, name: String, number: Int, ref: String,
                     minutes: Int, items: [(Product, Int)], accepted: Bool) -> Order {
            var o = Order(number: number, type: channel.isPartner ? .delivery : .takeaway)
            o.status = accepted ? .open : .placed
            o.channel = channel
            o.name = name
            o.customerName = name
            o.partnerReference = ref
            o.fulfilment = accepted ? .inPreparation : .notStarted
            o.dueAt = .now.addingTimeInterval(Double(minutes) * 60)
            o.createdAt = .now.addingTimeInterval(Double(-minutes) * 6)
            for (p, q) in items {
                var it = Seed.line(p, q, status: accepted ? .sent : .unsent,
                                   sentAgo: accepted ? 300 : 0)
                if !accepted { it.sendRecords = [] }
                o.items.append(it)
            }
            o.payments = [PaymentLeg(kind: .other, amount: o.total, staff: channel.label,
                                     reference: "PREPAID \(channel.label)")]
            return o
        }

        let o1 = partner(.uberEats, name: "Tara", number: 8801, ref: "#7712", minutes: 14,
                         items: [(products[4], 1), (products[8], 1)], accepted: true)
        let o2 = partner(.doorDash, name: "Nick", number: 8802, ref: "#2204", minutes: 22,
                         items: [(products[6], 2), (products[11], 1)], accepted: false)
        let o3 = partner(.menulog, name: "Priya", number: 8803, ref: "#5518", minutes: 26,
                         items: [(products[0], 1), (products[2], 1), (products[18], 2)], accepted: false)
        let o4 = partner(.ownWeb, name: "Jess", number: 8804, ref: "W-118", minutes: 18,
                         items: [(products[4], 1), (products[11], 1)], accepted: true)

        var counter = Order(number: 8805, type: .takeaway)
        counter.status = .open
        counter.name = "Sam"
        counter.fulfilment = .ready
        counter.items = [Seed.line(products[8], 2, sentAgo: 600, ready: true)]

        bundle.orders = [o1, o2, o3, o4, counter]
        bundle.tickets = [
            KitchenTicket(orderID: o1.id, orderLabel: "Tara", typeLabel: "Deliver", station: "Grill",
                          lines: [KitchenLine(itemID: o1.items[0].id, name: "Pad Thai", quantity: 1,
                                              modifiers: ["Chicken", "Mild"], removals: [], allergens: [])],
                          state: .started, receivedAt: .now.addingTimeInterval(-300),
                          startedAt: .now.addingTimeInterval(-240), channel: .uberEats),
            KitchenTicket(orderID: o4.id, orderLabel: "Jess", typeLabel: "Take", station: "Fryer",
                          lines: [KitchenLine(itemID: o4.items[1].id, name: "Spring Rolls 4pc",
                                              quantity: 1, modifiers: [], removals: [], allergens: [])],
                          state: .waiting, receivedAt: .now.addingTimeInterval(-120), channel: .ownWeb)
        ]
        return bundle
    }
}
