import SwiftUI

// MARK: - Order details
//
// Name, phone, time, address, table, covers: one sheet, opened once, because the operator is
// on the telephone while they fill it in.

struct OrderDetailsSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var name = ""
    @State private var phone = ""
    @State private var table = ""
    @State private var buzzer = ""
    @State private var room = ""
    @State private var address = ""
    @State private var instructions = ""
    @State private var zone = "Zone 1"
    @State private var covers = 2
    @State private var scheduled = false
    @State private var due = Date.now.addingTimeInterval(1800)

    private var order: Order? { store.currentOrder }

    var body: some View {
        if let order {
            SheetFrame(title: "Order details",
                       subtitle: "\(order.type.label) · \(order.identifierLabel)",
                       glyph: order.type.glyph) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        typeBlock(order)
                        if store.profile.identifier == .customerName || order.type != .dineIn {
                            nameBlock
                        }
                        if store.profile.typedTableNumber && order.type == .dineIn {
                            tableBlock
                        }
                        if store.profile.promptGuestCount && order.type == .dineIn {
                            coversBlock
                        }
                        if order.type == .delivery {
                            deliveryBlock
                        }
                        if order.type != .dineIn {
                            timingBlock
                        }
                        if store.mode == .fineDining || store.profile.houseAccounts {
                            roomBlock
                        }
                    }
                    .padding(Metric.padLarge)
                }
            } footer: {
                HStack(spacing: 10) {
                    SecondaryAction(title: "Cancel") { store.route = nil }
                    PrimaryAction(title: "Save", glyph: "checkmark") { save(order) }
                }
            }
            .onAppear { prime(order) }
        }
    }

    private func typeBlock(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Order type", detail: "changes pricing, routing and what is asked for")
            HStack(spacing: 7) {
                ForEach(store.profile.orderTypes) { t in
                    let active = order.type == t
                    Button {
                        store.setOrderType(order.id, t)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.glyph).font(.system(size: 16, weight: .semibold))
                            Text(t.label).font(.system(size: 13, weight: active ? .semibold : .regular))
                        }
                        .frame(maxWidth: .infinity).frame(height: 62)
                        .foregroundStyle(active ? .white : theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                .fill(active ? theme.accent : theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                                }
                        }
                    }
                    .posPress()
                }
            }
        }
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Name", detail: "goes on the cup, the docket and the collection screen")
            field($name, "Sam", glyph: "person")
            // Recent names remove four of the five taps in the name step.
            let recents = ["Sam", "Alex", "Priya", "Josh", "Marcus", "Sarah"]
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(recents, id: \.self) { r in
                        Button {
                            name = store.disambiguate(r)
                            if name != r {
                                store.toast(.info, "There is already a \(r)",
                                            detail: "Named this one \(name) so nobody gets the wrong drink")
                            }
                        } label: {
                            Text(r)
                                .font(.system(size: 14, weight: .medium))
                                .padding(.horizontal, 13).frame(height: 38)
                                .foregroundStyle(theme.ink)
                                .background(Capsule().fill(theme.accentSoft))
                        }
                        .posPress()
                    }
                }
            }
            PanelHeader("Phone")
            field($phone, "0412 345 678", glyph: "phone")
        }
    }

    private var tableBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Table number", detail: "typed, because this venue has no floor plan")
            HStack(spacing: 7) {
                field($table, "24", glyph: "number")
                if store.profile.buzzerEnabled {
                    field($buzzer, "Buzzer 12", glyph: "bell.badge")
                }
            }
        }
    }

    private var coversBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Covers", detail: "drives pacing, section stats and the service charge")
            HStack(spacing: 6) {
                ForEach(1...10, id: \.self) { n in
                    Button {
                        covers = n
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity).frame(height: 48)
                            .foregroundStyle(covers == n ? .white : theme.ink)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                    .fill(covers == n ? theme.accent : theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                    }
                            }
                    }
                    .posPress()
                }
            }
        }
    }

    private var deliveryBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Delivery")
            field($address, "14 Kestrel St", glyph: "mappin.and.ellipse")
            field($instructions, "Blue door, dog in the yard", glyph: "text.bubble")
            HStack(spacing: 7) {
                ForEach(["Zone 1", "Zone 2", "Outside"], id: \.self) { z in
                    Button {
                        zone = z
                    } label: {
                        VStack(spacing: 1) {
                            Text(z).font(.system(size: 13.5, weight: zone == z ? .semibold : .regular))
                            Text(z == "Zone 1" ? "$4.50" : (z == "Zone 2" ? "$7.50" : "not delivered"))
                                .font(.system(size: 11, design: .rounded)).opacity(0.8)
                        }
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .foregroundStyle(zone == z ? .white : (z == "Outside" ? Palette.stop : theme.ink))
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                .fill(zone == z ? theme.accent : theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                                }
                        }
                    }
                    .posPress()
                }
            }
            if zone == "Outside" {
                Text("Outside the delivery zone. Offer pickup, or a manager can override the zone.")
                    .font(.system(size: 12)).foregroundStyle(Palette.stop)
            }
        }
    }

    private var timingBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("When")
            HStack(spacing: 7) {
                ForEach([0, 15, 30, 45, 60], id: \.self) { m in
                    Button {
                        scheduled = m > 0
                        due = .now.addingTimeInterval(Double(m) * 60)
                    } label: {
                        Text(m == 0 ? "ASAP" : "\(m) min")
                            .font(.system(size: 14, weight: .medium))
                            .frame(maxWidth: .infinity).frame(height: 44)
                            .foregroundStyle(theme.ink)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                    .fill(theme.surface)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                    }
                            }
                    }
                    .posPress()
                }
            }
            DatePicker("Ready at", selection: $due, displayedComponents: [.hourAndMinute])
                .font(.system(size: 14))
        }
    }

    private var roomBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Room or account", detail: "charges to the guest's folio")
            field($room, "Room 412", glyph: "bed.double")
        }
    }

    private func field(_ binding: Binding<String>, _ placeholder: String, glyph: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: glyph).font(.system(size: 14)).foregroundStyle(theme.inkSecondary)
            TextField(placeholder, text: binding)
                .font(.system(size: 16))
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                }
        }
    }

    private func prime(_ order: Order) {
        name = order.name ?? ""
        phone = order.phone ?? ""
        table = order.typedTableNumber ?? ""
        buzzer = order.buzzer ?? ""
        room = order.roomNumber ?? ""
        covers = order.guestCount ?? 2
        address = order.delivery?.address ?? ""
        instructions = order.delivery?.instructions ?? ""
        zone = order.delivery?.zone.isEmpty == false ? order.delivery!.zone : "Zone 1"
        if let d = order.dueAt { due = d; scheduled = true }
    }

    private func save(_ order: Order) {
        store.setDetails(orderID: order.id,
                         name: name.isEmpty ? nil : name,
                         phone: phone.isEmpty ? nil : phone,
                         dueAt: scheduled ? due : nil,
                         address: address.isEmpty ? nil : address,
                         instructions: instructions.isEmpty ? nil : instructions,
                         zone: order.type == .delivery ? zone : nil,
                         buzzer: buzzer.isEmpty ? nil : buzzer,
                         tableNumber: table.isEmpty ? nil : table,
                         covers: covers,
                         room: room.isEmpty ? nil : room)
        store.route = nil
    }
}

