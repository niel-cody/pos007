import SwiftUI

// MARK: - Press feedback
//
// Every tap is acknowledged inside 100 ms with a visible state change, so an operator whose
// tap did not register can tell immediately rather than tapping harder and adding two items.
// A tap that travels up to about 2 mm still counts as a tap.

struct POSButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .contentShape(.rect)
    }
}

extension View {
    func posPress(scale: CGFloat = 0.97) -> some View {
        buttonStyle(POSButtonStyle(scale: scale))
    }
}

/// Repeat protection: a second tap on the same primary action inside 300 ms is a double
/// contact from a wet finger, and is ignored.
@MainActor
final class TapGuard {
    private var last: Date = .distantPast
    func allow(_ window: TimeInterval = 0.3) -> Bool {
        guard Date.now.timeIntervalSince(last) > window else { return false }
        last = .now
        return true
    }
}

// MARK: - Chips

struct Chip: View {
    @Environment(\.theme) private var theme
    var text: String
    var glyph: String?
    var tint: Color?
    var filled: Bool = false
    var small: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            if let glyph {
                Image(systemName: glyph)
                    .font(.system(size: small ? 9 : 10, weight: .bold))
            }
            Text(text)
                .font(.system(size: small ? 11 : 12, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, small ? 6 : 8)
        .padding(.vertical, small ? 3 : 4)
        .foregroundStyle(filled ? .white : (tint ?? theme.inkSecondary))
        .background {
            let c = tint ?? theme.inkSecondary
            RoundedRectangle(cornerRadius: small ? 6 : 7, style: .continuous)
                .fill(filled ? c : c.opacity(theme.dark ? 0.22 : 0.11))
        }
    }
}

/// State is never carried by colour alone: a word and a glyph go with every colour.
struct StateBadge: View {
    var state: TableState
    var compact: Bool = false

    var body: some View {
        Chip(text: compact ? state.word : state.word.uppercased(),
             glyph: state.glyph, tint: Palette.tint(for: state), filled: true, small: compact)
    }
}

extension Palette {
    static func tint(for state: TableState) -> Color {
        switch state {
        case .vacant: Color(white: 0.55)
        case .reserved: Palette.info
        case .seated: Color(red: 0.35, green: 0.45, blue: 0.62)
        case .ordering: Color(red: 0.42, green: 0.38, blue: 0.72)
        case .ordered: Color(red: 0.20, green: 0.42, blue: 0.78)
        case .cooking: Palette.fire
        case .ready: Color(red: 0.62, green: 0.40, blue: 0.02)
        case .partlyServed: Color(red: 0.30, green: 0.50, blue: 0.36)
        case .served: Palette.go
        case .dessert: Color(red: 0.62, green: 0.28, blue: 0.55)
        case .billRequested: Color(red: 0.75, green: 0.42, blue: 0.05)
        case .partlyPaid: Color(red: 0.66, green: 0.35, blue: 0.20)
        case .paid: Palette.go
        case .reset: Color(red: 0.45, green: 0.45, blue: 0.50)
        case .blocked: Color(white: 0.40)
        }
    }

    static func tint(for send: ItemSendState) -> Color {
        switch send {
        case .unsent: Color(red: 0.42, green: 0.38, blue: 0.72)
        case .held: Palette.warn
        case .sending: Palette.info
        case .sent: Palette.go
        case .notConfirmed: Palette.warn
        case .notSent: Palette.stop
        }
    }
}

// MARK: - Section headers

struct PanelHeader: View {
    @Environment(\.theme) private var theme
    var title: String
    var detail: String?
    var trailing: AnyView?

    init(_ title: String, detail: String? = nil, @ViewBuilder trailing: () -> some View = { EmptyView() }) {
        self.title = title
        self.detail = detail
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title).sectionLabelStyle(theme.inkSecondary)
            if let detail {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary.opacity(0.8))
            }
            Spacer(minLength: 4)
            trailing
        }
    }
}

// MARK: - Money row

