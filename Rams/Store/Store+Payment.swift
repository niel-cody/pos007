import SwiftUI

/// The four figures the operator must be able to read at every step. (W09.16)
struct BillFigures {
    var total: Money
    var allocated: Money
    var paid: Money
    var remaining: Money
    var surcharges: Money
    var rounding: Money
    var tips: Money
    var previousTotal: Money?

    var isOverpaid: Bool { remaining.cents < 0 }
}

extension POSStore {

    func figures(for order: Order) -> BillFigures {
        BillFigures(total: order.total,
                    allocated: order.splitPlan?.allocated ?? order.total,
                    paid: order.paidTotal,
                    remaining: order.amountDue,
                    surcharges: order.surchargeTotal,
                    rounding: order.roundingTotal,
                    tips: order.tipTotal,
                    previousTotal: nil)
    }

    // MARK: - Taking a tender

    /// One entry point for every tender. A portion id makes it a leg of a split.
    func tender(_ kind: TenderKind,
                amount: Money,
                tendered: Money? = nil,
                tip: Money = .zero,
                portionID: UUID? = nil,
                reference: String? = nil) {
        guard let id = currentOrderID, let order = order(id) else { return }

        if offline && !kind.worksOffline {
            toast(.stop, "\(kind.label) needs the network",
                  detail: "Take cash or a manual card record — the order is safe either way")
            return
        }

        var leg = PaymentLeg(kind: kind, amount: amount, tip: tip, tendered: tendered,
                             staff: operatorStaff.initials, reference: reference,
                             portionID: portionID)

        switch kind {
        case .cash:
            let rounding = PricingEngine.cashRounding(on: amount, profile: profile)
            leg.rounding = rounding
            leg.amount = amount
            settle(leg, orderID: id)

        case .card, .giftCard, .voucher, .loyalty:
            leg.surcharge = kind == .card ? PricingEngine.cardSurcharge(on: amount, profile: profile) : .zero
            leg.state = .pending
            settle(leg, orderID: id)
            runTerminal(legID: leg.id, orderID: id)

        case .houseAccount:
            leg.settlementPending = true
            settle(leg, orderID: id)

        default:
            settle(leg, orderID: id)
        }
        _ = order
    }

    private func settle(_ leg: PaymentLeg, orderID: UUID) {
        update(orderID) { $0.payments.append(leg) }
        if leg.state == .complete { finishIfPaid(orderID: orderID, leg: leg) }
    }

