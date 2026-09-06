import Foundation

// MARK: - Business mode

/// A venue is described by its service model and business type. Changing mode changes the
/// device profile, the catalogue, the working surface, the tenders and the workflows —
/// it does not rename buttons.
enum BusinessMode: String, CaseIterable, Identifiable, Codable {
    case cafe
    case qsr
    case bar
    case pub
    case fullService
    case fineDining
    case pizza
    case takeaway

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cafe: "Café"
        case .qsr: "QSR"
        case .bar: "Bar"
        case .pub: "Pub bistro"
        case .fullService: "Full service"
        case .fineDining: "Fine dining"
        case .pizza: "Pizza"
        case .takeaway: "Takeaway"
        }
    }

    var venueName: String {
        switch self {
        case .cafe: "Prospect & Grind"
        case .qsr: "Bolt Burger"
        case .bar: "The Lantern"
        case .pub: "The Royal Exchange"
        case .fullService: "Marlowe"
        case .fineDining: "Aster"
        case .pizza: "Via Norma"
        case .takeaway: "Sesame St Kitchen"
        }
    }

    var glyph: String {
        switch self {
        case .cafe: "cup.and.saucer.fill"
        case .qsr: "hare.fill"
        case .bar: "wineglass.fill"
        case .pub: "flag.pattern.checkered"
        case .fullService: "fork.knife"
        case .fineDining: "sparkles"
        case .pizza: "circle.grid.cross.fill"
        case .takeaway: "bicycle"
        }
    }

    /// One line the mode palette shows: what actually changes.
    var promise: String {
        switch self {
        case .cafe: "Coffee matrix on one sheet, names on cups, a make queue"
        case .qsr: "Combos, upsells, token numbers, kitchen packing"
        case .bar: "Tabs, rounds, repeat the round, card holds"
        case .pub: "Typed table, buzzer, drinks now and food to the kitchen"
        case .fullService: "Floor, covers, courses, hold and fire, split bills"
        case .fineDining: "Seats, pacing, call and uncall, allergens by seat"
        case .pizza: "Halves, sizes, crusts, toppings by section, delivery"
        case .takeaway: "One details sheet, the order book, aggregators"
        }
    }

    var accentHue: Double {
        switch self {
        case .cafe: 28
        case .qsr: 8
        case .bar: 268
        case .pub: 44
        case .fullService: 205
        case .fineDining: 320
        case .pizza: 355
        case .takeaway: 152
        }
    }
}

// MARK: - Surfaces

/// The working surfaces a mode exposes. A café has no floor plan; a bar has no course rail.
enum Surface: String, CaseIterable, Identifiable, Codable {
    case sell, floor, tabs, queue, orders, kitchen, online, shift

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sell: "Sell"
        case .floor: "Floor"
        case .tabs: "Tabs"
        case .queue: "Queue"
        case .orders: "Orders"
        case .kitchen: "Kitchen"
        case .online: "Inbox"
        case .shift: "Shift"
        }
    }

    var glyph: String {
        switch self {
        case .sell: "square.grid.2x2.fill"
        case .floor: "table.furniture.fill"
        case .tabs: "person.2.badge.key.fill"
        case .queue: "cup.and.heat.waves.fill"
        case .orders: "list.bullet.rectangle.portrait.fill"
        case .kitchen: "flame.fill"
        case .online: "tray.full.fill"
        case .shift: "chart.bar.fill"
        }
    }

    var shortcut: KeyEquivalentSpec { KeyEquivalentSpec(rawValue: shortcutKey) }
    var shortcutKey: String {
        switch self {
        case .sell: "1"
        case .floor: "2"
        case .tabs: "3"
        case .queue: "4"
        case .orders: "5"
        case .kitchen: "6"
        case .online: "7"
        case .shift: "8"
        }
    }
}

struct KeyEquivalentSpec { var rawValue: String }

// MARK: - Device profile

