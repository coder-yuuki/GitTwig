import Foundation

struct AppSettings: Codable, Equatable {
    var repositories: [Repository]
    var selectedRepositoryID: UUID?
    var commitLimit: Int

    static let defaultCommitLimit = 40

    static var `default`: AppSettings {
        AppSettings(
            repositories: [],
            selectedRepositoryID: nil,
            commitLimit: defaultCommitLimit
        )
    }
}
