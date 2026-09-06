import Foundation

// MARK: - Modifiers

enum ModifierSelection: String, Codable {
    case single       // min 1 max 1 — radio behaviour
    case multi        // min 0 max n
    case quantity     // the same modifier several times (extra shot x2, 3 sugars)
}

struct Modifier: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var kitchenName: String?
    var price: Money = .zero
    var isDefault: Bool = false
    var soldOut: Bool = false
    var pinned: Bool = false      // shown before the long tail (W02.03.f)
    var maxPerOption: Int = 1     // 4 sugars
    var allergens: [String] = []
    /// Changes what the maker does, so it belongs on a queue card. (W01.26 step 3)
    var changesTheMake: Bool = true

    var displayName: String { kitchenName ?? name }
}

struct ModifierGroup: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var selection: ModifierSelection = .multi
    var min: Int = 0
    var max: Int = 0              // zero means unlimited
    var modifiers: [Modifier] = []
    var freeFirstUnit: Bool = false
    /// A group of eighteen syrups needs search; a group of three does not. (W02.03.f)
    var needsSearch: Bool { modifiers.count > 10 }
    var isRequired: Bool { min >= 1 }

    var effectiveMax: Int { max == 0 ? modifiers.count : max }
}

struct SelectedModifier: Identifiable, Hashable, Codable {
    var id = UUID()
    var groupID: UUID
    var groupName: String
    var modifierID: UUID
    var name: String
    var unitPrice: Money
    var quantity: Int = 1
    /// A default that was toggled off prints as "- Name" on the docket. (W02.04)
    var isRemoval: Bool = false
    var soldOut: Bool = false
    var changesTheMake: Bool = true
    /// Fraction of the product this applies to: 1 for whole, 0.5 for one half of a pizza. (W02.14)
    var portion: Double = 1

    var total: Money { isRemoval ? .zero : unitPrice * quantity }

    var label: String {
        if isRemoval { return "no \(name)" }
        var s = quantity > 1 ? "\(quantity)× \(name)" : name
        if portion < 1 { s += " (½)" }
        return s
    }
}

// MARK: - Variants

struct VariantOption: Identifiable, Hashable, Codable {
    var id = UUID()
    var label: String            // Small / Regular / Large
    var priceDelta: Money = .zero
    var isDefault: Bool = false
    var soldOut: Bool = false
}

// MARK: - Combos and portions

enum ComboPricingRule: String, Codable {
    case highest     // addonPrice plus the dearest part — the Australian half-and-half rule
    case proRata     // half of each
    case fixed       // combo price plus option prices

    /// The rule stated in words so the operator can answer "why is it that much". (W02.14 step 3)
    var explanation: String {
        switch self {
        case .highest: "Priced at the dearer half"
        case .proRata: "Priced at half of each"
        case .fixed: "Fixed combo price"
        }
    }
}

struct ComboSlot: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String             // Main / Side / Drink, or Left half / Right half
    var productIDs: [UUID]
    var defaultProductID: UUID?
    var upgradePrices: [UUID: Money] = [:]   // swap the drink for a shake, +1.50
}

enum ComboKind: String, Codable {
    case meal        // main + side + drink
    case portion     // sections of one product: half-and-half
}

struct Combo: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var kind: ComboKind
    var slots: [ComboSlot]
    var addonPrice: Money = .zero
    var pricingRule: ComboPricingRule = .fixed
    var fixedPrice: Money = .zero
    /// A whole-pizza group that prints once, above the section blocks. (W02.14.b)
    var wholeGroups: [ModifierGroup] = []
    var sectionGroups: [ModifierGroup] = []
}

// MARK: - Products

struct Product: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var kitchenName: String?
    var price: Money
    var categoryID: UUID
    var station: String = "Kitchen"
    var glyph: String = "circle.fill"
    var accent: Int = 0                    // index into the palette's product hues
    var variantAxisName: String?           // "Size"
    var variants: [VariantOption] = []
    var groups: [ModifierGroup] = []
    var comboID: UUID?                     // this tile builds a combo
    var upsellComboIDs: [UUID] = []        // "make it a meal"
    var upsellModifierNames: [String] = [] // "add a shot of vanilla"
    var soldOut: Bool = false
    var trackedQuantity: Int?              // last six sourdough
    var ageRestricted: Bool = false
    var openPriced: Bool = false
    var weighed: Bool = false
    var allergens: [String] = []
    var isDrink: Bool = false
    var courseHint: String?                // "Mains", "Drinks"
    var favourite: Bool = false
    var barcode: String?

    var displayName: String { kitchenName ?? name }
    var hasChoices: Bool { !variants.isEmpty || !groups.isEmpty || comboID != nil }
    var requiresChoice: Bool {
        if comboID != nil { return true }
        return groups.contains { group in
            group.isRequired && group.modifiers.filter(\.isDefault).count < group.min
        }
    }
    var isAvailable: Bool { !soldOut && (trackedQuantity ?? 1) > 0 }
}

struct Category: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var glyph: String = "square.grid.2x2"
    var accent: Int = 0
}

// MARK: - Promotions and price lists

enum PromotionKind: Codable, Hashable {
    case percentOff(Double)
    case amountOff(Money)
    case fixedPrice(Money)
    case buyXGetY(buy: Int, free: Int)
    case thresholdAmountOff(spend: Money, off: Money)
    case bundleFixed(productNames: [String], price: Money)
}

struct Promotion: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var kind: PromotionKind
    var categoryIDs: [UUID] = []
    var productIDs: [UUID] = []
    /// Local hours; nil means always on. Happy hour is a schedule, not a discount. (W07.08)
    var fromHour: Int?
    var toHour: Int?
    var priority: Int = 0
    var stacks: Bool = false
    var orderTypes: [OrderType] = []
    var memberOnly: Bool = false
    /// Customer groups this price list applies to: Seniors, Staff, Wholesale.
    var groups: [String] = []
    var channels: [SalesChannel] = []

    func activeNow(hour: Int) -> Bool {
        guard let f = fromHour, let t = toHour else { return true }
        return hour >= f && hour < t
    }
}

// MARK: - Adjustments (the "why the price changed" record)

enum AdjustmentKind: String, Codable {
    case discountPercent, discountAmount, priceOverride, comp
    case promotion, memberPrice, loyaltyReward, voucher
    case surcharge, serviceCharge, deliveryFee, roundingAdj
}

struct Adjustment: Identifiable, Hashable, Codable {
    var id = UUID()
    var kind: AdjustmentKind
    var name: String              // "Seniors 10%", "Happy hour", "Public holiday 15%"
    var amount: Money             // signed: negative reduces
    var percent: Double?
    var reason: String?
    var approvedBy: String?
    var automatic: Bool = false
    var appliedBy: String = ""
    var at: Date = .now

    var isReduction: Bool { amount.cents < 0 }
    var explanation: String {
        if let p = percent { return "\(name) · \(Int(p))%" }
        return name
    }
}

// MARK: - Catalogue container

struct Catalogue {
    var categories: [Category] = []
    var products: [Product] = []
    var combos: [Combo] = []
    var promotions: [Promotion] = []

    func product(_ id: UUID) -> Product? { products.first { $0.id == id } }
    func combo(_ id: UUID) -> Combo? { combos.first { $0.id == id } }
    func category(_ id: UUID) -> Category? { categories.first { $0.id == id } }
    func products(in category: UUID) -> [Product] { products.filter { $0.categoryID == category } }
    func product(named name: String) -> Product? { products.first { $0.name == name } }
}
