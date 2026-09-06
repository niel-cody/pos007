import Foundation

// MARK: - Canonical Model §1: Order status
// "Can this order still be traded, and how did it end." Nothing about food, nothing about money
// beyond the fact of closure.

enum OrderStatus: String, Codable, CaseIterable {
    case draft          // a cart on this device only
    case placed         // persisted, nothing sent to a station
    case open           // items sent, or an online order accepted
    case held           // parked: a bistro pay-first order, or a whole order put aside
    case completed      // amount due reached zero
    case voided
    case cancelled
    case refunded
    case merged

    var isEditable: Bool { [.draft, .placed, .open, .held].contains(self) }
    var isLive: Bool { [.placed, .open, .held].contains(self) }

    var label: String {
        switch self {
        case .draft: "Draft"
        case .placed: "Placed"
        case .open: "Open"
        case .held: "Held"
        case .completed: "Completed"
        case .voided: "Voided"
        case .cancelled: "Cancelled"
        case .refunded: "Refunded"
        case .merged: "Merged"
        }
    }
}

// MARK: - Canonical Model §2: Order item status

enum OrderItemStatus: String, Codable {
    case draft
    case unsent        // in a course that fires now
    case held          // in a course whose auto-fire is off, or held explicitly
    case sent          // a station has it
    case completed
    case cancelled     // removed before the kitchen ever saw it
    case voided        // removed after the kitchen saw it — wastage
    case transferred
    case merged
    case refunded
}

/// §2.2 Sent is station-confirmed, never optimistic. One record per station the item routed to.
struct SendRecord: Identifiable, Codable, Hashable {
    enum State: String, Codable { case scheduled, confirmed, failed }
    var id = UUID()
    var station: String
    var state: State = .scheduled
    var at: Date = .now
    var failureReason: String?
}

/// §2.2 The derived display state. This, not the stored status, is what the line shows.
enum ItemSendState: Equatable {
    case unsent
    case held
    case sending
    case sent(Date)
    case notConfirmed
    case notSent(reason: String)

    var label: String {
        switch self {
        case .unsent: "Unsent"
        case .held: "Held"
        case .sending: "Sending"
        case .sent(let at): "Sent \(at.hhmm)"
        case .notConfirmed: "Not confirmed"
        case .notSent(let reason): reason
        }
    }

    var needsAttention: Bool {
        switch self {
        case .notConfirmed, .notSent: true
        default: false
        }
    }
}

// MARK: - Canonical Model §3: Fulfilment status (a field on the order, orthogonal to order status)

enum FulfilmentStatus: String, Codable, CaseIterable {
    case notStarted
    case inPreparation
    case ready
    case handedOver
    case failed
    case resolved

    var label: String {
        switch self {
        case .notStarted: "Not started"
        case .inPreparation: "Making"
        case .ready: "Ready"
        case .handedOver: "Handed over"
        case .failed: "Failed"
        case .resolved: "Resolved"
        }
    }
}

enum HandoverType: String, Codable { case guest, driver, table, courier }

// MARK: - Canonical Model §4: Table status (sixteen states, derived from events)

enum TableState: String, Codable, CaseIterable, Identifiable {
    case vacant, reserved, seated, ordering, ordered, cooking, ready
    case partlyServed, served, dessert, billRequested, partlyPaid, paid, reset, blocked

    var id: String { rawValue }

    /// Never colour alone. (W21.02)
    var word: String {
        switch self {
        case .vacant: "Available"
        case .reserved: "Reserved"
        case .seated: "Seated"
        case .ordering: "Ordering"
        case .ordered: "Ordered"
        case .cooking: "Cooking"
        case .ready: "Ready"
        case .partlyServed: "Part served"
        case .served: "Served"
        case .dessert: "Dessert"
        case .billRequested: "Bill requested"
        case .partlyPaid: "Part paid"
        case .paid: "Paid"
        case .reset: "Reset"
        case .blocked: "Blocked"
        }
    }

    /// A glyph so state survives colour blindness and glare.
    var glyph: String {
        switch self {
        case .vacant: "circle.dotted"
        case .reserved: "calendar"
        case .seated: "person.2.fill"
        case .ordering: "pencil.line"
        case .ordered: "arrow.up.circle.fill"
        case .cooking: "flame.fill"
        case .ready: "bell.fill"
        case .partlyServed: "circle.lefthalf.filled"
        case .served: "checkmark.circle.fill"
        case .dessert: "birthday.cake.fill"
        case .billRequested: "doc.text.fill"
        case .partlyPaid: "circle.bottomhalf.filled"
        case .paid: "dollarsign.circle.fill"
        case .reset: "sparkles"
        case .blocked: "xmark.circle.fill"
        }
    }

    var isOccupied: Bool { ![.vacant, .reserved, .blocked, .reset].contains(self) }

    /// Order used by the legend and by the "most advanced state" rule for multi-order tables.
    var advancement: Int { TableState.allCases.firstIndex(of: self) ?? 0 }
}

// MARK: - Canonical Model §5: Payments

