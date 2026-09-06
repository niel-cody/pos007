import Foundation

// MARK: - Courses

struct Course: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String              // Drinks, Starters, Mains, Dessert
    var index: Int
    /// Off means items land Held and wait for a deliberate fire. (Canonical §2.3)
    var autoFire: Bool
    var isDessert: Bool = false
    var calledAt: Date?
    var firedAt: Date?

    var glyph: String {
        switch name.lowercased() {
        case let n where n.contains("drink"): "wineglass"
        case let n where n.contains("start"), let n where n.contains("entr"): "leaf"
        case let n where n.contains("main"): "fork.knife"
        case let n where n.contains("dessert"): "birthday.cake"
        default: "circle.grid.2x2"
        }
    }
}

// MARK: - Portion selections (half-and-half)

struct PortionSelection: Identifiable, Hashable, Codable {
    var id = UUID()
    var slotName: String          // "Left half"
    var productID: UUID
    var productName: String
    var basePrice: Money
    var modifiers: [SelectedModifier] = []
}

// MARK: - Order item

struct OrderItem: Identifiable, Hashable, Codable {
    var id = UUID()
    var productID: UUID
    var name: String
    var kitchenName: String?
    var unitPrice: Money                 // resolved at add time by the pricing engine
    var listPrice: Money                 // what it would have been without price rules
    var quantity: Int = 1
    var variantLabel: String?
    var modifiers: [SelectedModifier] = []
    var portions: [PortionSelection] = []
    var comboName: String?
    var comboChildren: [OrderItem] = []
    var comboPricingRule: ComboPricingRule?
    var note: String?
    var seat: Int?
    var courseID: UUID?
    var status: OrderItemStatus = .unsent
    var sendRecords: [SendRecord] = []
    var station: String = "Kitchen"
    var readyAt: Date?
    var servedAt: Date?
    var addedAt: Date = .now
    var addedBy: String = ""
    var roundID: UUID?                   // the Add-to-tab boundary that groups a round
    var adjustments: [Adjustment] = []
    var voidReason: String?
    var isDrink: Bool = false
    var ageRestricted: Bool = false
    var allergens: [String] = []
    var weight: Double?
    var source: String = "manual"        // "repeat_round", "usual", "online"
    var refundedQuantity: Int = 0

    var displayName: String { kitchenName ?? name }

    /// Modifiers charged once per line, matching the current product's tested behaviour.
    var modifierTotal: Money { modifiers.map(\.total).total }

    var portionBase: Money {
        guard !portions.isEmpty, let rule = comboPricingRule else { return .zero }
        let bases = portions.map(\.basePrice)
        switch rule {
        case .highest: return bases.max() ?? .zero
        case .proRata: return Money(cents: bases.map { $0.cents / 2 }.reduce(0, +))
        case .fixed: return .zero
        }
    }

    var portionModifierTotal: Money {
        portions.flatMap(\.modifiers).map(\.total).total
    }

    var comboChildrenTotal: Money {
        comboChildren.map { $0.unitPrice + $0.modifierTotal }.total
    }

    /// Gross before adjustments.
    var gross: Money {
        let each = unitPrice + modifierTotal + portionBase + portionModifierTotal + comboChildrenTotal
        return each * quantity
    }

    var adjustmentTotal: Money { adjustments.map(\.amount).total }
    var lineTotal: Money { gross + adjustmentTotal }
    var eachTotal: Money { quantity == 0 ? .zero : Money(cents: lineTotal.cents / quantity) }

    // MARK: derived send state (Canonical §2.2)

    var sendState: ItemSendState {
        switch status {
        case .held: return .held
        case .unsent, .draft:
            return sendRecords.isEmpty ? .unsent : sendStateFromRecords
        default:
            return sendStateFromRecords
        }
    }

    private var sendStateFromRecords: ItemSendState {
        if let confirmed = sendRecords.first(where: { $0.state == .confirmed }) {
            return .sent(confirmed.at)
        }
        if sendRecords.allSatisfy({ $0.state == .failed }), let f = sendRecords.first {
            return .notSent(reason: f.failureReason ?? "Not printed")
        }
        if sendRecords.contains(where: { $0.state == .scheduled }) {
            let oldest = sendRecords.filter { $0.state == .scheduled }.map(\.at).min() ?? .now
            return Date.now.timeIntervalSince(oldest) > 20 ? .notConfirmed : .sending
        }
        return .unsent
    }

    var isSentOrLater: Bool {
        if case .sent = sendState { return true }
        if case .notConfirmed = sendState { return true }
        if case .notSent = sendState { return true }
        return status == .sent
    }

