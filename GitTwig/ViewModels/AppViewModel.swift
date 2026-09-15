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

    @Published var syncAction: SyncAction?
    @Published var syncMessage: String?
    @Published var syncFailed = false

    func synchronize(_ action: SyncAction, target: SyncTarget, repository: Repository) async {
        guard syncAction == nil else { return }
        syncAction = action
        syncMessage = nil
        syncFailed = false
        do {
            try await gitService.synchronize(action, repository: repository, expected: target)
            syncMessage = "\(repository.displayName): \(action.rawValue) completed."
        } catch {
            syncFailed = true
            syncMessage = error.localizedDescription
        }
        await refreshSelectedRepository()
        syncAction = nil
    }

    func syncTarget() async throws -> SyncTarget {
        guard let repository = selectedRepository else { throw SyncError(message: "Select a repository.") }
        return try await gitService.target(for: repository)
    }


    @Published var historyQuery = ""
    @Published var historySearchField: HistorySearchField = .message
    @Published var historyLoading = false
    @Published var historyHasMore = false
    @Published var historyError: String?
    @Published var historyIdentity = UUID()
    private var historyGeneration = UUID()
    private var historyRevisions: [String]?
    private var historyRows: [GitGraphRow] = []

    func resetHistory() async {
        historyGeneration = UUID()
        historyIdentity = UUID()
        historyLoading = false
        historyHasMore = true
        historyError = nil
        historyRevisions = nil
        historyRows = []
        currentSnapshot?.graphRows = []
        currentSnapshot?.graphEdges = []
        currentSnapshot?.graphText = "Searching history…"
        await loadMoreHistory()
    }

    func loadMoreHistory() async {
        guard !historyLoading, historyHasMore, let repository = selectedRepository,
              currentSnapshot?.repositoryID == repository.id else { return }
        let generation = historyGeneration
        historyLoading = true
        historyError = nil
        let query = historyQuery
        let field = historySearchField
        do {
            let page = try await gitService.history(for: repository, revisions: historyRevisions,
                offset: historyRows.count, limit: commitLimit, query: query, field: field)
            guard generation == historyGeneration, selectedRepositoryID == repository.id,
                  query == historyQuery, field == historySearchField else { return }
            historyRevisions = page.revisions
            var known = Set(historyRows.map(\.fullHash))
            historyRows += page.rows.filter { known.insert($0.fullHash).inserted }
            let layout = gitService.arrangeHistory(historyRows, filtered: !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            currentSnapshot?.graphRows = layout.rows
            currentSnapshot?.graphEdges = layout.edges
            currentSnapshot?.graphText = query.isEmpty ? "No commits yet." : "No matching commits."
            historyHasMore = page.hasMore
        } catch {
            guard generation == historyGeneration, selectedRepositoryID == repository.id else { return }
            historyError = error.localizedDescription
        }
        if generation == historyGeneration { historyLoading = false }
    }

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

    func menuBarTitle(maxLength: Int = 24) -> String {
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
        let visibleStatus = status == "\u{2713}" ? "" : status
        let suffix = visibleStatus.isEmpty ? "" : " \(visibleStatus)"
        let titleBudget = max(maxLength - "\u{2442} ".count - suffix.count, 8)
        let splitBudget = max(titleBudget - 1, 7)
        let nameBudget = max(4, splitBudget / 2)
        let branchBudget = max(3, splitBudget - nameBudget)
        let compactTitle = "\(name.gitTwigTruncated(to: nameBudget)):\(branch.gitTwigTruncated(to: branchBudget))"

        return "\u{2442} \(compactTitle)\(suffix)".gitTwigTruncated(to: maxLength)
    }

    func summary(for repository: Repository) -> RepositorySummary? {
        summariesByRepositoryID[repository.id]
    }

    private var activeRepositoryPanel: NSOpenPanel?
    private let lastRepositoryDirectoryKey = "lastRepositoryDirectory"

    func addRepository() {
        let rememberedPath = UserDefaults.standard.string(forKey: lastRepositoryDirectoryKey)
        let preferredURL = rememberedPath.map { URL(fileURLWithPath: $0) }
            ?? selectedRepository.map { URL(fileURLWithPath: $0.path).deletingLastPathComponent() }
            ?? FileManager.default.homeDirectoryForCurrentUser
        presentRepositoryPanel(
            title: "Add Repository",
            message: "Choose a Git repository folder. Use ⇧⌘G to enter a path.",
            prompt: "Add",
            directoryURL: preferredURL
        ) { [weak self] url in
            Task { await self?.addRepository(at: url) }
        }
    }

    func chooseAgain(for repository: Repository) {
        presentRepositoryPanel(
            title: "Choose Repository Again",
            message: "Choose the Git repository folder for \(repository.displayName).",
            prompt: "Choose",
            directoryURL: URL(fileURLWithPath: repository.path)
        ) { [weak self] url in
            Task { await self?.updateRepository(repository, to: url) }
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
        historyGeneration = UUID()
        historyLoading = false
        selectedRepositoryID = repository.id
        currentSnapshot = nil
        saveSettings()

        Task {
            await refreshSelectedRepository()
        }
    }

    private var refreshGeneration = UUID()

    func refreshSelectedRepository() async {
        let refresh = UUID()
        refreshGeneration = refresh
        historyGeneration = UUID()
        historyLoading = false
        guard let repository = selectedRepository else {
            currentSnapshot = nil
            isLoading = false
            return
        }

        let repositoryID = repository.id
        isLoading = true
        errorMessage = nil

        let snapshot = await gitService.snapshot(for: repository, commitLimit: commitLimit)
        guard refresh == refreshGeneration, selectedRepositoryID == repositoryID else { return }
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
        await resetHistory()
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

    func openInFinder(_ repository: Repository) {
        let url = existingFinderURL(for: repository.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func presentRepositoryPanel(
        title: String,
        message: String,
        prompt: String,
        directoryURL: URL,
        onSelection: @escaping (URL) -> Void
    ) {
        if let panel = activeRepositoryPanel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSApplication.shared.keyWindow?.screen
            ?? NSScreen.main
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.resolvesAliases = true
        panel.directoryURL = RepositoryPanelLocation.existingDirectory(startingAt: directoryURL)
        panel.setContentSize(NSSize(width: 760, height: 500))
        if let screen {
            panel.setFrameOrigin(RepositoryPanelLocation.centeredOrigin(
                panelSize: panel.frame.size, visibleFrame: screen.visibleFrame
            ))
        }
        activeRepositoryPanel = panel
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard let self else { return }
            self.activeRepositoryPanel = nil
            guard response == .OK, let url = panel.url else { return }
            UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: self.lastRepositoryDirectoryKey)
            onSelection(url)
        }
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

    private func updateRepository(_ repository: Repository, to url: URL) async {
        isLoading = true
        errorMessage = nil

        do {
            let oldPath = repository.path
            let topLevelPath = try await gitService.topLevelPath(for: url.path)

            if let existing = repositories.first(where: { $0.id != repository.id && $0.path == topLevelPath }) {
                selectRepository(existing)
                errorMessage = "That repository is already registered."
                isLoading = false
                return
            }

            guard let index = repositories.firstIndex(where: { $0.id == repository.id }) else {
                isLoading = false
                return
            }

            let topLevelURL = URL(fileURLWithPath: topLevelPath)
            let bookmarkData = try? topLevelURL.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let oldDefaultName = PathDisplayName.name(for: oldPath)
            if repositories[index].displayName == oldDefaultName {
                repositories[index].displayName = PathDisplayName.name(for: topLevelPath)
            }
            repositories[index].path = topLevelPath
            repositories[index].bookmarkData = bookmarkData
            selectedRepositoryID = repositories[index].id
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

    private func existingFinderURL(for path: String) -> URL {
        var url = URL(fileURLWithPath: path)
        var isDirectory: ObjCBool = false

        while !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            let parent = url.deletingLastPathComponent()
            if parent.path == url.path {
                return URL(fileURLWithPath: "/")
            }
            url = parent
        }

        return url
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
