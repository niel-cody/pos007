import SwiftUI

/// Approval comes to the operator. A manager taps a PIN on this device, the operator stays
/// logged in, and the action is audited against the person who approved it.
struct ApprovalOverlay: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var pin = ""
    @State private var reason: String?
    @State private var failed = false

    private var request: ApprovalRequest? { store.pendingApproval }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea()
                .onTapGesture { store.clearApproval() }

            if let request {
                VStack(spacing: 0) {
                    header(request)
                    Divider().overlay(theme.hairline)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if !request.reasons.isEmpty {
                                VStack(alignment: .leading, spacing: 7) {
                                    PanelHeader("Reason", detail: "goes on the docket and the audit log")
                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 2),
                                              spacing: 7) {
                                        ForEach(request.reasons, id: \.self) { r in
                                            Button {
                                                reason = r
                                            } label: {
                                                Text(r)
                                                    .font(.system(size: 14, weight: reason == r ? .semibold : .regular))
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.horizontal, 12)
                                                    .frame(height: 44)
                                                    .foregroundStyle(reason == r ? .white : theme.ink)
                                                    .background {
                                                        RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                            .fill(reason == r ? theme.accent : theme.surface)
                                                            .overlay {
                                                                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                                    .strokeBorder(theme.hairline, lineWidth: 0.7)
                                                            }
                                                    }
                                            }
                                            .posPress()
                                        }
                                    }
                                }
                            }

                            if !store.can(request.permission) {
                                VStack(alignment: .leading, spacing: 7) {
                                    PanelHeader("Supervisor PIN",
                                                detail: "\(store.operatorStaff.name.firstWord) stays logged in")
                                    HStack(spacing: 8) {
                                        ForEach(0..<4) { i in
                                            Text(pin.count > i ? "●" : "")
                                                .font(.system(size: 20, weight: .bold))
                                                .frame(width: 48, height: 54)
                                                .background {
                                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                        .fill(theme.surface)
                                                        .overlay {
                                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                                .strokeBorder(failed ? Palette.stop : theme.hairline,
                                                                              lineWidth: failed ? 1.5 : 0.7)
                                                        }
                                                }
                                                .foregroundStyle(theme.ink)
                                        }
                                        Spacer()
                                        if failed {
                                            Text("Not a PIN that can approve this")
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .foregroundStyle(Palette.stop)
                                        }
                                    }
                                    pinPad
                                    Text("Try 3333 (supervisor) or 9999 (manager).")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(theme.inkSecondary.opacity(0.8))
                                }
                            }
                        }
                        .padding(Metric.padLarge)
                    }
                    Divider().overlay(theme.hairline)
                    footer(request)
                }
                .frame(width: 520)
                .frame(maxHeight: 840)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous)
                        .fill(theme.canvas)
                        .shadow(color: .black.opacity(0.3), radius: 40, y: 14)
                }
                .clipShape(RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous))
            }
        }
    }

    private func header(_ r: ApprovalRequest) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "person.badge.key.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background { RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Palette.warn) }
            VStack(alignment: .leading, spacing: 1) {
                Text(r.what).font(.system(size: 17, weight: .semibold)).foregroundStyle(theme.ink)
                Text(r.detail ?? r.permission.label)
                    .font(.system(size: 12.5))
                    .foregroundStyle(theme.inkSecondary)
            }
            Spacer()
        }
        .padding(Metric.padLarge)
    }

    private var pinPad: some View {
        let keys = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 7) {
            ForEach(keys.indices, id: \.self) { row in
                HStack(spacing: 7) {
                    ForEach(keys[row], id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 48)
                        } else {
                            Button {
                                failed = false
                                if key == "⌫" { if !pin.isEmpty { pin.removeLast() } }
                                else if pin.count < 4 { pin += key }
                            } label: {
                                Group {
                                    if key == "⌫" {
                                        Image(systemName: "delete.left.fill").font(.system(size: 17))
                                    } else {
                                        Text(key).font(.system(size: 21, weight: .medium, design: .rounded))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .foregroundStyle(theme.ink)
                                .background {
                                    RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                        .fill(theme.surface)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                                                .strokeBorder(theme.hairline, lineWidth: 0.7)
                                        }
                                }
                            }
                            .posPress()
                        }
                    }
                }
            }
        }
    }

    private func footer(_ r: ApprovalRequest) -> some View {
        HStack(spacing: 10) {
            SecondaryAction(title: "Not now") { store.clearApproval() }
            PrimaryAction(title: store.can(r.permission) ? "Confirm" : "Approve",
                          glyph: "checkmark",
                          enabled: (!r.reasonRequired || reason != nil)
                                   && (store.can(r.permission) || pin.count == 4)) {
                if !store.resolveApproval(pin: pin, reason: reason) {
                    failed = true
                    pin = ""
                }
            }
        }
        .padding(Metric.padLarge)
        .background(theme.raised)
    }
}
