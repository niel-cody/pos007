import SwiftUI

extension POSStore {

    // MARK: - Send
    //
    // The tap is acknowledged inside 100 ms by the line leaving Unsent and the Send button
    // changing to "Sending 4". The word Sent and a time never appear before a station confirms.
    // (Canonical §2.2)

    func send(courseID: UUID? = nil) {
        guard let id = currentOrderID, let o = order(id) else { return }
        let targets = o.unsentItems.filter { courseID == nil || $0.courseID == courseID }
        guard !targets.isEmpty else {
            toast(.info, "Nothing to send")
            return
        }

        var routed: [String: [OrderItem]] = [:]
        update(id) { ord in
            for item in targets {
                guard let i = ord.items.firstIndex(where: { $0.id == item.id }) else { continue }
                let station = station(for: item)
                if let device = stationDevices.first(where: { $0.name == station }), !device.online {
                    // A docket that did not reach a station is visible on the line, with a reason.
                    ord.items[i].sendRecords = [SendRecord(station: station, state: .failed,
                                                           failureReason: "Not printed: \(station)")]
                    ord.items[i].status = .sent
                } else if stationDevices.contains(where: { $0.name == station }) {
                    ord.items[i].sendRecords = [SendRecord(station: station)]
                    ord.items[i].status = .sent
                } else {
                    ord.items[i].sendRecords = [SendRecord(station: station, state: .failed,
                                                           failureReason: "No station")]
                    ord.items[i].status = .sent
                }
                routed[station, default: []].append(ord.items[i])
            }
            if ord.status == .draft || ord.status == .placed { ord.status = .open }
            if ord.type.tracksFulfilment, ord.fulfilment == .notStarted || ord.fulfilment == nil {
                ord.fulfilment = .inPreparation
            }
        }

        for (station, items) in routed {
            raiseTicket(orderID: id, station: station, items: items,
                        courseName: courseID.flatMap { o.course($0)?.name })
        }
        log(id, "Sent \(targets.reduce(0) { $0 + $1.quantity }) item\(targets.count == 1 ? "" : "s") to \(routed.keys.sorted().joined(separator: ", "))",
            glyph: "paperplane.fill")

        let failed = routed.keys.filter { name in
            stationDevices.first(where: { $0.name == name })?.online == false
        }
        if failed.isEmpty {
            toast(.done, "Sending \(targets.reduce(0) { $0 + $1.quantity })",
                  detail: routed.keys.sorted().joined(separator: " · "))
        } else {
            toast(.stop, "\(failed.joined(separator: ", ")) did not print",
                  detail: "Reprint, or redirect to another station — the order is safe")
        }
        confirmSends(orderID: id)
    }

    func station(for item: OrderItem) -> String {
        // Drinks go to the bar where there is one, so the bar and kitchen dockets separate
        // themselves without the operator assigning a course by hand. (W05.14)
        if item.isDrink, profile.stations.contains("Bar") { return "Bar" }
        if profile.stations.contains(item.station) { return item.station }
        return profile.stations.first ?? "Kitchen"
    }