struct MoneyRow: View {
    @Environment(\.theme) private var theme
    var label: String
    var amount: Money
    var emphasis: Bool = false
    var reduction: Bool = false
    var note: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: emphasis ? 15 : 13, weight: emphasis ? .semibold : .regular))
                    .foregroundStyle(emphasis ? theme.ink : theme.inkSecondary)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.inkSecondary.opacity(0.85))
                }
            }
            Spacer(minLength: 8)
            Text(amount.formatted(showsSign: reduction && !amount.isZero))
                .font(emphasis ? .moneyLarge : .money)
                .moneyFigure()
                .foregroundStyle(reduction && !amount.isZero
                                 ? Palette.go
                                 : (emphasis ? theme.ink : theme.inkSecondary))
        }
    }
}

// MARK: - Big primary action
//
// 52 pt tall, 60 pt where the venue is a wet environment. Never smaller.

struct PrimaryAction: View {
    @Environment(\.theme) private var theme
    var title: String
    var subtitle: String?
    var glyph: String?
    var tint: Color?
    var enabled: Bool = true
    var action: () -> Void

    private let guardian = TapGuard()

    var body: some View {
        Button {
            guard guardian.allow() else { return }
            action()
        } label: {
            HStack(spacing: 10) {
                if let glyph {
                    Image(systemName: glyph).font(.system(size: 17, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 17, weight: .semibold))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 12, weight: .medium)).opacity(0.85)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: theme.primaryTarget)
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(tint ?? theme.accent)
            }
            .opacity(enabled ? 1 : 0.4)
        }
        .disabled(!enabled)
        .posPress()
    }
}

struct SecondaryAction: View {
    @Environment(\.theme) private var theme
    var title: String
    var glyph: String?
    var tint: Color?
    var enabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let glyph { Image(systemName: glyph).font(.system(size: 14, weight: .semibold)) }
                Text(title).font(.system(size: 15, weight: .medium))
            }
            .padding(.horizontal, 14)
            .frame(height: Metric.standardTarget)
            .frame(maxWidth: .infinity)
            .foregroundStyle(tint ?? theme.ink)
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                    .fill(theme.dark ? Color.white.opacity(0.08) : Color.black.opacity(0.045))
            }
            .opacity(enabled ? 1 : 0.35)
        }
        .disabled(!enabled)
        .posPress()
    }
}

/// A destructive control is 12 mm and sits at least 8 mm from its neighbours. It never lands
/// where a thumb rests.
struct DestructiveAction: View {
    var title: String
    var glyph: String = "trash.fill"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: glyph).font(.system(size: 14, weight: .semibold))
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: Metric.primaryTarget)
            .frame(maxWidth: .infinity)
            .foregroundStyle(Palette.stop)
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                    .fill(Palette.stop.opacity(0.1))
            }
        }
        .posPress()
        .padding(.top, Metric.destructiveIsolation - Metric.pad)
    }
}

// MARK: - Empty state

struct EmptyHint: View {
    @Environment(\.theme) private var theme
    var glyph: String
    var title: String
    var detail: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: glyph)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(theme.inkSecondary.opacity(0.45))
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(theme.inkSecondary)
            if let detail {
                Text(detail)
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.inkSecondary.opacity(0.8))
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card container

struct Panel<Content: View>: View {
    @Environment(\.theme) private var theme
    var padding: CGFloat = Metric.pad
    var radius: CGFloat = Metric.rCard
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(theme.hairline, lineWidth: 0.7)
                    }
            }
    }
}

// MARK: - Segmented control, sized for a till rather than a phone

struct POSSegments<T: Hashable>: View {
    @Environment(\.theme) private var theme
    var options: [(value: T, label: String, glyph: String?)]
    @Binding var selection: T
    var height: CGFloat = 44

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { opt in
                let active = opt.value == selection
                Button {
                    withAnimation(Motion.tap) { selection = opt.value }
                } label: {
                    HStack(spacing: 6) {
                        if let g = opt.glyph {
                            Image(systemName: g).font(.system(size: 13, weight: .semibold))
                        }
                        Text(opt.label).font(.system(size: 15, weight: active ? .semibold : .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .foregroundStyle(active ? .white : theme.ink)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                            .fill(active ? theme.accent : Color.clear)
                    }
                }
                .posPress(scale: 0.98)
            }
        }
        .padding(4)
        .background {
            RoundedRectangle(cornerRadius: Metric.rChip + 4, style: .continuous)
                .fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
        }
    }
}
