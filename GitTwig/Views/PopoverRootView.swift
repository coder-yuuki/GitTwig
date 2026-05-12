import SwiftUI

struct PopoverRootView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var isShowingSwitcher = false

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.repositories.isEmpty {
                EmptyStateView(viewModel: viewModel)
            } else if viewModel.isShowingSettings {
                SettingsView(viewModel: viewModel)
            } else {
                mainContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
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

            GitGraphView(
                snapshot: viewModel.currentSnapshot,
                isLoading: viewModel.isLoading
            )

            Divider()
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let repository = viewModel.selectedRepository {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isShowingSwitcher.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
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
            }

            Spacer(minLength: 12)

            Text(branchStatusText)
                .font(.subheadline.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                viewModel.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