    /// The terminal round trip. It is the bank's time, not the interface's, and the operator
    /// can see what is happening throughout.
    private func runTerminal(legID: UUID, orderID: UUID) {
        let outcome = cardOutcome
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            guard let oi = orders.firstIndex(where: { $0.id == orderID }),
                  let li = orders[oi].payments.firstIndex(where: { $0.id == legID }) else { return }
            switch outcome {
            case .approve:
                orders[oi].payments[li].state = .complete
                orders[oi].payments[li].reference = "APPROVED " + String(Int.random(in: 100000...999999))
                let leg = orders[oi].payments[li]
                finishIfPaid(orderID: orderID, leg: leg)
            case .decline:
                orders[oi].payments[li].state = .rejected
                toast(.stop, "Declined", detail: "Nothing was taken. Try another card or another tender.")
            case .timeout:
                // Never retry a hung payment: verify it. That is how a double charge starts.
                toast(.warn, "No answer from the terminal",
                      detail: "Tap Verify on the pending line. Do not retry.")
            }
        }
    }

    /// Resolve a pending or unknown card payment. (W08.04)
    func verify(legID: UUID, orderID: UUID) {
        guard let oi = orders.firstIndex(where: { $0.id == orderID }),
              let li = orders[oi].payments.firstIndex(where: { $0.id == legID }) else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.1))
            orders[oi].payments[li].state = .complete
            orders[oi].payments[li].reference = "VERIFIED " + String(Int.random(in: 100000...999999))
            let leg = orders[oi].payments[li]
            toast(.done, "Verified — approved", detail: "The terminal had it. Nothing was charged twice.")
            finishIfPaid(orderID: orderID, leg: leg)
        }
    }

    func cancelLeg(legID: UUID, orderID: UUID) {
        update(orderID) { ord in
            if let li = ord.payments.firstIndex(where: { $0.id == legID }) {
                ord.payments[li].state = .cancelled
            }
        }
    }

    /// Reverse a completed tender before the order closes. (W08.20)
    func reverse(legID: UUID, orderID: UUID) {
        update(orderID) { ord in
            guard let li = ord.payments.firstIndex(where: { $0.id == legID }) else { return }
            ord.payments[li].state = .reversed
            if let pid = ord.payments[li].portionID, var plan = ord.splitPlan,
               let pi = plan.portions.firstIndex(where: { $0.id == pid }) {
                plan.portions[pi].state = .unpaid
                plan.portions[pi].paid = .zero
                ord.splitPlan = plan
            }
            if ord.status == .completed { ord.status = .open; ord.closedAt = nil }
        }
        log(orderID, "Reversed a tender", glyph: "arrow.uturn.backward.circle.fill", notable: true)
        toast(.warn, "Tender reversed", detail: "The portion is unpaid again with its allocation intact")
    }

    private func finishIfPaid(orderID: UUID, leg: PaymentLeg) {
        // Portion bookkeeping first, so the split panel is right before anything closes.
        update(orderID) { ord in
            if let pid = leg.portionID, var plan = ord.splitPlan,
               let pi = plan.portions.firstIndex(where: { $0.id == pid }) {
                plan.portions[pi].paid = plan.portions[pi].paid + leg.amount
                plan.portions[pi].state = plan.portions[pi].remaining.cents <= 1 ? .paid : .partPaid
                ord.splitPlan = plan
            }
        }
        recordShift(leg)
        guard let o = order(orderID) else { return }
        guard o.amountDue.cents <= 1 else {
            toast(.done, "\(leg.kind.label) \(leg.amount.formatted())",
                  detail: "\(o.amountDue.formatted()) remaining")
            return
        }
        complete(orderID: orderID)
    }

    func complete(orderID: UUID) {
        guard let o = order(orderID) else { return }
        // Unsent items at payment are a question, not a silent loss. (W05.02)
        if !o.unsentItems.isEmpty && profile.coursesEnabled {
            send()
        }
        update(orderID) { ord in
            ord.status = .completed
            ord.closedAt = .now
            ord.lock = nil
            for i in ord.items.indices where ord.items[i].isLive {
                ord.items[i].status = .completed
            }
            if ord.type.tracksFulfilment, ord.fulfilment == nil { ord.fulfilment = .inPreparation }
        }
        shift.orders += 1
        shift.covers += o.guestCount ?? 0
        log(orderID, "Order completed \(o.total.formatted())", glyph: "checkmark.seal.fill")

        if let tid = o.tableID {
            releaseTable(tid, paid: true)
        }
        route = nil
        currentOrderID = nil
        surface = profile.postSaleSurface
        let change = o.payments.filter { $0.state == .complete }.map(\.change).total
        toast(.done, "Paid \(o.total.formatted())",
              detail: change.cents > 0 ? "Change \(change.formatted())" : o.identifierLabel)
    }

    private func recordShift(_ leg: PaymentLeg) {
        switch leg.kind {
        case .cash: shift.cashSales = shift.cashSales + leg.amount
        case .card, .manualCard: shift.cardSales = shift.cardSales + leg.amount + leg.surcharge
        default: shift.otherSales = shift.otherSales + leg.amount
        }
    }

    /// Zero balance: a fully discounted order still needs a deliberate close. (W08.13)
    func completeZero() {
        guard let id = currentOrderID else { return }
        complete(orderID: id)
    }

    // MARK: - Split plans

    func startSplit(_ mode: SplitMode, count: Int = 2) {
        guard let id = currentOrderID, let o = order(id) else { return }
        var plan = o.splitPlan ?? SplitPlan(mode: mode)
        plan.mode = mode
        plan.modesUsed.insert(mode)

        switch mode {
        case .equal:
            let capped = min(count, profile.maxSplitPayments)
            // Every part equal except the last, which carries the remainder.
            let parts = o.amountDue.split(into: capped)
            let paidPortions = plan.portions.filter { $0.state == .paid }
            plan.portions = paidPortions + parts.enumerated().map { i, amt in
                SplitPortion(label: "Guest \(paidPortions.count + i + 1)", amount: amt)
            }
        case .percentage:
            let parts = o.amountDue.split(into: min(count, profile.maxSplitPayments))
            plan.portions = parts.enumerated().map { i, amt in
                SplitPortion(label: "\(Int(100 / Double(parts.count)))% · \(i + 1)", amount: amt)
            }
        case .seats:
            let seats = o.seatsUsed
            var portions: [SplitPortion] = seats.map { seat in
                let items = o.liveItems.filter { $0.seat == seat }
                return SplitPortion(label: "Seat \(seat)",
                                    amount: items.map(\.lineTotal).total,
                                    shares: items.map { ItemShare(itemID: $0.id, quantity: $0.quantity) },
                                    seat: seat)
            }
            // Items with no seat go to a shared portion the operator allocates. (Canonical §8)
            let shared = o.liveItems.filter { $0.seat == nil }
            if !shared.isEmpty {
                portions.append(SplitPortion(label: "Shared",
                                             amount: shared.map(\.lineTotal).total,
                                             shares: shared.map { ItemShare(itemID: $0.id, quantity: $0.quantity) }))
            }
            plan.portions = portions
        case .items:
            plan.portions = [SplitPortion(label: "Guest 1", amount: .zero),
                             SplitPortion(label: "Guest 2", amount: .zero)]
        case .amount:
            plan.portions = plan.portions.filter { $0.state == .paid }
        }
        update(id) { $0.splitPlan = plan }
    }

    func addPortion() {
        guard let id = currentOrderID, let o = order(id), var plan = o.splitPlan else { return }
        guard plan.portions.count < profile.maxSplitPayments else {
            toast(.warn, "Up to \(profile.maxSplitPayments) on this device",
                  detail: "Use Amount for anything unusual, or a manager can raise the cap")
            return
        }
        plan.portions.append(SplitPortion(label: "Guest \(plan.portions.count + 1)", amount: .zero))
        update(id) { $0.splitPlan = plan }
    }

    func setPortionAmount(_ portionID: UUID, _ amount: Money) {
        guard let id = currentOrderID else { return }
        update(id) { ord in
            guard let pi = ord.splitPlan?.portions.firstIndex(where: { $0.id == portionID }) else { return }
            ord.splitPlan?.portions[pi].amount = amount
        }
    }

    /// Move an item between portions. Allocation is a tap, not a mode.
    func allocate(itemID: UUID, quantity: Int, to portionID: UUID?) {
        guard let id = currentOrderID, let o = order(id), var plan = o.splitPlan else { return }
        for pi in plan.portions.indices where plan.portions[pi].state != .paid {
            plan.portions[pi].shares.removeAll { $0.itemID == itemID }
        }
        if let portionID, let pi = plan.portions.firstIndex(where: { $0.id == portionID }) {
            plan.portions[pi].shares.append(ItemShare(itemID: itemID, quantity: quantity))
        }
        for pi in plan.portions.indices where plan.portions[pi].state != .paid {
            plan.portions[pi].amount = plan.portions[pi].shares.reduce(Money.zero) { acc, share in
                guard let item = o.liveItems.first(where: { $0.id == share.itemID }) else { return acc }
                return acc + Money(cents: Int(Double(item.eachTotal.cents * share.quantity) * share.fraction))
            }
        }
        plan.modesUsed.insert(.items)
        update(id) { $0.splitPlan = plan }
    }

    /// Share one item across several portions by value. (W09.07)
    func share(itemID: UUID, across portionIDs: [UUID]) {
        guard let id = currentOrderID, let o = order(id), var plan = o.splitPlan,
              let item = o.liveItems.first(where: { $0.id == itemID }), !portionIDs.isEmpty else { return }
        let fraction = 1.0 / Double(portionIDs.count)
        for pi in plan.portions.indices {
            plan.portions[pi].shares.removeAll { $0.itemID == itemID }
            if portionIDs.contains(plan.portions[pi].id) {
                plan.portions[pi].shares.append(ItemShare(itemID: itemID, quantity: item.quantity, fraction: fraction))
            }
        }
        for pi in plan.portions.indices where plan.portions[pi].state != .paid {
            plan.portions[pi].amount = plan.portions[pi].shares.reduce(Money.zero) { acc, share in
                guard let it = o.liveItems.first(where: { $0.id == share.itemID }) else { return acc }
                return acc + Money(cents: Int(Double(it.eachTotal.cents * share.quantity) * share.fraction))
            }
        }
        update(id) { $0.splitPlan = plan }
        toast(.done, "Shared \(item.name)", detail: "Divided across \(portionIDs.count)")
    }

    /// Equal re-splits what is left, never the original total. (W09.01.b)
    func resplitRemaining(_ count: Int) {
        guard let id = currentOrderID, let o = order(id), var plan = o.splitPlan else { return }
        let paid = plan.portions.filter { $0.state == .paid }
        let parts = o.amountDue.split(into: min(count, profile.maxSplitPayments))
        plan.portions = paid + parts.enumerated().map { i, amt in
            SplitPortion(label: "Guest \(paid.count + i + 1)", amount: amt)
        }
        update(id) { $0.splitPlan = plan }
        toast(.done, "Re-split the remaining \(o.amountDue.formatted())",
              detail: "Paid portions are untouched")
    }

    /// "Actually just put the rest on one card." (W09.01.c)
    func mergeUnpaidPortions() {
        guard let id = currentOrderID, let o = order(id), var plan = o.splitPlan else { return }
        let paid = plan.portions.filter { $0.state == .paid }
        let shares = plan.portions.filter { $0.state != .paid }.flatMap(\.shares)
        plan.portions = paid + [SplitPortion(label: "The rest", amount: o.amountDue, shares: shares)]
        update(id) { $0.splitPlan = plan }
        toast(.done, "Paying the rest together", detail: o.amountDue.formatted())
    }

    func clearSplit() {
        guard let id = currentOrderID else { return }
        update(id) { $0.splitPlan = nil }
    }

    // MARK: - Discounts, comps and price overrides

    func applyItemDiscount(_ itemID: UUID, percent: Double?, amount: Money?, name: String,
                           reason: String?, approvedBy: String?) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }) else { return }
        let value: Money = percent.map { item.gross.percent($0) } ?? (amount ?? .zero)
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].adjustments.removeAll { $0.kind == .discountPercent || $0.kind == .discountAmount }
            ord.items[i].adjustments.append(
                Adjustment(kind: percent != nil ? .discountPercent : .discountAmount,
                           name: name, amount: -value, percent: percent,
                           reason: reason, approvedBy: approvedBy,
                           appliedBy: operatorStaff.initials))
        }
        log(id, "\(name) on \(item.name) −\(value.formatted())", glyph: "tag.fill",
            approvedBy: approvedBy, notable: approvedBy != nil)
        applyAutomaticAdjustments()
        toast(.done, "\(name) applied", detail: "\(item.name) −\(value.formatted())", undo: "Undo")
        undoStack.append((order: o, label: name))
    }

    func applyOrderDiscount(percent: Double?, amount: Money?, targetTotal: Money? = nil,
                            name: String, reason: String?, approvedBy: String?) {
        guard let id = currentOrderID, let o = order(id) else { return }
        var value: Money = .zero
        if let percent { value = o.subtotal.percent(percent) }
        else if let amount { value = amount }
        else if let targetTotal { value = max(.zero, o.subtotal - targetTotal) }
        update(id) { ord in
            ord.adjustments.removeAll { ($0.kind == .discountPercent || $0.kind == .discountAmount) && !$0.automatic }
            ord.adjustments.append(Adjustment(kind: percent != nil ? .discountPercent : .discountAmount,
                                              name: name, amount: -value, percent: percent,
                                              reason: reason, approvedBy: approvedBy,
                                              appliedBy: operatorStaff.initials))
        }
        log(id, "\(name) on the order −\(value.formatted())", glyph: "tag.fill",
            approvedBy: approvedBy, notable: true)
        toast(.done, "\(name)", detail: "−\(value.formatted()) on the order", undo: "Undo")
        undoStack.append((order: o, label: name))
    }

    func comp(_ itemID: UUID, reason: String, approvedBy: String?) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }) else { return }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].adjustments.append(Adjustment(kind: .comp, name: "Complimentary",
                                                       amount: -item.gross, reason: reason,
                                                       approvedBy: approvedBy,
                                                       appliedBy: operatorStaff.initials))
        }
        log(id, "Comped \(item.name) — \(reason)", glyph: "gift.fill", approvedBy: approvedBy, notable: true)
        applyAutomaticAdjustments()
        toast(.done, "\(item.name) comped", detail: reason)
    }

    func overridePrice(_ itemID: UUID, to price: Money, reason: String?, approvedBy: String?) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.liveItems.first(where: { $0.id == itemID }) else { return }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            ord.items[i].adjustments.append(
                Adjustment(kind: .priceOverride, name: "Price override",
                           amount: (price * item.quantity) - item.gross,
                           reason: reason, approvedBy: approvedBy,
                           appliedBy: operatorStaff.initials))
        }
        log(id, "Price override on \(item.name) to \(price.formatted())",
            glyph: "pencil.circle.fill", approvedBy: approvedBy, notable: true)
        applyAutomaticAdjustments()
    }

    func removeAdjustment(_ adjustmentID: UUID, itemID: UUID?) {
        guard let id = currentOrderID else { return }
        update(id) { ord in
            if let itemID, let i = ord.items.firstIndex(where: { $0.id == itemID }) {
                ord.items[i].adjustments.removeAll { $0.id == adjustmentID }
            } else {
                ord.adjustments.removeAll { $0.id == adjustmentID }
            }
        }
        applyAutomaticAdjustments()
    }

    // MARK: - Refunds

    /// A refund is a new order that settles against a completed one. The original stays Completed.
    func refund(orderID: UUID, items: [(itemID: UUID, quantity: Int)], amount: Money?,
                reason: String, tender: TenderKind, approvedBy: String?) {
        guard let source = order(orderID) else { return }
        var refundOrder = Order(number: nextOrderNumber, type: source.type)
        nextOrderNumber += 1
        refundOrder.isRefund = true
        refundOrder.refundsOrderID = orderID
        refundOrder.status = .completed
        refundOrder.closedAt = .now
        refundOrder.customerID = source.customerID
        refundOrder.customerName = source.customerName
        refundOrder.openedBy = operatorStaff.initials

        var value: Money = .zero
        if let amount {
            value = amount
        } else {
            for ref in items {
                guard let item = source.items.first(where: { $0.id == ref.itemID }) else { continue }
                var copy = item
                copy.id = UUID()
                copy.quantity = ref.quantity
                copy.status = .refunded
                refundOrder.items.append(copy)
                value = value + Money(cents: item.eachTotal.cents * ref.quantity)
            }
        }
        refundOrder.payments = [PaymentLeg(kind: tender, amount: -value,
                                           staff: operatorStaff.initials,
                                           reference: "REFUND")]
        refundOrder.timeline.append(AuditEntry(actor: operatorStaff.initials,
                                               text: "Refund \(value.formatted()) — \(reason)",
                                               glyph: "arrow.uturn.left.circle.fill",
                                               approvedBy: approvedBy, isNotable: true))
        orders.append(refundOrder)

        update(orderID) { ord in
            for ref in items {
                if let i = ord.items.firstIndex(where: { $0.id == ref.itemID }) {
                    ord.items[i].refundedQuantity += ref.quantity
                }
            }
            let fullyRefunded = ord.items.allSatisfy { $0.refundedQuantity >= $0.quantity }
            if fullyRefunded || amount != nil && amount == ord.total { ord.status = .refunded }
            ord.timeline.append(AuditEntry(actor: operatorStaff.initials,
                                           text: "Refunded \(value.formatted()) — \(reason)",
                                           glyph: "arrow.uturn.left.circle.fill",
                                           approvedBy: approvedBy, isNotable: true))
        }
        shift.refunds = shift.refunds + value
        toast(.warn, "Refunded \(value.formatted())",
              detail: "\(tender.label) · \(reason) · logged against \(source.identifierLabel)")
    }

    // MARK: - Bill

    func printBill(_ orderID: UUID) {
        update(orderID) {
            $0.billPrintedAt = .now
            $0.billRequested = true
        }
        log(orderID, "Bill printed", glyph: "doc.text.fill")
        toast(.done, "Bill printed")
    }
}
