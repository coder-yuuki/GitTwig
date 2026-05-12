import Foundation

final class GitService {
    private let runner: GitCommandRunner

    init(runner: GitCommandRunner = GitCommandRunner()) {
        self.runner = runner
    }

    func topLevelPath(for path: String) async throws -> String {
        let result = try await runner.runGit(
            arguments: ["-C", path, "rev-parse", "--show-toplevel"],
            timeout: 4
        )
        let topLevelPath = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if topLevelPath.isEmpty {
            throw GitCommandError.nonZeroExit(["rev-parse", "--show-toplevel"], 1, "Could not resolve repository root.")
        }
        return topLevelPath
    }

    func snapshot(for repository: Repository, commitLimit: Int) async -> RepositorySnapshot {
        await withRepositoryAccess(repository) { path in
            do {
                let branchName = try await branchName(at: path)
                let isDirty = try await isDirty(at: path)
                let divergence = await aheadBehind(at: path)
                let graph = try await graph(at: path, commitLimit: commitLimit)

                return RepositorySnapshot(
                    repositoryID: repository.id,
                    branchName: branchName,
                    isDirty: isDirty,
                    ahead: divergence.ahead,
                    behind: divergence.behind,
                    graphText: graph.text,
                    graphRows: graph.rows,
                    graphEdges: graph.edges,
                    errorMessage: nil,
                    updatedAt: Date()
                )
            } catch {
                let message = friendlyErrorMessage(error)
                return RepositorySnapshot(
                    repositoryID: repository.id,
                    branchName: "unknown",
                    isDirty: false,
                    ahead: nil,
                    behind: nil,
                    graphText: errorGraphText(path: path, reason: message),
                    graphRows: [],
                    graphEdges: [],
                    errorMessage: message,
                    updatedAt: Date()
                )
            }
        }
    }

    func summary(for repository: Repository) async -> RepositorySummary {
        await withRepositoryAccess(repository) { path in
            do {
                let branchName = try await branchName(at: path)
                let isDirty = try await isDirty(at: path)
                let divergence = await aheadBehind(at: path)

                return RepositorySummary(
                    repositoryID: repository.id,
                    branchName: branchName,
                    isDirty: isDirty,
                    ahead: divergence.ahead,
                    behind: divergence.behind,
                    errorMessage: nil,
                    updatedAt: Date()
                )
            } catch {
                return RepositorySummary(
                    repositoryID: repository.id,
                    branchName: "unknown",
                    isDirty: false,
                    ahead: nil,
                    behind: nil,
                    errorMessage: friendlyErrorMessage(error),
                    updatedAt: Date()
                )
            }
        }
    }

    private func branchName(at path: String) async throws -> String {
        let branchResult = try await runner.runGit(
            arguments: ["-C", path, "branch", "--show-current"],
            timeout: 4
        )
        let branch = branchResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !branch.isEmpty {
            return branch
        }

        do {
            let headResult = try await runner.runGit(
                arguments: ["-C", path, "rev-parse", "--short", "HEAD"],
                timeout: 4
            )
            let hash = headResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            return hash.isEmpty ? "detached" : "detached@\(hash)"
        } catch {
            return "no commits"
        }
    }

