import SwiftUI

struct GitGraphView: View {
    var snapshot: RepositorySnapshot?
    var isLoading: Bool
    var repository: Repository?
    var onRefresh: () -> Void
    var onChooseAgain: (Repository) -> Void
    var onOpenInFinder: (Repository) -> Void
    var onRemove: (Repository) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if let snapshot {
                if snapshot.errorMessage != nil {
                    repositoryErrorView(snapshot: snapshot)
                } else if snapshot.graphRows.isEmpty {
                    ScrollView(.vertical) {
                        Text(snapshot.graphText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                } else {
                    let edgesByRow = edgesByRow(for: snapshot)
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(snapshot.graphRows) { row in
                                GitGraphRowView(
                                    row: row,
                                    visibleLaneCount: visibleLaneCount(for: snapshot),
                                    edges: edgesByRow[row.rowIndex] ?? []
                                )
                            }
                        }
                    }
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("No repository selected.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if isLoading, snapshot != nil {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func repositoryErrorView(snapshot: RepositorySnapshot) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                Text(snapshot.graphText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let repository {
                    HStack(spacing: 8) {
                        Button {
                            onRefresh()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }

                        Button {
                            onChooseAgain(repository)
                        } label: {
                            Label("Choose Again", systemImage: "folder")
                        }

                        Button {
                            onOpenInFinder(repository)
                        } label: {
                            Label("Finder", systemImage: "finder")
                        }

                        Spacer()

                        Button(role: .destructive) {
                            onRemove(repository)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func visibleLaneCount(for snapshot: RepositorySnapshot) -> Int {
        let rowMax = snapshot.graphRows.map(\.column).max() ?? 0
        let edgeMax = snapshot.graphEdges.flatMap { [$0.fromColumn, $0.toColumn] }.max() ?? 0
        let laneCount = max(rowMax, edgeMax) + 1
        return min(max(laneCount, 1), 5)
    }

    private func edgesByRow(for snapshot: RepositorySnapshot) -> [Int: [GitGraphEdge]] {
        var result: [Int: [GitGraphEdge]] = [:]
        for edge in snapshot.graphEdges where edge.toRow >= edge.fromRow {
            for rowIndex in edge.fromRow...edge.toRow {
                result[rowIndex, default: []].append(edge)
            }
        }
        return result
    }
}

private struct GitGraphRowView: View {
    var row: GitGraphRow
    var visibleLaneCount: Int
    var edges: [GitGraphEdge]

    private var rowHeight: CGFloat {
        row.decorations.isEmpty ? 48 : 66
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            GitGraphLinesView(
                row: row,
                visibleLaneCount: visibleLaneCount,
                edges: edges
            )
                .frame(width: graphWidth, height: rowHeight)

            Text(row.shortHash)
                .font(.system(.subheadline, design: .monospaced).weight(row.isHead ? .bold : .medium))
                .foregroundColor(row.isHead ? .accentColor : .secondary)
                .lineLimit(1)
                .frame(width: 62, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                if !row.decorations.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(row.decorations) { decoration in
                                GitDecorationPill(decoration: decoration)
                            }
                        }
                    }
                    .frame(height: 24)
                }

                Text(row.subject)
                    .font(.subheadline.weight(row.isHead ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.relativeDate.gitTwigShortRelativeDate)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: rowHeight)
        .background(row.isHead ? Color.accentColor.opacity(0.10) : Color.clear)
        .overlay(alignment: .bottom) {
            Color(nsColor: .separatorColor)
                .opacity(0.15)
                .frame(height: 1)
        }
        .help("\(row.shortHash) \(row.subject)\n\(row.authorName) · \(row.relativeDate)")
    }

    private var graphWidth: CGFloat {
        CGFloat(visibleLaneCount - 1) * 17 + 26
    }
}

private struct GitGraphLinesView: View {
    var row: GitGraphRow
    var visibleLaneCount: Int
    var edges: [GitGraphEdge]

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2
            drawEdges(in: &context, size: size, midY: midY)
            drawCommitCircle(in: &context, size: size, midY: midY)
        }
    }

    private func drawEdges(in context: inout GraphicsContext, size: CGSize, midY: CGFloat) {
        for edge in edges {
            let fromX = xPosition(for: clamped(edge.fromColumn))
            let toX = xPosition(for: clamped(edge.toColumn))
            let color = laneColor(for: edge.colorIndex)
            let lineWidth: CGFloat = 2.4

            if edge.fromRow == row.rowIndex {
                var path = Path()
                switch edge.edgeType {
                case .linear:
                    path.move(to: CGPoint(x: fromX, y: midY))
                    path.addLine(to: CGPoint(x: fromX, y: size.height))
                case .branch:
                    path.move(to: CGPoint(x: fromX, y: midY))
                    path.addLine(to: CGPoint(x: fromX, y: size.height))
                case .merge:
                    path.move(to: CGPoint(x: fromX, y: midY))
                    path.addCurve(
                        to: CGPoint(x: toX, y: size.height),
                        control1: CGPoint(x: fromX, y: midY),
                        control2: CGPoint(x: toX, y: midY)
                    )
                }
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            } else if edge.toRow == row.rowIndex {
                var path = Path()
                switch edge.edgeType {
                case .linear, .merge:
                    path.move(to: CGPoint(x: toX, y: 0))
                    path.addLine(to: CGPoint(x: toX, y: midY))
                case .branch:
                    path.move(to: CGPoint(x: fromX, y: 0))
                    path.addCurve(
                        to: CGPoint(x: toX, y: midY),
                        control1: CGPoint(x: fromX, y: midY),
                        control2: CGPoint(x: toX, y: midY)
                    )
                }
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            } else if row.rowIndex > edge.fromRow && row.rowIndex < edge.toRow {
                var path = Path()
                let x = edge.edgeType == .merge ? toX : fromX
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(color), lineWidth: lineWidth)
            }
        }
    }

