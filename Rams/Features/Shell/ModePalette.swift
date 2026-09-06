import SwiftUI

/// The mode switcher. Discreet: one chip in the chrome, ⌘K, and it is gone again in a tap.
/// It costs no POS screen space, and what it changes is stated on every row so nobody has to
/// take on faith that the modes differ.
struct ModePalette: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var hovered: BusinessMode?

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()
                .onTapGesture { store.route = nil }

            VStack(spacing: 0) {
                header
                Divider().overlay(theme.hairline)
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(BusinessMode.allCases) { mode in
                            row(mode)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 660)
                Divider().overlay(theme.hairline)
                footer
            }
            .frame(width: 720)
            .background {
                RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous)
                    .fill(theme.surface)
                    .shadow(color: .black.opacity(0.28), radius: 40, y: 16)
            }
            .clipShape(RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Business type")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("One device, eight venues. The workflow changes, not the labels.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.inkSecondary)
            }
            Spacer()
            Text("⌘K")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(theme.hairline.opacity(0.6)))
                .foregroundStyle(theme.inkSecondary)
        }
        .padding(16)
    }

    private func row(_ mode: BusinessMode) -> some View {
        let active = mode == store.mode
        let p = VenueProfile.profile(for: mode)
        return Button {
            store.switchMode(mode)
        } label: {
            HStack(spacing: 13) {
                Image(systemName: mode.glyph)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(hue: mode.accentHue / 360, saturation: 0.78, brightness: 0.60))
                    }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(mode.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        Text(mode.venueName)
                            .font(.system(size: 13))
                            .foregroundStyle(theme.inkSecondary)
                        if active {
                            Chip(text: "Open now", glyph: "checkmark", tint: Palette.go, filled: true, small: true)
                        }
                    }
                    Text(mode.promise)
                        .font(.system(size: 12.5))
                        .foregroundStyle(theme.inkSecondary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        ForEach(p.surfaces.prefix(6)) { s in
                            Chip(text: s.title, glyph: s.glyph, small: true)
                        }
                    }
                    .padding(.top, 1)
                }
                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(active ? theme.accent : theme.inkSecondary.opacity(0.4))
            }
            .padding(11)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(active ? theme.accentSoft : (theme.dark ? Color.white.opacity(0.03) : Color.black.opacity(0.02)))
            }
        }
        .posPress(scale: 0.99)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            detail("Order identity", VenueProfile.profile(for: store.mode).identifier.label)
            detail("Tenders", VenueProfile.profile(for: store.mode).quickTenders.map(\.label).joined(separator: " · "))
            detail("Stations", VenueProfile.profile(for: store.mode).stations.joined(separator: " · "))
            Spacer()
            Button("Close") { store.route = nil }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.inkSecondary)
        }
        .padding(14)
        .background(theme.raised)
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).sectionLabelStyle(theme.inkSecondary.opacity(0.8))
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
        }
    }
}

extension OrderIdentifierStyle {
    var label: String {
        switch self {
        case .none: "Order number"
        case .customerName: "Name on the cup"
        case .token: "Token number"
        case .tableNumber: "Table"
        case .tabName: "Tab name"
        }
    }
}
