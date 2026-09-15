import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isShowingSwitcher = false

    @State private var showFiles = false
    @State private var pendingAction: SyncAction?
    @State private var pendingTarget: SyncTarget?
    @State private var pendingRepository: Repository?

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isShowingSettings {
                SettingsView(viewModel: viewModel)
            } else if viewModel.repositories.isEmpty {
                EmptyStateView(viewModel: viewModel)
            } else {
                mainContent
            }
        }
        .tint(TwigTheme.leaf)
        .background(Color(nsColor: .windowBackgroundColor))
        .confirmationDialog("Push to \(pendingTarget?.label ?? "")?", isPresented: Binding(
            get: { pendingAction != nil }, set: { if !$0 { pendingAction = nil } }
        ), titleVisibility: .visible) {
            Button("Push") {
                if let target = pendingTarget, let repository = pendingRepository {
                    Task { await viewModel.synchronize(.push, target: target, repository: repository) }
                }
                pendingAction = nil
            }
            Button("Cancel", role: .cancel) { pendingAction = nil }
        } message: {
            Text("Send commits from \(pendingTarget?.branch ?? "") to its tracking branch.")
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if isShowingSwitcher {
                RepositorySwitcherView(
                    viewModel: viewModel,
                    isShowingSwitcher: $isShowingSwitcher
                )
                Divider()
            }

            statusPanel
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search commit history", text: $viewModel.historyQuery)
                    .textFieldStyle(.plain)
                if !viewModel.historyQuery.isEmpty {
                    Button { viewModel.historyQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }.buttonStyle(.plain).help("Clear search")
                }
                Picker("Search by", selection: $viewModel.historySearchField) {
                    ForEach(HistorySearchField.allCases, id: \.self) { field in
                        Text(field.rawValue).tag(field)
                    }
                }.labelsHidden().frame(width: 110)
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .task(id: "\(viewModel.historySearchField.rawValue):\(viewModel.historyQuery)") {
                do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                await viewModel.resetHistory()
            }
            HStack {
                Label("RECENT COMMITS", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.caption2.weight(.semibold)).foregroundStyle(TwigTheme.leaf)
                Spacer()
                Text(viewModel.historyQuery.isEmpty ? "All branches" : "Search results").font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            GitGraphView(
                snapshot: viewModel.currentSnapshot,
                isLoading: viewModel.isLoading,
                repository: viewModel.selectedRepository,
                onRefresh: {
                    Task {
                        await viewModel.refreshSelectedRepository()
                    }
                },
                onChooseAgain: { repository in
                    viewModel.chooseAgain(for: repository)
                },
                onOpenInFinder: { repository in
                    viewModel.openInFinder(repository)
                },
                onRemove: { repository in
                    viewModel.removeRepository(repository)
                },
                hasMore: viewModel.historyHasMore,
                loadingMore: viewModel.historyLoading,
                historyError: viewModel.historyError,
                onLoadMore: { Task { await viewModel.loadMoreHistory() } }
            )
            .id(viewModel.historyIdentity)

            Divider()
            footer
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let snapshot = viewModel.currentSnapshot, snapshot.errorMessage == nil {
                Button {
                    withAnimation { showFiles.toggle() }
                } label: {
                    HStack {
                        Image(systemName: snapshot.isDirty ? "doc.badge.ellipsis" : "checkmark.circle.fill")
                            .foregroundStyle(snapshot.isDirty ? TwigTheme.amber : TwigTheme.leaf)
                        Text(snapshot.isDirty ? "\(snapshot.changedFiles.count) changed files" : "Working tree clean")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: showFiles ? "chevron.up" : "chevron.down").font(.caption)
                    }
                }
                .buttonStyle(.plain)
                if showFiles && !snapshot.changedFiles.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(snapshot.changedFiles) { file in
                                HStack(spacing: 10) {
                                    Text(file.status).font(.caption.monospaced()).foregroundStyle(.orange)
                                    Text(file.path).font(.caption).textSelection(.enabled)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }.frame(maxHeight: 110)
                }
                HStack {
                    Label(snapshot.ahead.map { "\($0) to push" } ?? "Push count unknown", systemImage: "arrow.up")
                        .foregroundStyle(TwigTheme.plum)
                    Label(snapshot.behind.map { "\($0) to pull" } ?? "Pull count unknown", systemImage: "arrow.down")
                        .foregroundStyle(TwigTheme.sky)
                }
                .font(.caption).foregroundStyle(.secondary)
                .help("Compared with locally stored remote information. Fetch to update.")
                Text(snapshot.upstream.map { "Tracking \($0)" } ?? "No supported tracking branch. Configure one in your terminal.")
                    .font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    syncButton(.fetch, icon: "arrow.clockwise")
                    syncButton(.pull, icon: "arrow.down")
                    syncButton(.push, icon: "arrow.up")
                    Spacer()
                    if let action = viewModel.syncAction {
                        ProgressView().controlSize(.small)
                        Text("\(action.rawValue)…").font(.caption)
                    }
                }
                .disabled(viewModel.syncAction != nil || snapshot.upstream == nil || viewModel.isLoading)
            }
            if let message = viewModel.syncMessage {
                ScrollView {
                    Text(message).font(.caption)
                        .foregroundStyle(viewModel.syncFailed ? Color.red : Color.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 65)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(TwigTheme.leaf.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(TwigTheme.leaf.opacity(0.22), lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }

    private func syncButton(_ action: SyncAction, icon: String) -> some View {
        Button {
            Task {
                do {
                    guard let repository = viewModel.selectedRepository else { return }
                    let target = try await viewModel.syncTarget()
                    if action == .push {
                        pendingTarget = target
                        pendingRepository = repository
                        pendingAction = action
                    } else {
                        await viewModel.synchronize(action, target: target, repository: repository)
                    }
                } catch {
                    viewModel.syncFailed = true
                    viewModel.syncMessage = error.localizedDescription
                }
            }
        } label: {
            Label(action.rawValue, systemImage: icon)
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .tint(action == .push ? TwigTheme.plum : action == .pull ? TwigTheme.sky : TwigTheme.leaf)
        .disabled(action == .pull && viewModel.currentSnapshot?.isDirty == true)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let repository = viewModel.selectedRepository {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingSwitcher.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        TwigAppIcon(size: 24)
                        Text(repository.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        Image(systemName: isShowingSwitcher ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .help("Switch repository")
                .disabled(viewModel.syncAction != nil)
            }

            Spacer(minLength: 12)

            Text(branchStatusText)
                .font(.caption.monospaced().weight(.medium))
                .foregroundStyle(TwigTheme.leaf)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Capsule().fill(TwigTheme.leaf.opacity(0.12)))

            Button {
                viewModel.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(TwigTheme.header)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text(lastUpdatedText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                Task {
                    await viewModel.refreshSelectedRepository()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var branchStatusText: String {
        guard let snapshot = viewModel.currentSnapshot else {
            return viewModel.selectedRepository.map { viewModel.summary(for: $0)?.branchName ?? "..." } ?? ""
        }
        return "\(snapshot.branchName) \(snapshot.statusText)"
    }

    private var lastUpdatedText: String {
        guard let updatedAt = viewModel.currentSnapshot?.updatedAt else {
            return "Last updated: never"
        }
        return "Last updated: \(updatedAt.gitTwigRelativeText)"
    }
}
