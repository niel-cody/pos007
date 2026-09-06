import SwiftUI

extension POSStore {

    // MARK: - The inbox
    //
    // Accept on the alert itself, and Accept all for a batch. On a ninety second aggregator
    // clock, navigation is how an order gets reassigned to another venue. (W12.02)

    func accept(_ orderID: UUID) {
        guard let o = order(orderID) else { return }
        update(orderID) {
            $0.status = .open
            $0.fulfilment = .inPreparation
            for i in $0.items.indices where $0.items[i].status == .unsent {
                $0.items[i].status = .sent
                $0.items[i].sendRecords = [SendRecord(station: station(for: $0.items[i]))]
            }
        }
        if let updated = order(orderID) {
            var byStation: [String: [OrderItem]] = [:]
            for item in updated.sentItems { byStation[station(for: item), default: []].append(item) }
            for (st, items) in byStation {
                raiseTicket(orderID: orderID, station: st, items: items, courseName: nil)
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(800))
            update(orderID) { ord in
                for i in ord.items.indices {
                    for r in ord.items[i].sendRecords.indices where ord.items[i].sendRecords[r].state == .scheduled {
                        ord.items[i].sendRecords[r].state = .confirmed
                    }
                }
            }
        }
        log(orderID, "Accepted from \(o.channel.label)", glyph: "checkmark.circle.fill")
        toast(.done, "Accepted \(o.identifierLabel)", detail: "\(o.channel.label) · straight to the kitchen")
    }

    func acceptAll() {
        let batch = onlineInbox
        for o in batch { accept(o.id) }
        toast(.done, "Accepted \(batch.count) orders", detail: "Every channel, one tap")
    }

    func reject(_ orderID: UUID, reason: String) {
        guard let o = order(orderID) else { return }
        update(orderID) { $0.status = .cancelled }
        log(orderID, "Rejected — \(reason)", glyph: "xmark.circle.fill", notable: true)
        toast(.warn, "Rejected \(o.identifierLabel)", detail: "\(reason) · stock returned")
    }

    func setPrepTime(_ minutes: Int) {
        toast(.done, "Prep time \(minutes) min", detail: "Pushed to every channel")
    }

    func pauseChannel(_ channel: SalesChannel, minutes: Int) {
        toast(.warn, "\(channel.label) paused \(minutes) min",
              detail: "Better than rejecting orders one at a time")
    }

    /// An order arriving mid-demo, because that is what a rush feels like.
    func simulateIncomingOrder() {
        let channel = profile.channels.filter { $0 != .pos }.randomElement() ?? .ownWeb
        let names = ["Priya", "Tom", "Marcus", "Ada", "Jules", "Rob", "Kiri", "Sam"]
        var o = Order(number: nextOrderNumber,
                      type: channel.isPartner ? .delivery : .takeaway)
        nextOrderNumber += 1
        o.status = .placed
        o.channel = channel
        o.name = names.randomElement()
        o.customerName = o.name
        o.phone = "04\(Int.random(in: 10...99)) \(Int.random(in: 100...999)) \(Int.random(in: 100...999))"
        o.partnerReference = channel.isPartner ? "#\(Int.random(in: 1000...9999))" : nil
        o.fulfilment = .notStarted
        o.dueAt = .now.addingTimeInterval(Double(Int.random(in: 12...30)) * 60)
        if o.type == .delivery {
            o.delivery = DeliveryDetails(address: "\(Int.random(in: 2...80)) Barkly St",
                                         zone: "Zone 1", fee: Money(4.5))
        }
        let pool = catalogue.products.filter { $0.isAvailable && !$0.hasChoices }
        for p in pool.shuffled().prefix(Int.random(in: 1...3)) {
            let priced = PricingEngine.price(p, variant: nil, in: catalogue, context: pricingContext)
            o.items.append(OrderItem(productID: p.id, name: p.name, unitPrice: priced.price,
                                     listPrice: priced.listPrice,
                                     quantity: Int.random(in: 1...2),
                                     station: p.station, addedBy: channel.label,
                                     isDrink: p.isDrink, source: "online"))
        }
        // Prepaid on partner channels; pay at venue on the venue's own.
        if channel.isPartner {
            o.payments = [PaymentLeg(kind: .other, amount: o.total, staff: channel.label,
                                     reference: "PREPAID \(channel.label)")]
        }
        orders.append(o)
        if profile.autoAcceptOwnChannel && !channel.isPartner {
            accept(o.id)
        } else {
            toast(.info, "New \(channel.label) order", detail: "\(o.identifierLabel) · \(o.itemCount) items · accept on this alert")
        }
    }

    // MARK: - Delivery and takeaway details
    //
    // Name, phone and pickup time are three fields in one sheet, opened once, because the
    // operator is on the telephone while they fill it in. (W12.16)

