import SwiftUI

/// The cart. Grouped the way the venue thinks: by course in a restaurant, by round at a bar,
/// flat at a counter. Sent lines collapse so the cart stays readable when a table has ordered
/// three times.
struct CartBody: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    @State private var collapseSent = true

    var body: some View {
        VStack(spacing: 0) {
            if order.hasAttention { attentionBanner }
            scroller
        }
    }

    private var scroller: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                switch store.grouping {
                case .courses: courseGroups
                case .rounds: roundGroups
                case .flat: flatLines
                }

                if !order.adjustments.isEmpty {
                    adjustmentBlock
                }
            }
            .padding(.horizontal, Metric.pad)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Courses

    private var courseGroups: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(order.courses) { course in
                let items = order.items(inCourse: course.id)
                if !items.isEmpty || store.courseFilterID == course.id {
                    CourseBlock(order: order, course: course, items: items)
                }
            }
            let orphans = order.liveItems.filter { $0.courseID == nil }
            if !orphans.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    PanelHeader("No course")
                    ForEach(orphans) { CartLineRow(order: order, item: $0) }
                }
            }
        }
    }

    // MARK: - Rounds

    private var roundGroups: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(order.rounds, id: \.id) { round in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Text("Round \(roundNumber(round.id))")
                            .sectionLabelStyle(theme.inkSecondary)
                        Text(round.at.hhmm)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.inkSecondary.opacity(0.8))
                        Spacer()
                        Text(round.items.map(\.lineTotal).total.formatted())
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .moneyFigure()
                            .foregroundStyle(theme.inkSecondary)
                        Button {
                            store.repeatRound(round.id)
                        } label: {
                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(theme.accent)
                                .frame(width: 30, height: 30)
                        }
                        .posPress()
                        .help("Repeat this round")
                    }
                    ForEach(round.items) { CartLineRow(order: order, item: $0) }
                }
            }
            let loose = order.liveItems.filter { $0.roundID == nil }
            if !loose.isEmpty {
                ForEach(loose) { CartLineRow(order: order, item: $0) }
            }
        }
    }

    private func roundNumber(_ id: UUID) -> Int {
        let all = order.rounds.sorted { $0.at < $1.at }
        return (all.firstIndex { $0.id == id } ?? 0) + 1
    }

    // MARK: - Flat

    private var flatLines: some View {
        VStack(alignment: .leading, spacing: 6) {
            let sent = order.liveItems.filter(\.isSentOrLater)
            let unsent = order.liveItems.filter { !$0.isSentOrLater }

            if !sent.isEmpty {
                HStack {
                    PanelHeader("Sent", detail: "\(sent.reduce(0) { $0 + $1.quantity }) items")
                    Button(collapseSent ? "Show" : "Hide") {
                        withAnimation(Motion.tap) { collapseSent.toggle() }
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.accent)
                }
                if !collapseSent {
                    ForEach(sent) { CartLineRow(order: order, item: $0) }
                } else {
                    collapsedSummary(sent)
                }
            }
            if !unsent.isEmpty {
                if !sent.isEmpty { PanelHeader("Adding now").padding(.top, 6) }
                ForEach(unsent) { CartLineRow(order: order, item: $0) }
            }
            if order.liveItems.isEmpty {
                EmptyHint(glyph: "plus.circle", title: "Nothing on this order yet",
                          detail: "Tap a product. Long press to add it with its defaults.")
                    .frame(height: 180)
            }
        }
    }

    private func collapsedSummary(_ items: [OrderItem]) -> some View {
        Button {
            withAnimation(Motion.tap) { collapseSent = false }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.go)
                Text(items.map { "\($0.quantity)× \($0.name)" }.joined(separator: ", "))
                    .font(.system(size: 13))
                    .foregroundStyle(theme.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 6)
                Text(items.map(\.lineTotal).total.formatted())
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(theme.inkSecondary)
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                    .fill(theme.dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025))
            }
        }
        .posPress(scale: 0.995)
    }

    // MARK: - Adjustments

    private var adjustmentBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            PanelHeader("Why the price changed")
            ForEach(order.adjustments) { adj in
                HStack(spacing: 7) {
                    Image(systemName: adj.isReduction ? "tag.fill" : "plus.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(adj.isReduction ? Palette.go : theme.inkSecondary)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(adj.explanation)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(theme.ink)
                        if let r = adj.reason ?? adj.approvedBy.map({ "Approved by \($0)" }) {
                            Text(r).font(.system(size: 11)).foregroundStyle(theme.inkSecondary)
                        }
                    }
                    Spacer(minLength: 6)
                    Text(adj.amount.formatted(showsSign: true))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .moneyFigure()
                        .foregroundStyle(adj.isReduction ? Palette.go : theme.ink)
                    if !adj.automatic {
                        Button {
                            store.removeAdjustment(adj.id, itemID: nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.inkSecondary.opacity(0.6))
                        }
                    }
                }
                .padding(.vertical, 3)
            }
        }
    }

    private var attentionBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "printer.trianglebadge.exclamationmark.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
            Text("A docket did not reach its station")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, Metric.pad)
        .padding(.vertical, 8)
        .background(Palette.stop)
    }
}

