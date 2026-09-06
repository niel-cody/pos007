import SwiftUI

extension POSStore {

    // MARK: - Reading the floor
    //
    // State is derived from the same events every device holds, so two tills cannot disagree
    // about a table. (Canonical §4)

    func orders(onTable id: UUID) -> [Order] {
        orders.filter { $0.tableID == id && $0.status.isLive }
    }

    func state(of table: FloorTable) -> TableState {
        if !table.isActive || table.blockedReason != nil { return .blocked }
        let live = orders(onTable: table.id)

        if live.isEmpty {
            if let r = table.resetSince, Date.now.timeIntervalSince(r) < 300 { return .reset }
            if let res = table.reservation, !res.seated,
               res.at.timeIntervalSince(.now) < 3600 * 6,
               res.at.timeIntervalSince(.now) > -900 { return .reserved }
            return .vacant
        }

        // A table with several orders shows the most advanced state of its orders.
        return live.map { state(of: $0) }.max { $0.advancement < $1.advancement } ?? .seated
    }

    func state(of order: Order) -> TableState {
        if order.paymentState == .paid { return profile.requireResetAfterPay ? .paid : .vacant }
        if order.paymentState == .partPaid { return .partlyPaid }
        if order.billRequested || order.billPrintedAt != nil { return .billRequested }

        let sent = order.sentItems
        if sent.isEmpty {
            return order.liveItems.isEmpty ? .seated : .ordering
        }

        // Venues that do not track service states collapse the middle of the meal into Ordered.
        guard profile.serviceStates != .off else { return .ordered }

        if let dessert = order.courses.first(where: \.isDessert),
           order.items(inCourse: dessert.id).contains(where: \.isSentOrLater) {
            return .dessert
        }
        if sent.allSatisfy(\.isServed), order.unsentItems.isEmpty { return .served }
        if sent.contains(where: \.isServed) { return .partlyServed }
        if sent.allSatisfy(\.isReady) { return .ready }
        if tickets.contains(where: { $0.orderID == order.id && $0.state == .started }) { return .cooking }
        return .ordered
    }

    /// Why a table is asking for attention. Named, never a bare red dot.
    func attention(for table: FloorTable) -> String? {
        let live = orders(onTable: table.id)
        for o in live {
            if o.hasAttention { return "A docket did not print" }
            if let lock = o.lock, lock.isLive,
               Date.now.timeIntervalSince(lock.takenAt) > 180 { return "Locked \(lock.takenAt.elapsedShort)" }
            if o.billRequested, Date.now.timeIntervalSince(o.updatedAt) > 300 { return "Waiting to pay" }
            if o.paymentState == .partPaid, Date.now.timeIntervalSince(o.updatedAt) > 300 {
                return "Part paid \(o.amountDue.formatted()) left"
            }
            if state(of: o) == .ready, let ready = o.sentItems.compactMap(\.readyAt).min(),
               Date.now.timeIntervalSince(ready) > 120 { return "Food on the pass" }
            if state(of: o) == .ordered, Date.now.timeIntervalSince(o.updatedAt) > 900 {
                return "Kitchen over target"
            }
            if o.channel != .pos, o.status == .placed { return "Online order landed here" }
        }
        return nil
    }

    func table(_ id: UUID) -> FloorTable? { tables.first { $0.id == id } }

    var tablesInSection: [FloorTable] {
        tables.filter { $0.sectionID == floorSectionID }
    }

    func stateCounts() -> [(TableState, Int)] {
        let visible = tablesInSection
        var counts: [TableState: Int] = [:]
        for t in visible { counts[state(of: t), default: 0] += 1 }
        return TableState.allCases.compactMap { s in
            counts[s].map { (s, $0) }
        }
    }

    // MARK: - Opening and covers

