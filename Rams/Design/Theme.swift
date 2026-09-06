import SwiftUI

// MARK: - Metrics
//
// The numbers come from the research's measurable baseline (W21.01), converted to points.
// A 10.1" terminal at 149 ppi puts 1 mm at roughly 5.9 px / 4.0 pt, so:
//   primary action   12 mm → 48 pt   (14 mm → 56 pt in wet environments)
//   standard control  9 mm → 36 pt
//   dense accelerator 7 mm → 28 pt   (accelerators only, never the only route)
//   destructive       12 mm and 8 mm (32 pt) clear of its neighbours

enum Metric {
    static let primaryTarget: CGFloat = 52
    static let primaryTargetWet: CGFloat = 60
    static let standardTarget: CGFloat = 40
    static let denseTarget: CGFloat = 30
    static let destructiveIsolation: CGFloat = 32

    static let gutter: CGFloat = 10
    static let pad: CGFloat = 14
    static let padLarge: CGFloat = 20

    // Concentric radii: a control inside a container is inset by the gap between them.
    static let rTile: CGFloat = 16
    static let rCard: CGFloat = 20
    static let rPanel: CGFloat = 26
    static let rChip: CGFloat = 10

    static let cartWidth: CGFloat = 380
    static let cartWidthWide: CGFloat = 420
    static let railWidth: CGFloat = 92
}

// MARK: - Palette
//
// Two grounds, not one: the content layer is opaque so money can be read in glare
// (7:1 on any figure the operator acts on), and glass is reserved for the navigation layer.

struct Palette {
    var hue: Double

    // Grounds
    var canvas: Color { Color(hue: hue / 360, saturation: 0.06, brightness: 0.99) }
    var canvasDark: Color { Color(hue: hue / 360, saturation: 0.10, brightness: 0.09) }
    var surface: Color { .white }
    var surfaceDark: Color { Color(hue: hue / 360, saturation: 0.08, brightness: 0.15) }
    var raised: Color { Color(hue: hue / 360, saturation: 0.04, brightness: 0.965) }
    var raisedDark: Color { Color(hue: hue / 360, saturation: 0.09, brightness: 0.20) }

    // Ink
    var ink: Color { Color(hue: hue / 360, saturation: 0.22, brightness: 0.11) }
    var inkDark: Color { Color(hue: hue / 360, saturation: 0.05, brightness: 0.99) }
    var inkSecondary: Color { Color(hue: hue / 360, saturation: 0.12, brightness: 0.42) }
    var inkSecondaryDark: Color { Color(hue: hue / 360, saturation: 0.06, brightness: 0.68) }

    // Accent
    var accent: Color { Color(hue: hue / 360, saturation: 0.82, brightness: 0.62) }
    var accentSoft: Color { Color(hue: hue / 360, saturation: 0.16, brightness: 0.96) }
    var accentSoftDark: Color { Color(hue: hue / 360, saturation: 0.45, brightness: 0.28) }

    var hairline: Color { Color(hue: hue / 360, saturation: 0.10, brightness: 0.88) }
    var hairlineDark: Color { Color(hue: hue / 360, saturation: 0.10, brightness: 0.30) }

    // Semantics. Every one of these is paired with a word and a glyph, never used alone.
    static let go = Color(red: 0.05, green: 0.55, blue: 0.32)
    static let warn = Color(red: 0.85, green: 0.55, blue: 0.05)
    static let stop = Color(red: 0.80, green: 0.16, blue: 0.16)
    static let info = Color(red: 0.10, green: 0.42, blue: 0.85)
    static let fire = Color(red: 0.88, green: 0.36, blue: 0.08)
    static let cool = Color(red: 0.36, green: 0.42, blue: 0.55)

    /// Product hues, used at low saturation so a grid of forty tiles is scannable, not loud.
    static let productHues: [Double] = [12, 32, 48, 96, 152, 188, 208, 258, 292, 328]

    static func productTint(_ index: Int) -> Color {
        let h = productHues[abs(index) % productHues.count]
        return Color(hue: h / 360, saturation: 0.68, brightness: 0.58)
    }
}

// MARK: - Theme environment

struct Theme {
    var palette: Palette
    var dark: Bool
    var wet: Bool

    var canvas: Color { dark ? palette.canvasDark : palette.canvas }
    var surface: Color { dark ? palette.surfaceDark : palette.surface }
    var raised: Color { dark ? palette.raisedDark : palette.raised }
    var ink: Color { dark ? palette.inkDark : palette.ink }
    var inkSecondary: Color { dark ? palette.inkSecondaryDark : palette.inkSecondary }
    var accent: Color { palette.accent }
    var accentSoft: Color { dark ? palette.accentSoftDark : palette.accentSoft }
    var hairline: Color { dark ? palette.hairlineDark : palette.hairline }

    var primaryTarget: CGFloat { wet ? Metric.primaryTargetWet : Metric.primaryTarget }

    static let fallback = Theme(palette: Palette(hue: 205), dark: false, wet: false)
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.fallback
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Type
//
// One scale, used everywhere. Money is always tabular so columns of figures line up and a
// changing total does not shuffle its own digits.

extension Font {
    static func pos(_ size: CGFloat, _ weight: Font.Weight = .regular, rounded: Bool = false) -> Font {
        .system(size: size, weight: weight, design: rounded ? .rounded : .default)
    }

    /// 32 pt minimum, and the largest text on its screen.
    static let amountDue = Font.system(size: 40, weight: .semibold, design: .rounded)
    /// 40 pt minimum: the single number an operator most often misreads.
    static let changeDue = Font.system(size: 52, weight: .bold, design: .rounded)
    static let money = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let moneyLarge = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let tileTitle = Font.system(size: 16, weight: .semibold)
    static let tilePrice = Font.system(size: 14, weight: .medium, design: .rounded)
    /// Cart line item names never go below 16 pt.
    static let cartLine = Font.system(size: 16, weight: .medium)
    static let cartDetail = Font.system(size: 13, weight: .regular)
    static let sectionLabel = Font.system(size: 12, weight: .semibold)
    static let chip = Font.system(size: 12, weight: .semibold)
    static let screenTitle = Font.system(size: 26, weight: .bold)
}

extension View {
    /// Figures the operator acts on are tabular and never shuffle their own digits.
    func moneyFigure() -> some View { monospacedDigit() }

    func sectionLabelStyle(_ color: Color) -> some View {
        font(.sectionLabel)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(color)
    }
}

// MARK: - Motion
//
// Fast, purposeful, and switched off entirely under Reduce Motion. (W21.15)

enum Motion {
    static let tap = Animation.spring(response: 0.22, dampingFraction: 0.78)
    static let panel = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let quick = Animation.easeOut(duration: 0.16)
}
