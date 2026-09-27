import SwiftUI

/// The composer. The guest talks in changes, not in forms:
///
///   "Cheeseburger." → "Make it a meal." → "Large fries." → "No pickles." → "Shake instead."
///
/// Each of those is one tap here, applied to the line in place. Nothing reopens, nothing is
/// removed and re-added, and the sheet stays available for the long tail behind More.
struct LineComposer: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var item: OrderItem

    @State private var swapSlotIndex: Int?

    private var chips: [QuickChip] { store.quickChips(for: item) }

    var body: some View {
        HStack(spacing: 12) {
            identity
            Divider().frame(height: 38)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(chips) { chip in
                        chipView(chip)
                    }
                }
                .padding(.vertical, 2)
            }
            Button {
                store.select(nil)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(theme.inkSecondary)
            }
            .posPress()
            .accessibilityLabel("Stop editing this line")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .shadow(color: .black.opacity(theme.dark ? 0.5 : 0.14), radius: 22, y: 8)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(theme.accent.opacity(0.35), lineWidth: 1)
                }
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 6) {
                if item.quantity > 1 {
                    Text("\(item.quantity)×")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.accent)
                }
                Text(item.comboName ?? item.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text(item.lineTotal.formatted())
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.inkSecondary)
            }
            Text(item.configurationSummary.isEmpty
                 ? "tap a change, or More for everything"
                 : item.configurationSummary)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.inkSecondary)
                .lineLimit(1)
        }
        .frame(minWidth: 130, maxWidth: 190, alignment: .leading)
    }

    @ViewBuilder private func chipView(_ chip: QuickChip) -> some View {
        if case .swapSlot(let index) = chip.kind {
            Menu {
                ForEach(store.slotOptions(item, index: index), id: \.0.id) { option in
                    Button {
                        store.swapSlot(item.id, index: index, to: option.0.id)
                    } label: {
                        Label(option.1.isZero
                              ? option.0.name
                              : "\(option.0.name)  \(option.1.formatted(showsSign: true))",
                              systemImage: item.comboChildren.indices.contains(index)
                                && item.comboChildren[index].productID == option.0.id
                                ? "checkmark" : option.0.glyph)
                    }
                }
            } label: {
                chipLabel(chip)
            }
        } else {
            Button {
                store.apply(chip, to: item.id)
            } label: {
                chipLabel(chip)
            }
            .posPress()
        }
    }

    private func chipLabel(_ chip: QuickChip) -> some View {
        HStack(spacing: 5) {
            if let glyph = chip.glyph {
                Image(systemName: glyph).font(.system(size: 11, weight: .bold))
            }
            Text(chip.title)
                .font(.system(size: 14, weight: chip.tone == .neutral ? .medium : .semibold))
                .lineLimit(1)
            if let detail = chip.detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .moneyFigure()
                    .opacity(0.8)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .foregroundStyle(foreground(chip.tone))
        .background {
            Capsule().fill(background(chip.tone))
                .overlay {
                    if chip.tone == .neutral {
                        Capsule().strokeBorder(theme.hairline, lineWidth: 0.8)
                    }
                }
        }
    }

    private func foreground(_ tone: QuickChip.Tone) -> Color {
        switch tone {
        case .neutral: theme.ink
        case .on: .white
        case .offer: .white
        case .swap: theme.accentText
        }
    }

    private func background(_ tone: QuickChip.Tone) -> Color {
        switch tone {
        case .neutral: theme.dark ? Color.white.opacity(0.06) : Color.black.opacity(0.03)
        case .on: theme.accent
        case .offer: Palette.go
        case .swap: theme.accent.opacity(theme.dark ? 0.24 : 0.14)
        }
    }
}
