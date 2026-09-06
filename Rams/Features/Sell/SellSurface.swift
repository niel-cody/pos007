import SwiftUI

struct SellSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            CategoryRail()
            Divider().overlay(theme.hairline)
            VStack(spacing: 0) {
                SellHeader()
                ProductArea()
            }
            .frame(maxWidth: .infinity)
            Divider().overlay(theme.hairline)
            CartPanel()
                .frame(width: store.profile.grid == .dense ? Metric.cartWidth : Metric.cartWidthWide)
        }
    }
}

// MARK: - Category rail

struct CategoryRail: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(store.catalogue.categories) { cat in
                    let active = store.selectedCategoryID == cat.id && store.searchText.isEmpty
                    Button {
                        store.selectedCategoryID = cat.id
                        store.searchText = ""
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: cat.glyph)
                                .font(.system(size: 19, weight: .medium))
                            Text(cat.name)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .frame(width: Metric.railWidth - 16, height: 68)
                        .foregroundStyle(active ? .white : theme.ink)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                .fill(active ? theme.accent : Color.clear)
                        }
                    }
                    .posPress()
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
        }
        .frame(width: Metric.railWidth)
        .background(theme.raised)
    }
}

// MARK: - Header: search, order type, identity
//
// Search first, because a scanner is a keyboard and a name is faster than a category tap.

struct SellHeader: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.inkSecondary)
                    TextField("Search the menu, or scan", text: Binding(
                        get: { store.searchText },
                        set: { store.searchText = $0 }))
                        .font(.system(size: 16))
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .onSubmit {
                            if let first = store.searchResults().first {
                                store.tapProduct(first)
                                store.searchText = ""
                            }
                        }
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(theme.inkSecondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .frame(maxWidth: 420)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                        .fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                }

                if store.profile.keypadPrefix {
                    QuantityPrefixPad(prefix: Binding(get: { store.keypadPrefix },
                                                      set: { store.keypadPrefix = $0 }))
                }

                Spacer(minLength: 4)

                if store.profile.askOrderType {
                    orderTypePicker
                }
            }
            .padding(.horizontal, Metric.pad)
            .padding(.top, Metric.pad)

            if !store.searchText.isEmpty {
                HStack {
                    Text("\(store.searchResults().count) result\(store.searchResults().count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.inkSecondary)
                    Spacer()
                }
                .padding(.horizontal, Metric.pad)
            }
        }
        .padding(.bottom, 4)
    }

    private var orderTypePicker: some View {
        HStack(spacing: 4) {
            ForEach(store.profile.orderTypes) { t in
                let active = (store.currentOrder?.type ?? store.profile.defaultOrderType) == t
                Button {
                    if let o = store.currentOrder {
                        store.setOrderType(o.id, t)
                    } else {
                        _ = store.newOrder(type: t)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: t.glyph).font(.system(size: 12, weight: .semibold))
                        Text(t.short).font(.system(size: 13.5, weight: active ? .semibold : .medium))
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 38)
                    .foregroundStyle(active ? .white : theme.ink)
                    .background {
                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                            .fill(active ? theme.accent : (theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04)))
                    }
                }
                .posPress()
            }
        }
    }
}