    private func drawCommitCircle(in context: inout GraphicsContext, size: CGSize, midY: CGFloat) {
        let lane = clamped(row.column)
        let radius: CGFloat = row.isHead ? 5.5 : 5
        let center = CGPoint(x: xPosition(for: lane), y: midY)
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let circle = Path(ellipseIn: rect)
        context.fill(circle, with: .color(laneColor(for: row.colorIndex)))
        context.stroke(circle, with: .color(Color(nsColor: .textBackgroundColor)), lineWidth: 1.5)
    }

    private func xPosition(for lane: Int) -> CGFloat {
        13 + CGFloat(lane) * 17
    }

    private func clamped(_ lane: Int) -> Int {
        min(max(lane, 0), max(visibleLaneCount - 1, 0))
    }

    private func laneColor(for lane: Int) -> Color {
        let colors: [Color] = [
            Color(red: 0.33, green: 0.62, blue: 1.0),
            Color(red: 0.66, green: 0.41, blue: 1.0),
            Color(red: 0.24, green: 0.78, blue: 0.34),
            Color(red: 1.0, green: 0.61, blue: 0.22),
            Color(red: 0.97, green: 0.36, blue: 0.55)
        ]
        return colors[lane % colors.count]
    }
}

private struct GitDecorationPill: View {
    var decoration: GitDecoration

    var body: some View {
        Text(decoration.text)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .truncationMode(.middle)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }

    private var foregroundColor: Color {
        switch decoration.kind {
        case .head:
            return Color(red: 0.25, green: 1.0, blue: 0.47)
        case .localBranch:
            return Color(red: 1.0, green: 0.72, blue: 0.90)
        case .remoteBranch:
            return .primary
        case .tag:
            return Color(red: 1.0, green: 0.80, blue: 0.02)
        case .other:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch decoration.kind {
        case .head:
            return Color(red: 0.04, green: 0.34, blue: 0.20)
        case .localBranch:
            return Color(red: 0.42, green: 0.09, blue: 0.28)
        case .remoteBranch:
            return Color(nsColor: .controlBackgroundColor)
        case .tag:
            return Color(red: 0.38, green: 0.26, blue: 0.03)
        case .other:
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var borderColor: Color {
        switch decoration.kind {
        case .remoteBranch, .other:
            return Color(nsColor: .separatorColor)
        default:
            return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch decoration.kind {
        case .remoteBranch, .other:
            return 1
        default:
            return 0
        }
    }
}

private extension String {
    var gitTwigShortRelativeDate: String {
        replacingOccurrences(of: " seconds ago", with: "s")
            .replacingOccurrences(of: " second ago", with: "s")
            .replacingOccurrences(of: " minutes ago", with: "m")
            .replacingOccurrences(of: " minute ago", with: "m")
            .replacingOccurrences(of: " hours ago", with: "h")
            .replacingOccurrences(of: " hour ago", with: "h")
            .replacingOccurrences(of: " days ago", with: "d")
            .replacingOccurrences(of: " day ago", with: "d")
            .replacingOccurrences(of: " weeks ago", with: "w")
            .replacingOccurrences(of: " week ago", with: "w")
            .replacingOccurrences(of: " months ago", with: "mo")
            .replacingOccurrences(of: " month ago", with: "mo")
            .replacingOccurrences(of: " years ago", with: "y")
            .replacingOccurrences(of: " year ago", with: "y")
            .replacingOccurrences(of: " ago", with: "")
    }
}
