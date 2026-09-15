import SwiftUI

struct GitGraphView: View {
    var snapshot: RepositorySnapshot?
    var isLoading: Bool
    var repository: Repository?
    var onRefresh: () -> Void
    var onChooseAgain: (Repository) -> Void
    var onOpenInFinder: (Repository) -> Void
    var onRemove: (Repository) -> Void

    var hasMore = false
    var loadingMore = false
    var historyError: String?
    var onLoadMore: () -> Void = {}

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(nsColor: .textBackgroundColor)

            if let snapshot {
                if snapshot.errorMessage != nil {
                    repositoryErrorView(snapshot: snapshot)
                } else if snapshot.graphRows.isEmpty {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(snapshot.graphText)
                            if loadingMore || historyError != nil { historyFooter }
                        }
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                } else {
                    let edgesByRow = edgesByRow(for: snapshot)
                    let laneCount = visibleLaneCount(for: snapshot)
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(snapshot.graphRows) { row in
                                GitGraphRowView(
                                    row: row,
                                    visibleLaneCount: laneCount,
                                    edges: edgesByRow[row.rowIndex] ?? []
                                )
                                .equatable()
                            }
                            if hasMore || historyError != nil {
                                historyFooter
                                    .id(snapshot.graphRows.count)
                                    .onAppear {
                                        if historyError == nil { onLoadMore() }
                                    }
                            } else {
                                Text("End of history")
                                    .font(.caption).foregroundStyle(.secondary).padding(12)
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

    private var historyFooter: some View {
        VStack(spacing: 8) {
            if let historyError {
                Text(historyError).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                Button("Retry", action: onLoadMore)
            } else if loadingMore {
                ProgressView().controlSize(.small)
            } else {
                Button("Load more commits", action: onLoadMore)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
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

private struct GitGraphRowView: View, Equatable {
    var row: GitGraphRow
    var visibleLaneCount: Int
    var edges: [GitGraphEdge]

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                if !row.decorations.isEmpty {
                    GitDecorationFlowLayout(spacing: 6) {
                        ForEach(row.decorations) { decoration in
                            GitDecorationPill(decoration: decoration)
                                .help(decoration.text)
                        }
                    }
                }

                Text(row.subject)
                    .font(.subheadline.weight(row.isHead ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)
                Text("\(row.shortHash) · \(row.authorName)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.relativeDate.gitTwigShortRelativeDate)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 46, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.leading, graphWidth + 20)
        .padding(.trailing, 10)
        .frame(minHeight: 60)
        .overlay(alignment: .leading) {
            GitGraphLinesView(row: row, visibleLaneCount: visibleLaneCount, edges: edges)
                .frame(width: graphWidth)
                .padding(.leading, 10)
                .allowsHitTesting(false)
        }
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

/// Wrap labels without nested scroll views or hidden branch names.
struct GitDecorationFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrangement(width: proposal.width ?? 400, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = arrangement(width: bounds.width, subviews: subviews)
        for (index, point) in layout.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: layout.sizes[index].width, height: layout.sizes[index].height)
            )
        }
    }

    private func arrangement(width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint], sizes: [CGSize]) {
        let width = max(1, width)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        for view in subviews {
            let ideal = view.sizeThatFits(.unspecified)
            let size = view.sizeThatFits(ProposedViewSize(width: min(ideal.width, width), height: nil))
            if x > 0 && x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            sizes.append(size)
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: width, height: y + lineHeight), positions, sizes)
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
            .fixedSize(horizontal: false, vertical: true)
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
        case .head: return TwigTheme.leaf
        case .localBranch: return TwigTheme.plum
        case .remoteBranch: return TwigTheme.sky
        case .tag: return TwigTheme.amber
        case .other: return .secondary
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(decoration.kind == .head ? 0.18 : 0.10)
    }

    private var borderColor: Color {
        switch decoration.kind {
        case .remoteBranch, .other:
            return foregroundColor.opacity(0.25)
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