// MARK: - Course block
//
// Hold and fire live on the course header, which is where the waiter is looking when they
// decide. Two taps to fire mains, not four.

struct CourseBlock: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var order: Order
    var course: Course
    var items: [OrderItem]

    private var held: Bool { items.contains { $0.status == .held } }
    private var allServed: Bool {
        let sent = items.filter(\.isSentOrLater)
        return !sent.isEmpty && sent.allSatisfy(\.isServed)
    }
    private var active: Bool { store.courseFilterID == course.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Button {
                    store.courseFilterID = course.id
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: course.glyph)
                            .font(.system(size: 11, weight: .bold))
                        Text(course.name.uppercased())
                            .font(.system(size: 11.5, weight: .bold))
                            .tracking(0.6)
                        if !items.isEmpty {
                            Text("\(items.reduce(0) { $0 + $1.quantity })")
                                .font(.system(size: 10.5, weight: .bold))
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Capsule().fill(active ? Color.white.opacity(0.25) : theme.hairline))
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: 28)
                    .foregroundStyle(active ? .white : theme.inkSecondary)
                    .background {
                        Capsule().fill(active ? theme.accent : Color.clear)
                    }
                }
                .posPress()

                if course.calledAt != nil {
                    Chip(text: "Called \(course.calledAt!.hhmm)", glyph: "bell.fill",
                         tint: Palette.info, filled: true, small: true)
                }
                if held {
                    Chip(text: "Held", glyph: "pause.fill", tint: Palette.warn, filled: true, small: true)
                }
                if allServed {
                    Chip(text: "Served", glyph: "checkmark", tint: Palette.go, small: true)
                }

                Spacer(minLength: 4)

                if held {
                    Button {
                        store.fireCourse(course.id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "flame.fill").font(.system(size: 11, weight: .bold))
                            Text("Fire").font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .foregroundStyle(.white)
                        .background(Capsule().fill(Palette.fire))
                    }
                    .posPress()
                } else if !items.isEmpty && items.contains(where: { $0.status == .unsent }) {
                    Button("Hold") { store.holdCourse(course.id) }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.inkSecondary)
                }

                Menu {
                    Button { store.callCourse(course.id) } label: {
                        Label(course.calledAt == nil ? "Call this course" : "Uncall",
                              systemImage: "bell")
                    }
                    Button { store.fireCourse(course.id, andSend: false) } label: {
                        Label("Fire without sending", systemImage: "flame")
                    }
                    Button { store.send(courseID: course.id) } label: {
                        Label("Send this course", systemImage: "paperplane")
                    }
                    Button { store.markServedAll(orderID: order.id, courseID: course.id) } label: {
                        Label("All served", systemImage: "checkmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 28, height: 28)
                        .foregroundStyle(theme.inkSecondary)
                }
            }

            if items.isEmpty {
                Text("Tapping a product now puts it in \(course.name).")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.inkSecondary.opacity(0.8))
                    .padding(.leading, 2)
            } else {
                ForEach(items) { CartLineRow(order: order, item: $0) }
            }
        }
    }
}
