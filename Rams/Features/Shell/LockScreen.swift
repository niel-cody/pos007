import SwiftUI

/// The lock screen. One tile per person on shift, and the tile says what that person can do,
/// because a new starter should not have to be told which name is the supervisor.
struct LockScreen: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    @State private var pinFor: Staff?
    @State private var pin = ""
    @State private var failed = false

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 24)
                VStack(spacing: 34) {
                    header
                    if let staff = pinFor {
                        pinPanel(staff)
                    } else {
                        tiles
                    }
                }
                Spacer(minLength: 24)
                footer
            }
        }
        .transition(.opacity)
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: store.mode.glyph)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(theme.accent))
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.profile.venueName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(store.profile.deviceName) · \(store.now.hhmm)")
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.inkSecondary)
                }
            }
            if let reason = store.lockReason {
                Chip(text: reason, glyph: "lock.fill", tint: theme.inkSecondary)
            }
        }
    }

    private var tiles: some View {
        VStack(spacing: 18) {
            Text("Tap your tile to start")
                .font(.system(size: 15))
                .foregroundStyle(theme.inkSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14),
                                     count: min(4, max(2, store.staff.count))),
                      spacing: 14) {
                ForEach(store.staff) { staff in
                    Button {
                        if store.needsPIN(for: staff) {
                            withAnimation(Motion.panel) { pinFor = staff; pin = "" }
                        } else {
                            withAnimation(Motion.panel) { store.logIn(as: staff) }
                        }
                    } label: {
                        tile(staff)
                    }
                    .posPress(scale: 0.98)
                }
            }
            .frame(maxWidth: 940)
        }
        .padding(.horizontal, 40)
    }

    private func tile(_ staff: Staff) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Text(staff.initials)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(tint(staff.role)))
                Spacer(minLength: 0)
                if store.needsPIN(for: staff) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.inkSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(staff.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(staff.role.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tint(staff.role))
                    Chip(text: "\(staff.role.tier) access", tint: theme.inkSecondary, small: true)
                }
            }
            Text(staff.role.summary)
                .font(.system(size: 12))
                .foregroundStyle(theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(15)
        .frame(height: 180, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(tint(staff.role).opacity(0.4), lineWidth: 1.2)
                }
        }
    }

    private func tint(_ role: Staff.Role) -> Color {
        switch role {
        case .manager, .admin: Palette.stop
        case .supervisor: Palette.warn
        default: theme.accent
        }
    }

    private func pinPanel(_ staff: Staff) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(staff.initials)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(tint(staff.role)))
                Text(staff.name)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(staff.role.label) · PIN required for \(staff.role.tier.lowercased()) access")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
            }

            HStack(spacing: 10) {
                ForEach(0..<4) { i in
                    Text(pin.count > i ? "●" : "")
                        .font(.system(size: 22, weight: .bold))
                        .frame(width: 54, height: 60)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                .fill(theme.surface)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .strokeBorder(failed ? Palette.stop : theme.hairline,
                                                      lineWidth: failed ? 1.6 : 0.8)
                                }
                        }
                        .foregroundStyle(theme.ink)
                }
            }

            let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
            VStack(spacing: 8) {
                ForEach(keys.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(keys[row], id: \.self) { key in
                            if key.isEmpty {
                                Color.clear.frame(width: 76, height: 56)
                            } else {
                                Button {
                                    press(key, staff)
                                } label: {
                                    Group {
                                        if key == "⌫" {
                                            Image(systemName: "delete.left.fill").font(.system(size: 18))
                                        } else {
                                            Text(key).font(.system(size: 23, weight: .medium, design: .rounded))
                                        }
                                    }
                                    .frame(width: 76, height: 56)
                                    .foregroundStyle(theme.ink)
                                    .background {
                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                            .fill(theme.surface)
                                            .overlay {
                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                    .strokeBorder(theme.hairline, lineWidth: 0.8)
                                            }
                                    }
                                }
                                .posPress()
                            }
                        }
                    }
                }
            }

            Text(failed ? "That is not \(staff.name.firstWord)’s PIN" : "Try \(staff.pin) for the demo")
                .font(.system(size: 12))
                .foregroundStyle(failed ? Palette.stop : theme.inkSecondary.opacity(0.8))

            Button("Someone else") {
                withAnimation(Motion.panel) { pinFor = nil; pin = ""; failed = false }
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(theme.accent)
        }
    }

    private func press(_ key: String, _ staff: Staff) {
        failed = false
        if key == "⌫" {
            if !pin.isEmpty { pin.removeLast() }
            return
        }
        guard pin.count < 4 else { return }
        pin += key
        guard pin.count == 4 else { return }
        if store.attemptLogIn(staff, pin: pin) {
            pinFor = nil
            pin = ""
        } else {
            failed = true
            pin = ""
        }
    }

    private var footer: some View {
        HStack(spacing: 22) {
            stat("Shift open", store.shift.openedAt.hhmm)
            stat("Orders", "\(store.shift.orders)")
            stat("Net sales", store.shift.netSales.formatted())
            if !store.openTabs.isEmpty {
                stat("Tabs open", "\(store.openTabs.count)")
            }
            Spacer()
            Button {
                store.route = .modes
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: store.mode.glyph).font(.system(size: 12, weight: .semibold))
                    Text("Change business type").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(theme.inkSecondary)
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(theme.raised)
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .moneyFigure()
                .foregroundStyle(theme.ink)
            Text(label).sectionLabelStyle(theme.inkSecondary)
        }
    }
}