enum ServiceStateTracking: String, Codable { case fromKDS, fromStaff, off }
enum OrderIdentifierStyle: String, Codable { case none, customerName, token, tableNumber, tabName }
enum GridDensity: String, Codable, CaseIterable {
    case comfortable, standard, dense
    var columns: Int {
        switch self {
        case .comfortable: 4
        case .standard: 5
        case .dense: 6
        }
    }
}

/// The device profile. Every field here is read by the interface, so changing mode really
/// changes what the operator can do and how fast.
struct VenueProfile: Codable {
    var mode: BusinessMode
    var venueName: String
    var deviceName: String
    var sectionName: String

    // Surfaces and navigation
    var surfaces: [Surface]
    var homeSurface: Surface
    var postSaleSurface: Surface

    // Order identity
    var orderTypes: [OrderType]
    var defaultOrderType: OrderType
    var askOrderType: Bool
    var identifier: OrderIdentifierStyle
    var buzzerEnabled: Bool
    var typedTableNumber: Bool

    // Floor and service
    var floorEnabled: Bool
    var coursesEnabled: Bool
    var seatsEnabled: Bool
    var promptGuestCount: Bool
    var waiterAssignment: Bool
    var serviceStates: ServiceStateTracking
    var requireResetAfterPay: Bool
    var allergensEnabled: Bool
    var coursePlan: [String]
    var autoFireCourses: Set<String>

    // Bar
    var tabsEnabled: Bool
    var roundsEnabled: Bool
    var cardHoldsEnabled: Bool

    // Selling
    var grid: GridDensity
    var showPricesOnTiles: Bool
    var upsellEnabled: Bool
    var recentsEnabled: Bool
    var keypadPrefix: Bool
    var largeQuantityThreshold: Int
    var wetEnvironment: Bool
    var darkPreferred: Bool

    // Payment
    var quickTenders: [TenderKind]
    var allTenders: [TenderKind]
    var maxSplitPayments: Int
    var hideSplitBySeat: Bool
    var hideSplitByItem: Bool
    var tipsEnabled: Bool
    var tipPresets: [Double]
    var cashRounding: Int          // 5c, or 0 for none
    var quickPaymentMode: Bool
    var surchargePercent: Double?  // card surcharge
    var serviceChargePercent: Double?
    var serviceChargeCoverThreshold: Int?

    // Commerce
    var memberPricing: Bool
    var houseAccounts: Bool
    var loyaltyEnabled: Bool
    var deliveryEnabled: Bool
    var onlineOrdersEnabled: Bool
    var autoAcceptOwnChannel: Bool
    var channels: [SalesChannel]

    // Kitchen
    var stations: [String]
    var kdsEnabled: Bool
    var labelPrinting: Bool

    var mapsDrinksToNow: Bool      // pub: drinks poured now, food to the kitchen
    var queueBoardEnabled: Bool
}

