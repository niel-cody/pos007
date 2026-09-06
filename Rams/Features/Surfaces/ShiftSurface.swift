import SwiftUI

/// The shift. What is in the drawer, what has been sold, what went out as voids and refunds,
/// and a reconciliation that explains its own variance instead of just naming it.
struct ShiftSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.gutter),
                                         count: 4), spacing: Metric.gutter) {
                    tile("Net sales", store.shift.netSales.formatted(), "chart.line.uptrend.xyaxis", theme.accent)
                    tile("Orders", "\(store.shift.orders)", "receipt", Palette.info)
                    tile("Average order", store.shift.averageOrder.formatted(), "divide", theme.inkSecondary)
                    tile("Covers", "\(store.shift.covers)", "person.2.fill", theme.inkSecondary)
                }

                HStack(alignment: .top, spacing: Metric.gutter) {
                    Panel {
                        VStack(alignment: .leading, spacing: 9) {
                            PanelHeader("The drawer", detail: "expected against counted")
                            MoneyRow(label: "Opening float", amount: store.shift.float)
                            MoneyRow(label: "Cash sales", amount: store.shift.cashSales)
                            MoneyRow(label: "Paid in", amount: store.shift.paidIn)
                            MoneyRow(label: "Paid out", amount: -store.shift.paidOut, reduction: true)
                            MoneyRow(label: "Cash drops", amount: -store.shift.drops, reduction: true)
                            Divider().overlay(theme.hairline)
                            MoneyRow(label: "Expected in the drawer",
                                     amount: store.shift.expectedCash, emphasis: true)
                            HStack(spacing: 7) {
                                SecondaryAction(title: "Paid out", glyph: "arrow.up.circle") {
                                    store.shift.paidOut = store.shift.paidOut + Money(20)
                                    store.toast(.done, "Paid out $20.00", detail: "Reason recorded against the shift")
                                }
                                SecondaryAction(title: "Cash drop", glyph: "shippingbox") {
                                    store.shift.drops = store.shift.drops + Money(200)
                                    store.toast(.done, "Dropped $200.00 to the safe", detail: "Two names on the drop")
                                }
                                SecondaryAction(title: "Open drawer", glyph: "tray") {
                                    store.requireApproval(.openDrawer, what: "Open the drawer with no sale",
                                                          reasons: ["Change needed", "Customer query", "Count"]) { approver, reason in
                                        store.toast(.done, "Drawer opened",
                                                    detail: "\(reason ?? "") · audited to \(approver.initials)")
                                    }
                                }
                            }
                        }
                    }

                    Panel {
                        VStack(alignment: .leading, spacing: 9) {
                            PanelHeader("Tenders")
                            MoneyRow(label: "Cash", amount: store.shift.cashSales)
                            MoneyRow(label: "Card", amount: store.shift.cardSales)
                            MoneyRow(label: "Other and prepaid", amount: store.shift.otherSales)
                            Divider().overlay(theme.hairline)
                            PanelHeader("Losses and corrections")
                            MoneyRow(label: "Voids", amount: store.shift.voids, note: "with reasons, in the audit log")
                            MoneyRow(label: "Refunds", amount: store.shift.refunds)
                            Divider().overlay(theme.hairline)
                            MoneyRow(label: "GST included in sales",
                                     amount: Money(cents: Int(Double(store.shift.netSales.cents) / 11)))
                        }
                    }
                }

                Panel {
                    VStack(alignment: .leading, spacing: 9) {
                        PanelHeader("This device", detail: "\(store.profile.deviceName) · \(store.profile.venueName)")
                        HStack(spacing: 20) {
                            info("Shift open", store.shift.openedAt.hhmm)
                            info("Operator", "\(store.operatorStaff.name) · \(store.operatorStaff.role.label)")
                            info("Stations", store.stationDevices.map { "\($0.name)\($0.online ? "" : " (offline)")" }
                                .joined(separator: ", "))
                            info("Sync", store.offline ? "Offline — \(store.orders.filter(\.unsynced).count) queued" : "Up to date")
                        }
                        HStack(spacing: 7) {
                            PrimaryAction(title: "Count and close the shift", glyph: "lock.fill") {
                                store.route = .shiftClose
                            }
                            .frame(width: 300)
                            SecondaryAction(title: "Print the shift report", glyph: "printer") {
                                store.toast(.done, "Shift report printed")
                            }
                            .frame(width: 220)
                        }
                    }
                }
            }
            .padding(Metric.pad)
        }
    }

    private func tile(_ label: String, _ value: String, _ glyph: String, _ tint: Color) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: glyph)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.ink)
                Text(label).sectionLabelStyle(theme.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func info(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).sectionLabelStyle(theme.inkSecondary)
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(theme.ink)
        }
    }
}
