import Foundation

struct SeedBundle {
    var catalogue: Catalogue
    var sections: [FloorSection] = []
    var tables: [FloorTable] = []
    var customers: [Customer] = []
    var staff: [Staff] = []
    var orders: [Order] = []
    var tickets: [KitchenTicket] = []
    var recents: [OrderItem] = []
    var shift: Shift = Shift()
    var hour: Int = 12
    var recentNames: [String] = ["Sam", "Alex", "Priya", "Josh", "Marcus", "Sarah",
                                 "Tom", "Ana", "Kiri", "Dan"]
}

// MARK: - Authoring helpers

enum Seed {

    static func group(_ name: String, _ selection: ModifierSelection = .multi,
                      min: Int = 0, max: Int = 0, freeFirst: Bool = false,
                      _ mods: [Modifier]) -> ModifierGroup {
        ModifierGroup(name: name, selection: selection, min: min, max: max,
                      modifiers: mods, freeFirstUnit: freeFirst)
    }

    static func mod(_ name: String, _ price: Double = 0, def: Bool = false,
                    pinned: Bool = false, maxPer: Int = 1, makes: Bool = true,
                    allergens: [String] = [], kitchen: String? = nil) -> Modifier {
        Modifier(name: name, kitchenName: kitchen, price: Money(price), isDefault: def,
                 pinned: pinned, maxPerOption: maxPer, allergens: allergens, changesTheMake: makes)
    }

    static func variants(_ pairs: [(String, Double, Bool)]) -> [VariantOption] {
        pairs.map { VariantOption(label: $0.0, priceDelta: Money($0.1), isDefault: $0.2) }
    }

    static func staffSet(_ roles: [(String, String, Staff.Role, String)]) -> [Staff] {
        roles.map { Staff(name: $0.0, initials: $0.1, role: $0.2, pin: $0.3, clockedIn: true) }
    }

    /// A rectangular block of tables, laid out on the 0...1 grid the floor view draws on.
    static func tableGrid(section: UUID, labels: [String], columns: Int,
                          seats: [Int], shape: TableShape = .square,
                          originX: Double = 0.08, originY: Double = 0.12,
                          stepX: Double = 0.16, stepY: Double = 0.22) -> [FloorTable] {
        labels.enumerated().map { i, label in
            FloorTable(label: label, sectionID: section,
                       seats: seats[i % seats.count], shape: shape,
                       x: originX + Double(i % columns) * stepX,
                       y: originY + Double(i / columns) * stepY)
        }
    }

    static func line(_ product: Product, _ qty: Int = 1, variant: String? = nil,
                     mods: [SelectedModifier] = [], course: UUID? = nil,
                     seat: Int? = nil, status: OrderItemStatus = .sent,
                     sentAgo: TimeInterval = 300, ready: Bool = false,
                     served: Bool = false, note: String? = nil,
                     by: String = "AM") -> OrderItem {
        var item = OrderItem(productID: product.id, name: product.name,
                             kitchenName: product.kitchenName,
                             unitPrice: product.price + (product.variants.first { $0.label == variant }?.priceDelta ?? .zero),
                             listPrice: product.price,
                             quantity: qty, variantLabel: variant, modifiers: mods,
                             note: note, seat: seat, courseID: course, status: status,
                             station: product.station,
                             addedAt: .now.addingTimeInterval(-sentAgo), addedBy: by,
                             isDrink: product.isDrink, ageRestricted: product.ageRestricted,
                             allergens: product.allergens)
        if status == .sent {
            item.sendRecords = [SendRecord(station: product.station, state: .confirmed,
                                           at: .now.addingTimeInterval(-sentAgo))]
        }
        if ready { item.readyAt = .now.addingTimeInterval(-sentAgo / 3) }
        if served { item.servedAt = .now.addingTimeInterval(-sentAgo / 4) }
        return item
    }

    static func selected(_ group: ModifierGroup, _ name: String, qty: Int = 1,
                         removal: Bool = false, portion: Double = 1) -> SelectedModifier? {
        guard let m = group.modifiers.first(where: { $0.name == name }) else { return nil }
        return SelectedModifier(groupID: group.id, groupName: group.name, modifierID: m.id,
                                name: m.name, unitPrice: m.price, quantity: qty,
                                isRemoval: removal, changesTheMake: m.changesTheMake,
                                portion: portion)
    }
}

// MARK: - Dispatch

enum Seeder {
    static func seed(for mode: BusinessMode) -> SeedBundle {
        var bundle = build(mode)
        // Timers are read constantly on the floor, the queue and the tabs list, so a seeded
        // order carries the age its items imply rather than being born the moment the app opens.
        for i in bundle.orders.indices {
            let earliest = bundle.orders[i].items.map(\.addedAt).min()
            let latest = bundle.orders[i].items.map(\.addedAt).max()
            if let earliest {
                bundle.orders[i].createdAt = earliest.addingTimeInterval(-90)
                bundle.orders[i].updatedAt = latest ?? earliest
            } else {
                bundle.orders[i].createdAt = .now.addingTimeInterval(-240)
                bundle.orders[i].updatedAt = .now.addingTimeInterval(-240)
            }
            for entry in bundle.orders[i].timeline where entry.at > .now {
                // Nothing in a seeded timeline may be in the future.
                bundle.orders[i].timeline.removeAll { $0.id == entry.id }
            }
        }
        return bundle
    }

    private static func build(_ mode: BusinessMode) -> SeedBundle {
        switch mode {
        case .cafe: CafeSeed.build()
        case .qsr: QSRSeed.build()
        case .bar: BarSeed.build()
        case .pub: PubSeed.build()
        case .fullService: FullServiceSeed.build()
        case .fineDining: FineDiningSeed.build()
        case .pizza: PizzaSeed.build()
        case .takeaway: TakeawaySeed.build()
        }
    }
}