// MARK: - Customers

struct CustomerSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var query = ""
    @State private var newName = ""
    @State private var newPhone = ""

    var body: some View {
        SheetFrame(title: "Customer",
                   subtitle: "a lookup must not slow down a sale",
                   glyph: "person.crop.circle") {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass").font(.system(size: 15)).foregroundStyle(theme.inkSecondary)
                    TextField("Name, phone or member number", text: $query)
                        .font(.system(size: 16)).textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                        .fill(theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                        }
                }
                .padding(Metric.padLarge)

                ScrollView {
                    VStack(spacing: 7) {
                        ForEach(store.searchCustomers(query)) { c in
                            row(c)
                        }
                        if store.searchCustomers(query).isEmpty {
                            VStack(alignment: .leading, spacing: 9) {
                                PanelHeader("New customer", detail: "duplicates are caught before creation")
                                TextField("Name", text: $newName)
                                    .font(.system(size: 16)).textFieldStyle(.plain)
                                    .padding(12)
                                    .background {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .fill(theme.surface)
                                    }
                                TextField("Phone", text: $newPhone)
                                    .font(.system(size: 16)).textFieldStyle(.plain)
                                    .padding(12)
                                    .background {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .fill(theme.surface)
                                    }
                                PrimaryAction(title: "Create and attach", glyph: "plus",
                                              enabled: !newName.isEmpty) {
                                    if let c = store.createCustomer(name: newName, phone: newPhone),
                                       let id = store.currentOrderID {
                                        store.attach(customer: c, to: id)
                                    }
                                    store.route = nil
                                }
                            }
                            .padding(.horizontal, Metric.padLarge)
                        }
                    }
                    .padding(.bottom, Metric.padLarge)
                }
            }
        } footer: {
            HStack(spacing: 10) {
                if store.currentOrder?.customerID != nil {
                    SecondaryAction(title: "Remove the customer", glyph: "person.badge.minus") {
                        if let id = store.currentOrderID { store.detach(from: id) }
                        store.route = nil
                    }
                }
                SecondaryAction(title: "Anonymous guest") { store.route = nil }
            }
        }
    }

    private func row(_ c: Customer) -> some View {
        HStack(spacing: 11) {
            Text(c.initials)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(c.isVIP ? Palette.warn : theme.inkSecondary))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(c.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                    if c.isMember { Chip(text: "Member", glyph: "checkmark.seal.fill", tint: Palette.go, small: true) }
                    if c.isVIP { Chip(text: "VIP", glyph: "star.fill", tint: Palette.warn, small: true) }
                    if let g = c.group { Chip(text: g, small: true) }
                }
                Text(detail(c)).font(.system(size: 12)).foregroundStyle(theme.inkSecondary).lineLimit(1)
                if let a = c.allergyNote {
                    Chip(text: a, glyph: "exclamationmark.shield.fill", tint: Palette.stop, filled: true, small: true)
                }
            }
            Spacer(minLength: 6)
            if !c.usualOrderProductNames.isEmpty {
                Button {
                    store.addUsual(for: c)
                    store.route = nil
                } label: {
                    VStack(spacing: 0) {
                        Text("The usual").font(.system(size: 13, weight: .semibold))
                        Text(c.usualOrderProductNames.joined(separator: ", "))
                            .font(.system(size: 10.5)).lineLimit(1)
                    }
                    .padding(.horizontal, 13).frame(height: 44)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(theme.accent))
                }
                .posPress()
            }
            Button {
                if let id = store.currentOrderID { store.attach(customer: c, to: id) }
                store.route = nil
            } label: {
                Text("Attach")
                    .font(.system(size: 14, weight: .semibold))
                    .padding(.horizontal, 15).frame(height: 44)
                    .foregroundStyle(theme.accent)
                    .background(Capsule().fill(theme.accentSoft))
            }
            .posPress()
        }
        .padding(.horizontal, Metric.padLarge)
        .padding(.vertical, 9)
    }

    private func detail(_ c: Customer) -> String {
        var parts = [c.phone]
        if c.loyaltyPoints > 0 { parts.append("\(c.loyaltyPoints) points") }
        if let b = c.houseAccountBalance { parts.append("account \(b.formatted())") }
        if c.visits > 0 { parts.append("\(c.visits) visits") }
        if let n = c.note { parts.append(n) }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Discounts

struct DiscountSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var itemID: UUID?

    @State private var percent: Double?
    @State private var amountPad = ""
    @State private var targetPad = ""
    @State private var mode = 0

    private var item: OrderItem? {
        itemID.flatMap { id in store.currentOrder?.liveItems.first { $0.id == id } }
    }
    private var base: Money { item?.gross ?? store.currentOrder?.subtotal ?? .zero }

    var body: some View {
        SheetFrame(title: item.map { "Discount \($0.name)" } ?? "Discount the order",
                   subtitle: "\(base.formatted()) before the discount",
                   glyph: "tag.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader("Percentage")
                        HStack(spacing: 7) {
                            ForEach([5.0, 10.0, 15.0, 20.0, 50.0], id: \.self) { p in
                                Button {
                                    percent = percent == p ? nil : p
                                    mode = 0
                                } label: {
                                    VStack(spacing: 1) {
                                        Text("\(Int(p))%").font(.system(size: 17, weight: .semibold))
                                        Text("−\(base.percent(p).formatted())")
                                            .font(.system(size: 11, design: .rounded)).moneyFigure().opacity(0.8)
                                    }
                                    .frame(maxWidth: .infinity).frame(height: 56)
                                    .foregroundStyle(percent == p ? .white : theme.ink)
                                    .background {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .fill(percent == p ? theme.accent : theme.surface)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .strokeBorder(theme.hairline, lineWidth: 0.7)
                                            }
                                    }
                                }
                                .posPress()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader("Named venue discounts", detail: "the ones this venue actually uses")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                            ForEach(NamedDiscounts.all, id: \.0) { named in
                                Button {
                                    apply(named.1, name: named.0)
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(named.0).font(.system(size: 14, weight: .semibold))
                                        Text("\(Int(named.1))% · −\(base.percent(named.1).formatted())")
                                            .font(.system(size: 11, design: .rounded)).moneyFigure().opacity(0.8)
                                    }
                                    .padding(.horizontal, 11)
                                    .frame(height: 52, alignment: .leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(theme.ink)
                                    .background {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .fill(theme.surface)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .strokeBorder(theme.hairline, lineWidth: 0.7)
                                            }
                                    }
                                }
                                .posPress()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader(itemID == nil ? "Or set the total the guest pays" : "Or take an amount off")
                        NumberPad(value: itemID == nil ? $targetPad : $amountPad,
                                  style: .money,
                                  confirmTitle: itemID == nil
                                    ? "Make the total \(Money(cents: Int(targetPad) ?? 0).formatted())"
                                    : "Take off \(Money(cents: Int(amountPad) ?? 0).formatted())",
                                  confirmEnabled: (Int(itemID == nil ? targetPad : amountPad) ?? 0) > 0) {
                            if itemID == nil {
                                applyTarget(Money(cents: Int(targetPad) ?? 0))
                            } else {
                                applyAmount(Money(cents: Int(amountPad) ?? 0))
                            }
                        }
                    }
                }
                .padding(Metric.padLarge)
            }
        } footer: {
            HStack(spacing: 10) {
                SecondaryAction(title: "Cancel") { store.route = nil }
                if let p = percent {
                    PrimaryAction(title: "Apply \(Int(p))% · −\(base.percent(p).formatted())",
                                  glyph: "tag.fill") {
                        apply(p, name: "\(Int(p))% discount")
                    }
                }
            }
        }
    }

    /// Anything above a small percentage needs a reason and, for most roles, approval.
    private func apply(_ p: Double, name: String) {
        let permission: Permission = p > 10 ? .discountAny : .discountSmall
        store.requireApproval(permission,
                              what: "\(name) on \(item?.name ?? "the order")",
                              detail: "−\(base.percent(p).formatted())",
                              reasons: p > 10 ? VoidReasons.discount : []) { approver, reason in
            if let id = itemID {
                store.applyItemDiscount(id, percent: p, amount: nil, name: name,
                                        reason: reason, approvedBy: approver.initials)
            } else {
                store.applyOrderDiscount(percent: p, amount: nil, name: name,
                                         reason: reason, approvedBy: approver.initials)
            }
            store.route = nil
        }
    }

    private func applyAmount(_ amount: Money) {
        store.requireApproval(.discountAny, what: "Take \(amount.formatted()) off",
                              reasons: VoidReasons.discount) { approver, reason in
            if let id = itemID {
                store.applyItemDiscount(id, percent: nil, amount: amount, name: "Discount",
                                        reason: reason, approvedBy: approver.initials)
            } else {
                store.applyOrderDiscount(percent: nil, amount: amount, name: "Discount",
                                         reason: reason, approvedBy: approver.initials)
            }
            store.route = nil
        }
    }

    private func applyTarget(_ target: Money) {
        store.requireApproval(.discountAny, what: "Make the total \(target.formatted())",
                              reasons: VoidReasons.discount) { approver, reason in
            store.applyOrderDiscount(percent: nil, amount: nil, targetTotal: target,
                                     name: "Total set to \(target.formatted())",
                                     reason: reason, approvedBy: approver.initials)
            store.route = nil
        }
    }
}

