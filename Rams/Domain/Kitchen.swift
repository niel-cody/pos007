import Foundation

enum TicketState: String, Codable {
    case waiting, started, ready, recalled, served, cancelled

    var label: String {
        switch self {
        case .waiting: "New"
        case .started: "Working"
        case .ready: "Ready"
        case .recalled: "Recalled"
        case .served: "Served"
        case .cancelled: "Cancelled"
        }
    }
}

struct KitchenLine: Identifiable, Hashable, Codable {
    var id = UUID()
    var itemID: UUID
    var name: String
    var quantity: Int
    var modifiers: [String]
    var removals: [String]
    var note: String?
    var allergens: [String]
    var seat: Int?
    var portionBlocks: [PortionBlock] = []
    var isReady: Bool = false
}

/// A labelled block on a docket: "LEFT: Margherita" with its own toppings. (W02.14 step 6)
struct PortionBlock: Identifiable, Hashable, Codable {
    var id = UUID()
    var label: String
    var lines: [String]
}

struct KitchenTicket: Identifiable, Hashable, Codable {
    var id = UUID()
    var orderID: UUID
    var orderLabel: String
    var typeLabel: String
    var station: String
    var courseName: String?
    var lines: [KitchenLine]
    var state: TicketState = .waiting
    var receivedAt: Date = .now
    var startedAt: Date?
    var readyAt: Date?
    var isRush: Bool = false
    var isVoidDocket: Bool = false
    var isAddition: Bool = false
    var channel: SalesChannel = .pos
    var tableLabel: String?
    var covers: Int?
    var buzzer: String?

    var age: String { receivedAt.elapsedShort }
    var ageSeconds: Int { Int(Date.now.timeIntervalSince(receivedAt)) }

    /// The kitchen's own attention rule: a ticket that has waited too long.
    func isLate(target: Int) -> Bool { state != .ready && ageSeconds > target }
}

/// A printer or KDS station, and whether it is reachable. Offline is a mode, not an error.
struct StationDevice: Identifiable, Hashable, Codable {
    enum Kind: String, Codable { case printer, kds, label }
    var id = UUID()
    var name: String
    var kind: Kind
    var online: Bool = true
    var queuedDockets: Int = 0
}