    var isLive: Bool {
        switch status {
        case .cancelled, .voided, .transferred, .merged, .refunded: false
        default: true
        }
    }
    var isReady: Bool { readyAt != nil }
    var isServed: Bool { servedAt != nil }

    /// The merge key: identical unsent lines collapse. (mergeIdenticalOrderItems)
    var mergeKey: String {
        let mods = modifiers.sorted { $0.name < $1.name }
            .map { "\($0.modifierID)x\($0.quantity)\($0.isRemoval)" }.joined(separator: "|")
        return [productID.uuidString, variantLabel ?? "", mods, note ?? "",
                seat.map(String.init) ?? "", courseID?.uuidString ?? "",
                portions.map(\.productName).joined(separator: "/")].joined(separator: "~")
    }

    /// The one-line summary a cart shows under the name.
    var configurationSummary: String {
        var parts: [String] = []
        if let v = variantLabel { parts.append(v) }
        parts.append(contentsOf: modifiers.map(\.label))
        parts.append(contentsOf: comboChildren.map(\.name))
        if let n = note { parts.append("“\(n)”") }
        return parts.joined(separator: " · ")
    }

    /// Only what changes the make reaches a queue card. (W01.26 step 3)
    var makeSummary: String {
        var parts: [String] = []
        if let v = variantLabel { parts.append(v) }
        parts.append(contentsOf: modifiers.filter(\.changesTheMake).map(\.label))
        return parts.joined(separator: ", ")
    }
}

// MARK: - Customer-facing detail blocks

struct DeliveryDetails: Hashable, Codable {
    var address: String = ""
    var instructions: String = ""
    var zone: String = ""
    var fee: Money = .zero
    var driver: String?
    var failureReason: String?
    var resolution: String?
}

struct AuditEntry: Identifiable, Hashable, Codable {
    var id = UUID()
    var at: Date = .now
    var actor: String
    var text: String
    var glyph: String = "circle"
    var approvedBy: String?
    var isNotable: Bool = false
}

// MARK: - Split plan (Canonical §5.3)

enum SplitMode: String, Codable, CaseIterable, Identifiable {
    case equal, amount, percentage, items, seats
    var id: String { rawValue }
    var label: String {
        switch self {
        case .equal: "Equal"
        case .amount: "Amount"
        case .percentage: "Percent"
        case .items: "Items"
        case .seats: "Seats"
        }
    }
    var glyph: String {
        switch self {
        case .equal: "equal.circle"
        case .amount: "dollarsign.circle"
        case .percentage: "percent"
        case .items: "list.bullet"
        case .seats: "chair.lounge"
        }
    }
}

enum PortionState: String, Codable {
    case unpaid, tendering, partPaid, paid
    var label: String {
        switch self {
        case .unpaid: "Unpaid"
        case .tendering: "Tendering"
        case .partPaid: "Part paid"
        case .paid: "Paid"
        }
    }
}

struct ItemShare: Identifiable, Hashable, Codable {
    var id = UUID()
    var itemID: UUID
    var quantity: Int          // how many units of that line belong to this portion
    var fraction: Double = 1   // a shared bottle divided across four seats
}

struct SplitPortion: Identifiable, Hashable, Codable {
    var id = UUID()
    var label: String
    var amount: Money
    var shares: [ItemShare] = []
    var state: PortionState = .unpaid
    var paid: Money = .zero
    var customerName: String?
    var seat: Int?

    var remaining: Money { max(.zero, amount - paid) }
}

struct SplitPlan: Hashable, Codable {
    var mode: SplitMode
    var portions: [SplitPortion] = []
    /// Mixing modes is allowed: the mode lock is removed. (W09.12)
    var modesUsed: Set<SplitMode> = []
    var createdAt: Date = .now

    var allocated: Money { portions.map(\.amount).total }
    var paid: Money { portions.map(\.paid).total }
    var nextUnpaidIndex: Int? { portions.firstIndex { $0.state != .paid } }
}

// MARK: - Order

