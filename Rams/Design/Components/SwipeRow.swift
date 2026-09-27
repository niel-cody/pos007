import SwiftUI

/// A swipeable row, the way a mail client does it: pull it aside and the actions are there.
///
/// Two rules from the research hold it in place. Swipe is an accelerator and never the only
/// route, so every action here also exists in the line's menu. And a wet finger cannot be
/// asked for precision, so the actions are large, the row snaps rather than tracking loosely,
/// and a long pull commits the leading action instead of demanding an aim.
struct SwipeAction: Identifiable {
    var id = UUID()
    var title: String
    var glyph: String
    var tint: Color
    var isDestructive: Bool = false
    var run: () -> Void
}

struct SwipeRow<Content: View>: View {
    @Environment(\.theme) private var theme
    var leading: [SwipeAction]
    var trailing: [SwipeAction]
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var committed = false
    private let buttonWidth: CGFloat = 76
    private let commitThreshold: CGFloat = 190

    private var leadingWidth: CGFloat { CGFloat(leading.count) * buttonWidth }
    private var trailingWidth: CGFloat { CGFloat(trailing.count) * buttonWidth }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(leading) { action in
                    actionButton(action, revealed: offset > 0)
                }
                Spacer(minLength: 0)
                ForEach(trailing) { action in
                    actionButton(action, revealed: offset < 0)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous))

            content
                .background {
                    RoundedRectangle(cornerRadius: Metric.rChip + 2, style: .continuous)
                        .fill(theme.surface)
                        .opacity(offset == 0 ? 0 : 1)
                }
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 14)
                        .onChanged { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let raw = value.translation.width
                            // Resistance past the revealed width, so the row feels attached.
                            let limit = raw > 0 ? leadingWidth : trailingWidth
                            if limit == 0 { return }
                            offset = abs(raw) <= limit ? raw : raw > 0
                                ? limit + (raw - limit) * 0.35
                                : -limit + (raw + limit) * 0.35
                        }
                        .onEnded { value in
                            let raw = value.translation.width
                            // A long pull commits the first action without having to aim.
                            if raw <= -commitThreshold, let first = trailing.first {
                                commit(first)
                            } else if raw >= commitThreshold, let first = leading.first {
                                commit(first)
                            } else if raw < -buttonWidth / 2, !trailing.isEmpty {
                                withAnimation(Motion.tap) { offset = -trailingWidth }
                            } else if raw > buttonWidth / 2, !leading.isEmpty {
                                withAnimation(Motion.tap) { offset = leadingWidth }
                            } else {
                                close()
                            }
                        }
                )
        }
        .animation(Motion.tap, value: offset)
    }

    private func actionButton(_ action: SwipeAction, revealed: Bool) -> some View {
        Button {
            commit(action)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: action.glyph).font(.system(size: 17, weight: .bold))
                Text(action.title).font(.system(size: 11, weight: .semibold))
            }
            .frame(width: buttonWidth)
            .frame(maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(action.tint)
        }
        .opacity(revealed ? 1 : 0)
        .allowsHitTesting(revealed)
    }

    private func commit(_ action: SwipeAction) {
        guard !committed else { return }
        committed = true
        action.run()
        close()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            committed = false
        }
    }

    private func close() {
        withAnimation(Motion.tap) { offset = 0 }
    }
}
