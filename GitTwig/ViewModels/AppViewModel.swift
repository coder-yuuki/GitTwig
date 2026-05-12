import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    @Published var repositories: [Repository]
    @Published var selectedRepositoryID: UUID?
    @Published var currentSnapshot: RepositorySnapshot?
    @Published var summariesByRepositoryID: [UUID: RepositorySummary]
    @Published var isLoading: Bool
    @Published var errorMessage: String?
    @Published var isShowingSettings: Bool
    @Published var commitLimit: Int

    private let store: RepositoryStore
    private let gitService: GitService

    init(
        store: RepositoryStore = RepositoryStore(),
        gitService: GitService = GitService()
    ) {
        self.store = store
        self.gitService = gitService

        let settings = store.load()
        self.repositories = settings.repositories
        self.selectedRepositoryID = settings.selectedRepositoryID
        self.commitLimit = settings.commitLimit
        self.currentSnapshot = nil
        self.summariesByRepositoryID = [:]
        self.isLoading = false
        self.errorMessage = nil
        self.isShowingSettings = false

        Task {
            await refreshSelectedRepository()
            await refreshAllRepositorySummaries()
        }
    }

    var selectedRepository: Repository? {
        guard let selectedRepositoryID else {
            return nil
        }
        return repositories.first { $0.id == selectedRepositoryID }
    }

    func menuBarTitle(maxLength: Int = 34) -> String {
        guard let repository = selectedRepository else {
            return "\u{2442} GitTwig"
        }

        let name = repository.displayName
        let branch = currentSnapshot?.branchName
            ?? summariesByRepositoryID[repository.id]?.branchName
            ?? "..."
        let status = currentSnapshot?.statusText
            ?? summariesByRepositoryID[repository.id]?.statusText
            ?? ""
        let rawTitle = "\u{2442} \(name) / \(branch) \(status)"
        return rawTitle.gitTwigTruncated(to: maxLength)
    }

    func summary(for repository: Repository) -> RepositorySummary? {
        summariesByRepositoryID[repository.id]
    }

    func addRepository() {
        let panel = NSOpenPanel()
        panel.title = "Add Repository"
        panel.message = "Choose a Git repository folder."
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.directoryURL = URL(fileURLWithPath: "/")
        panel.level = .floating

        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.orderFrontRegardless()

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        Task {
            await addRepository(at: url)
        }
    }

    func removeRepository(_ repository: Repository) {
        repositories.removeAll { $0.id == repository.id }
        summariesByRepositoryID[repository.id] = nil

        if selectedRepositoryID == repository.id {
            selectedRepositoryID = repositories.first?.id
            currentSnapshot = nil
        }

        saveSettings()

        Task {
            await refreshSelectedRepository()
            await refreshAllRepositorySummaries()
        }
    }

    func selectRepository(_ repository: Repository) {
        selectedRepositoryID = repository.id
        currentSnapshot = nil
        saveSettings()

        Task {
            await refreshSelectedRepository()
        }
    }

    func refreshSelectedRepository() async {
        guard let repository = selectedRepository else {
            currentSnapshot = nil
            isLoading = false
            return
        }

        let repositoryID = repository.id
        isLoading = true
        errorMessage = nil

        let snapshot = await gitService.snapshot(for: repository, commitLimit: commitLimit)
        summariesByRepositoryID[repositoryID] = RepositorySummary(
            repositoryID: snapshot.repositoryID,
            branchName: snapshot.branchName,
            isDirty: snapshot.isDirty,
            ahead: snapshot.ahead,
            behind: snapshot.behind,
            errorMessage: snapshot.errorMessage,
            updatedAt: snapshot.updatedAt
        )

        if selectedRepositoryID == repositoryID {
            currentSnapshot = snapshot
        }

        isLoading = false
    }

    func refreshAllRepositorySummaries() async {
        let repositories = repositories
        for repository in repositories {
            let summary = await gitService.summary(for: repository)
            summariesByRepositoryID[repository.id] = summary
        }
    }

    func refreshAll() async {
        await refreshSelectedRepository()
        await refreshAllRepositorySummaries()
    }

    func renameRepository(_ repository: Repository, displayName: String) {
        guard let index = repositories.firstIndex(where: { $0.id == repository.id }) else {
            return
        }

        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        repositories[index].displayName = trimmedName.isEmpty
            ? PathDisplayName.name(for: repositories[index].path)
            : trimmedName
        saveSettings()
    }

    func moveRepositories(from source: IndexSet, to destination: Int) {
        repositories.move(fromOffsets: source, toOffset: destination)
        saveSettings()
    }

    func moveRepository(_ repository: Repository, direction: Int) {
        guard let index = repositories.firstIndex(where: { $0.id == repository.id }) else {
            return
        }

        let targetIndex = index + direction
        guard repositories.indices.contains(targetIndex) else {
            return
        }

        repositories.swapAt(index, targetIndex)
        saveSettings()
    }

    func updateCommitLimit(_ newValue: Int) {
        commitLimit = min(max(newValue, 5), 200)
        saveSettings()

        Task {
            await refreshSelectedRepository()
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func addRepository(at url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            let topLevelPath = try await gitService.topLevelPath(for: url.path)
            let topLevelURL = URL(fileURLWithPath: topLevelPath)

            if let existing = repositories.first(where: { $0.path == topLevelPath }) {
                selectRepository(existing)
                isLoading = false
                return
            }

            let bookmarkData = try? topLevelURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let repository = Repository(
                displayName: PathDisplayName.name(for: topLevelPath),
                path: topLevelPath,
                bookmarkData: bookmarkData
            )

            repositories.append(repository)
            selectedRepositoryID = repository.id
            currentSnapshot = nil
            saveSettings()

            await refreshSelectedRepository()
            await refreshAllRepositorySummaries()
        } catch {
            errorMessage = "Selected folder is not a Git repository.\n\n\(error.localizedDescription)"
        }

        isLoading = false
    }

    private func saveSettings() {
        store.save(
            AppSettings(
                repositories: repositories,
                selectedRepositoryID: selectedRepositoryID,
                commitLimit: commitLimit
            )
        )
    }
}

private extension String {
    func gitTwigTruncated(to maxLength: Int) -> String {
        guard count > maxLength, maxLength > 1 else {
            return self
        }
        let endIndex = index(startIndex, offsetBy: maxLength - 1)
        return String(self[..<endIndex]) + "\u{2026}"
    }
}