/// The three seconds after the money is taken: what was paid, what change to hand back, and
/// the receipt question. Then the till hands itself to whoever is next, because several people
/// use this screen in an hour and every line has to carry a name.
struct SaleCompleteScreen: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var summary: SaleSummary

    @State private var ring: CGFloat = 1
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .strokeBorder(theme.hairline, lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: ring)
                        .stroke(Palette.go, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "checkmark")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Palette.go)
                        .scaleEffect(appeared ? 1 : 0.4)
                        .opacity(appeared ? 1 : 0)
                }
                .frame(width: 76, height: 76)

                VStack(spacing: 4) {
                    Text("Paid \(summary.total.formatted())")
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .moneyFigure()
                        .foregroundStyle(theme.ink)
                    Text("\(summary.orderLabel) · \(summary.itemCount) items · \(summary.operatorName)")
                        .font(.system(size: 13.5))
                        .foregroundStyle(theme.inkSecondary)
                }

                if summary.change.cents > 0 {
                    VStack(spacing: 2) {
                        Text("Change").sectionLabelStyle(theme.inkSecondary)
                        Text(summary.change.formatted())
                            .font(.changeDue)
                            .moneyFigure()
                            .foregroundStyle(theme.ink)
                    }
                    .padding(.horizontal, 34)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .fill(Palette.go.opacity(theme.dark ? 0.24 : 0.12))
                    }
                }

                if !summary.tenders.isEmpty {
                    Text(summary.tenders.joined(separator: "  ·  "))
                        .font(.system(size: 13))
                        .foregroundStyle(theme.inkSecondary)
                }

                HStack(spacing: 10) {
                    SecondaryAction(title: "Receipt", glyph: "printer") {
                        store.finishSale(printReceipt: true)
                    }
                    PrimaryAction(title: "No receipt", glyph: "checkmark") {
                        store.finishSale(printReceipt: false)
                    }
                }
                .frame(maxWidth: 420)

                Text(footnote)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary.opacity(0.85))
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 34)
            .frame(width: 560)
            .background {
                RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous)
                    .fill(theme.surface)
                    .shadow(color: .black.opacity(0.32), radius: 44, y: 16)
            }
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { appeared = true }
            withAnimation(.linear(duration: Double(store.profile.lockGraceSeconds))) { ring = 0 }
        }
    }

    private var footnote: String {
        guard summary.returnsToLock else { return "Tap to start the next order" }
        let n = max(store.lockCountdown, 1)
        return "Handing the till back in \(n)… \(summary.operatorName.firstWord) will be logged out"
    }
}