    /// Stations confirm asynchronously. Nothing waits for them; the operator may leave.
    private func confirmSends(orderID: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(offline ? 2600 : 900))
            update(orderID) { ord in
                for i in ord.items.indices {
                    for r in ord.items[i].sendRecords.indices
                    where ord.items[i].sendRecords[r].state == .scheduled {
                        ord.items[i].sendRecords[r].state = .confirmed
                        ord.items[i].sendRecords[r].at = .now
                    }
                }
            }
        }
    }

    func reprint(_ itemID: UUID, to station: String? = nil) {
        guard let id = currentOrderID else { return }
        update(id) { ord in
            guard let i = ord.items.firstIndex(where: { $0.id == itemID }) else { return }
            let target = station ?? ord.items[i].station
            ord.items[i].sendRecords = [SendRecord(station: target)]
        }
        confirmSends(orderID: id)
        toast(.done, "Reprinting", detail: station.map { "Redirected to \($0)" })
    }

    /// Re-fire: the kitchen makes it again and the docket says so. (W05.07)
    func refire(_ itemID: UUID) {
        guard let id = currentOrderID, let o = order(id),
              let item = o.items.first(where: { $0.id == itemID }) else { return }
        raiseTicket(orderID: id, station: station(for: item), items: [item],
                    courseName: o.course(item.courseID)?.name, isAddition: true, rush: true)
        log(id, "Re-fired \(item.name) as a rush", glyph: "flame.fill", notable: true)
        toast(.warn, "Re-fired \(item.name)", detail: "Marked rush at \(station(for: item))")
    }

    // MARK: - Courses: hold, fire, call

    /// Fire is an operator act and only that. It releases held items so they may be sent.
    func fireCourse(_ courseID: UUID, andSend: Bool = true) {
        guard let id = currentOrderID, let o = order(id), let course = o.course(courseID) else { return }
        update(id) { ord in
            for i in ord.items.indices where ord.items[i].courseID == courseID && ord.items[i].status == .held {
                ord.items[i].status = .unsent
            }
            if let ci = ord.courses.firstIndex(where: { $0.id == courseID }) {
                ord.courses[ci].firedAt = .now
            }
        }
        log(id, "Fired \(course.name)", glyph: "flame.fill")
        if andSend { send(courseID: courseID) }
        else { toast(.done, "\(course.name) fired", detail: "Send when you are ready") }
    }

    func holdCourse(_ courseID: UUID) {
        guard let id = currentOrderID, let o = order(id), let course = o.course(courseID) else { return }
        update(id) { ord in
            for i in ord.items.indices
            where ord.items[i].courseID == courseID && ord.items[i].status == .unsent {
                ord.items[i].status = .held
            }
            if let ci = ord.courses.firstIndex(where: { $0.id == courseID }) {
                ord.courses[ci].autoFire = false
            }
        }
        log(id, "Held \(course.name)", glyph: "pause.fill")
        toast(.info, "\(course.name) held", detail: "Nothing in it will send until you fire it")
    }

    /// Call a course: the pass is told to get ready. Uncall exists because tables talk. (W05.06)
    func callCourse(_ courseID: UUID) {
        guard let id = currentOrderID, let o = order(id), let course = o.course(courseID) else { return }
        let called = course.calledAt != nil
        update(id) { ord in
            if let ci = ord.courses.firstIndex(where: { $0.id == courseID }) {
                ord.courses[ci].calledAt = called ? nil : .now
            }
        }
        if !called {
            raiseCourseCall(order: o, course: course)
        } else {
            tickets.removeAll { $0.orderID == id && $0.courseName == course.name && $0.lines.isEmpty }
        }
        log(id, called ? "Uncalled \(course.name)" : "Called \(course.name)", glyph: "bell.fill")
        toast(.done, called ? "\(course.name) uncalled" : "\(course.name) called",
              detail: called ? "Nothing was fired twice" : "The pass has the call")
    }

    func addCourse(_ name: String) {
        guard let id = currentOrderID, let o = order(id) else { return }
        update(id) {
            $0.courses.append(Course(name: name, index: o.courses.count, autoFire: false))
        }
    }

    // MARK: - Ready and served
    //
    // A bump on a production station raises Ready. Served is a second act by a different
    // person, needs no permission, and never gates payment. (Canonical §2.4, §2.5)

    func markReady(itemID: UUID, orderID: UUID) {
        update(orderID) { ord in
            if let i = ord.items.firstIndex(where: { $0.id == itemID }) {
                ord.items[i].readyAt = .now
            }
            ord.fulfilment = ord.derivedFulfilment
        }
        for ti in tickets.indices {
            for li in tickets[ti].lines.indices where tickets[ti].lines[li].itemID == itemID {
                tickets[ti].lines[li].isReady = true
            }
            if tickets[ti].lines.allSatisfy(\.isReady), tickets[ti].state != .ready {
                tickets[ti].state = .ready
                tickets[ti].readyAt = .now
            }
        }
    }

    func markServed(itemID: UUID, orderID: UUID) {
        update(orderID) { ord in
            if let i = ord.items.firstIndex(where: { $0.id == itemID }) {
                if ord.items[i].readyAt == nil { ord.items[i].readyAt = .now }
                ord.items[i].servedAt = .now
            }
        }
    }

    /// One tap on a course header or a table writes one event per item in scope, so a later
    /// void does not corrupt the aggregate. (Canonical §2.5)
    func markServedAll(orderID: UUID, courseID: UUID? = nil) {
        guard let o = order(orderID) else { return }
        let scope = o.sentItems.filter { courseID == nil || $0.courseID == courseID }
        for item in scope { markServed(itemID: item.id, orderID: orderID) }
        let what = courseID.flatMap { o.course($0)?.name } ?? "Everything"
        log(orderID, "\(what) marked served", glyph: "checkmark.circle.fill")
        toast(.done, "\(what) served", detail: "\(scope.count) line\(scope.count == 1 ? "" : "s")", undo: "Undo")
        undoStack.append((order: o, label: "Served \(what)"))
    }

    // MARK: - Tickets

    func raiseTicket(orderID: UUID, station: String, items: [OrderItem],
                     courseName: String?, isAddition: Bool = false, rush: Bool = false) {
        guard let o = order(orderID) else { return }
        let lines = items.map { item in
            KitchenLine(itemID: item.id,
                        name: item.displayName,
                        quantity: item.quantity,
                        modifiers: item.modifiers.filter { !$0.isRemoval }.map(\.label),
                        removals: item.modifiers.filter(\.isRemoval).map(\.name),
                        note: item.note,
                        allergens: item.allergens,
                        seat: item.seat,
                        portionBlocks: item.portions.map {
                            PortionBlock(label: $0.slotName.uppercased(),
                                         lines: [$0.productName] + $0.modifiers.map(\.label))
                        })
        }
        let ticket = KitchenTicket(orderID: orderID,
                                   orderLabel: o.identifierLabel,
                                   typeLabel: o.type.short,
                                   station: station,
                                   courseName: courseName,
                                   lines: lines,
                                   isRush: rush,
                                   isAddition: isAddition,
                                   channel: o.channel,
                                   tableLabel: o.tableLabel ?? o.typedTableNumber.map { "T\($0)" },
                                   covers: o.guestCount,
                                   buzzer: o.buzzer)
        tickets.insert(ticket, at: 0)
    }

    func raiseVoidDocket(order: Order, item: OrderItem, reason: String) {
        guard item.isSentOrLater else { return }
        var t = KitchenTicket(orderID: order.id,
                              orderLabel: order.identifierLabel,
                              typeLabel: order.type.short,
                              station: station(for: item),
                              courseName: order.course(item.courseID)?.name,
                              lines: [KitchenLine(itemID: item.id, name: item.displayName,
                                                  quantity: item.quantity, modifiers: [],
                                                  removals: [], note: reason, allergens: [],
                                                  seat: item.seat)],
                              isVoidDocket: true)
        t.tableLabel = order.tableLabel
        tickets.insert(t, at: 0)
    }

    func raiseCourseCall(order: Order, course: Course) {
        var t = KitchenTicket(orderID: order.id,
                              orderLabel: order.identifierLabel,
                              typeLabel: order.type.short,
                              station: profile.stations.first(where: { $0 == "Pass" }) ?? profile.stations.first ?? "Kitchen",
                              courseName: course.name,
                              lines: [])
        t.tableLabel = order.tableLabel
        tickets.insert(t, at: 0)
    }

    // MARK: - KDS actions

    func startTicket(_ id: UUID) {
        guard let i = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[i].state = .started
        tickets[i].startedAt = .now
        update(tickets[i].orderID) { $0.fulfilment = $0.derivedFulfilment }
    }

    /// A bump produces Ready, never Served.
    func bumpTicket(_ id: UUID) {
        guard let i = tickets.firstIndex(where: { $0.id == id }) else { return }
        let ticket = tickets[i]
        tickets[i].state = .ready
        tickets[i].readyAt = .now
        for li in tickets[i].lines.indices { tickets[i].lines[li].isReady = true }
        for line in ticket.lines { markReady(itemID: line.itemID, orderID: ticket.orderID) }
    }

    func recallTicket(_ id: UUID) {
        guard let i = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[i].state = .recalled
        tickets[i].readyAt = nil
        for li in tickets[i].lines.indices { tickets[i].lines[li].isReady = false }
        let ticket = tickets[i]
        update(ticket.orderID) { ord in
            for line in ticket.lines {
                if let ii = ord.items.firstIndex(where: { $0.id == line.itemID }) {
                    ord.items[ii].readyAt = nil
                }
            }
            ord.fulfilment = ord.derivedFulfilment
        }
        toast(.warn, "Recalled", detail: "\(ticket.orderLabel) is back on the board")
    }

    func rushTicket(_ id: UUID) {
        guard let i = tickets.firstIndex(where: { $0.id == id }) else { return }
        tickets[i].isRush.toggle()
    }

    func clearBumped() {
        tickets.removeAll { $0.state == .ready && ($0.readyAt.map { Date.now.timeIntervalSince($0) > 300 } ?? false) }
    }

    /// The kitchen works on its own while the demo runs, so the boards are alive.
    func advanceKitchen() {
        for i in tickets.indices where tickets[i].state == .waiting {
            if tickets[i].ageSeconds > 30 { tickets[i].state = .started; tickets[i].startedAt = .now }
        }
        for oi in orders.indices {
            let derived = orders[oi].derivedFulfilment
            if orders[oi].fulfilment != derived, orders[oi].type.tracksFulfilment {
                orders[oi].fulfilment = derived
            }
        }
    }

    // MARK: - Fulfilment (the counter's side)

    func markOrderReady(_ id: UUID) {
        guard let o = order(id) else { return }
        for item in o.sentItems where item.readyAt == nil { markReady(itemID: item.id, orderID: id) }
        update(id) { $0.fulfilment = .ready }
        toast(.done, "\(o.identifierLabel) ready")
    }

    func callOrder(_ id: UUID) {
        update(id) { $0.calledAt = .now }
        guard let o = order(id) else { return }
        toast(.info, "Called \(o.identifierLabel)", detail: "On the collection display")
    }

    func handOver(_ id: UUID, type: HandoverType = .guest, driver: String? = nil) {
        guard let o = order(id) else { return }
        update(id) {
            $0.fulfilment = .handedOver
            $0.handoverType = type
            if let driver { $0.delivery?.driver = driver }
        }
        log(id, "Handed over to \(type.rawValue)\(driver.map { " — \($0)" } ?? "")",
            glyph: "hand.raised.fill")
        toast(.done, "\(o.identifierLabel) handed over")
    }

    func markFailed(_ id: UUID, reason: String) {
        update(id) {
            $0.fulfilment = .failed
            $0.delivery?.failureReason = reason
        }
        log(id, "Delivery failed — \(reason)", glyph: "exclamationmark.triangle.fill", notable: true)
        toast(.stop, "Delivery failed", detail: "\(reason) · decide refund, re-deliver or retain")
    }

    func resolveFailed(_ id: UUID, resolution: String) {
        update(id) {
            $0.fulfilment = .resolved
            $0.delivery?.resolution = resolution
        }
        log(id, "Failed delivery resolved — \(resolution)", glyph: "checkmark.seal.fill", notable: true)
    }

    // MARK: - Devices

    func toggleStation(_ id: UUID) {
        guard let i = stationDevices.firstIndex(where: { $0.id == id }) else { return }
        stationDevices[i].online.toggle()
        let d = stationDevices[i]
        toast(d.online ? .done : .stop,
              d.online ? "\(d.name) back online" : "\(d.name) offline",
              detail: d.online ? "Queued dockets will flush" : "Sends will be marked Not printed with the reason")
    }
}
