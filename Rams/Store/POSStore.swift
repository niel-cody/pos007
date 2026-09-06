import SwiftUI
import Observation

// MARK: - Ephemeral UI state

struct Toast: Identifiable, Equatable {
    enum Kind { case done, info, warn, stop }
    var id = UUID()
    var kind: Kind
    var text: String
    var detail: String?
    var undo: String?
}

enum Route: Identifiable, Equatable {
    case configure(productID: UUID, editing: UUID?)
    case combo(comboID: UUID, productID: UUID, editing: UUID?)
    case portions(comboID: UUID, editing: UUID?)
    case payment
    case split
    case orderDetails
    case customers
    case discountItem(itemID: UUID)
    case discountOrder
    case voidItem(itemID: UUID)
    case refund(orderID: UUID)
    case timeline(orderID: UUID)
    case tableSheet(tableID: UUID)
    case openTab
    case courses
    case seats(itemID: UUID)
    case note(itemID: UUID?)
    case openPrice(productID: UUID)
    case transfer(orderID: UUID)
    case modes
    case shiftClose
    case help

    var id: String {
        switch self {
        case .configure(let p, let e): "cfg\(p)\(e?.uuidString ?? "")"
        case .combo(let c, _, let e): "cmb\(c)\(e?.uuidString ?? "")"
        case .portions(let c, let e): "prt\(c)\(e?.uuidString ?? "")"
        case .payment: "pay"
        case .split: "split"
        case .orderDetails: "details"
        case .customers: "cust"
        case .discountItem(let i): "di\(i)"
        case .discountOrder: "do"
        case .voidItem(let i): "vi\(i)"
        case .refund(let o): "rf\(o)"
        case .timeline(let o): "tl\(o)"
        case .tableSheet(let t): "tbl\(t)"
        case .openTab: "tab"
        case .courses: "crs"
        case .seats(let i): "seat\(i)"
        case .note(let i): "note\(i?.uuidString ?? "order")"
        case .openPrice(let p): "op\(p)"
        case .transfer(let o): "tr\(o)"
        case .modes: "modes"
        case .shiftClose: "shift"
        case .help: "help"
        }
    }
}

/// Approval comes to the operator: a manager confirms on the operator's device without
/// logging the operator out. (W14.10)
struct ApprovalRequest: Identifiable, Equatable {
    var id = UUID()
    var permission: Permission
    var what: String
    var detail: String?
    var reasonRequired: Bool = false
    var reasons: [String] = []
}

struct Shift {
    var openedAt: Date = .now
    var float: Money = Money(300)
    var cashSales: Money = .zero
    var cardSales: Money = .zero
    var otherSales: Money = .zero
    var paidIn: Money = .zero
    var paidOut: Money = .zero
    var drops: Money = .zero
    var voids: Money = .zero
    var refunds: Money = .zero
    var covers: Int = 0
    var orders: Int = 0

    var expectedCash: Money { float + cashSales + paidIn - paidOut - drops }
    var netSales: Money { cashSales + cardSales + otherSales }
    var averageOrder: Money { orders == 0 ? .zero : Money(cents: netSales.cents / orders) }
}

// MARK: - Store

@Observable
final class POSStore {

    // Configuration
    var mode: BusinessMode = .cafe
    var profile: VenueProfile = .profile(for: .cafe)
    var catalogue: Catalogue = Catalogue()
    var sections: [FloorSection] = []
    var tables: [FloorTable] = []
    var stationDevices: [StationDevice] = []

    // People
    var staff: [Staff] = []
    var operatorStaff: Staff = Staff(name: "Alex Moreau", initials: "AM", role: .manager, pin: "1234")
    var customers: [Customer] = []

    // Orders
    var orders: [Order] = []
    var currentOrderID: UUID?
    var tickets: [KitchenTicket] = []
    var nextOrderNumber: Int = 1041
    var nextToken: Int = 12

