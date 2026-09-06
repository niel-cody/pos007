import Foundation

/// Reason codes. A void or a refund without a reason is a hole in the audit trail, and a
/// free-text box at a busy till is a hole with extra steps.
enum VoidReasons {
    static let unsent = ["Customer changed their mind", "Rang up in error", "Duplicate line"]
    static let sent = ["Customer changed their mind", "Wrong item made", "Rang up in error",
                       "Item unavailable", "Quality — sent back", "Spillage or breakage"]
    static let order = ["Customer left", "Rang up in error", "Duplicate order",
                        "Kitchen cannot make it", "Test order"]
    static let refund = ["Wrong item", "Quality complaint", "Order cancelled",
                         "Overcharged", "Duplicate payment", "Goodwill"]
    static let wastage = ["Spillage", "Breakage", "Wrong drink made", "Dropped", "Out of date"]
    static let discount = ["Service recovery", "Regular customer", "Staff", "Seniors",
                           "Promotion not scanning", "Manager’s discretion"]
    static let deliveryFailure = ["Customer unavailable", "Address wrong",
                                  "Refused on delivery", "Damaged in transit"]
}

enum NamedDiscounts {
    static let all: [(String, Double)] = [
        ("Staff", 30), ("Seniors", 10), ("Member", 10), ("Manager", 20), ("House", 15)
    ]
}
