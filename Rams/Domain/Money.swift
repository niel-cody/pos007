import Foundation

/// Money is stored as integer cents. Nothing in this app ever multiplies a Double by a price.
struct Money: Hashable, Codable, Comparable, AdditiveArithmetic, CustomStringConvertible {
    var cents: Int

    init(cents: Int) { self.cents = cents }
    init(_ dollars: Double) { self.cents = Int((dollars * 100).rounded()) }

    static let zero = Money(cents: 0)

    var dollars: Double { Double(cents) / 100 }
    var isZero: Bool { cents == 0 }
    var isNegative: Bool { cents < 0 }

    static func + (l: Money, r: Money) -> Money { Money(cents: l.cents + r.cents) }
    static func - (l: Money, r: Money) -> Money { Money(cents: l.cents - r.cents) }
    static func < (l: Money, r: Money) -> Bool { l.cents < r.cents }
    static prefix func - (m: Money) -> Money { Money(cents: -m.cents) }

    static func * (m: Money, q: Int) -> Money { Money(cents: m.cents * q) }
    static func * (q: Int, m: Money) -> Money { Money(cents: m.cents * q) }

    /// Percentage of a money amount, rounded half-up to the cent.
    func percent(_ pct: Double) -> Money {
        Money(cents: Int((Double(cents) * pct / 100).rounded()))
    }

    /// Proportional share, rounded down; the caller places the residue on the last share.
    func share(numerator: Int, denominator: Int) -> Money {
        guard denominator != 0 else { return .zero }
        return Money(cents: Int((Double(cents) * Double(numerator) / Double(denominator)).rounded()))
    }

    /// Divide into `n` parts. Every part equal except the last, which carries the remainder,
    /// so the parts always sum exactly to the whole. (W09.01)
    func split(into n: Int) -> [Money] {
        guard n > 0 else { return [] }
        let base = cents / n
        var parts = Array(repeating: Money(cents: base), count: n)
        parts[n - 1] = Money(cents: cents - base * (n - 1))
        return parts
    }

    /// Australian cash rounding to the nearest 5c. (W07.21)
    func roundedForCash(to unit: Int = 5) -> Money {
        guard unit > 1 else { return self }
        let r = Int((Double(cents) / Double(unit)).rounded()) * unit
        return Money(cents: r)
    }

    var description: String { formatted() }

    func formatted(showsSign: Bool = false) -> String {
        let sign = cents < 0 ? "−" : (showsSign && cents > 0 ? "+" : "")
        let a = abs(cents)
        return "\(sign)$\(a / 100).\(String(format: "%02d", a % 100))"
    }

    /// Compact form for tiles: $4 rather than $4.00 when the cents are zero.
    var tileLabel: String {
        cents % 100 == 0 ? "$\(cents / 100)" : formatted()
    }
}

extension Sequence where Element == Money {
    var total: Money { reduce(Money.zero, +) }
}