    // Working state
    var surface: Surface = .sell
    var route: Route?
    var toasts: [Toast] = []
    var searchText: String = ""
    var selectedCategoryID: UUID?
    var keypadPrefix: String = ""
    var recents: [OrderItem] = []
    var pendingApproval: ApprovalRequest?
    var approvalContinuation: ((Staff, String?) -> Void)?
    var undoStack: [(order: Order, label: String)] = []
    var shift = Shift()
    var now: Date = .now

    // Demo controls: everything an investor might want to see happen on cue.
    var offline: Bool = false
    var simulatedHour: Int = 12
    var cardOutcome: CardOutcome = .approve
    var showKeyboardHints: Bool = false
    var floorSectionID: UUID?
    var courseFilterID: UUID?
    var lastRoundID: UUID?
    var upsell: UpsellOffer?

    enum CardOutcome: String, CaseIterable, Identifiable {
        case approve, decline, timeout
        var id: String { rawValue }
        var label: String {
            switch self {
            case .approve: "Approves"
            case .decline: "Declines"
            case .timeout: "Times out"
            }
        }
    }

    // MARK: - Lifecycle

    init() {
        load(mode: .cafe)
        startClock()
    }

    private func startClock() {
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = .now
                self?.advanceKitchen()
            }
        }
    }

    // MARK: - Mode

    func switchMode(_ new: BusinessMode) {
        guard new != mode else { route = nil; return }
        load(mode: new)
        route = nil
        toast(.info, "\(new.venueName)", detail: new.promise)
    }

    private func load(mode new: BusinessMode) {
        mode = new
        profile = .profile(for: new)
        let seed = Seeder.seed(for: new)
        catalogue = seed.catalogue
        sections = seed.sections
        tables = seed.tables
        customers = seed.customers
        staff = seed.staff
        operatorStaff = seed.staff.first ?? operatorStaff
        orders = seed.orders
        tickets = seed.tickets
        stationDevices = profile.stations.map {
            StationDevice(name: $0, kind: profile.kdsEnabled ? .kds : .printer)
        }
        if profile.labelPrinting {
            stationDevices.append(StationDevice(name: "Labels", kind: .label))
        }
        recents = seed.recents
        shift = seed.shift
        surface = profile.homeSurface
        selectedCategoryID = catalogue.categories.first?.id
        floorSectionID = sections.first?.id
        currentOrderID = nil
        searchText = ""
        keypadPrefix = ""
        courseFilterID = nil
        simulatedHour = seed.hour
        nextOrderNumber = (orders.map(\.number).max() ?? 1040) + 1
        nextToken = (orders.compactMap(\.token).max() ?? 11) + 1
    }

    var theme: Theme {
        Theme(palette: Palette(hue: mode.accentHue),
              dark: profile.darkPreferred,
              wet: profile.wetEnvironment)
    }

    // MARK: - Current order

    var currentOrder: Order? {
        get { currentOrderID.flatMap { id in orders.first { $0.id == id } } }
        set {
            guard let newValue else { return }
            if let i = orders.firstIndex(where: { $0.id == newValue.id }) {
                orders[i] = newValue
                orders[i].updatedAt = .now
            } else {
                orders.append(newValue)
            }
        }
    }

    func order(_ id: UUID) -> Order? { orders.first { $0.id == id } }

    func update(_ id: UUID, _ mutate: (inout Order) -> Void) {
        guard let i = orders.firstIndex(where: { $0.id == id }) else { return }
        mutate(&orders[i])
        orders[i].updatedAt = .now
        if offline { orders[i].unsynced = true }
    }

    func mutateCurrent(_ mutate: (inout Order) -> Void) {
        guard let id = currentOrderID else { return }
        update(id, mutate)
    }

    var pricingContext: PricingContext {
        PricingContext(hour: simulatedHour,
                       orderType: currentOrder?.type ?? profile.defaultOrderType,
                       channel: currentOrder?.channel ?? .pos,
                       customer: currentOrder?.customerID.flatMap { cid in customers.first { $0.id == cid } },
                       profile: profile)
    }

    // MARK: - Order lists

    var liveOrders: [Order] { orders.filter { $0.status.isLive }.sorted { $0.updatedAt > $1.updatedAt } }
    var openTabs: [Order] { liveOrders.filter(\.isTab).sorted { $0.createdAt < $1.createdAt } }
    var completedOrders: [Order] { orders.filter { $0.status == .completed || $0.status == .refunded }
        .sorted { ($0.closedAt ?? $0.updatedAt) > ($1.closedAt ?? $1.updatedAt) } }
    var onlineInbox: [Order] { orders.filter { $0.status == .placed && $0.channel != .pos }
        .sorted { $0.createdAt < $1.createdAt } }

    /// Orders that are being made and not yet handed over: the counter's own queue. (W01.26)
    var queueOrders: [Order] {
        orders.filter { o in
            guard o.type.tracksFulfilment || profile.queueBoardEnabled else { return false }
            guard let f = o.derivedFulfilment else { return false }
            return [.notStarted, .inPreparation, .ready].contains(f)
                && (o.status == .open || o.status == .completed || o.status == .held)
                && o.closedAt.map { Date.now.timeIntervalSince($0) < 3600 } ?? true
        }
        .sorted { ($0.calledAt ?? $0.createdAt) < ($1.calledAt ?? $1.createdAt) }
    }

    // MARK: - Toasts
    // Confirmation is a toast that leaves the work visible, never a modal that hides it.

    func toast(_ kind: Toast.Kind, _ text: String, detail: String? = nil, undo: String? = nil) {
        let t = Toast(kind: kind, text: text, detail: detail, undo: undo)
        toasts.append(t)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(kind == .stop ? 6 : 3.4))
            toasts.removeAll { $0.id == t.id }
        }
    }

    func dismissToast(_ id: UUID) { toasts.removeAll { $0.id == id } }

    // MARK: - Permissions and approval

    func can(_ p: Permission) -> Bool { operatorStaff.role.permissions.contains(p) }

    /// Ask for approval on this device. The operator stays logged in; the approver taps a PIN.
    func requireApproval(_ p: Permission, what: String, detail: String? = nil,
                         reasons: [String] = [], then action: @escaping (Staff, String?) -> Void) {
        if can(p) && reasons.isEmpty {
            action(operatorStaff, nil)
            return
        }
        if can(p) {
            pendingApproval = ApprovalRequest(permission: p, what: what, detail: detail,
                                              reasonRequired: true, reasons: reasons)
            approvalContinuation = action
            return
        }
        pendingApproval = ApprovalRequest(permission: p, what: what, detail: detail,
                                          reasonRequired: !reasons.isEmpty, reasons: reasons)
        approvalContinuation = action
    }

    func resolveApproval(pin: String, reason: String?) -> Bool {
        guard let req = pendingApproval else { return false }
        // The operator's own authority is enough where they hold the permission.
        if can(req.permission), pin.isEmpty || pin == operatorStaff.pin {
            approvalContinuation?(operatorStaff, reason)
            clearApproval()
            return true
        }
        guard let approver = staff.first(where: { $0.pin == pin && $0.role.permissions.contains(req.permission) })
        else { return false }
        approvalContinuation?(approver, reason)
        clearApproval()
        return true
    }

    func clearApproval() {
        pendingApproval = nil
        approvalContinuation = nil
    }

    // MARK: - Undo
    // Nothing routine needs a confirmation dialog if it can be undone instead.

    func snapshot(_ label: String) {
        guard let o = currentOrder else { return }
        undoStack.append((order: o, label: label))
        if undoStack.count > 12 { undoStack.removeFirst() }
    }

    func undoLast() {
        guard let last = undoStack.popLast() else { return }
        if let i = orders.firstIndex(where: { $0.id == last.order.id }) {
            orders[i] = last.order
        }
        toast(.info, "Undone", detail: last.label)
    }

    // MARK: - Audit

    func log(_ orderID: UUID, _ text: String, glyph: String = "circle.fill",
             approvedBy: String? = nil, notable: Bool = false) {
        update(orderID) {
            $0.timeline.append(AuditEntry(actor: operatorStaff.initials, text: text,
                                          glyph: glyph, approvedBy: approvedBy,
                                          isNotable: notable))
        }
    }
}
