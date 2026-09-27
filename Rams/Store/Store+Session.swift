import SwiftUI

/// What the operator sees for the few seconds between taking the money and handing the till
/// to whoever is next.
struct SaleSummary: Equatable {
    var orderLabel: String
    var total: Money
    var change: Money
    var tenders: [String]
    var itemCount: Int
    var operatorName: String
    var operatorInitials: String
    var at: Date = .now
    var returnsToLock: Bool
}

extension POSStore {

    // MARK: - Locking
    //
    // A shared till behind a bar is rung by four people in an hour. Every sale belongs to
    // somebody, and the way to make that true without slowing anyone down is a lock screen
    // that costs one tap to get past.

    func lock(reason: String? = nil) {
        route = nil
        selectedLineID = nil
        isLocked = true
        if let reason { lockReason = reason } else { lockReason = nil }
    }

    func logIn(as staff: Staff) {
        operatorStaff = staff
        isLocked = false
        lockReason = nil
        saleSummary = nil
        surface = profile.homeSurface
        toast(.done, "\(staff.name.firstWord) is on", detail: "\(staff.role.label) · \(staff.role.tier) permissions")
    }

    /// Operators tap and are in. Supervisors and above confirm with a PIN, because their tile
    /// carries voids, refunds and the drawer.
    func needsPIN(for staff: Staff) -> Bool {
        profile.pinAboveOperator && staff.role.needsPIN
    }

    func attemptLogIn(_ staff: Staff, pin: String) -> Bool {
        guard !needsPIN(for: staff) || pin == staff.pin else { return false }
        logIn(as: staff)
        return true
    }

    // MARK: - The end of a sale

    func presentSaleSummary(for order: Order) {
        let change = order.payments.filter { $0.state == .complete }.map(\.change).total
        let tenders = order.payments.filter { $0.state == .complete }.map { leg -> String in
            leg.surcharge.isZero
                ? "\(leg.kind.label) \(leg.amount.formatted())"
                : "\(leg.kind.label) \(leg.amount.formatted()) +\(leg.surcharge.formatted())"
        }
        saleSummary = SaleSummary(orderLabel: order.identifierLabel,
                                  total: order.total,
                                  change: change,
                                  tenders: tenders,
                                  itemCount: order.itemCount,
                                  operatorName: operatorStaff.name,
                                  operatorInitials: operatorStaff.initials,
                                  returnsToLock: profile.postSaleReturnsToLock)
        guard profile.postSaleReturnsToLock else { return }
        lockCountdown = profile.lockGraceSeconds
        runLockCountdown()
    }

    private func runLockCountdown() {
        let token = saleSummary?.at
        Task { @MainActor in
            while lockCountdown > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard saleSummary?.at == token else { return }
                lockCountdown -= 1
            }
            guard saleSummary?.at == token else { return }
            saleSummary = nil
            lock(reason: "Locked after the sale")
        }
    }

    /// The operator is still serving, so the till stays theirs.
    func stayOn() {
        lockCountdown = 0
        saleSummary = nil
    }

    func logOutNow() {
        lockCountdown = 0
        saleSummary = nil
        lock(reason: "Logged out")
    }

    func dismissSaleSummary() {
        if saleSummary?.returnsToLock == true { logOutNow() } else { saleSummary = nil }
    }
}
