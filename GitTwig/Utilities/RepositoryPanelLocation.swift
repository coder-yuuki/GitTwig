import AppKit

enum RepositoryPanelLocation {
    static func existingDirectory(startingAt requested: URL) -> URL {
        var url = requested.standardizedFileURL
        while url.path != "/" {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return url
            }
            url.deleteLastPathComponent()
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static func centeredOrigin(panelSize: NSSize, visibleFrame: NSRect) -> NSPoint {
        NSPoint(
            x: visibleFrame.minX + max(0, (visibleFrame.width - panelSize.width) / 2),
            y: visibleFrame.minY + max(0, (visibleFrame.height - panelSize.height) / 2)
        )
    }
}
