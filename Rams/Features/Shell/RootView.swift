import SwiftUI

struct RootView: View {
    @State private var store = POSStore()
    @State private var showDemoPanel = false

    var body: some View {
        let theme = store.theme
        ZStack(alignment: .bottomLeading) {
            theme.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                Chrome(showDemoPanel: $showDemoPanel)
                Divider().overlay(theme.hairline)
                surface
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            ToastStack()
        }
        .overlay {
            if store.route == .modes {
                ModePalette()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }
        }
        .overlay {
            if store.pendingApproval != nil {
                ApprovalOverlay()
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showDemoPanel {
                DemoPanel(isOpen: $showDemoPanel)
                    .padding(.top, 62)
                    .padding(.trailing, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Motion.panel, value: store.route)
        .animation(Motion.panel, value: showDemoPanel)
        .sheet(item: sheetBinding) { route in
            RouteSheet(route: route)
                .environment(store)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.dark ? .dark : .light)
                .tint(theme.accent)
        }
        .background { KeyboardShortcuts(showDemoPanel: $showDemoPanel) }
        .task {
            if let script = POSStore.requestedScript() { store.runScript(script) }
        }
        // The environment goes on last, so every overlay and background above is a
        // descendant of it rather than a sibling.
        .environment(store)
        .environment(\.theme, theme)
        .preferredColorScheme(theme.dark ? .dark : .light)
        .tint(theme.accent)
    }

    /// The mode palette and the approval prompt are overlays rather than sheets, because
    /// they must not hide the work underneath.
    private var sheetBinding: Binding<Route?> {
        Binding(get: { store.route == .modes ? nil : store.route },
                set: { store.route = $0 })
    }

    @ViewBuilder private var surface: some View {
        switch store.surface {
        case .sell: SellSurface()
        case .floor: FloorSurface()
        case .tabs: TabsSurface()
        case .queue: QueueSurface()
        case .orders: OrdersSurface()
        case .kitchen: KitchenSurface()
        case .online: InboxSurface()
        case .shift: ShiftSurface()
        }
    }
}

// MARK: - Chrome
//
// Liquid Glass belongs in the navigation layer. The working surfaces underneath stay opaque,
// because a total that cannot be read at a sunlit window is a refund waiting to happen.

private struct Chrome: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @Binding var showDemoPanel: Bool

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                venueChip
                Divider().frame(height: 26)
                surfaces
                Spacer(minLength: 8)
                statusCluster
                operatorChip
                Button {
                    showDemoPanel.toggle()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(theme.ink)
                }
                .glassEffect(.regular.interactive(), in: .circle)
                .posPress()
                .help("Presenter controls")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(theme.canvas)
    }

    private var venueChip: some View {
        Button {
            store.route = .modes
        } label: {
            HStack(spacing: 9) {
                Image(systemName: store.mode.glyph)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(theme.accent))
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.profile.venueName)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(store.mode.title) · \(store.profile.deviceName)")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.inkSecondary)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(theme.inkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
        .posPress(scale: 0.98)
        .help("Switch business type (⌘K)")
    }

    private var surfaces: some View {
        HStack(spacing: 4) {
            ForEach(store.profile.surfaces) { s in
                let active = store.surface == s
                Button {
                    withAnimation(Motion.tap) { store.surface = s }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: s.glyph).font(.system(size: 13, weight: .semibold))
                        Text(s.title).font(.system(size: 14, weight: active ? .semibold : .medium))
                        if let count = badge(for: s) {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Capsule().fill(active ? Color.white.opacity(0.3) : Palette.stop))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .foregroundStyle(active ? .white : theme.ink)
                    .background {
                        Capsule().fill(active ? theme.accent : Color.clear)
                    }
                }
                .posPress(scale: 0.98)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }

    private func badge(for surface: Surface) -> Int? {
        switch surface {
        case .online:
            let n = store.onlineInbox.count
            return n > 0 ? n : nil
        case .kitchen:
            let n = store.tickets.filter { $0.state == .waiting || $0.state == .started }.count
            return n > 0 ? n : nil
        case .queue:
            let n = store.queueOrders.count
            return n > 0 ? n : nil
        case .tabs:
            let n = store.openTabs.count
            return n > 0 ? n : nil
        default: return nil
        }
    }

    private var statusCluster: some View {
        HStack(spacing: 6) {
            if store.offline {
                Chip(text: "Offline", glyph: "wifi.slash", tint: Palette.warn, filled: true)
            }
            let unsynced = store.orders.filter(\.unsynced).count
            if unsynced > 0 {
                Chip(text: "\(unsynced) unsynced", glyph: "arrow.triangle.2.circlepath", tint: Palette.warn)
            }
            let down = store.stationDevices.filter { !$0.online }
            if !down.isEmpty {
                Chip(text: down.map(\.name).joined(separator: ", ") + " offline",
                     glyph: "printer.trianglebadge.exclamationmark", tint: Palette.stop, filled: true)
            }
            if store.simulatedHour >= 16 && store.simulatedHour < 18 && store.mode == .bar {
                Chip(text: "Happy hour", glyph: "clock.fill", tint: Palette.go, filled: true)
            }
        }
    }

    private var operatorChip: some View {
        Menu {
            Section("Signed in") {
                ForEach(store.staff) { s in
                    Button {
                        store.operatorStaff = s
                        store.toast(.info, "\(s.name)", detail: s.role.label)
                    } label: {
                        Label("\(s.name) · \(s.role.label)",
                              systemImage: s.id == store.operatorStaff.id ? "checkmark" : "person")
                    }
                }
            }
            Divider()
            Button { store.route = .help } label: { Label("What to try", systemImage: "sparkles") }
        } label: {
            HStack(spacing: 7) {
                Text(store.operatorStaff.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(theme.inkSecondary))
                VStack(alignment: .leading, spacing: 0) {
                    Text(store.operatorStaff.name.firstWord)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text(store.operatorStaff.role.label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(theme.inkSecondary)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
        }
        .glassEffect(.regular.interactive(), in: .capsule)
    }
}

// MARK: - Keyboard shortcuts
//
// A till with a keyboard should reward it: the research asks for keyboard operation, and a
// scanner is a keyboard too.

private struct KeyboardShortcuts: View {
    @Environment(POSStore.self) private var store
    @Binding var showDemoPanel: Bool

    var body: some View {
        Group {
            Button("Modes") { store.route = store.route == .modes ? nil : .modes }
                .keyboardShortcut("k", modifiers: .command)
            Button("Pay") {
                if store.currentOrder != nil { store.route = .payment }
            }
            .keyboardShortcut("p", modifiers: .command)
            Button("Send") { store.send() }
                .keyboardShortcut("s", modifiers: .command)
            Button("Split") {
                if store.currentOrder != nil { store.route = .split }
            }
            .keyboardShortcut("d", modifiers: .command)
            Button("New order") { _ = store.newOrder() }
                .keyboardShortcut("n", modifiers: .command)
            Button("Undo") { store.undoLast() }
                .keyboardShortcut("z", modifiers: .command)
            Button("Presenter") { showDemoPanel.toggle() }
                .keyboardShortcut(".", modifiers: .command)
            Button("Close") { store.route = nil }
                .keyboardShortcut(.escape, modifiers: [])
            ForEach(Array(store.profile.surfaces.enumerated()), id: \.element) { i, s in
                Button(s.title) { store.surface = s }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }
}