    func setDetails(orderID: UUID, name: String?, phone: String?, dueAt: Date?,
                    address: String?, instructions: String?, zone: String?, buzzer: String?,
                    tableNumber: String?, covers: Int?, room: String?) {
        update(orderID) { o in
            if let name, !name.isEmpty { o.name = name; o.customerName = name }
            if let phone, !phone.isEmpty { o.phone = phone }
            o.dueAt = dueAt
            if let buzzer, !buzzer.isEmpty { o.buzzer = buzzer }
            if let tableNumber, !tableNumber.isEmpty { o.typedTableNumber = tableNumber }
            if let covers { o.guestCount = covers }
            if let room, !room.isEmpty { o.roomNumber = room }
            if o.type == .delivery || address?.isEmpty == false {
                var d = o.delivery ?? DeliveryDetails()
                if let address { d.address = address }
                if let instructions { d.instructions = instructions }
                if let zone, !zone.isEmpty {
                    d.zone = zone
                    d.fee = zone == "Zone 2" ? Money(7.5) : Money(4.5)
                }
                o.delivery = d
            }
        }
        applyAutomaticAdjustments()
    }

    /// Two guests called Sarah in the same five minutes. The current product does nothing
    /// about this; the target disambiguates with a suffix. (W03.11)
    func disambiguate(_ name: String) -> String {
        let clashes = orders.filter { $0.status.isLive || $0.derivedFulfilment == .ready }
            .compactMap { $0.name }
            .filter { $0.lowercased().hasPrefix(name.lowercased()) }
        guard !clashes.isEmpty else { return name }
        return "\(name) \(clashes.count + 1)"
    }

    func setOrderType(_ orderID: UUID, _ type: OrderType) {
        update(orderID) { o in
            o.type = type
            o.fulfilment = type.tracksFulfilment ? (o.fulfilment ?? .notStarted) : nil
            if type != .delivery { o.delivery = nil }
        }
        applyAutomaticAdjustments()
    }

    // MARK: - Customers

    func attach(customer: Customer, to orderID: UUID) {
        update(orderID) {
            $0.customerID = customer.id
            $0.customerName = customer.name
            if $0.phone == nil { $0.phone = customer.phone }
            if $0.type == .delivery, let a = customer.address {
                var d = $0.delivery ?? DeliveryDetails()
                if d.address.isEmpty { d.address = a }
                if let i = customer.deliveryInstructions, d.instructions.isEmpty { d.instructions = i }
                $0.delivery = d
            }
        }
        applyAutomaticAdjustments()
        var detail: [String] = []
        if customer.isMember { detail.append("Member price applies") }
        if let a = customer.allergyNote { detail.append(a) }
        if customer.isVIP { detail.append("VIP") }
        if customer.loyaltyPoints > 0 { detail.append("\(customer.loyaltyPoints) points") }
        toast(.done, customer.name, detail: detail.isEmpty ? nil : detail.joined(separator: " · "))
    }

    func detach(from orderID: UUID) {
        update(orderID) {
            $0.customerID = nil
            $0.customerName = nil
        }
        applyAutomaticAdjustments()
    }

    func searchCustomers(_ q: String) -> [Customer] {
        let query = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return Array(customers.prefix(8)) }
        return customers.filter {
            $0.name.lowercased().contains(query)
            || $0.phone.replacingOccurrences(of: " ", with: "").contains(query.replacingOccurrences(of: " ", with: ""))
            || ($0.memberNumber?.lowercased().contains(query) ?? false)
        }
    }

    func createCustomer(name: String, phone: String) -> Customer? {
        // Duplicate detection before creation, not after. (W13.03)
        if let existing = customers.first(where: { $0.phone.replacingOccurrences(of: " ", with: "")
            == phone.replacingOccurrences(of: " ", with: "") && !phone.isEmpty }) {
            toast(.warn, "That number is already \(existing.name)", detail: "Attached the existing customer")
            return existing
        }
        let c = Customer(name: name, phone: phone)
        customers.insert(c, at: 0)
        return c
    }

    func redeemLoyalty(_ orderID: UUID) {
        guard let o = order(orderID), let cid = o.customerID,
              let ci = customers.firstIndex(where: { $0.id == cid }),
              customers[ci].loyaltyPoints >= 100 else {
            toast(.warn, "Not enough points")
            return
        }
        customers[ci].loyaltyPoints -= 100
        update(orderID) {
            $0.adjustments.append(Adjustment(kind: .loyaltyReward, name: "Loyalty reward",
                                             amount: Money(-5), appliedBy: operatorStaff.initials))
        }
        toast(.done, "Reward redeemed", detail: "−$5.00 · \(customers[ci].loyaltyPoints) points left")
    }
}