    func openTable(_ table: FloorTable, covers: Int?) {
        let existing = orders(onTable: table.id)
        if existing.count == 1, let o = existing.first {
            openOrder(o.id)
            return
        }
        if existing.count > 1 {
            route = .tableSheet(tableID: table.id)
            return
        }
        let o = newOrder(type: .dineIn, table: table, covers: covers)
        if let res = table.reservation, !res.seated {
            update(o.id) {
                $0.customerName = res.name
                if let n = res.notes { $0.orderNote = n }
            }
            if let ti = tables.firstIndex(where: { $0.id == table.id }) {
                tables[ti].reservation?.seated = true
            }
            toast(.info, "Seated \(res.name)", detail: res.notes ?? "Booking for \(res.partySize)")
        }
        surface = .sell
    }

    func setCovers(_ orderID: UUID, _ covers: Int) {
        guard let o = order(orderID) else { return }
        // Covers are only a count: reducing them never orphans an item on a higher seat.
        if covers == 0 && !o.liveItems.isEmpty {
            toast(.warn, "This table has items on it",
                  detail: "Pay, transfer or void them rather than setting covers to zero")
            return
        }
        update(orderID) { $0.guestCount = covers }
        applyAutomaticAdjustments()
    }

    func assignWaiter(_ orderID: UUID, to initials: String) {
        update(orderID) { $0.waiter = initials }
        log(orderID, "Waiter set to \(initials)", glyph: "person.fill")
    }

    // MARK: - Moving work around the floor

    func moveOrder(_ orderID: UUID, to table: FloorTable) {
        guard let o = order(orderID) else { return }
        let from = o.tableLabel ?? "no table"
        update(orderID) {
            $0.tableID = table.id
            $0.tableLabel = table.label
        }
        log(orderID, "Moved from \(from) to \(table.label)", glyph: "arrow.left.arrow.right", notable: true)
        // The kitchen is told, so a runner does not carry plates to the wrong table.
        raiseTicket(orderID: orderID, station: profile.stations.first ?? "Kitchen",
                    items: [], courseName: "Moved to \(table.label)")
        toast(.done, "Moved to \(table.label)", detail: "The kitchen has a transfer docket")
    }

    func mergeOrders(_ sourceID: UUID, into targetID: UUID) {
        guard let source = order(sourceID), let target = order(targetID) else { return }
        update(targetID) { t in
            for var item in source.liveItems {
                item.id = UUID()
                t.items.append(item)
            }
            t.guestCount = (t.guestCount ?? 0) + (source.guestCount ?? 0)
        }
        update(sourceID) { $0.status = .merged }
        log(targetID, "Merged \(source.identifierLabel) in", glyph: "arrow.triangle.merge", notable: true)
        toast(.done, "Merged into \(target.identifierLabel)",
              detail: "\(source.itemCount) items moved")
    }

    /// Split a table into two orders: the second half walks away with its own bill.
    func splitTable(_ orderID: UUID, itemIDs: [UUID]) {
        guard let o = order(orderID) else { return }
        var newOrd = Order(number: nextOrderNumber, type: o.type)
        nextOrderNumber += 1
        newOrd.tableID = o.tableID
        newOrd.tableLabel = o.tableLabel
        newOrd.status = .open
        newOrd.courses = o.courses
        newOrd.waiter = o.waiter
        newOrd.openedBy = operatorStaff.initials
        for id in itemIDs {
            guard var item = o.items.first(where: { $0.id == id }) else { continue }
            item.id = UUID()
            newOrd.items.append(item)
        }
        orders.append(newOrd)
        update(orderID) { ord in
            for id in itemIDs {
                if let i = ord.items.firstIndex(where: { $0.id == id }) {
                    ord.items[i].status = .transferred
                }
            }
        }
        toast(.done, "Split into two orders", detail: "\(itemIDs.count) items moved to a new bill")
    }