// MARK: - Void a sent item

struct VoidSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var itemID: UUID
    @State private var reason: String?
    @State private var quantity = 1

    private var item: OrderItem? { store.currentOrder?.liveItems.first { $0.id == itemID } }

    var body: some View {
        SheetFrame(title: "Void \(item?.name ?? "")",
                   subtitle: "the kitchen has this, so it becomes wastage",
                   glyph: "xmark.bin.fill") {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let item, item.quantity > 1 {
                        VStack(alignment: .leading, spacing: 7) {
                            PanelHeader("How many of the \(item.quantity)")
                            HStack(spacing: 7) {
                                ForEach(1...item.quantity, id: \.self) { n in
                                    Button {
                                        quantity = n
                                    } label: {
                                        Text("\(n)")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .frame(maxWidth: .infinity).frame(height: 48)
                                            .foregroundStyle(quantity == n ? .white : theme.ink)
                                            .background {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .fill(quantity == n ? theme.accent : theme.surface)
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                                                    }
                                            }
                                    }
                                    .posPress()
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        PanelHeader("Reason", detail: "prints on the void docket and goes to reporting")
                        ForEach(VoidReasons.sent, id: \.self) { r in
                            Button {
                                reason = r
                            } label: {
                                HStack {
                                    Image(systemName: reason == r ? "largecircle.fill.circle" : "circle")
                                        .font(.system(size: 15))
                                    Text(r).font(.system(size: 15, weight: reason == r ? .semibold : .regular))
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 48)
                                .foregroundStyle(reason == r ? .white : theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(reason == r ? theme.accent : theme.surface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                                        }
                                }
                            }
                            .posPress()
                        }
                    }
                }
                .padding(Metric.padLarge)
            }
        } footer: {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    SecondaryAction(title: "Keep it") { store.route = nil }
                    PrimaryAction(title: "Void and tell the kitchen",
                                  glyph: "xmark.bin.fill",
                                  tint: Palette.stop,
                                  enabled: reason != nil) {
                        guard let reason else { return }
                        store.requireApproval(.voidSent, what: "Void \(item?.name ?? "")",
                                              detail: reason) { approver, _ in
                            store.voidItem(itemID, reason: reason, approvedBy: approver.initials)
                            store.route = nil
                        }
                    }
                }
                Text("A void docket goes to \(item.map { store.station(for: $0) } ?? "the kitchen") so nobody makes it twice.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.inkSecondary)
            }
        }
    }
}
