import SwiftUI

/// Tabs. Retrieval is the bar's real problem — "it is under Dave", "it is on the black Amex" —
/// so this is a search over the name, the card and the bartender, with a repeat control on
/// every round.
struct TabsSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var query = ""

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider().overlay(theme.hairline)
                if store.openTabs.isEmpty {
                    EmptyHint(glyph: "person.2.badge.key",
                              title: "No tabs open",
                              detail: "Open one with a name, a spend limit, or a card held on file.")
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.gutter),
                                                 count: 3),
                                  spacing: Metric.gutter) {
                            ForEach(store.findTabs(query)) { tab in
                                TabCard(tab: tab)
                            }
                        }
                        .padding(Metric.pad)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if store.currentOrder != nil {
                Divider().overlay(theme.hairline)
                CartPanel().frame(width: Metric.cartWidth)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(Motion.panel, value: store.currentOrderID)
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.inkSecondary)
                    TextField("Name, card, bartender", text: $query)
                        .font(.system(size: 16))
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: 340)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                        .fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                }

                Spacer()

                let clashes = store.tabsNeedingDisambiguation()
                if !clashes.isEmpty {
                    Chip(text: "Two tabs called \(clashes.map(\.capitalized).joined(separator: ", "))",
                         glyph: "exclamationmark.triangle.fill", tint: Palette.warn, filled: true)
                }

                SecondaryAction(title: "Last drinks sweep", glyph: "moon.stars.fill") {
                    let sweep = store.tabSweep()
                    store.toast(.info, "\(sweep.count) tabs still open",
                                detail: sweep.prefix(2).map { "\($0.order.name ?? ""): \($0.suggestion)" }
                                    .joined(separator: " · "))
                }
                .frame(width: 200)

                PrimaryAction(title: "Open a tab", glyph: "plus") {
                    store.route = .openTab
                }
                .frame(width: 190)
            }
        }
        .padding(Metric.pad)
        .background(theme.raised)
    }
}

struct TabCard: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var tab: Order

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Text(tab.name ?? "Tab")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Spacer()
                if let w = tab.waiter {
                    Text(w)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(theme.inkSecondary))
                }
            }

            if let auth = tab.tabAuth {
                HStack(spacing: 6) {
                    Image(systemName: "creditcard.fill").font(.system(size: 11, weight: .bold))
                    Text("\(auth.scheme) ···\(auth.last4)")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(auth.state.label).font(.system(size: 11.5))
                    Spacer()
                }
                .foregroundStyle(auth.state == .authorised ? Palette.go : Palette.warn)

                if let pressure = store.authPressure(tab) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.hairline).frame(height: 5)
                            Capsule()
                                .fill(pressure.used >= 0.8 ? Palette.warn : Palette.go)
                                .frame(width: geo.size.width * min(1, pressure.used), height: 5)
                        }
                    }
                    .frame(height: 5)
                    if let w = pressure.warning {
                        Text(w).font(.system(size: 11, weight: .semibold)).foregroundStyle(Palette.warn)
                    }
                }
            } else if let limit = tab.spendLimit {
                Chip(text: "Limit \(limit.formatted())", glyph: "gauge.with.needle",
                     tint: tab.total > limit ? Palette.stop : theme.inkSecondary,
                     filled: tab.total > limit)
            }

            let rounds = tab.rounds
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rounds.prefix(2), id: \.id) { round in
                    HStack(spacing: 6) {
                        Text(round.at.hhmm)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.inkSecondary)
                        Text(round.items.map { "\($0.quantity)× \($0.name)" }.joined(separator: ", "))
                            .font(.system(size: 12.5))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Button {
                            store.openOrder(tab.id)
                            store.repeatRound(round.id)
                        } label: {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.accent)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(theme.accentSoft))
                        }
                        .posPress()
                        .help("Repeat this round")
                    }
                }
                if rounds.count > 2 {
                    Text("+ \(rounds.count - 2) earlier round\(rounds.count - 2 == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.inkSecondary)
                }
            }

            Divider().overlay(theme.hairline)

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Open \(tab.createdAt.elapsedShort)")
                        .font(.system(size: 11))
                        .foregroundStyle(theme.inkSecondary)
                    Text(tab.total.formatted())
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .moneyFigure()
                        .foregroundStyle(theme.ink)
                }
                Spacer()
            }

            HStack(spacing: 7) {
                if let r = tab.rounds.first {
                    PrimaryAction(title: "Same again", glyph: "arrow.trianglehead.2.clockwise.rotate.90") {
                        store.openOrder(tab.id)
                        store.repeatRound(r.id)
                    }
                }
                SecondaryAction(title: "Open", glyph: "chevron.right") {
                    store.openOrder(tab.id)
                }
                .frame(width: 96)
            }

            HStack(spacing: 7) {
                SecondaryAction(title: tab.tabAuth?.state == .authorised ? "Capture" : "Close",
                                glyph: "checkmark") {
                    if tab.tabAuth?.state == .authorised {
                        store.captureTab(tab.id)
                    } else {
                        store.closeTab(tab.id)
                    }
                }
                Menu {
                    Button { store.openOrder(tab.id); store.route = .transfer(orderID: tab.id) } label: {
                        Label("Move to a table or another bartender", systemImage: "arrow.left.arrow.right")
                    }
                    Button { store.openOrder(tab.id); store.route = .split } label: {
                        Label("Split it", systemImage: "divide")
                    }
                    Button { store.openOrder(tab.id); store.route = .timeline(orderID: tab.id) } label: {
                        Label("Timeline", systemImage: "clock.arrow.circlepath")
                    }
                    if let auth = tab.tabAuth, auth.state == .authorised {
                        Button { store.incrementAuth(tab.id, by: Money(100)) } label: {
                            Label("Top up the hold by $100", systemImage: "plus.circle")
                        }
                        Button { store.releaseAuth(tab.id) } label: {
                            Label("Release the hold", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 44, height: Metric.standardTarget)
                        .foregroundStyle(theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                                .fill(theme.dark ? Color.white.opacity(0.08) : Color.black.opacity(0.045))
                        }
                }
            }
        }
        .padding(Metric.pad)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                }
        }
    }
}