enum TenderKind: String, Codable, CaseIterable, Identifiable {
    case cash, card, manualCard, giftCard, voucher, loyalty, houseAccount, roomCharge, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cash: "Cash"
        case .card: "Card"
        case .manualCard: "Manual card"
        case .giftCard: "Gift card"
        case .voucher: "Voucher"
        case .loyalty: "Points"
        case .houseAccount: "Account"
        case .roomCharge: "Room"
        case .other: "Other"
        }
    }

    var glyph: String {
        switch self {
        case .cash: "banknote"
        case .card: "creditcard"
        case .manualCard: "creditcard.trianglebadge.exclamationmark"
        case .giftCard: "giftcard"
        case .voucher: "ticket"
        case .loyalty: "star.circle"
        case .houseAccount: "building.columns"
        case .roomCharge: "bed.double"
        case .other: "ellipsis.circle"
        }
    }

    /// Anything that does not need a third party works offline. (Offline is a mode, not an error.)
    var worksOffline: Bool {
        switch self {
        case .cash, .manualCard, .houseAccount, .roomCharge, .other: true
        case .card, .giftCard, .voucher, .loyalty: false
        }
    }
}

enum PaymentLegState: String, Codable {
    case pending, complete, rejected, reversed, cancelled

    var label: String {
        switch self {
        case .pending: "Pending"
        case .complete: "Paid"
        case .rejected: "Declined"
        case .reversed: "Reversed"
        case .cancelled: "Cancelled"
        }
    }
}

struct PaymentLeg: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: TenderKind
    var amount: Money            // what settles against the order
    var surcharge: Money = .zero // charged on top, on this leg only
    var tip: Money = .zero
    var rounding: Money = .zero  // cash rounding on this leg only
    var tendered: Money?         // cash handed over
    var state: PaymentLegState = .complete
    var at: Date = .now
    var staff: String = ""
    var reference: String?
    var portionID: UUID?
    var settlementPending: Bool = false   // on-account leg: order is Completed, money is not in
    var offlineCaptured: Bool = false

    var change: Money { max(.zero, (tendered ?? amount) - amount) }
    var collected: Money { amount + surcharge + tip }
}

/// §5.1 Derived on the order from its legs. Never an OrderStatus value.
enum OrderPaymentState: String {
    case unpaid, partPaid, paid, settlementPending, refunded

    var label: String {
        switch self {
        case .unpaid: "Unpaid"
        case .partPaid: "Part paid"
        case .paid: "Paid"
        case .settlementPending: "On account"
        case .refunded: "Refunded"
        }
    }
}

/// §5.4 An authorisation is not a payment. It never appears in payments[] until captured.
struct TabAuthorisation: Codable, Hashable {
    enum State: String, Codable {
        case requested, authorised, expiring, expired, captured, partlyCaptured, released, failed
        var label: String {
            switch self {
            case .requested: "Authorising"
            case .authorised: "Card held"
            case .expiring: "Hold expiring"
            case .expired: "Hold expired"
            case .captured: "Captured"
            case .partlyCaptured: "Part captured"
            case .released: "Released"
            case .failed: "Hold failed"
            }
        }
    }
    var state: State = .requested
    var amount: Money
    var last4: String
    var scheme: String
    var at: Date = .now
}

// MARK: - Canonical Model §6: Lock
// The lock blocks payment, transfer, merge and whole-order void. It never blocks reading or
// ordinary item editing. It expires by itself.

struct OrderLock: Codable, Hashable {
    var holder: String
    var device: String
    var takenAt: Date
    var expiresAt: Date
    var hasPendingCardLeg: Bool = false

    var isLive: Bool { expiresAt > .now }
    var freesIn: String { expiresAt.countdown }
}

// MARK: - Order types and channels

enum OrderType: String, Codable, CaseIterable, Identifiable {
    case dineIn, takeaway, delivery, pickup, driveThrough, roomService

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dineIn: "Dine in"
        case .takeaway: "Takeaway"
        case .delivery: "Delivery"
        case .pickup: "Pickup"
        case .driveThrough: "Drive-through"
        case .roomService: "Room service"
        }
    }

    var short: String {
        switch self {
        case .dineIn: "Dine"
        case .takeaway: "Take"
        case .delivery: "Deliver"
        case .pickup: "Pickup"
        case .driveThrough: "Lane"
        case .roomService: "Room"
        }
    }

    var glyph: String {
        switch self {
        case .dineIn: "fork.knife"
        case .takeaway: "bag"
        case .delivery: "bicycle"
        case .pickup: "clock.badge.checkmark"
        case .driveThrough: "car.fill"
        case .roomService: "bed.double.fill"
        }
    }

    var tracksFulfilment: Bool {
        switch self {
        case .dineIn: false
        default: true
        }
    }
}

enum SalesChannel: String, Codable, CaseIterable {
    case pos, kiosk, ownWeb, uberEats, doorDash, menulog, phone

    var label: String {
        switch self {
        case .pos: "POS"
        case .kiosk: "Kiosk"
        case .ownWeb: "Web"
        case .uberEats: "Uber Eats"
        case .doorDash: "DoorDash"
        case .menulog: "Menulog"
        case .phone: "Phone"
        }
    }

    var isPartner: Bool { [.uberEats, .doorDash, .menulog].contains(self) }
}

// MARK: - Small shared helpers

extension Date {
    var hhmm: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: self)
    }

    /// "4m", "1h 12m" — the compact timer on a table tile or a queue card.
    var elapsedShort: String {
        let s = Int(Date.now.timeIntervalSince(self))
        if s < 60 { return "\(max(0, s))s" }
        let m = s / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }

    var countdown: String {
        let s = max(0, Int(timeIntervalSince(.now)))
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }
}
