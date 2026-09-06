import SwiftUI

/// A confirmation is a deliberate stop, so it looks like one: large, isolated, and it says
/// what will happen rather than asking "are you sure".
struct ConfirmOverlay: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
                .onTapGesture { store.resolveConfirm(false) }

            if let request = store.pendingConfirm {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: request.glyph)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(request.destructive ? Palette.stop : Palette.warn)
                            }
                        Text(request.title)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        Spacer()
                    }
                    Text(request.message)
                        .font(.system(size: 15))
                        .foregroundStyle(theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 10) {
                        SecondaryAction(title: "Not this time") { store.resolveConfirm(false) }
                        PrimaryAction(title: request.confirmTitle,
                                      glyph: "checkmark",
                                      tint: request.destructive ? Palette.stop : theme.accent) {
                            store.resolveConfirm(true)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(Metric.padLarge)
                .frame(width: 520)
                .background {
                    RoundedRectangle(cornerRadius: Metric.rPanel, style: .continuous)
                        .fill(theme.surface)
                        .shadow(color: .black.opacity(0.3), radius: 34, y: 12)
                }
            }
        }
    }
}
