import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    @State private var section = Section.repositories

    private enum Section: String, CaseIterable {
        case repositories = "Repositories"
        case general = "General"
        case about = "About"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Picker("Settings section", selection: $section) {
                ForEach(Section.allCases, id: \.self) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            content
            Divider()
            footer
        }
    }

    private var header: some View {
        HStack {
            Button {
                viewModel.isShowingSettings = false
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)
            .help("Back")

            Label("Settings", systemImage: "slider.horizontal.3")
                .font(.headline)
                .foregroundStyle(TwigTheme.leaf)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(TwigTheme.header)
    }

    private var content: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                switch section {
                case .repositories:
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Repositories · \(viewModel.repositories.count)", systemImage: "folder.fill")
                                .font(.headline).foregroundStyle(TwigTheme.leaf)
                            Text("Choose a repository or edit its display name.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { viewModel.addRepository() } label: {
                            Label("Add", systemImage: "folder.badge.plus")
                        }
                    }
                    if viewModel.repositories.isEmpty {
                        Label("Add a local Git repository to get started.", systemImage: "folder")
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 24)
                    }
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.repositories) { repository in
                            SettingsRepositoryRow(viewModel: viewModel, repository: repository)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10)
                                    .fill(repository.id == viewModel.selectedRepositoryID
                                          ? TwigTheme.leaf.opacity(0.09)
                                          : Color(nsColor: .controlBackgroundColor)))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                    .stroke(repository.id == viewModel.selectedRepositoryID
                                            ? TwigTheme.leaf.opacity(0.4) : Color.primary.opacity(0.07),
                                            lineWidth: 1))
                        }
                    }
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption).foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                case .general:
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Stepper(
                                "Commits per page: \(viewModel.commitLimit)",
                                value: Binding(
                                    get: { viewModel.commitLimit },
                                    set: { viewModel.updateCommitLimit($0) }
                                ),
                                in: 5...200,
                                step: 5
                            )
                            Text("Number of commits loaded at a time. Scroll down to load more.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.padding(6)
                    } label: {
                        Label("Display", systemImage: "rectangle.grid.1x2").foregroundStyle(TwigTheme.sky)
                    }
                    GroupBox {
                        SoftwareUpdateSettingsView().padding(6)
                    } label: {
                        Label("Updates", systemImage: "arrow.triangle.2.circlepath").foregroundStyle(TwigTheme.plum)
                    }
                case .about:
                    AboutAppView()
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Spacer()

            Button(role: .destructive) {
                viewModel.quit()
            } label: {
                Label("Quit GitTwig", systemImage: "power")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

private struct SoftwareUpdateSettingsView: View {
    @State private var automaticallyChecksForUpdates = false
    @State private var lastUpdateCheckText = "Last checked: never"
    @State private var canCheckForUpdates = true

    private var updater: SoftwareUpdateController {
        SoftwareUpdateController.shared
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { automaticallyChecksForUpdates },
                        set: { newValue in
                            updater.updater.automaticallyChecksForUpdates = newValue
                            refreshState()
                        }
                    )
                )

                Button {
                    updater.updater.checkForUpdates()
                    refreshState()
                } label: {
                    Label("Check Now", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(!canCheckForUpdates)
            }

            Text(lastUpdateCheckText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear(perform: refreshState)
    }

    private func refreshState() {
        automaticallyChecksForUpdates = updater.updater.automaticallyChecksForUpdates
        canCheckForUpdates = updater.updater.canCheckForUpdates

        if let lastUpdateCheckDate = updater.updater.lastUpdateCheckDate {
            lastUpdateCheckText = "Last checked: \(lastUpdateCheckDate.gitTwigRelativeText)"
        } else {
            lastUpdateCheckText = "Last checked: never"
        }
    }
}

private struct AboutAppView: View {
    private let appInfo = AppInfo.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TwigAppIcon(size: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text("GitTwig").font(.title2.weight(.bold))
                    Text("A little closer to your code.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 5) {
                InfoRow(label: "Version", value: appInfo.versionText)
                InfoRow(label: "Developer", value: "野久知優希 (@coder_yuuki)")
                InfoRow(label: "License", value: "MIT")

                Text(appInfo.copyrightText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Link(destination: URL(string: "https://github.com/coder-yuuki/GitTwig")!) {
                    Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
                }

                Link(destination: URL(string: "https://github.com/coder-yuuki/GitTwig/issues")!) {
                    Label("Report Issue", systemImage: "exclamationmark.bubble")
                }

                Link(destination: URL(string: "https://github.com/coder-yuuki/GitTwig/releases")!) {
                    Label("View Releases", systemImage: "tag")
                }

                Link(destination: URL(string: "https://x.com/coder_yuuki")!) {
                    Label("@coder_yuuki on X", systemImage: "arrow.up.right.square")
                }
            }
        }
    }
}

private struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 68, alignment: .leading)

            Text(value)
                .textSelection(.enabled)
        }
        .font(.caption)
    }
}

