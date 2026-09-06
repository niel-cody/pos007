import SwiftUI

struct ProductArea: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.searchText.isEmpty {
                    if store.profile.recentsEnabled && !store.recents.isEmpty {
                        recentsStrip
                    }
                    if store.profile.roundsEnabled, let o = store.currentOrder, !o.rounds.isEmpty {
                        repeatRoundStrip(o)
                    }
                }
                grid
            }
            .padding(Metric.pad)
            .padding(.bottom, 120)
        }
        .overlay(alignment: .bottom) {
            if let offer = store.upsell {
                upsellStrip(offer)
                    .padding(.bottom, 14)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(Motion.panel, value: store.upsell)
    }

    // MARK: - Recents
    //
    // A configured line captured in Recents reproduces the whole drink in one tap. This is
    // the single largest speed win in a café's morning.

    private var recentsStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Just made", detail: "one tap reproduces the whole configuration")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.recents) { snap in
                        Button {
                            store.addRecent(snap)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(snap.variantLabel.map { "\($0) \(snap.name)" } ?? snap.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(1)
                                Text(snap.makeSummary.isEmpty ? "as it comes" : snap.makeSummary)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(theme.inkSecondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 52, alignment: .leading)
                            .frame(minWidth: 150, maxWidth: 230, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .fill(theme.accentSoft)
                            }
                        }
                        .posPress()
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    /// "Same again" is the most common sentence at a bar, and the biggest single gain here.
    private func repeatRoundStrip(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            PanelHeader("Rounds on this tab", detail: "repeat at today’s prices")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(order.rounds.prefix(4), id: \.id) { round in
                        Button {
                            store.repeatRound(round.id)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Repeat · \(round.at.hhmm)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(theme.ink)
                                    Text(round.items.map { "\($0.quantity)× \($0.name)" }
                                        .joined(separator: ", "))
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(theme.inkSecondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 52, alignment: .leading)
                            .frame(minWidth: 200, maxWidth: 300, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                    .fill(theme.accentSoft)
                            }
                        }
                        .posPress()
                    }
                }
            }
        }
    }

    // MARK: - Grid

    private var grid: some View {
        let columns = store.profile.grid.columns
        return VStack(alignment: .leading, spacing: 7) {
            if store.searchText.isEmpty, let cat = store.selectedCategoryID.flatMap(store.catalogue.category) {
                PanelHeader(cat.name, detail: "\(store.gridProducts.count) items")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.gutter),
                                     count: columns),
                      spacing: Metric.gutter) {
                ForEach(store.gridProducts) { product in
                    ProductTile(product: product)
                }
            }
        }
    }

    // MARK: - Upsell

    private func upsellStrip(_ offer: UpsellOffer) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(offer.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(theme.ink)
                Text(offer.detail).font(.system(size: 12.5)).foregroundStyle(theme.inkSecondary)
            }
            Spacer(minLength: 10)
            Button("No thanks") { store.upsell = nil }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(theme.inkSecondary)
            Button {
                store.acceptUpsell()
            } label: {
                Text("Add")
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .frame(height: 40)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(theme.accent))
            }
            .posPress()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule().fill(theme.surface)
                .shadow(color: .black.opacity(theme.dark ? 0.5 : 0.16), radius: 20, y: 8)
        }
    }
}

// MARK: - Product tile

struct ProductTile: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var product: Product

    private var tint: Color { Palette.productTint(product.accent) }
    private var available: Bool { product.isAvailable }

    var body: some View {
        Button {
            store.tapProduct(product)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: product.glyph)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 26, height: 26)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(tint.opacity(theme.dark ? 0.26 : 0.14))
                        }
                    Spacer(minLength: 0)
                    if product.requiresChoice {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.inkSecondary.opacity(0.6))
                    }
                    if product.ageRestricted {
                        Text("18+")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.warn)
                    }
                }

                Spacer(minLength: 6)

                Text(product.name)
                    .font(.tileTitle)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .strikethrough(!available, color: Palette.stop)

                HStack(spacing: 5) {
                    if store.profile.showPricesOnTiles {
                        Text(priceLabel)
                            .font(.tilePrice)
                            .moneyFigure()
                            .foregroundStyle(theme.inkSecondary)
                    }
                    Spacer(minLength: 0)
                    if !available {
                        Chip(text: "Sold out", glyph: "xmark", tint: Palette.stop, filled: true, small: true)
                    } else if let q = product.trackedQuantity, q <= 6 {
                        Chip(text: "\(q) left", glyph: "exclamationmark", tint: Palette.warn, small: true)
                    } else if let reason = priceReason {
                        Chip(text: reason, glyph: "tag.fill", tint: Palette.go, small: true)
                    }
                }
                .padding(.top, 3)
            }
            .padding(11)
            .frame(height: 96, alignment: .topLeading)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                            .strokeBorder(available ? theme.hairline : Palette.stop.opacity(0.4),
                                          lineWidth: available ? 0.7 : 1.2)
                    }
            }
            .opacity(available ? 1 : 0.62)
        }
        .posPress()
        .contextMenu {
            Button {
                store.longPressProduct(product)
            } label: {
                Label(product.hasChoices ? "Add with defaults" : "Add", systemImage: "plus")
            }
            if product.hasChoices {
                Button {
                    store.route = .configure(productID: product.id, editing: nil)
                } label: { Label("Configure", systemImage: "slider.horizontal.3") }
            }
            Divider()
            Button {
                store.setSoldOut(product.id, !product.soldOut)
            } label: {
                Label(product.soldOut ? "Back on the menu" : "Mark sold out",
                      systemImage: product.soldOut ? "checkmark.circle" : "xmark.circle")
            }
        }
        .accessibilityLabel("\(product.name), \(priceLabel)\(available ? "" : ", sold out")")
    }

    private var priced: PricedProduct {
        PricingEngine.price(product, variant: product.variants.first(where: \.isDefault),
                            in: store.catalogue, context: store.pricingContext)
    }

    private var priceLabel: String {
        let p = priced
        if !product.variants.isEmpty {
            let low = product.variants.map { product.price + $0.priceDelta }.min() ?? product.price
            return "from \(low.tileLabel)"
        }
        return p.price.tileLabel
    }

    private var priceReason: String? {
        let p = priced
        return p.isReduced ? p.reason : nil
    }
}
