import SwiftUI

extension POSStore {

    // MARK: - Tabs
    //
    // A tab is an order with a name. There is no tab entity. Everything true of an order is
    // true of a tab: splitting, moving to a table, reporting. (Canonical §7)

    @discardableResult
    func openTab(name: String, limit: Money? = nil, card: (last4: String, scheme: String)? = nil) -> Order {
        var o = newOrder(type: .dineIn, name: name.isEmpty ? "Tab \(nextOrderNumber)" : name)
        o.status = .open
        o.spendLimit = limit
        o.waiter = operatorStaff.initials
        if let card {
            o.tabAuth = TabAuthorisation(state: .requested,
                                         amount: limit ?? Money(100),
                                         last4: card.last4, scheme: card.scheme)
        }
        currentOrder = o
        currentOrderID = o.id
        if let card {
            authoriseTab(o.id, amount: limit ?? Money(100), last4: card.last4, scheme: card.scheme)
        }
        log(o.id, "Tab opened as “\(o.name ?? "")”", glyph: "person.badge.key.fill")
        toast(.done, "Tab open: \(o.name ?? "")",
              detail: card.map { "\($0.scheme) ···\($0.last4) held" } ?? limit.map { "Limit \($0.formatted())" })
        return o
    }

    /// An authorisation is not a payment. It never appears in payments[] until captured.
    func authoriseTab(_ orderID: UUID, amount: Money, last4: String, scheme: String) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            update(orderID) {
                $0.tabAuth = TabAuthorisation(state: .authorised, amount: amount,
                                              last4: last4, scheme: scheme)
            }
            toast(.done, "Card held \(amount.formatted())", detail: "\(scheme) ···\(last4)")
        }
    }

    func incrementAuth(_ orderID: UUID, by extra: Money) {
        guard let o = order(orderID), let auth = o.tabAuth else { return }
        update(orderID) {
            $0.tabAuth?.amount = auth.amount + extra
            $0.tabAuth?.state = .authorised
        }
        toast(.done, "Hold topped up", detail: (auth.amount + extra).formatted())
    }

    func releaseAuth(_ orderID: UUID) {
        update(orderID) { $0.tabAuth?.state = .released }
    }

    /// Spend against the hold, with the amber threshold the research asks for at 80 per cent.
    func authPressure(_ order: Order) -> (used: Double, warning: String?)? {
        guard let auth = order.tabAuth, auth.state == .authorised || auth.state == .expiring else { return nil }
        let used = auth.amount.cents == 0 ? 0 : Double(order.total.cents) / Double(auth.amount.cents)
        if used >= 1 { return (used, "Spend is past the hold — top it up before the next round") }
        if used >= 0.8 { return (used, "80% of the hold used") }
        return (used, nil)
    }

    func closeTab(_ orderID: UUID) {
        openOrder(orderID)
        takeLock(orderID)
        route = .payment
    }

    func transferTabToTable(_ orderID: UUID, table: FloorTable) {
        guard let o = order(orderID) else { return }
        update(orderID) {
            $0.tableID = table.id
            $0.tableLabel = table.label
        }
        log(orderID, "Tab “\(o.name ?? "")” moved to \(table.label)", glyph: "arrow.right.circle.fill")
        toast(.done, "\(o.name ?? "Tab") is now on \(table.label)")
    }

    func transferTab(_ orderID: UUID, to staffInitials: String) {
        update(orderID) { $0.waiter = staffInitials }
        log(orderID, "Tab handed to \(staffInitials)", glyph: "person.2.fill")
    }

    /// Retrieval is a search and presentation problem over the name and the card, not a
    /// modelling one. Ten deep at the bar, the bartender types two letters.
    func findTabs(_ query: String) -> [Order] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = openTabs
        guard !q.isEmpty else { return all }
        return all.filter {
            ($0.name ?? "").lowercased().contains(q)
            || ($0.tabAuth?.last4.contains(q) ?? false)
            || ($0.tabAuth?.scheme.lowercased().contains(q) ?? false)
            || ($0.waiter ?? "").lowercased().contains(q)
            || String($0.number).contains(q)
        }
    }

    /// Two tabs under the same first name is the bar's real problem: disambiguate, never guess.
    func tabsNeedingDisambiguation() -> [String] {
        let names = openTabs.compactMap { $0.name?.firstWord.lowercased() }
        return Dictionary(grouping: names, by: { $0 }).filter { $0.value.count > 1 }.keys.map { $0 }
    }

    /// Last drinks: the end-of-night sweep, with the reason each tab is still open. (W06.20)
    func tabSweep() -> [(order: Order, suggestion: String)] {
        openTabs.map { o in
            if let auth = o.tabAuth, auth.state == .authorised {
                return (o, "Capture \(o.total.formatted()) on \(auth.scheme) ···\(auth.last4)")
            }
            if Date.now.timeIntervalSince(o.updatedAt) > 1800 {
                return (o, "Unattended for \(o.updatedAt.elapsedShort) — find the guest or hold it")
            }
            return (o, "Close on a tender")
        }
    }

    func captureTab(_ orderID: UUID) {
        guard let o = order(orderID), let auth = o.tabAuth else { return }
        update(orderID) {
            $0.tabAuth?.state = o.total < auth.amount ? .partlyCaptured : .captured
            $0.payments.append(PaymentLeg(kind: .card, amount: o.total,
                                          staff: operatorStaff.initials,
                                          reference: "CAPTURE \(auth.scheme) ···\(auth.last4)"))
        }
        shift.cardSales = shift.cardSales + o.total
        complete(orderID: orderID)
    }

    // MARK: - Holding and recalling an order
    //
    // Interruptions are a property of a shift, so parking work has to be free.

    func holdOrder(_ orderID: UUID, note: String? = nil) {
        update(orderID) {
            $0.status = .held
            if let note { $0.orderNote = note }
        }
        guard let o = order(orderID) else { return }
        currentOrderID = nil
        surface = profile.postSaleSurface
        toast(.done, "Parked \(o.identifierLabel)", detail: "In Orders, exactly as you left it")
    }

    func recallOrder(_ orderID: UUID) {
        update(orderID) { $0.status = $0.items.contains(where: \.isSentOrLater) ? .open : .placed }
        openOrder(orderID)
    }

    func voidOrder(_ orderID: UUID, reason: String, approvedBy: String?) {
        guard let o = order(orderID) else { return }
        for item in o.sentItems { raiseVoidDocket(order: o, item: item, reason: reason) }
        update(orderID) { ord in
            ord.status = .voided
            for i in ord.items.indices where ord.items[i].isLive {
                ord.items[i].status = ord.items[i].isSentOrLater ? .voided : .cancelled
                ord.items[i].voidReason = reason
            }
        }
        shift.voids = shift.voids + o.total
        log(orderID, "Order voided — \(reason)", glyph: "xmark.bin.fill",
            approvedBy: approvedBy, notable: true)
        if let t = o.tableID { releaseTable(t, paid: false) }
        currentOrderID = nil
        surface = profile.postSaleSurface
        toast(.warn, "Order voided", detail: "\(reason) · void dockets sent")
    }
}
