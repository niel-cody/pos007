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
                header
                Spacer(minLength: 0)
                if let staff = pinFor {
                    pinPanel(staff)
                } else {
                    tiles
                }
                Spacer(minLength: 0)
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
        .padding(.top, 48)
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

/// The few seconds after the money is taken: what was paid, what change to hand back, and a
/// countdown that hands the till on without anybody having to remember to.
struct SaleCompleteScreen: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var summary: SaleSummary

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(Palette.go)

                    VStack(spacing: 3) {
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
                            Text("Change")
                                .sectionLabelStyle(theme.inkSecondary)
                            Text(summary.change.formatted())
                                .font(.changeDue)
                                .moneyFigure()
                                .foregroundStyle(theme.ink)
                        }
                        .padding(.horizontal, 30)
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

                    HStack(spacing: 8) {
                        SecondaryAction(title: "Print receipt", glyph: "printer") {
                            store.toast(.done, "Receipt printed")
                        }
                        SecondaryAction(title: "No receipt", glyph: "xmark") {
                            store.dismissSaleSummary()
                        }
                    }
                    .frame(maxWidth: 380)
                }
                .padding(.horizontal, 34)
                .padding(.top, 34)
                .padding(.bottom, 24)

                if summary.returnsToLock {
                    Divider().overlay(theme.hairline)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .strokeBorder(theme.hairline, lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            Text("\(store.lockCountdown)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.ink)
                        }
                        .frame(width: 38, height: 38)
                        .animation(.linear(duration: 1), value: store.lockCountdown)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("Handing the till back")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(theme.ink)
                            Text("\(summary.operatorName.firstWord) will be logged out so the next round is rung under the right name.")
                                .font(.system(size: 12))
                                .foregroundStyle(theme.inkSecondary)
                        }
                        Spacer(minLength: 8)
                        SecondaryAction(title: "Stay on", glyph: "person.fill.checkmark") {
                            store.stayOn()
                        }
                        .frame(width: 150)
                        PrimaryAction(title: "Log out", glyph: "lock.fill") {
                            store.logOutNow()
                        }
                        .frame(width: 160)
                    }
                    .padding(Metric.padLarge)
                    .background(theme.raised)
                }
            }
            .frame(width: 620)
            .background {
                RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous)
                    .fill(theme.surface)
                    .shadow(color: .black.opacity(0.3), radius: 40, y: 14)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous))
        }
    }

    private var progress: CGFloat {
        let total = max(1, store.profile.lockGraceSeconds)
        return CGFloat(store.lockCountdown) / CGFloat(total)
    }
}