extension VenueProfile {
    static func base(_ mode: BusinessMode) -> VenueProfile {
        VenueProfile(
            mode: mode,
            venueName: mode.venueName,
            deviceName: "Till 1",
            sectionName: "Main",
            surfaces: [.sell, .orders, .shift],
            homeSurface: .sell,
            postSaleSurface: .sell,
            orderTypes: [.dineIn, .takeaway],
            defaultOrderType: .takeaway,
            askOrderType: false,
            identifier: .none,
            buzzerEnabled: false,
            typedTableNumber: false,
            floorEnabled: false,
            coursesEnabled: false,
            seatsEnabled: false,
            promptGuestCount: false,
            waiterAssignment: false,
            serviceStates: .off,
            requireResetAfterPay: false,
            allergensEnabled: false,
            coursePlan: [],
            autoFireCourses: [],
            tabsEnabled: false,
            roundsEnabled: false,
            cardHoldsEnabled: false,
            grid: .standard,
            showPricesOnTiles: true,
            upsellEnabled: false,
            recentsEnabled: true,
            keypadPrefix: false,
            largeQuantityThreshold: 24,
            wetEnvironment: false,
            darkPreferred: false,
            quickTenders: [.cash, .card],
            allTenders: [.cash, .card, .giftCard, .voucher, .houseAccount, .other],
            maxSplitPayments: 4,
            hideSplitBySeat: true,
            hideSplitByItem: false,
            tipsEnabled: false,
            tipPresets: [5, 10, 15],
            cashRounding: 5,
            quickPaymentMode: false,
            surchargePercent: nil,
            serviceChargePercent: nil,
            serviceChargeCoverThreshold: nil,
            memberPricing: false,
            houseAccounts: false,
            loyaltyEnabled: true,
            deliveryEnabled: false,
            onlineOrdersEnabled: false,
            autoAcceptOwnChannel: true,
            channels: [.pos],
            stations: ["Kitchen"],
            kdsEnabled: false,
            labelPrinting: false,
            mapsDrinksToNow: false,
            queueBoardEnabled: false
        )
    }

