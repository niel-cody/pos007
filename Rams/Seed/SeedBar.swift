import Foundation

/// The Lantern — a busy bar. Rounds, tabs, card holds, and a dense grid because more drinks
/// per screen beats bigger tiles when the queue is ten deep. Dark by default.
enum BarSeed {
    static func build() -> SeedBundle {
        let tap = Category(name: "Tap", glyph: "drop.fill", accent: 1)
        let bottles = Category(name: "Bottles", glyph: "waterbottle.fill", accent: 2)
        let wine = Category(name: "Wine", glyph: "wineglass.fill", accent: 9)
        let spirits = Category(name: "Spirits", glyph: "flask.fill", accent: 7)
        let cocktails = Category(name: "Cocktails", glyph: "sparkles", accent: 8)
        let soft = Category(name: "Soft", glyph: "cup.and.straw.fill", accent: 6)
        let snacks = Category(name: "Snacks", glyph: "fork.knife", accent: 4)

        let glassSize = Seed.variants([("Schooner", 0, true), ("Pint", 2.50, false), ("Jug", 12.00, false)])

        func beer(_ name: String, _ price: Double, accent: Int, fav: Bool = false) -> Product {
            Product(name: name, price: Money(price), categoryID: tap.id, station: "Bar",
                    glyph: "drop.fill", accent: accent,
                    variantAxisName: "Glass", variants: glassSize,
                    ageRestricted: true, isDrink: true, favourite: fav)
        }

        let spiritGroups = [
            Seed.group("Pour", .single, min: 1, max: 1, [
                Seed.mod("Single", def: true), Seed.mod("Double", 4.00), Seed.mod("Neat"), Seed.mod("On the rocks")
            ]),
            Seed.group("Mixer", .single, min: 0, max: 1, [
                Seed.mod("Soda", pinned: true), Seed.mod("Tonic", pinned: true), Seed.mod("Coke", pinned: true),
                Seed.mod("Dry ginger"), Seed.mod("Lemonade"), Seed.mod("Ginger beer", 1.00), Seed.mod("No mixer")
            ]),
            Seed.group("Garnish", .multi, [
                Seed.mod("Lime"), Seed.mod("Lemon"), Seed.mod("Orange"), Seed.mod("Olive"), Seed.mod("No garnish")
            ])
        ]

        func spirit(_ name: String, _ price: Double, accent: Int) -> Product {
            Product(name: name, price: Money(price), categoryID: spirits.id, station: "Bar",
                    glyph: "flask.fill", accent: accent, groups: spiritGroups,
                    ageRestricted: true, isDrink: true)
        }

        let wineGroups = [Seed.group("Serve", .single, min: 1, max: 1, [
            Seed.mod("Glass", def: true), Seed.mod("Bottle", 32.00)
        ])]

        let cocktailGroups = [
            Seed.group("Strength", .single, min: 0, max: 1, [
                Seed.mod("Standard", def: true), Seed.mod("Extra shot", 4.00), Seed.mod("Virgin", -4.00)
            ]),
            Seed.group("Glass", .single, min: 0, max: 1, [
                Seed.mod("Coupe", def: true), Seed.mod("Rocks"), Seed.mod("Highball"), Seed.mod("Martini")
            ]),
            Seed.group("Garnish", .multi, [
                Seed.mod("Twist"), Seed.mod("Cherry"), Seed.mod("Mint"), Seed.mod("Salt rim"), Seed.mod("No garnish")
            ])
        ]

        let paleAle = beer("Pale Ale", 9.50, accent: 1, fav: true)
        let lager = beer("Lager", 8.50, accent: 2, fav: true)
        let stout = beer("Stout", 10.50, accent: 0)
        let cider = beer("Cider", 9.50, accent: 3)
        let ipa = beer("Hazy IPA", 11.00, accent: 4, fav: true)
        let mid = beer("Mid Strength", 7.50, accent: 6)

        let products: [Product] = [
            paleAle, lager, stout, cider, ipa, mid,
            Product(name: "Corona", price: Money(10.00), categoryID: bottles.id, station: "Bar",
                    glyph: "waterbottle.fill", accent: 2, ageRestricted: true, isDrink: true),
            Product(name: "Great Northern", price: Money(9.00), categoryID: bottles.id, station: "Bar",
                    glyph: "waterbottle.fill", accent: 1, ageRestricted: true, isDrink: true),
            Product(name: "Seltzer", price: Money(9.50), categoryID: bottles.id, station: "Bar",
                    glyph: "bubbles.and.sparkles.fill", accent: 6,
                    groups: [Seed.group("Flavour", .single, min: 1, max: 1, [
                        Seed.mod("Lime", def: true), Seed.mod("Peach"), Seed.mod("Berry")
                    ])], ageRestricted: true, isDrink: true),
            Product(name: "Ginger Beer", price: Money(8.00), categoryID: bottles.id, station: "Bar",
                    glyph: "waterbottle.fill", accent: 3, ageRestricted: true, isDrink: true),

            Product(name: "Shiraz", price: Money(13.00), categoryID: wine.id, station: "Bar",
                    glyph: "wineglass.fill", accent: 9, groups: wineGroups, ageRestricted: true, isDrink: true, favourite: true),
            Product(name: "Pinot Noir", price: Money(15.00), categoryID: wine.id, station: "Bar",
                    glyph: "wineglass.fill", accent: 8, groups: wineGroups, ageRestricted: true, isDrink: true),
            Product(name: "Sauv Blanc", price: Money(12.00), categoryID: wine.id, station: "Bar",
                    glyph: "wineglass", accent: 4, groups: wineGroups, ageRestricted: true, isDrink: true, favourite: true),
            Product(name: "Chardonnay", price: Money(13.00), categoryID: wine.id, station: "Bar",
                    glyph: "wineglass", accent: 2, groups: wineGroups, ageRestricted: true, isDrink: true),
            Product(name: "Prosecco", price: Money(14.00), categoryID: wine.id, station: "Bar",
                    glyph: "sparkles", accent: 1, groups: wineGroups, ageRestricted: true, isDrink: true),
            Product(name: "House Rosé", price: Money(12.00), categoryID: wine.id, station: "Bar",
                    glyph: "wineglass.fill", accent: 0, groups: wineGroups, ageRestricted: true, isDrink: true),

            spirit("Gin", 11.00, accent: 6),
            spirit("Vodka", 11.00, accent: 7),
            spirit("Whisky", 13.00, accent: 1),
            spirit("Rum", 11.50, accent: 0),
            spirit("Tequila", 12.00, accent: 3),
            spirit("Aperol", 12.00, accent: 1),

            Product(name: "Espresso Martini", price: Money(22.00), categoryID: cocktails.id, station: "Bar",
                    glyph: "sparkles", accent: 0, groups: cocktailGroups, ageRestricted: true, isDrink: true, favourite: true),
            Product(name: "Negroni", price: Money(21.00), categoryID: cocktails.id, station: "Bar",
                    glyph: "sparkles", accent: 5, groups: cocktailGroups, ageRestricted: true, isDrink: true),
            Product(name: "Margarita", price: Money(20.00), categoryID: cocktails.id, station: "Bar",
                    glyph: "sparkles", accent: 4, groups: cocktailGroups, ageRestricted: true, isDrink: true, favourite: true),
            Product(name: "Old Fashioned", price: Money(23.00), categoryID: cocktails.id, station: "Bar",
                    glyph: "sparkles", accent: 1, groups: cocktailGroups, ageRestricted: true, isDrink: true),
            Product(name: "Spritz", price: Money(19.00), categoryID: cocktails.id, station: "Bar",
                    glyph: "sparkles", accent: 2, groups: cocktailGroups, ageRestricted: true, isDrink: true),
            Product(name: "Paloma", price: Money(20.00), categoryID: cocktails.id, station: "Bar",
                    glyph: "sparkles", accent: 3, groups: cocktailGroups, ageRestricted: true, isDrink: true),

            Product(name: "Coke", price: Money(4.50), categoryID: soft.id, station: "Bar",
                    glyph: "cup.and.straw.fill", accent: 6, isDrink: true),
            Product(name: "Soda Lime", price: Money(4.00), categoryID: soft.id, station: "Bar",
                    glyph: "cup.and.straw", accent: 4, isDrink: true),
            Product(name: "Tonic", price: Money(4.50), categoryID: soft.id, station: "Bar",
                    glyph: "waterbottle", accent: 7, isDrink: true),
            Product(name: "Tap Water", price: Money(0), categoryID: soft.id, station: "Bar",
                    glyph: "drop", accent: 6, isDrink: true),

            Product(name: "Chips & Aioli", price: Money(12.00), categoryID: snacks.id, station: "Bar",
                    glyph: "takeoutbag.and.cup.and.straw.fill", accent: 2),
            Product(name: "Olives", price: Money(8.00), categoryID: snacks.id, station: "Bar",
                    glyph: "circle.fill", accent: 4),
            Product(name: "Cheese Toastie", price: Money(14.00), categoryID: snacks.id, station: "Bar",
                    glyph: "square.stack.fill", accent: 1, allergens: ["Gluten", "Dairy"])
        ]

        // Happy hour is a price list on a schedule, not a discount someone remembers to apply.
        let promos = [
            Promotion(name: "Happy hour", kind: .percentOff(25),
                      categoryIDs: [tap.id, wine.id], fromHour: 16, toHour: 18, priority: 9)
        ]

        let cat = Catalogue(categories: [tap, bottles, wine, spirits, cocktails, soft, snacks],
                            products: products, promotions: promos)

        let staff = Seed.staffSet([
            ("Jonah Reid", "JR", .bartender, "1111"),
            ("Elle Marsh", "EM", .bartender, "2222"),
            ("Cass Vega", "CV", .supervisor, "3333"),
            ("Theo Blake", "TB", .manager, "9999")
        ])

        var bundle = SeedBundle(catalogue: cat, customers: [], staff: staff)
        bundle.hour = 20
        bundle.shift = Shift(openedAt: .now.addingTimeInterval(-14400), float: Money(500),
                             cashSales: Money(1_140.50), cardSales: Money(4_820.00), orders: 312)

        // Four tabs open, one on a card hold near its limit, two under the same first name.
        func tab(_ name: String, number: Int, rounds: [[(Product, Int, String?)]],
                 auth: (String, String, Double)? = nil, owner: String) -> Order {
            var o = Order(number: number, type: .dineIn)
            o.status = .open
            o.name = name
            o.waiter = owner
            o.openedBy = owner
            if let auth {
                o.tabAuth = TabAuthorisation(state: .authorised, amount: Money(auth.2),
                                             last4: auth.0, scheme: auth.1,
                                             at: .now.addingTimeInterval(-3000))
            }
            for (ri, round) in rounds.enumerated() {
                let rid = UUID()
                for (p, q, variant) in round {
                    var item = Seed.line(p, q, variant: variant,
                                         sentAgo: Double(1800 - ri * 500), by: owner)
                    item.roundID = rid
                    o.items.append(item)
                }
            }
            o.timeline = [AuditEntry(at: .now.addingTimeInterval(-3100), actor: owner,
                                     text: "Tab opened as “\(name)”", glyph: "person.badge.key.fill")]
            return o
        }

        let t1 = tab("Dave", number: 3301,
                     rounds: [[(paleAle, 4, "Schooner"), (products[11], 2, nil)],
                              [(paleAle, 2, "Schooner"), (products[19], 2, nil)]],
                     auth: ("4417", "Amex", 200), owner: "JR")
        let t2 = tab("Dave B", number: 3302,
                     rounds: [[(ipa, 2, "Pint"), (products[13], 1, nil)]], owner: "EM")
        let t3 = tab("Booth 4", number: 3303,
                     rounds: [[(products[18], 4, nil), (products[20], 2, nil)]],
                     auth: ("8802", "Visa", 300), owner: "JR")
        let t4 = tab("Steph", number: 3304,
                     rounds: [[(lager, 6, "Schooner")]], owner: "EM")

        bundle.orders = [t1, t2, t3, t4]
        return bundle
    }
}
