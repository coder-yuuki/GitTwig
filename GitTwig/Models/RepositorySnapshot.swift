import Foundation

struct RepositorySnapshot: Equatable {
    var repositoryID: UUID
    var branchName: String
    var isDirty: Bool
    var ahead: Int?
    var behind: Int?
    var graphText: String
    var graphRows: [GitGraphRow]
    var graphEdges: [GitGraphEdge]
    var errorMessage: String?
    var updatedAt: Date

    var changedFiles: [ChangedFile] = []
    var upstream: String? = nil

    var statusText: String {
        if errorMessage != nil {
            return "!"
        }

        var text = ""
        if let ahead, ahead > 0 {
            text += "\u{2191}\(ahead)"
        }
        if let behind, behind > 0 {
            text += "\u{2193}\(behind)"
        }
        if isDirty {
            text += "*"
        }

        return text.isEmpty ? "\u{2713}" : text
    }
}

struct GitGraphRow: Identifiable, Equatable {
    var id: String { fullHash }

    var rowIndex: Int
    var fullHash: String
    var shortHash: String
    var subject: String
    var authorName: String
    var relativeDate: String
    var parents: [String]
    var decorations: [GitDecoration]
    var column: Int
    var colorIndex: Int

    var isHead: Bool {
        decorations.contains { $0.kind == .head }
    }
}

struct GitGraphEdge: Identifiable, Equatable {
    enum EdgeType: Equatable {
        case linear
        case branch
        case merge
    }

    var id: String { "\(fromHash)-\(toHash)-\(fromRow)-\(toRow)" }
    var fromHash: String
    var toHash: String
    var fromColumn: Int
    var toColumn: Int
    var fromRow: Int
    var toRow: Int
    var colorIndex: Int
    var edgeType: EdgeType
}

struct GitDecoration: Identifiable, Equatable {
    enum Kind: String {
        case head
        case localBranch
        case remoteBranch
        case tag
        case other
    }

    var id: String { "\(kind.rawValue):\(text)" }
    var text: String
    var kind: Kind
}

struct RepositorySummary: Equatable {
    var repositoryID: UUID
    var branchName: String
    var isDirty: Bool
    var ahead: Int?
    var behind: Int?
    var errorMessage: String?
    var updatedAt: Date

    var statusText: String {
        if errorMessage != nil {
            return "!"
        }

        var text = ""
        if let ahead, ahead > 0 {
            text += "\u{2191}\(ahead)"
        }
        if let behind, behind > 0 {
            text += "\u{2193}\(behind)"
        }
        if isDirty {
            text += "*"
        }

        return text.isEmpty ? "\u{2713}" : text
    }
}

struct ChangedFile: Identifiable, Equatable {
    var id: String { path }
    var path: String
    var status: String

    static func parse(_ output: String) -> [ChangedFile] {
        let records = output.split(separator: "\0", omittingEmptySubsequences: true)
        var files: [ChangedFile] = []
        var index = 0
        while index < records.count {
            let record = String(records[index])
            index += 1
            guard record.count >= 4 else { continue }
            let status = String(record.prefix(2))
            files.append(ChangedFile(path: String(record.dropFirst(3)), status: status))
            if status.contains("R") || status.contains("C") { index += 1 }
        }
        return files
    }
}

enum SyncAction: String, Identifiable {
    case fetch = "Fetch", pull = "Pull", push = "Push"
    var id: String { rawValue }
}

struct SyncTarget: Equatable {
    var branch: String
    var remote: String
    var ref: String
    var label: String { "\(remote)/\(ref.replacingOccurrences(of: "refs/heads/", with: ""))" }
}

struct SyncError: LocalizedError {
    var message: String
    var errorDescription: String? { message }
}

enum HistorySearchField: String, CaseIterable {
    case message = "Message", author = "Author", hash = "Hash"
}

struct HistoryPage {
    var rows: [GitGraphRow]
    var hasMore: Bool
    var revisions: [String]
}
