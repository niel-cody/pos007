import Foundation

/// Price resolution and the explanation that goes with it. Every price change carries a reason
/// the operator can read out loud. (W07.22)
struct PricingContext {
    var hour: Int
    var orderType: OrderType
    var channel: SalesChannel
    var customer: Customer?
    var profile: VenueProfile

    var isMember: Bool { customer?.isMember == true }
    var customerGroup: String? { customer?.group }
}

struct PricedProduct {
    var price: Money
    var listPrice: Money
    var reason: String?

    var isReduced: Bool { price < listPrice }
}

enum PricingEngine {

    // MARK: - Line pricing

    static func price(_ product: Product,
                      variant: VariantOption?,
                      in catalogue: Catalogue,
                      context: PricingContext) -> PricedProduct {
        let list = product.price + (variant?.priceDelta ?? .zero)
        var best = list
        var reason: String?

        // Automatic promotions that reprice a single line (happy hour, fixed price).
        for promo in catalogue.promotions.sorted(by: { $0.priority > $1.priority }) {
            guard promo.activeNow(hour: context.hour) else { continue }
            if promo.memberOnly && !context.isMember { continue }
            if !promo.groups.isEmpty && !promo.groups.contains(context.customerGroup ?? "") { continue }
            if !promo.orderTypes.isEmpty && !promo.orderTypes.contains(context.orderType) { continue }
            let matchesProduct = promo.productIDs.contains(product.id)
            let matchesCategory = promo.categoryIDs.contains(product.categoryID)
            guard matchesProduct || matchesCategory else { continue }

            switch promo.kind {
            case .percentOff(let pct):
                let candidate = list - list.percent(pct)
                if candidate < best { best = candidate; reason = promo.name }
            case .amountOff(let off):
                let candidate = max(.zero, list - off)
                if candidate < best { best = candidate; reason = promo.name }
            case .fixedPrice(let p):
                if p < best { best = p; reason = promo.name }
            default:
                continue
            }
        }

        return PricedProduct(price: best, listPrice: list, reason: reason)
    }

    // MARK: - Order level automatic promotions

    /// Threshold, buy-X-get-Y and bundle promotions applied to the whole order, highest
    /// priority first, and only stacked where the promotion says it may.
    static func orderPromotions(for order: Order,
                                catalogue: Catalogue,
                                context: PricingContext) -> [Adjustment] {
        var result: [Adjustment] = []
        var exclusiveApplied = false

        for promo in catalogue.promotions.sorted(by: { $0.priority > $1.priority }) {
            guard promo.activeNow(hour: context.hour) else { continue }
            if promo.memberOnly && !context.isMember { continue }
            if !promo.groups.isEmpty && !promo.groups.contains(context.customerGroup ?? "") { continue }
            if exclusiveApplied && !promo.stacks { continue }

            switch promo.kind {
            case .thresholdAmountOff(let spend, let off):
                guard order.subtotal >= spend else { continue }
                result.append(Adjustment(kind: .promotion, name: promo.name,
                                         amount: -off, automatic: true))
                if !promo.stacks { exclusiveApplied = true }

            case .buyXGetY(let buy, let free):
                let eligible = order.liveItems.filter {
                    promo.productIDs.contains($0.productID) ||
                    (catalogue.product($0.productID).map { promo.categoryIDs.contains($0.categoryID) } ?? false)
                }
                let units = eligible.reduce(0) { $0 + $1.quantity }
                let sets = units / (buy + free)
                guard sets > 0, let cheapest = eligible.map(\.eachTotal).min() else { continue }
                let off = cheapest * (sets * free)
                result.append(Adjustment(kind: .promotion, name: promo.name,
                                         amount: -off, automatic: true))
                if !promo.stacks { exclusiveApplied = true }

            case .bundleFixed(let names, let price):
                let matched = names.allSatisfy { n in
                    order.liveItems.contains { $0.name == n }
                }
                guard matched else { continue }
                let bundleGross = names.compactMap { n in
                    order.liveItems.first { $0.name == n }?.eachTotal
                }.total
                guard bundleGross > price else { continue }
                result.append(Adjustment(kind: .promotion, name: promo.name,
                                         amount: -(bundleGross - price), automatic: true))
                if !promo.stacks { exclusiveApplied = true }

            default:
                continue
            }
        }
        return result
    }

    // MARK: - Surcharges and service charges

    static func serviceCharge(for order: Order, profile: VenueProfile) -> Adjustment? {
        guard let pct = profile.serviceChargePercent else { return nil }
        if let threshold = profile.serviceChargeCoverThreshold {
            guard (order.guestCount ?? 0) >= threshold else { return nil }
        }
        let amount = order.subtotal.percent(pct)
        guard amount.cents > 0 else { return nil }
        return Adjustment(kind: .serviceCharge,
                          name: "Service charge \(Int(pct))%",
                          amount: amount, percent: pct, automatic: true)
    }

    static func cardSurcharge(on amount: Money, profile: VenueProfile) -> Money {
        guard let pct = profile.surchargePercent else { return .zero }
        return amount.percent(pct)
    }

    /// Australian cash rounding applies to the cash leg only, never to the order total.
    static func cashRounding(on amount: Money, profile: VenueProfile) -> Money {
        guard profile.cashRounding > 1 else { return .zero }
        return amount.roundedForCash(to: profile.cashRounding) - amount
    }
}
