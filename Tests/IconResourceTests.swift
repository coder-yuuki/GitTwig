import XCTest
import AppKit
@testable import GitTwig

final class IconResourceTests: XCTestCase {
    func testRelocatedAppResourcesAndMissingResource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = root.appendingPathComponent("GitTwig.app")
        let contents = app.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: String] = ["CFBundleIdentifier": "test.GitTwig", "CFBundlePackageType": "APPL", "CFBundleExecutable": "GitTwig"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        let bundle = try XCTUnwrap(Bundle(url: app))
        XCTAssertNil(TwigIconResource.url(in: bundle))
        let resources = contents.appendingPathComponent("Resources/GitTwig_GitTwig.bundle")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        // The source fixture is not used by the application resolver.
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Assets/AppIcon.png")
        let destination = resources.appendingPathComponent("AppIcon.png")
        try FileManager.default.copyItem(at: source, to: destination)
        XCTAssertEqual(TwigIconResource.url(in: bundle), destination)
        XCTAssertTrue(try XCTUnwrap(NSImage(contentsOf: destination)).isValid)
    }
}
