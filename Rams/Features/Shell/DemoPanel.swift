import SwiftUI

/// Presenter controls. Not part of the product: it is the switchboard that lets someone
/// demonstrate a printer failing, a card declining or a rush arriving, on cue.
struct DemoPanel: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @Binding var isOpen: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Presenter").font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                Spacer()
                Button { isOpen = false } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.inkSecondary)
                }
            }

            block("Network") {
                Toggle(isOn: Binding(get: { store.offline }, set: { on in
                    store.offline = on
                    store.toast(on ? .warn : .done,
                                on ? "Offline" : "Back online",
                                detail: on ? "Cash, accounts and manual card keep trading. Sends queue."
                                           : "Queued events flushed in order")
                })) {
                    Text("Offline mode").font(.system(size: 13.5))
                }
                .toggleStyle(.switch)
            }

            block("Card terminal") {
                Picker("", selection: Binding(get: { store.cardOutcome },
                                              set: { store.cardOutcome = $0 })) {
                    ForEach(POSStore.CardOutcome.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            block("Stations") {
                VStack(spacing: 5) {
                    ForEach(store.stationDevices) { d in
                        Button {
                            store.toggleStation(d.id)
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: d.online ? "printer.fill" : "printer.trianglebadge.exclamationmark.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(d.online ? Palette.go : Palette.stop)
                                Text(d.name).font(.system(size: 13)).foregroundStyle(theme.ink)
                                Spacer()
                                Text(d.online ? "Online" : "Offline")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(d.online ? Palette.go : Palette.stop)
                            }
                        }
                        .posPress()
                    }
                }
            }

            block("Clock") {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(value: Binding(get: { Double(store.simulatedHour) },
                                          set: { store.simulatedHour = Int($0) }),
                           in: 6...23, step: 1)
                    Text("\(store.simulatedHour):00 — drives happy hour and scheduled pricing")
                        .font(.system(size: 11.5))
                        .foregroundStyle(theme.inkSecondary)
                }
            }

            VStack(spacing: 6) {
                SecondaryAction(title: "An order arrives", glyph: "tray.and.arrow.down.fill") {
                    store.simulateIncomingOrder()
                }
                if let o = store.currentOrder {
                    SecondaryAction(title: "Another till takes this order", glyph: "lock.fill") {
                        store.takeLockAsOther(o.id)
                    }
                }
                SecondaryAction(title: "Reload this venue", glyph: "arrow.counterclockwise") {
                    store.switchMode(store.mode)
                }
            }
        }
        .padding(15)
        .frame(width: 300)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .shadow(color: .black.opacity(0.22), radius: 26, y: 10)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(theme.hairline, lineWidth: 0.7)
                }
        }
    }

    @ViewBuilder private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).sectionLabelStyle(theme.inkSecondary)
            content()
        }
    }
}
