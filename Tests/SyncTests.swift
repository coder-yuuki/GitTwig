import XCTest
@testable import GitTwig

final class SyncTests: XCTestCase {
    func testPorcelainPaths() {
        let files = ChangedFile.parse(" M space name.txt\0R  new\nname\0old name\0?? fresh\0UU conflict\0")
        XCTAssertEqual(files.map(\.path), ["space name.txt", "new\nname", "fresh", "conflict"])
        XCTAssertEqual(files.map(\.status), [" M", "R ", "??", "UU"])
    }

    func testLocalRemoteSyncAndGuards() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let runner = GitCommandRunner()
        func git(_ path: String, _ args: [String]) async throws {
            _ = try await runner.runGit(arguments: ["-C", path] + args)
        }
        let remote = root.appendingPathComponent("remote.git").path
        let local = root.appendingPathComponent("local").path
        let other = root.appendingPathComponent("other").path
        try await git(root.path, ["init", "--bare", remote])
        try await git(root.path, ["clone", remote, local])
        try await git(local, ["checkout", "-b", "main"])
        func commit(_ path: String, _ name: String) async throws {
            try name.write(toFile: path + "/" + name, atomically: true, encoding: .utf8)
            try await git(path, ["add", "."])
            try await git(path, ["-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", name])
        }
        try await commit(local, "first")
        try await git(local, ["push", "-u", "origin", "main"])
        try await git(root.path, ["clone", "-b", "main", remote, other])
        let service = GitService()
        let repository = Repository(displayName: "test", path: local)
        let target = try await service.target(for: repository)
        try await commit(other, "second")
        try await git(other, ["push"])
        try await service.synchronize(.pull, repository: repository, expected: target)
        XCTAssertTrue(FileManager.default.fileExists(atPath: local + "/second"))
        try await commit(local, "third")
        try await service.synchronize(.push, repository: repository, expected: target)
        try await service.synchronize(.fetch, repository: repository, expected: target)
        let snapshot = await service.snapshot(for: repository, commitLimit: 10)
        XCTAssertEqual(snapshot.ahead, 0)
        XCTAssertEqual(snapshot.behind, 0)
        try "dirty".write(toFile: local + "/dirty", atomically: true, encoding: .utf8)
        do {
            try await service.synchronize(.pull, repository: repository, expected: target)
            XCTFail("Dirty pull must fail")
        } catch {}
        try FileManager.default.removeItem(atPath: local + "/dirty")
        try await commit(local, "local-only")
        try await commit(other, "remote-only")
        try await git(other, ["pull", "--rebase"])
        try await git(other, ["push"])
        do {
            try await service.synchronize(.pull, repository: repository, expected: target)
            XCTFail("Divergent pull must fail")
        } catch {}
        try await git(local, ["checkout", "-b", "changed"])
        do {
            try await service.synchronize(.push, repository: repository, expected: target)
            XCTFail("Changed branch must fail")
        } catch {}
    }
}