private struct AppInfo {
    var versionText: String
    var copyrightText: String

    static var current: AppInfo {
        let bundle = Bundle.main
        let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let copyright = bundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String

        return AppInfo(
            versionText: formattedVersion(shortVersion: shortVersion, buildNumber: buildNumber),
            copyrightText: copyright ?? "Copyright © 2026 野久知優希"
        )
    }

    private static func formattedVersion(shortVersion: String?, buildNumber: String?) -> String {
        switch (shortVersion?.isEmpty == false ? shortVersion : nil, buildNumber?.isEmpty == false ? buildNumber : nil) {
        case let (version?, build?):
            "\(version) (\(build))"
        case let (version?, nil):
            version
        case let (nil, build?):
            "Build \(build)"
        case (nil, nil):
            "Development"
        }
    }
}

private struct SettingsRepositoryRow: View {
    @ObservedObject var viewModel: AppViewModel
    var repository: Repository

    var body: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.selectRepository(repository)
            } label: {
                Image(systemName: repository.id == viewModel.selectedRepositoryID ? "largecircle.fill.circle" : "circle")
            }
            .buttonStyle(.borderless)
            .help("Make selected repository")

            VStack(alignment: .leading, spacing: 4) {
                TextField(
                    "Display name",
                    text: Binding(
                        get: { currentRepository.displayName },
                        set: { viewModel.renameRepository(repository, displayName: $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Text(repository.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Text(viewModel.summary(for: repository)?.statusText ?? "")
                .font(.caption.monospaced().weight(.semibold))
                .frame(width: 44, alignment: .trailing)

            Menu {
                Button("Open in Finder") {
                    viewModel.openInFinder(repository)
                }
                Button("Choose Folder Again…") {
                    viewModel.chooseAgain(for: repository)
                }
                Divider()
                Button("Move Up") {
                    viewModel.moveRepository(repository, direction: -1)
                }.disabled(isFirst)
                Button("Move Down") {
                    viewModel.moveRepository(repository, direction: 1)
                }.disabled(isLast)
                Divider()
                Button("Remove from GitTwig", role: .destructive) {
                    viewModel.removeRepository(repository)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Repository actions")
            .disabled(viewModel.syncAction != nil)
        }
        .padding(.vertical, 4)
    }

    private var currentRepository: Repository {
        viewModel.repositories.first(where: { $0.id == repository.id }) ?? repository
    }

    private var currentIndex: Int? {
        viewModel.repositories.firstIndex(where: { $0.id == repository.id })
    }

    private var isFirst: Bool {
        currentIndex == viewModel.repositories.startIndex
    }

    private var isLast: Bool {
        guard let currentIndex else {
            return false
        }
        return currentIndex == viewModel.repositories.index(before: viewModel.repositories.endIndex)
    }
}
