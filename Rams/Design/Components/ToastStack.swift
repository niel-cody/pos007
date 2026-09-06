import SwiftUI

/// Confirmation is a toast that leaves the work visible. A modal that hides the cart costs
/// the operator the thing they were looking at.
struct ToastStack: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(store.toasts) { toast in
                HStack(spacing: 10) {
                    Image(systemName: glyph(toast.kind))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint(toast.kind))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.text)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        if let d = toast.detail {
                            Text(d)
                                .font(.system(size: 12.5))
                                .foregroundStyle(theme.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let undo = toast.undo {
                        Divider().frame(height: 26)
                        Button(undo) {
                            store.undoLast()
                            store.dismissToast(toast.id)
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .frame(maxWidth: 460, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                        .fill(theme.surface)
                        .shadow(color: .black.opacity(theme.dark ? 0.5 : 0.14), radius: 16, y: 6)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(tint(toast.kind))
                                .frame(width: 3)
                                .padding(.vertical, 8)
                                .padding(.leading, 3)
                        }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onTapGesture { store.dismissToast(toast.id) }
            }
        }
        .animation(Motion.panel, value: store.toasts.count)
        .padding(.leading, 20)
        .padding(.bottom, 20)
    }

    private func glyph(_ k: Toast.Kind) -> String {
        switch k {
        case .done: "checkmark.circle.fill"
        case .info: "info.circle.fill"
        case .warn: "exclamationmark.triangle.fill"
        case .stop: "exclamationmark.octagon.fill"
        }
    }

    private func tint(_ k: Toast.Kind) -> Color {
        switch k {
        case .done: Palette.go
        case .info: Palette.info
        case .warn: Palette.warn
        case .stop: Palette.stop
        }
    }
}