    /// Each profile below is drawn from the matching venue profile in the research:
    /// its service models, its device set, its top workflows and its configuration.
    static func profile(for mode: BusinessMode) -> VenueProfile {
        var p = base(mode)
        switch mode {

        case .cafe:
            p.surfaces = [.sell, .queue, .orders, .online, .shift]
            p.homeSurface = .sell
            p.orderTypes = [.takeaway, .dineIn]
            p.defaultOrderType = .takeaway
            p.askOrderType = true
            p.identifier = .customerName
            p.grid = .standard
            p.recentsEnabled = true
            p.wetEnvironment = true
            p.quickTenders = [.card, .cash]
            p.quickPaymentMode = true
            p.loyaltyEnabled = true
            p.stations = ["Coffee", "Kitchen"]
            p.labelPrinting = true
            p.queueBoardEnabled = true
            p.onlineOrdersEnabled = true
            p.channels = [.pos, .ownWeb]
            p.upsellEnabled = true
            p.maxSplitPayments = 2

        case .qsr:
            p.surfaces = [.sell, .orders, .kitchen, .online, .shift]
            p.orderTypes = [.dineIn, .takeaway, .delivery, .driveThrough]
            p.defaultOrderType = .takeaway
            p.askOrderType = true
            p.identifier = .token
            p.grid = .comfortable
            p.upsellEnabled = true
            p.quickTenders = [.card, .cash]
            p.quickPaymentMode = true
            p.stations = ["Grill", "Fryer", "Drinks", "Expo"]
            p.kdsEnabled = true
            p.onlineOrdersEnabled = true
            p.autoAcceptOwnChannel = true
            p.channels = [.pos, .kiosk, .ownWeb, .uberEats, .doorDash]
            p.maxSplitPayments = 2
            p.hideSplitByItem = false
            p.deliveryEnabled = true

        case .bar:
            p.surfaces = [.sell, .tabs, .orders, .shift]
            p.orderTypes = [.dineIn]
            p.defaultOrderType = .dineIn
            p.askOrderType = false
            p.identifier = .tabName
            p.tabsEnabled = true
            p.roundsEnabled = true
            p.cardHoldsEnabled = true
            p.grid = .dense
            p.showPricesOnTiles = true
            p.keypadPrefix = true
            p.largeQuantityThreshold = 12
            p.wetEnvironment = true
            p.darkPreferred = true
            p.quickTenders = [.card, .cash]
            p.quickPaymentMode = true
            p.tipsEnabled = true
            p.tipPresets = [5, 10, 15]
            p.maxSplitPayments = 4
            p.stations = ["Bar"]

        case .pub:
            p.surfaces = [.sell, .orders, .kitchen, .shift]
            p.orderTypes = [.dineIn, .takeaway]
            p.defaultOrderType = .dineIn
            p.askOrderType = true
            p.identifier = .token
            p.buzzerEnabled = true
            p.typedTableNumber = true
            p.coursesEnabled = true
            p.coursePlan = ["Drinks", "Food"]
            p.autoFireCourses = ["Drinks", "Food"]
            p.mapsDrinksToNow = true
            p.tabsEnabled = true
            p.roundsEnabled = true
            p.memberPricing = true
            p.houseAccounts = true
            p.grid = .standard
            p.quickTenders = [.cash, .card]
            p.stations = ["Grill", "Larder", "Bar"]
            p.kdsEnabled = true
            p.allergensEnabled = true
            p.wetEnvironment = true

        case .fullService:
            p.surfaces = [.sell, .floor, .orders, .kitchen, .shift]
            p.homeSurface = .floor
            p.postSaleSurface = .floor
            p.orderTypes = [.dineIn, .takeaway, .delivery]
            p.defaultOrderType = .dineIn
            p.askOrderType = false
            p.identifier = .tableNumber
            p.floorEnabled = true
            p.coursesEnabled = true
            p.coursePlan = ["Drinks", "Starters", "Mains", "Dessert"]
            p.autoFireCourses = ["Drinks", "Starters"]
            p.seatsEnabled = false
            p.promptGuestCount = true
            p.waiterAssignment = true
            p.serviceStates = .fromKDS
            p.allergensEnabled = true
            p.hideSplitBySeat = true
            p.maxSplitPayments = 6
            p.tipsEnabled = true
            p.quickTenders = [.card, .cash]
            p.stations = ["Grill", "Larder", "Pass", "Bar"]
            p.kdsEnabled = true
            p.serviceChargePercent = 10
            p.serviceChargeCoverThreshold = 8
            p.requireResetAfterPay = true

        case .fineDining:
            p.surfaces = [.sell, .floor, .orders, .kitchen, .shift]
            p.homeSurface = .floor
            p.postSaleSurface = .floor
            p.orderTypes = [.dineIn]
            p.defaultOrderType = .dineIn
            p.askOrderType = false
            p.identifier = .tableNumber
            p.floorEnabled = true
            p.coursesEnabled = true
            p.coursePlan = ["Aperitif", "First", "Second", "Main", "Cheese", "Dessert"]
            p.autoFireCourses = ["Aperitif"]
            p.seatsEnabled = true
            p.promptGuestCount = true
            p.waiterAssignment = true
            p.serviceStates = .fromKDS
            p.allergensEnabled = true
            p.hideSplitBySeat = false
            p.maxSplitPayments = 8
            p.tipsEnabled = true
            p.darkPreferred = true
            p.grid = .comfortable
            p.quickTenders = [.card]
            p.stations = ["Pass", "Garde manger", "Sauce", "Pastry", "Cellar"]
            p.kdsEnabled = true
            p.serviceChargePercent = 10
            p.serviceChargeCoverThreshold = 6
            p.requireResetAfterPay = true

        case .pizza:
            p.surfaces = [.sell, .orders, .kitchen, .online, .shift]
            p.orderTypes = [.takeaway, .delivery, .dineIn]
            p.defaultOrderType = .takeaway
            p.askOrderType = true
            p.identifier = .customerName
            p.grid = .comfortable
            p.deliveryEnabled = true
            p.onlineOrdersEnabled = true
            p.channels = [.pos, .phone, .ownWeb, .menulog]
            p.quickTenders = [.cash, .card]
            p.stations = ["Make line", "Oven", "Fryer"]
            p.kdsEnabled = true
            p.labelPrinting = true
            p.upsellEnabled = true

        case .takeaway:
            p.surfaces = [.sell, .online, .orders, .kitchen, .shift]
            p.homeSurface = .online
            p.postSaleSurface = .online
            p.orderTypes = [.takeaway, .delivery, .pickup, .dineIn]
            p.defaultOrderType = .takeaway
            p.askOrderType = true
            p.identifier = .customerName
            p.deliveryEnabled = true
            p.onlineOrdersEnabled = true
            p.autoAcceptOwnChannel = true
            p.channels = [.pos, .ownWeb, .uberEats, .doorDash, .menulog, .phone]
            p.grid = .standard
            p.quickTenders = [.card, .cash]
            p.stations = ["Grill", "Fryer", "Pack"]
            p.kdsEnabled = true
            p.labelPrinting = true
            p.upsellEnabled = true
        }
        return p
    }
}