    private func isDirty(at path: String) async throws -> Bool {
        let result = try await runner.runGit(
            arguments: ["-C", path, "status", "--porcelain"],
            timeout: 4
        )
        return !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func aheadBehind(at path: String) async -> (ahead: Int?, behind: Int?) {
        do {
            _ = try await runner.runGit(
                arguments: ["-C", path, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
                timeout: 4
            )
        } catch {
            return (nil, nil)
        }

        do {
            let result = try await runner.runGit(
                arguments: ["-C", path, "rev-list", "--left-right", "--count", "HEAD...@{u}"],
                timeout: 4
            )
            let parts = result.stdout
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(whereSeparator: { $0 == " " || $0 == "\t" })
                .compactMap { Int($0) }
            guard parts.count == 2 else {
                return (nil, nil)
            }
            return (parts[0], parts[1])
        } catch {
            return (nil, nil)
        }
    }

    private func graph(at path: String, commitLimit: Int) async throws -> (text: String, rows: [GitGraphRow], edges: [GitGraphEdge]) {
        do {
            let result = try await runner.runGit(
                arguments: [
                    "-C", path,
                    "log",
                    "--all",
                    "HEAD",
                    "--topo-order",
                    "--date=relative",
                    "--pretty=format:%H%x1f%h%x1f%D%x1f%s%x1f%an%x1f%cr%x1f%P",
                    "-n", "\(commitLimit)",
                    "--color=never"
                ],
                timeout: 8
            )
            let output = result.stdout.trimmingCharacters(in: .newlines)
            let graphRows = parseGraphRows(from: output)
            if output.isEmpty || graphRows.isEmpty {
                return ("No commits yet.", [], [])
            }
            let layout = layoutGraphRows(graphRows)
            let fallbackText = layout.rows.map { "\($0.shortHash) \($0.subject)" }.joined(separator: "\n")
            return (fallbackText, layout.rows, layout.edges)
        } catch let error as GitCommandError {
            if case let .nonZeroExit(_, _, stderr) = error,
               stderr.localizedCaseInsensitiveContains("does not have any commits") ||
                stderr.localizedCaseInsensitiveContains("your current branch") {
                return ("No commits yet.", [], [])
            }
            throw error
        }
    }

    private func parseGraphRows(from output: String) -> [GitGraphRow] {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .compactMap { offset, line -> GitGraphRow? in
                let fields = line.split(separator: "\u{1f}", omittingEmptySubsequences: false)
                guard fields.count >= 7 else {
                    return nil
                }

                let fullHash = String(fields[0])
                let shortHash = String(fields[1])
                let decorations = decorations(from: String(fields[2]))
                let subject = String(fields[3])
                let authorName = String(fields[4])
                let relativeDate = String(fields[5])
                let parents = String(fields[6])
                    .split(separator: " ")
                    .map(String.init)

                return GitGraphRow(
                    rowIndex: offset,
                    fullHash: fullHash,
                    shortHash: shortHash,
                    subject: subject,
                    authorName: authorName,
                    relativeDate: relativeDate,
                    parents: parents,
                    decorations: decorations,
                    column: 0,
                    colorIndex: 0
                )
            }
    }

    private func layoutGraphRows(_ inputRows: [GitGraphRow]) -> (rows: [GitGraphRow], edges: [GitGraphEdge]) {
        guard !inputRows.isEmpty else {
            return ([], [])
        }

        var rows = inputRows
        let hashToRow = Dictionary(uniqueKeysWithValues: rows.map { ($0.fullHash, $0.rowIndex) })
        let rowByHash = Dictionary(uniqueKeysWithValues: rows.map { ($0.fullHash, $0) })
        let mainLine = mainLineHashes(in: rows, rowByHash: rowByHash)

        var lanes: [String?] = []
        var laneTokens: [Int?] = []
        var nextToken = 1
        var hashToColumn: [String: Int] = [:]
        var hashToColorIndex: [String: Int] = [:]

        for index in rows.indices {
            let commit = rows[index]
            let isMainCommit = mainLine.contains(commit.fullHash)
            let existingIndex = lanes.firstIndex { $0 == commit.fullHash }
            let column: Int

            if isMainCommit {
                if existingIndex == 0 {
                    column = 0
                } else if let existingIndex {
                    let laneHash = lanes.remove(at: existingIndex)
                    _ = laneTokens.remove(at: existingIndex)
                    lanes.insert(laneHash, at: 0)
                    laneTokens.insert(0, at: 0)
                    column = 0
                } else if lanes.first ?? nil == nil {
                    if lanes.isEmpty {
                        lanes.append(nil)
                        laneTokens.append(nil)
                    }
                    lanes[0] = commit.fullHash
                    laneTokens[0] = 0
                    column = 0
                } else {
                    lanes.insert(commit.fullHash, at: 0)
                    laneTokens.insert(0, at: 0)
                    column = 0
                }
            } else if let existingIndex {
                column = existingIndex
            } else if let freeIndex = lanes.firstIndex(where: { $0 == nil }) {
                lanes[freeIndex] = commit.fullHash
                if laneTokens[freeIndex] == nil {
                    laneTokens[freeIndex] = nextToken
                    nextToken += 1
                }
                column = freeIndex
            } else {
                lanes.append(commit.fullHash)
                laneTokens.append(nextToken)
                nextToken += 1
                column = lanes.count - 1
            }

            if isMainCommit {
                laneTokens[column] = 0
            } else if laneTokens[column] == nil {
                laneTokens[column] = nextToken
                nextToken += 1
            }

            let token = laneTokens[column] ?? 0
            rows[index].column = column
            rows[index].colorIndex = token
            hashToColumn[commit.fullHash] = column
            hashToColorIndex[commit.fullHash] = token

            if commit.parents.isEmpty {
                lanes[column] = nil
                laneTokens[column] = nil
                continue
            }

            var currentColumn = column
            lanes[currentColumn] = commit.parents[0]

            for parentHash in commit.parents.dropFirst() {
                if lanes.contains(parentHash) {
                    continue
                }

                let parentIsMain = mainLine.contains(parentHash)
                let insertAt = parentIsMain ? 0 : currentColumn + 1
                let token = parentIsMain ? 0 : nextToken
                if !parentIsMain {
                    nextToken += 1
                }

                lanes.insert(parentHash, at: min(insertAt, lanes.count))
                laneTokens.insert(token, at: min(insertAt, laneTokens.count))
                if insertAt <= currentColumn {
                    currentColumn += 1
                }
            }
        }

        var edges: [GitGraphEdge] = []
        for commit in rows {
            let fromColumn = hashToColumn[commit.fullHash] ?? 0
            let fromColorIndex = hashToColorIndex[commit.fullHash] ?? 0
            let fromRow = hashToRow[commit.fullHash] ?? commit.rowIndex

            for (parentIndex, parentHash) in commit.parents.enumerated() {
                guard let parentRow = hashToRow[parentHash] else {
                    continue
                }

                let toColumn = hashToColumn[parentHash] ?? fromColumn
                let edgeType: GitGraphEdge.EdgeType
                if fromColumn == toColumn {
                    edgeType = .linear
                } else if parentIndex == 0 {
                    edgeType = .branch
                } else {
                    edgeType = .merge
                }

                edges.append(
                    GitGraphEdge(
                        fromHash: commit.fullHash,
                        toHash: parentHash,
                        fromColumn: fromColumn,
                        toColumn: toColumn,
                        fromRow: fromRow,
                        toRow: parentRow,
                        colorIndex: parentIndex == 0 ? fromColorIndex : (hashToColorIndex[parentHash] ?? fromColorIndex),
                        edgeType: edgeType
                    )
                )
            }
        }

        return (rows, edges)
    }

    private func mainLineHashes(in rows: [GitGraphRow], rowByHash: [String: GitGraphRow]) -> Set<String> {
        var hashes: Set<String> = []
        var current: GitGraphRow? = rows.first
        while let commit = current {
            hashes.insert(commit.fullHash)
            guard let firstParent = commit.parents.first else {
                break
            }
            current = rowByHash[firstParent]
        }
        return hashes
    }

    private func decorations(from rawDecorations: String) -> [GitDecoration] {
        rawDecorations
            .split(separator: ",")
            .flatMap { rawPart -> [GitDecoration] in
                let part = rawPart.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !part.isEmpty else {
                    return []
                }

                if part.hasPrefix("HEAD -> ") {
                    let branch = String(part.dropFirst("HEAD -> ".count))
                    return [
                        GitDecoration(text: "HEAD", kind: .head),
                        decoration(for: branch)
                    ]
                }

                if part == "HEAD" {
                    return [GitDecoration(text: "HEAD", kind: .head)]
                }

                if part.hasPrefix("tag: ") {
                    return [GitDecoration(text: String(part.dropFirst("tag: ".count)), kind: .tag)]
                }

                if let arrowRange = part.range(of: " -> ") {
                    let target = String(part[arrowRange.upperBound...])
                    return [decoration(for: target)]
                }

                return [decoration(for: part)]
            }
    }

    private func decoration(for text: String) -> GitDecoration {
        if text.contains("/") {
            return GitDecoration(text: text, kind: .remoteBranch)
        }
        return GitDecoration(text: text, kind: .localBranch)
    }

    private func withRepositoryAccess<T>(
        _ repository: Repository,
        operation: (String) async -> T
    ) async -> T {
        var didStartAccess = false
        var resolvedURL: URL?

        if let bookmarkData = repository.bookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                resolvedURL = url
                didStartAccess = url.startAccessingSecurityScopedResource()
            }
        }

        let path = resolvedURL?.path ?? repository.path
        let result = await operation(path)

        if didStartAccess {
            resolvedURL?.stopAccessingSecurityScopedResource()
        }

        return result
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return error.localizedDescription
    }

    private func errorGraphText(path: String, reason: String) -> String {
        """
        Could not read repository.

        \(path)

        Reason:
        \(reason)
        """
    }
}
