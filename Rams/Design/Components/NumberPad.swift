import SwiftUI

/// The number pad is forgiving: large keys, a visible running value, a clear delete, and a
/// confirm that states what it will do. (W21.10)
struct NumberPad: View {
    @Environment(\.theme) private var theme

    enum Style { case money, integer, text }

    @Binding var value: String
    var style: Style = .money
    var quickAmounts: [Money] = []
    var confirmTitle: String
    var confirmDetail: String?
    var confirmEnabled: Bool = true
    var onConfirm: () -> Void
    var onCancel: (() -> Void)?

    private var display: String {
        switch style {
        case .money:
            let cents = Int(value) ?? 0
            return Money(cents: cents).formatted()
        default:
            return value.isEmpty ? "—" : value
        }
    }

    var money: Money { Money(cents: Int(value) ?? 0) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Text(display)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                    .contentTransition(.numericText())
                    .animation(Motion.quick, value: value)
            }
            .padding(.horizontal, 14)
            .frame(height: 68)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
            }

            if !quickAmounts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(quickAmounts, id: \.cents) { amt in
                        Button {
                            value = String(amt.cents)
                        } label: {
                            Text(amt.tileLabel)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .moneyFigure()
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .foregroundStyle(theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(theme.accentSoft)
                                }
                        }
                        .posPress()
                    }
                }
            }

            let keys: [[String]] = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"],
                                    [style == .money ? "00" : "0", "0", "⌫"]]
            VStack(spacing: 8) {
                ForEach(keys.indices, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(keys[row], id: \.self) { key in
                            Button {
                                press(key)
                            } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(systemName: "delete.left.fill")
                                            .font(.system(size: 20, weight: .medium))
                                    } else {
                                        Text(key).font(.system(size: 24, weight: .medium, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .foregroundStyle(theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                        .fill(theme.surface)
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

            VStack(spacing: 8) {
                PrimaryAction(title: confirmTitle, subtitle: confirmDetail,
                              enabled: confirmEnabled, action: onConfirm)
                if let onCancel {
                    SecondaryAction(title: "Cancel", action: onCancel)
                }
            }
        }
    }

    private func press(_ key: String) {
        switch key {
        case "⌫":
            if !value.isEmpty { value.removeLast() }
        case "00":
            value += "00"
        default:
            guard value.count < 9 else { return }
            if value == "0" { value = key } else { value += key }
        }
    }
}

/// A compact keypad for a quantity prefix on the bar layout: type 4, tap the tile.
struct QuantityPrefixPad: View {
    @Environment(\.theme) private var theme
    @Binding var prefix: String

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { n in
                Button {
                    prefix = prefix == String(n) ? "" : String(n)
                } label: {
                    Text("\(n)")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(prefix == String(n) ? .white : theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(prefix == String(n) ? theme.accent : (theme.dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                        }
                }
                .posPress()
            }
            if !prefix.isEmpty {
                Button {
                    prefix = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(theme.inkSecondary)
                }
                .posPress()
            }
        }
    }
}
