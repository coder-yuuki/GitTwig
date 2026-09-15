import XCTest
@testable import GitTwig

final class RepositoryPanelLocationTests: XCTestCase {
    func testMissingDirectoryFallsBackToExistingParent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        XCTAssertEqual(
            RepositoryPanelLocation.existingDirectory(startingAt: root.appendingPathComponent("missing/repo")),
            root.standardizedFileURL
        )
    }

    func testRootStartsAtHome() {
        XCTAssertEqual(
            RepositoryPanelLocation.existingDirectory(startingAt: URL(fileURLWithPath: "/")),
            FileManager.default.homeDirectoryForCurrentUser
        )
    }

    func testPanelCenteredOnSecondaryScreen() {
        let origin = RepositoryPanelLocation.centeredOrigin(
            panelSize: NSSize(width: 760, height: 500),
            visibleFrame: NSRect(x: -1920, y: 80, width: 1920, height: 1000)
        )
        XCTAssertEqual(origin, NSPoint(x: -1340, y: 330))
    }
}
