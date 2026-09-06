import SwiftUI

struct RouteSheet: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var route: Route

    var body: some View {
        content
            .frame(width: size.width, height: size.height)
            .presentationSizing(.fitted)
            .background(theme.canvas)
    }

    private var size: CGSize {
        switch route {
        case .configure(let pid, _):
            // The sheet is the size of what is on it, never more.
            guard let product = store.catalogue.product(pid) else {
                return CGSize(width: 660, height: 520)
            }
            let twoColumns = product.groups.count > 2
            let width: CGFloat = twoColumns ? (product.groups.count > 4 ? 1000 : 900) : 660
            let content = ConfigureSheet.contentHeight(for: product, twoColumns: twoColumns)
            let height = min(872, max(430, content + 150))
            return CGSize(width: width, height: height)
        case .combo, .portions: return CGSize(width: 960, height: 720)
        case .payment: return CGSize(width: 1000, height: 862)
        case .split: return CGSize(width: 1020, height: 840)
        case .orderDetails, .customers: return CGSize(width: 760, height: 780)
        case .refund: return CGSize(width: 820, height: 800)
        case .timeline: return CGSize(width: 640, height: 760)
        case .tableSheet: return CGSize(width: 620, height: 780)
        case .help: return CGSize(width: 760, height: 720)
        case .transfer: return CGSize(width: 700, height: 760)
        case .courses: return CGSize(width: 620, height: 720)
        case .discountItem, .discountOrder: return CGSize(width: 680, height: 800)
        case .voidItem: return CGSize(width: 560, height: 700)
        case .openTab: return CGSize(width: 620, height: 700)
        case .shiftClose: return CGSize(width: 820, height: 780)
        default: return CGSize(width: 520, height: 640)
        }
    }

    @ViewBuilder private var content: some View {
        switch route {
        case .configure(let pid, let editing):
            if let p = store.catalogue.product(pid) {
                ConfigureSheet(product: p, editingItemID: editing)
            }
        case .combo(let cid, let pid, let editing):
            if let combo = store.catalogue.combo(cid) {
                ComboSheet(combo: combo, seedProductID: pid, editingItemID: editing)
            }
        case .portions(let cid, let editing):
            if let combo = store.catalogue.combo(cid) {
                PortionSheet(combo: combo, editingItemID: editing)
            }
        case .payment: PaymentSheet()
        case .split: SplitSheet()
        case .orderDetails: OrderDetailsSheet()
        case .customers: CustomerSheet()
        case .discountItem(let id): DiscountSheet(itemID: id)
        case .discountOrder: DiscountSheet(itemID: nil)
        case .voidItem(let id): VoidSheet(itemID: id)
        case .refund(let id): RefundSheet(orderID: id)
        case .timeline(let id): TimelineSheet(orderID: id)
        case .tableSheet(let id): TableSheet(tableID: id)
        case .openTab: OpenTabSheet()
        case .courses: CoursesSheet()
        case .seats(let id): SeatSheet(itemID: id)
        case .note(let id): NoteSheet(itemID: id)
        case .openPrice(let id): OpenPriceSheet(productID: id)
        case .transfer(let id): TransferSheet(orderID: id)
        case .shiftClose: ShiftCloseSheet()
        case .help: HelpSheet()
        case .modes: EmptyView()
        }
    }
}

/// A common frame for every sheet: a title, a way out, and a primary action that says what
/// it will do.
struct SheetFrame<Content: View, Footer: View>: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var title: String
    var subtitle: String?
    var glyph: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                if let glyph {
                    Image(systemName: glyph)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(theme.accent)
                        }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5))
                            .foregroundStyle(theme.inkSecondary)
                    }
                }
                Spacer()
                Button {
                    store.route = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 38, height: 38)
                        .foregroundStyle(theme.inkSecondary)
                        .background {
                            Circle().fill(theme.dark ? Color.white.opacity(0.07) : Color.black.opacity(0.04))
                        }
                }
                .posPress()
            }
            .padding(.horizontal, Metric.padLarge)
            .padding(.vertical, 13)

            Divider().overlay(theme.hairline)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            let f = footer
            if !(f is EmptyView) {
                Divider().overlay(theme.hairline)
                f
                    .padding(Metric.padLarge)
                    .background(theme.raised)
            }
        }
        .background(theme.canvas)
    }
}