    func transferItems(_ itemIDs: [UUID], from sourceID: UUID, to targetID: UUID) {
        guard let source = order(sourceID) else { return }
        update(targetID) { t in
            for id in itemIDs {
                guard var item = source.items.first(where: { $0.id == id }) else { continue }
                item.id = UUID()
                t.items.append(item)
            }
        }
        update(sourceID) { ord in
            for id in itemIDs {
                if let i = ord.items.firstIndex(where: { $0.id == id }) {
                    ord.items[i].status = .transferred
                }
            }
        }
        toast(.done, "Moved \(itemIDs.count) item\(itemIDs.count == 1 ? "" : "s")")
    }

    // MARK: - Releasing

    func releaseTable(_ tableID: UUID, paid: Bool) {
        guard let i = tables.firstIndex(where: { $0.id == tableID }) else { return }
        if profile.requireResetAfterPay && paid {
            tables[i].resetSince = .now
        } else {
            tables[i].resetSince = nil
            tables[i].reservation = nil
        }
    }

    func clearTable(_ tableID: UUID) {
        guard let i = tables.firstIndex(where: { $0.id == tableID }) else { return }
        tables[i].resetSince = nil
        tables[i].reservation = nil
        toast(.done, "\(tables[i].label) cleared")
    }

    func blockTable(_ tableID: UUID, reason: String?) {
        guard let i = tables.firstIndex(where: { $0.id == tableID }) else { return }
        tables[i].blockedReason = reason
        toast(.info, reason == nil ? "\(tables[i].label) back in service" : "\(tables[i].label) blocked",
              detail: reason)
    }

    func setTableNote(_ tableID: UUID, _ note: String?) {
        guard let i = tables.firstIndex(where: { $0.id == tableID }) else { return }
        tables[i].note = note?.isEmpty == true ? nil : note
    }

    // MARK: - The lock
    //
    // The lock blocks payment, transfer, merge and whole-order void. It never blocks reading
    // and never blocks ordinary item editing. (Canonical §6)

    func takeLock(_ orderID: UUID) {
        update(orderID) {
            $0.lock = OrderLock(holder: operatorStaff.name, device: profile.deviceName,
                                takenAt: .now, expiresAt: .now.addingTimeInterval(300),
                                hasPendingCardLeg: $0.hasPendingLeg)
        }
    }

    func releaseLock(_ orderID: UUID) {
        update(orderID) { $0.lock = nil }
    }

    func canPay(_ order: Order) -> Bool {
        guard let lock = order.lock, lock.isLive else { return true }
        return lock.device == profile.deviceName
    }

    func overrideLock(_ orderID: UUID) {
        guard let o = order(orderID), let lock = o.lock else { return }
        let detail = lock.hasPendingCardLeg
            ? "\(lock.holder) may be part way through a card payment. Unlocking will not cancel it."
            : "\(lock.holder) had it on \(lock.device)."
        requireApproval(.unlockOrder, what: "Unlock \(o.identifierLabel)", detail: detail) { [weak self] approver, _ in
            guard let self else { return }
            self.update(orderID) { $0.lock = nil }
            self.log(orderID, "Lock overridden (was \(lock.holder))",
                     glyph: "lock.open.fill", approvedBy: approver.initials, notable: true)
            self.toast(.warn, "Unlocked", detail: "Audited against \(approver.name)")
        }
    }

    /// A second device is working on this table. Nothing is silently overwritten.
    func simulateOtherDevice(_ orderID: UUID) {
        guard let o = order(orderID) else { return }
        takeLockAsOther(orderID)
        _ = o
    }

    func takeLockAsOther(_ orderID: UUID) {
        let other = staff.first { $0.initials != operatorStaff.initials } ?? operatorStaff
        update(orderID) {
            $0.lock = OrderLock(holder: other.name, device: "Till 2",
                                takenAt: .now, expiresAt: .now.addingTimeInterval(300),
                                hasPendingCardLeg: true)
        }
        toast(.warn, "\(other.name) is on the payment screen",
              detail: "You can still add items and send. Payment is held until they finish.")
    }
}