struct Order: Identifiable, Hashable, Codable {
    var id = UUID()
    var number: Int
    var token: Int?
    var name: String?                 // the name on the cup, or the tab name
    var type: OrderType
    var status: OrderStatus = .draft
    var channel: SalesChannel = .pos
    var items: [OrderItem] = []
    var courses: [Course] = []
    var tableID: UUID?
    var tableLabel: String?
    var typedTableNumber: String?     // dine-in without table management (W03.03)
    var buzzer: String?
    var guestCount: Int?
    var seatCount: Int = 0
    var waiter: String?
    var customerID: UUID?
    var customerName: String?
    var payments: [PaymentLeg] = []
    var splitPlan: SplitPlan?
    var adjustments: [Adjustment] = []
    var fulfilment: FulfilmentStatus?
    var handoverType: HandoverType?
    var lock: OrderLock?
    var tabAuth: TabAuthorisation?
    var spendLimit: Money?
    var delivery: DeliveryDetails?
    var dueAt: Date?                  // scheduled pickup or delivery
    var phone: String?
    var orderNote: String?
    var timeline: [AuditEntry] = []
    var createdAt: Date = .now
    var updatedAt: Date = .now
    var closedAt: Date?
    var openedBy: String = ""
    var isTraining: Bool = false
    var unsynced: Bool = false
    var billPrintedAt: Date?
    var billRequested: Bool = false
    var roomNumber: String?
    var isRefund: Bool = false
    var refundsOrderID: UUID?
    var prepMinutes: Int?
    var partnerReference: String?
    var calledAt: Date?

    // MARK: derived

    var liveItems: [OrderItem] { items.filter(\.isLive) }
    var itemCount: Int { liveItems.reduce(0) { $0 + $1.quantity } }

    var subtotal: Money { liveItems.map(\.lineTotal).total }
    var orderAdjustmentTotal: Money { adjustments.map(\.amount).total }
    var total: Money { max(.zero, subtotal + orderAdjustmentTotal) }

    /// GST is included in Australian shelf prices, so tax is derived, never added.
    var gstIncluded: Money { Money(cents: Int((Double(total.cents) / 11.0).rounded())) }

    var paidTotal: Money { payments.filter { $0.state == .complete }.map(\.amount).total }
    var surchargeTotal: Money { payments.filter { $0.state == .complete }.map(\.surcharge).total }
    var tipTotal: Money { payments.filter { $0.state == .complete }.map(\.tip).total }
    var roundingTotal: Money { payments.filter { $0.state == .complete }.map(\.rounding).total }
    var amountDue: Money { total - paidTotal }
    var hasPendingLeg: Bool { payments.contains { $0.state == .pending } }

    var paymentState: OrderPaymentState {
        if isRefund || status == .refunded { return .refunded }
        if payments.contains(where: { $0.state == .complete && $0.settlementPending }),
           amountDue.cents <= 1 { return .settlementPending }
        if amountDue.cents <= 1 { return paidTotal.isZero && total.isZero ? .unpaid : .paid }
        return paidTotal.isZero ? .unpaid : .partPaid
    }

    var unsentItems: [OrderItem] { liveItems.filter { $0.status == .unsent } }
    var heldItems: [OrderItem] { liveItems.filter { $0.status == .held } }
    var sentItems: [OrderItem] { liveItems.filter(\.isSentOrLater) }
    var sendableCount: Int { unsentItems.reduce(0) { $0 + $1.quantity } }
    var hasAttention: Bool { liveItems.contains { $0.sendState.needsAttention } }

    /// Canonical §3: order-level fulfilment derived from its items.
    var derivedFulfilment: FulfilmentStatus? {
        guard type.tracksFulfilment else { return fulfilment }
        if let f = fulfilment, [.handedOver, .failed, .resolved].contains(f) { return f }
        let sent = sentItems
        guard !sent.isEmpty else { return .notStarted }
        if sent.allSatisfy(\.isReady) && unsentItems.isEmpty && heldItems.isEmpty { return .ready }
        return .inPreparation
    }

    var isTab: Bool { name != nil && tableID == nil && type == .dineIn }

    var identifierLabel: String {
        if let n = name, !n.isEmpty { return n }
        if let t = token { return "#\(t)" }
        if let l = tableLabel { return l }
        if let t = typedTableNumber { return "Table \(t)" }
        return "Order \(number)"
    }

    func course(_ id: UUID?) -> Course? { courses.first { $0.id == id } }

    func items(inCourse id: UUID) -> [OrderItem] { liveItems.filter { $0.courseID == id } }

    var rounds: [(id: UUID, items: [OrderItem], at: Date)] {
        let grouped = Dictionary(grouping: liveItems.filter { $0.roundID != nil }) { $0.roundID! }
        return grouped.map { (id: $0.key, items: $0.value.sorted { $0.addedAt < $1.addedAt },
                              at: $0.value.map(\.addedAt).min() ?? .now) }
            .sorted { $0.at > $1.at }
    }

    var seatsUsed: [Int] { Array(Set(liveItems.compactMap(\.seat))).sorted() }
}
