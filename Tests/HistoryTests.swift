import XCTest
@testable import GitTwig

final class HistoryTests: XCTestCase {
    func testPagingSearchAndStableRevisionRoots() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = GitCommandRunner()
        func git(_ args: [String]) async throws -> String {
            try await runner.runGit(arguments: ["-C", root.path] + args).stdout
        }
        _ = try await git(["init", "-b", "main"])
        for index in 0..<9 {
            _ = try await git(["-c", "user.name=History Tester", "-c", "user.email=history@example.com",
                              "commit", "--allow-empty", "-m", index == 0 ? "Old needle [literal]" : "Commit \(index)"])
        }
        let service = GitService()
        let repository = Repository(displayName: "history", path: root.path)
        let first = try await service.history(for: repository, revisions: nil, offset: 0, limit: 4, query: "", field: .message)
        XCTAssertEqual(first.rows.count, 4)
        XCTAssertTrue(first.hasMore)
        _ = try await git(["-c", "user.name=History Tester", "-c", "user.email=history@example.com",
                          "commit", "--allow-empty", "-m", "New commit during paging"])
        let second = try await service.history(for: repository, revisions: first.revisions, offset: 4, limit: 4, query: "", field: .message)
        let last = try await service.history(for: repository, revisions: first.revisions, offset: 8, limit: 4, query: "", field: .message)
        XCTAssertEqual(Set((first.rows + second.rows + last.rows).map(\.fullHash)).count, 9)
        XCTAssertEqual(last.rows.count, 1)
        XCTAssertFalse(last.hasMore)
        let match = try await service.history(for: repository, revisions: nil, offset: 0, limit: 4, query: "NEEDLE [literal]", field: .message)
        XCTAssertEqual(match.rows.count, 1)
        XCTAssertEqual(match.rows.first?.subject, "Old needle [literal]")
        let author = try await service.history(for: repository, revisions: nil, offset: 0, limit: 4, query: "history tester", field: .author)
        XCTAssertEqual(author.rows.count, 4)
        XCTAssertTrue(author.hasMore)
        let hash = try XCTUnwrap(match.rows.first?.shortHash)
        let hashMatch = try await service.history(for: repository, revisions: nil, offset: 0, limit: 4, query: hash, field: .hash)
        XCTAssertEqual(hashMatch.rows.first?.fullHash, match.rows.first?.fullHash)
        XCTAssertFalse(hashMatch.hasMore)
        let none = try await service.history(for: repository, revisions: nil, offset: 0, limit: 4, query: "no-such-message", field: .message)
        XCTAssertTrue(none.rows.isEmpty)
        XCTAssertFalse(none.hasMore)
        XCTAssertTrue(service.arrangeHistory(first.rows, filtered: true).edges.isEmpty)
    }

    func testEmptyRepository() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await GitCommandRunner().runGit(arguments: ["-C", root.path, "init"])
        let page = try await GitService().history(for: Repository(displayName: "empty", path: root.path),
            revisions: nil, offset: 0, limit: 40, query: "", field: .message)
        XCTAssertTrue(page.rows.isEmpty)
        XCTAssertFalse(page.hasMore)
    }
}
