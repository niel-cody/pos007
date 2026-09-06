import SwiftUI

/// The kitchen board. Targets are the largest in the product, because a chef bumps with a
/// knuckle. A bump raises Ready and never Served: somebody still has to carry the plate.
struct KitchenSurface: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    @State private var station: String?

    private var visible: [KitchenTicket] {
        store.tickets
            .filter { station == nil || $0.station == station }
            .filter { $0.state != .served }
            .sorted { a, b in
                if a.isRush != b.isRush { return a.isRush }
                return a.receivedAt < b.receivedAt
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            stationBar
            Divider().overlay(theme.hairline)
            if visible.isEmpty {
                EmptyHint(glyph: "flame", title: "The board is clear",
                          detail: "Every ticket is bumped. New sends land here within a second.")
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Metric.gutter),
                                             count: 4), spacing: Metric.gutter) {
                        ForEach(visible) { TicketCard(ticket: $0) }
                    }
                    .padding(Metric.pad)
                }
            }
        }
    }

    private var stationBar: some View {
        HStack(spacing: 8) {
            Button {
                station = nil
            } label: {
                stationChip("All", count: store.tickets.filter { $0.state != .served }.count,
                            active: station == nil, online: true)
            }
            .posPress()
            ForEach(store.stationDevices.filter { $0.kind != .label }) { device in
                Button {
                    station = device.name
                } label: {
                    stationChip(device.name,
                                count: store.tickets.filter { $0.station == device.name && $0.state != .served }.count,
                                active: station == device.name,
                                online: device.online)
                }
                .posPress()
            }
            Spacer()
            SecondaryAction(title: "Clear bumped", glyph: "tray.and.arrow.up") {
                store.clearBumped()
            }
            .frame(width: 180)
        }
        .padding(Metric.pad)
        .background(theme.raised)
    }

    private func stationChip(_ name: String, count: Int, active: Bool, online: Bool) -> some View {
        HStack(spacing: 6) {
            if !online {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(active ? .white : Palette.stop)
            }
            Text(name).font(.system(size: 14.5, weight: active ? .semibold : .medium))
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(Capsule().fill(active ? Color.white.opacity(0.28) : theme.hairline))
            }
        }
        .padding(.horizontal, 13)
        .frame(height: 42)
        .foregroundStyle(active ? .white : theme.ink)
        .background {
            RoundedRectangle(cornerRadius: Metric.rChip, style: .continuous)
                .fill(active ? theme.accent : Color.clear)
        }
    }
}

struct TicketCard: View {
    @Environment(POSStore.self) private var store
    @Environment(\.theme) private var theme
    var ticket: KitchenTicket

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(ticket.orderLabel)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Spacer()
                Text(ticket.age)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .moneyFigure()
                    .foregroundStyle(ticket.isLate(target: 600) ? Palette.stop : theme.inkSecondary)
            }

            HStack(spacing: 4) {
                Chip(text: ticket.typeLabel, glyph: "tag.fill", small: true)
                if let t = ticket.tableLabel { Chip(text: t, glyph: "table.furniture", small: true) }
                if let c = ticket.covers { Chip(text: "\(c) cov", glyph: "person.2.fill", small: true) }
                if let b = ticket.buzzer { Chip(text: "buzz \(b)", glyph: "bell.badge", small: true) }
                if let course = ticket.courseName {
                    Chip(text: course, glyph: "list.number", tint: Palette.info, filled: true, small: true)
                }
                if ticket.isRush {
                    Chip(text: "RUSH", glyph: "flame.fill", tint: Palette.stop, filled: true, small: true)
                }
                if ticket.isVoidDocket {
                    Chip(text: "VOID", glyph: "xmark", tint: Palette.stop, filled: true, small: true)
                }
                if ticket.isAddition {
                    Chip(text: "ADDITION", glyph: "plus", tint: Palette.warn, filled: true, small: true)
                }
                if ticket.channel != .pos {
                    Chip(text: ticket.channel.label, small: true)
                }
            }

            if ticket.lines.isEmpty {
                Text(ticket.isVoidDocket ? "Cancelled" : "Course call — get ready")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ticket.isVoidDocket ? Palette.stop : Palette.info)
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(ticket.lines) { line in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(line.quantity)")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.accent)
                            Text(line.name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(theme.ink)
                                .strikethrough(line.isReady, color: theme.inkSecondary)
                            if let seat = line.seat {
                                Chip(text: "S\(seat)", tint: theme.accent, small: true)
                            }
                        }
                        ForEach(line.portionBlocks) { block in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(block.label)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(theme.accent)
                                ForEach(block.lines, id: \.self) { l in
                                    Text(l).font(.system(size: 13)).foregroundStyle(theme.ink)
                                }
                            }
                            .padding(.leading, 8)
                        }
                        if !line.modifiers.isEmpty {
                            Text(line.modifiers.joined(separator: " · "))
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundStyle(theme.ink)
                                .padding(.leading, 20)
                        }
                        if !line.removals.isEmpty {
                            Text(line.removals.map { $0.lowercased().hasPrefix("no ") ? $0 : "no \($0)" }
                                .joined(separator: " · "))
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Palette.stop)
                                .padding(.leading, 20)
                        }
                        if !line.allergens.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.shield.fill").font(.system(size: 10, weight: .bold))
                                Text(line.allergens.joined(separator: ", ").uppercased())
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Palette.stop))
                            .padding(.leading, 20)
                        }
                        if let n = line.note {
                            Text("“\(n)”")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Palette.warn)
                                .padding(.leading, 20)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                switch ticket.state {
                case .waiting:
                    PrimaryAction(title: "Start", glyph: "play.fill", tint: Palette.info) {
                        store.startTicket(ticket.id)
                    }
                case .started, .recalled:
                    PrimaryAction(title: "Bump", glyph: "bell.fill", tint: Palette.go) {
                        store.bumpTicket(ticket.id)
                    }
                case .ready:
                    SecondaryAction(title: "Recall", glyph: "arrow.uturn.backward") {
                        store.recallTicket(ticket.id)
                    }
                default:
                    EmptyView()
                }
                Button {
                    store.rushTicket(ticket.id)
                } label: {
                    Image(systemName: "flame")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 52, height: Metric.primaryTargetWet)
                        .foregroundStyle(ticket.isRush ? .white : Palette.fire)
                        .background {
                            RoundedRectangle(cornerRadius: Metric.rTile, style: .continuous)
                                .fill(ticket.isRush ? Palette.fire : Palette.fire.opacity(0.13))
                        }
                }
                .posPress()
            }
        }
        .padding(Metric.pad)
        .frame(minHeight: 190, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                .fill(theme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rCard, style: .continuous)
                        .strokeBorder(borderTint, lineWidth: ticket.isRush || ticket.isVoidDocket ? 2 : 0.7)
                }
        }
    }

    private var borderTint: Color {
        if ticket.isVoidDocket { return Palette.stop }
        if ticket.isRush { return Palette.fire }
        if ticket.state == .ready { return Palette.go.opacity(0.6) }
        if ticket.isLate(target: 600) { return Palette.stop.opacity(0.7) }
        return theme.hairline
    }
}