// MARK: - Floor

struct FloorSection: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var glyph: String = "square.split.bottomrightquarter"
}

enum TableShape: String, Codable { case round, square, rect, booth, barStool }

struct FloorTable: Identifiable, Hashable, Codable {
    var id = UUID()
    var label: String
    var sectionID: UUID
    var seats: Int
    var shape: TableShape = .square
    var x: Double            // 0...1 within the section
    var y: Double
    var w: Double = 1
    var h: Double = 1
    var isActive: Bool = true
    var blockedReason: String?
    var note: String?
    var reservation: Reservation?
    var resetSince: Date?
}

struct Reservation: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var partySize: Int
    var at: Date
    var notes: String?
    var seated: Bool = false
}

// MARK: - People

struct Staff: Identifiable, Hashable, Codable {
    enum Role: String, Codable, CaseIterable {
        case cashier, barista, waiter, bartender, runner, host, supervisor, manager, admin

        var label: String { rawValue.capitalized }

        /// Frequency times consequence decides the tier; role decides who may.
        var permissions: Set<Permission> {
            switch self {
            case .cashier, .barista, .runner, .host:
                return [.sell, .voidUnsent, .discountSmall]
            case .waiter, .bartender:
                return [.sell, .voidUnsent, .discountSmall, .transferTable, .assignWaiter]
            case .supervisor:
                return [.sell, .voidUnsent, .voidSent, .discountSmall, .discountAny, .comp,
                        .transferTable, .assignWaiter, .unlockOrder, .openDrawer, .priceOverride]
            case .manager, .admin:
                return Set(Permission.allCases)
            }
        }
    }

    var id = UUID()
    var name: String
    var initials: String
    var role: Role
    var pin: String
    var clockedIn: Bool = false
}

enum Permission: String, CaseIterable {
    case sell, voidUnsent, voidSent, refund, discountSmall, discountAny, comp
    case transferTable, assignWaiter, unlockOrder, openDrawer, priceOverride
    case reopenOrder, cancelPayment, removeServiceCharge, changeSettings

    var label: String {
        switch self {
        case .sell: "Sell"
        case .voidUnsent: "Remove an unsent item"
        case .voidSent: "Void a sent item"
        case .refund: "Refund"
        case .discountSmall: "Discount up to 10%"
        case .discountAny: "Any discount"
        case .comp: "Complimentary item"
        case .transferTable: "Transfer a table"
        case .assignWaiter: "Assign a waiter"
        case .unlockOrder: "Unlock an order"
        case .openDrawer: "Open the drawer"
        case .priceOverride: "Override a price"
        case .reopenOrder: "Reopen an order"
        case .cancelPayment: "Cancel a payment"
        case .removeServiceCharge: "Remove a service charge"
        case .changeSettings: "Change settings"
        }
    }
}

struct Customer: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var phone: String
    var email: String?
    var loyaltyPoints: Int = 0
    var isMember: Bool = false
    var memberNumber: String?
    var group: String?                 // Seniors, Staff, Wholesale
    var houseAccountBalance: Money?
    var houseAccountLimit: Money?
    var allergyNote: String?
    var note: String?
    var isVIP: Bool = false
    var birthday: String?
    var address: String?
    var deliveryInstructions: String?
    var usualOrderProductNames: [String] = []
    var visits: Int = 0
    var lastVisit: Date?
    var marketingOptIn: Bool = false

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
