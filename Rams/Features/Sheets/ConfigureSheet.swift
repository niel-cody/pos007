import SwiftUI

/// One sheet, every group visible, a running price in the header. This is the workflow that
/// takes the Australian coffee matrix from twenty-four taps across eleven screens to twelve
/// taps on one — and the eight decisions that remain are the guest's, not the interface's.
struct ConfigureSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var product: Product
    var editingItemID: UUID?

    @State private var variant: VariantOption?
    @State private var selections: [SelectedModifier] = []
    @State private var quantity = 1
    @State private var note = ""
    @State private var searchByGroup: [UUID: String] = [:]
    @State private var seat: Int?

    var body: some View {
        SheetFrame(title: product.name,
                   subtitle: subtitle,
                   glyph: product.glyph) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !product.variants.isEmpty { variantBlock }
                    // Two columns, so seven modifier groups fit on one tablet screen.
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 13) {
                            ForEach(leftGroups) { groupBlock($0) }
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        if !rightGroups.isEmpty {
                            VStack(alignment: .leading, spacing: 13) {
                                ForEach(rightGroups) { groupBlock($0) }
                                noteBlock
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }
                    if rightGroups.isEmpty { noteBlock }
                }
                .padding(Metric.padLarge)
            }
        } footer: {
            footer
        }
        .onAppear(perform: prime)
    }

    private var subtitle: String {
        var parts: [String] = []
        if let a = product.allergens.first.map({ _ in product.allergens.joined(separator: ", ") }) {
            parts.append("Contains \(a)")
        }
        let unanswered = product.groups.filter { group in
            group.isRequired && group.modifiers.filter(\.isDefault).count < group.min
        }.count
        if unanswered > 0 {
            parts.append("\(unanswered) choice\(unanswered == 1 ? "" : "s") to make")
        }
        parts.append(product.station)
        return parts.joined(separator: " · ")
    }

    /// Groups are dealt into two columns by weight, so neither column runs long. The same
    /// split decides how tall the sheet needs to be.
    static func deal(_ groups: [ModifierGroup], twoColumns: Bool) -> ([ModifierGroup], [ModifierGroup]) {
        guard twoColumns else { return (groups, []) }
        var left: [ModifierGroup] = []
        var right: [ModifierGroup] = []
        var leftWeight = 0
        var rightWeight = 0
        for group in groups {
            let weight = 1 + (min(group.modifiers.count, 8) + 1) / 2
            if leftWeight <= rightWeight { left.append(group); leftWeight += weight }
            else { right.append(group); rightWeight += weight }
        }
        return (left, right)
    }

    /// Rows of tiles plus a header per group, in points, for the taller column.
    static func contentHeight(for product: Product, twoColumns: Bool) -> CGFloat {
        let (left, right) = deal(product.groups, twoColumns: twoColumns)
        func height(_ groups: [ModifierGroup]) -> CGFloat {
            groups.reduce(CGFloat(0)) { total, group in
                let perRow = twoColumns ? 2 : 4
                let shown = group.needsSearch
                    ? max(2, group.modifiers.filter(\.pinned).count)
                    : group.modifiers.count
                let rows = CGFloat((shown + perRow - 1) / perRow)
                return total + 24 + rows * 50 + 13
            }
        }
        // The note block sits at the foot of the right column in two-column layouts.
        let note: CGFloat = 108
        let tallest = twoColumns
            ? max(height(left), height(right) + note)
            : height(left) + note
        let variants: CGFloat = product.variants.isEmpty ? 0 : 80
        return variants + tallest + 40
    }

    private var columns: ([ModifierGroup], [ModifierGroup]) {
        guard product.groups.count > 2 else { return (product.groups, []) }
        var left: [ModifierGroup] = []
        var right: [ModifierGroup] = []
        var leftWeight = 0
        var rightWeight = 0
        for group in product.groups {
            let weight = 1 + (min(group.modifiers.count, 8) + 1) / 2
            if leftWeight <= rightWeight {
                left.append(group); leftWeight += weight
            } else {
                right.append(group); rightWeight += weight
            }
        }
        return (left, right)
    }

    private var leftGroups: [ModifierGroup] { columns.0 }
    private var rightGroups: [ModifierGroup] { columns.1 }

    // MARK: - Variants
    //
    // Size is a segmented control at the top, because it is the axis that changes every
    // price below it.

    private var variantBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader(product.variantAxisName ?? "Size")
            HStack(spacing: 7) {
                ForEach(product.variants) { v in
                    let active = variant?.id == v.id
                    Button {
                        withAnimation(Motion.tap) { variant = v }
                    } label: {
                        VStack(spacing: 2) {
                            Text(v.label).font(.system(size: 15, weight: .semibold))
                            Text((product.price + v.priceDelta).formatted())
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .moneyFigure()
                                .opacity(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .foregroundStyle(active ? .white : theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                .fill(active ? theme.accent : theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                        .strokeBorder(active ? .clear : theme.hairline, lineWidth: 0.7)
                                }
                        }
                    }
                    .posPress()
                }
            }
        }
    }

    // MARK: - Groups

    @ViewBuilder private func groupBlock(_ group: ModifierGroup) -> some View {
        let query = searchByGroup[group.id] ?? ""
        let visible = visibleModifiers(group, query: query)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                PanelHeader(group.name, detail: requirementHint(group))
                if group.needsSearch {
                    HStack(spacing: 5) {
                        Image(systemName: "magnifyingglass").font(.system(size: 11))
                        TextField("Find", text: Binding(
                            get: { searchByGroup[group.id] ?? "" },
                            set: { searchByGroup[group.id] = $0 }))
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .frame(width: 110)
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 30)
                    .foregroundStyle(theme.inkSecondary)
                    .background {
                        Capsule().fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                    }
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7),
                                     count: rightGroups.isEmpty ? 4 : 2), spacing: 7) {
                ForEach(visible) { mod in
                    modifierTile(group, mod)
                }
            }
            if group.needsSearch && query.isEmpty && group.modifiers.count > visible.count {
                Text("\(group.modifiers.count - visible.count) more — search to find them")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.inkSecondary.opacity(0.85))
            }
        }
    }

    /// Pinned favourites first; the long tail only when it is asked for.
    private func visibleModifiers(_ group: ModifierGroup, query: String) -> [Modifier] {
        if !query.isEmpty {
            return group.modifiers.filter { $0.name.lowercased().contains(query.lowercased()) }
        }
        guard group.needsSearch else { return group.modifiers }
        let pinned = group.modifiers.filter { $0.pinned || isSelected(group, $0) }
        return pinned.isEmpty ? Array(group.modifiers.prefix(4)) : pinned
    }

    private func requirementHint(_ group: ModifierGroup) -> String? {
        let chosen = selections.filter { $0.groupID == group.id && !$0.isRemoval }
            .reduce(0) { $0 + $1.quantity }
        switch group.selection {
        case .single:
            return group.isRequired ? (chosen == 0 ? "choose one" : nil) : "one, or none"
        case .quantity:
            return "tap to add more"
        case .multi:
            if group.max > 0 { return "up to \(group.max)\(chosen > 0 ? " · \(chosen) chosen" : "")" }
            return chosen > 0 ? "\(chosen) chosen" : "any"
        }
    }

    private func isSelected(_ group: ModifierGroup, _ mod: Modifier) -> Bool {
        selections.contains { $0.groupID == group.id && $0.modifierID == mod.id && !$0.isRemoval }
    }

    private func quantityOf(_ group: ModifierGroup, _ mod: Modifier) -> Int {
        selections.first { $0.groupID == group.id && $0.modifierID == mod.id }?.quantity ?? 0
    }

    private func modifierTile(_ group: ModifierGroup, _ mod: Modifier) -> some View {
        let selected = isSelected(group, mod)
        let qty = quantityOf(group, mod)
        let removedDefault = mod.isDefault && !selected
        return Button {
            toggle(group, mod)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(mod.name)
                        .font(.system(size: 14, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .strikethrough(mod.soldOut || removedDefault,
                                       color: mod.soldOut ? Palette.stop : theme.inkSecondary)
                    Spacer(minLength: 0)
                    if qty > 1 {
                        Text("\(qty)×")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .opacity(0.9)
                    }
                }
                HStack(spacing: 4) {
                    if !mod.price.isZero {
                        Text(mod.price.formatted(showsSign: true))
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .moneyFigure()
                            .opacity(0.8)
                    } else if mod.isDefault {
                        Text(removedDefault ? "removed" : "included")
                            .font(.system(size: 11))
                            .opacity(0.75)
                    }
                    Spacer(minLength: 0)
                    if mod.soldOut {
                        Text("sold out").font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Palette.stop)
                    }
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 44, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(selected ? .white : theme.ink)
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                    .fill(selected ? theme.accent : theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                            .strokeBorder(selected ? .clear : theme.hairline, lineWidth: 0.7)
                    }
            }
            .opacity(mod.soldOut ? 0.55 : 1)
        }
        .posPress()
    }

    private func toggle(_ group: ModifierGroup, _ mod: Modifier) {
        withAnimation(Motion.quick) {
            switch group.selection {
            case .single:
                // A single-select group replaces its own choice with no warning.
                selections.removeAll { $0.groupID == group.id }
                if !isSelectedBefore(group, mod) {
                    selections.append(make(group, mod))
                }
            case .quantity:
                if let i = selections.firstIndex(where: { $0.groupID == group.id && $0.modifierID == mod.id }) {
                    if selections[i].quantity < mod.maxPerOption {
                        selections[i].quantity += 1
                    } else {
                        selections.remove(at: i)
                    }
                } else {
                    selections.append(make(group, mod))
                }
            case .multi:
                if let i = selections.firstIndex(where: { $0.groupID == group.id && $0.modifierID == mod.id }) {
                    // Toggling a default off records a removal, so the docket prints "- Name".
                    if mod.isDefault {
                        selections[i].isRemoval = true
                    } else {
                        selections.remove(at: i)
                    }
                } else {
                    let chosen = selections.filter { $0.groupID == group.id && !$0.isRemoval }.count
                    if group.max > 0 && chosen >= group.max {
                        store.toast(.info, "\(group.name): up to \(group.max)",
                                    detail: "Remove one first")
                        return
                    }
                    selections.append(make(group, mod))
                }
            }
        }
    }

    private func isSelectedBefore(_ group: ModifierGroup, _ mod: Modifier) -> Bool {
        selections.contains { $0.groupID == group.id && $0.modifierID == mod.id }
    }

    private func make(_ group: ModifierGroup, _ mod: Modifier) -> SelectedModifier {
        SelectedModifier(groupID: group.id, groupName: group.name, modifierID: mod.id,
                         name: mod.name, unitPrice: mod.price,
                         soldOut: mod.soldOut, changesTheMake: mod.changesTheMake)
    }

    // MARK: - Note

    private var noteBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Note to the kitchen")
            TextField("Anything the make line needs to know", text: $note, axis: .vertical)
                .font(.system(size: 15))
                .textFieldStyle(.plain)
                .padding(12)
                .frame(minHeight: 52, alignment: .top)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                        .fill(theme.surface)
                        .overlay {
                            RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                        }
                }
            if store.profile.seatsEnabled {
                HStack(spacing: 7) {
                    Text("Seat").sectionLabelStyle(theme.inkSecondary)
                    ForEach(1...max(4, store.currentOrder?.guestCount ?? 4), id: \.self) { s in
                        Button {
                            seat = seat == s ? nil : s
                        } label: {
                            Text("\(s)")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .frame(width: 40, height: 40)
                                .foregroundStyle(seat == s ? .white : theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(seat == s ? theme.accent : theme.surface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                                        }
                                }
                        }
                        .posPress()
                    }
                    Button("Shared") { seat = nil }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(seat == nil ? theme.accent : theme.inkSecondary)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Button {
                    quantity = max(1, quantity - 1)
                } label: {
                    Image(systemName: "minus").font(.system(size: 14, weight: .bold))
                        .frame(width: 46, height: 52).foregroundStyle(theme.ink)
                }
                Text("\(quantity)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .moneyFigure()
                    .frame(width: 44)
                    .foregroundStyle(theme.ink)
                Button {
                    quantity += 1
                } label: {
                    Image(systemName: "plus").font(.system(size: 14, weight: .bold))
                        .frame(width: 46, height: 52).foregroundStyle(theme.ink)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                    }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(runningTotal.formatted())
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
                if let missing = missingRequirement {
                    Text(missing)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.warn)
                } else if !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.inkSecondary)
                        .lineLimit(1)
                }
            }
            .animation(Motion.quick, value: runningTotal.cents)

            Spacer(minLength: 6)

            PrimaryAction(title: editingItemID == nil ? "Add" : "Save",
                          glyph: editingItemID == nil ? "plus" : "checkmark",
                          enabled: missingRequirement == nil) {
                commit()
            }
            .frame(width: 220)
        }
    }

    private var runningTotal: Money {
        let base = product.price + (variant?.priceDelta ?? .zero)
        let mods = selections.map(\.total).total
        return (base + mods) * quantity
    }

    /// Only what the guest asked for. A list that repeats "Standard, Standard" tells the
    /// operator nothing.
    private var summary: String {
        let interesting = selections.filter { sel in
            guard let group = product.groups.first(where: { $0.id == sel.groupID }),
                  let mod = group.modifiers.first(where: { $0.id == sel.modifierID })
            else { return true }
            return !mod.isDefault || sel.isRemoval || sel.quantity > 1
        }
        return interesting.isEmpty ? "as it comes" : interesting.map(\.label).joined(separator: " · ")
    }

    private var missingRequirement: String? {
        for g in product.groups where g.isRequired {
            let chosen = selections.filter { $0.groupID == g.id && !$0.isRemoval }.count
            if chosen < g.min { return "Choose \(g.name.lowercased())" }
        }
        return nil
    }

    // MARK: - Commit

    private func prime() {
        if let id = editingItemID, let item = store.currentOrder?.items.first(where: { $0.id == id }) {
            variant = product.variants.first { $0.label == item.variantLabel }
                ?? product.variants.first(where: \.isDefault)
            selections = item.modifiers
            quantity = item.quantity
            note = item.note ?? ""
            seat = item.seat
        } else {
            variant = product.variants.first(where: \.isDefault) ?? product.variants.first
            selections = store.defaultModifiers(for: product)
            seat = nil
        }
    }

    private func commit() {
        if let id = editingItemID {
            store.mutateCurrent { o in
                guard let i = o.items.firstIndex(where: { $0.id == id }) else { return }
                let wasSent = o.items[i].isSentOrLater
                o.items[i].variantLabel = variant?.label
                o.items[i].modifiers = selections
                o.items[i].quantity = quantity
                o.items[i].note = note.isEmpty ? nil : note
                o.items[i].seat = seat
                o.items[i].unitPrice = product.price + (variant?.priceDelta ?? .zero)
                // Changing a sent item means the kitchen has to be told again.
                if wasSent {
                    o.items[i].sendRecords = []
                    o.items[i].status = .unsent
                }
            }
            store.applyAutomaticAdjustments()
            store.toast(.done, "Updated \(product.name)",
                        detail: store.currentOrder?.items.first { $0.id == id }?.isSentOrLater == false
                            ? "Send again so the kitchen sees the change" : nil)
        } else {
            store.add(product: product, variant: variant, modifiers: selections,
                      quantity: quantity, note: note.isEmpty ? nil : note, seat: seat)
            store.offerUpsell(for: product)
        }
        store.route = nil
    }
}
