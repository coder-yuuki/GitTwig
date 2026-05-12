import Foundation

final class RepositoryStore {
    private let defaults: UserDefaults
    private let key = "gitTwig.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key) else {
            return .default
        }

        do {
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            return normalized(settings)
        } catch {
            return .default
        }
    }

    func save(_ settings: AppSettings) {
        do {
            let data = try JSONEncoder().encode(normalized(settings))
            defaults.set(data, forKey: key)
        } catch {
            assertionFailure("Failed to encode settings: \(error)")
        }
    }

    private func normalized(_ settings: AppSettings) -> AppSettings {
        var copy = settings
        copy.commitLimit = min(max(copy.commitLimit, 5), 200)

        if let selectedRepositoryID = copy.selectedRepositoryID,
           copy.repositories.contains(where: { $0.id == selectedRepositoryID }) {
            return copy
        }

        copy.selectedRepositoryID = copy.repositories.first?.id
        return copy
    }
}
