import Foundation

struct Repository: Identifiable, Codable, Equatable {
    var id: UUID
    var displayName: String
    var path: String
    var createdAt: Date
    var bookmarkData: Data?

    init(
        id: UUID = UUID(),
        displayName: String,
        path: String,
        createdAt: Date = Date(),
        bookmarkData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.path = path
        self.createdAt = createdAt
        self.bookmarkData = bookmarkData
    }
}
