import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
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

            Text("Settings")
                .font(.headline)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Repositories")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    viewModel.addRepository()
                } label: {
                    Label("Add", systemImage: "folder.badge.plus")
                }
            }

            List {
                ForEach(viewModel.repositories) { repository in
                    SettingsRepositoryRow(viewModel: viewModel, repository: repository)
                }
            }
            .listStyle(.inset)
            .frame(minHeight: 160)

            VStack(alignment: .leading, spacing: 6) {
                Stepper(
                    "Commit limit: \(viewModel.commitLimit)",
                    value: Binding(
                        get: { viewModel.commitLimit },
                        set: { viewModel.updateCommitLimit($0) }
                    ),
                    in: 5...200,
                    step: 5
                )
            }

            Divider()

            AboutAppView()

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
    }

    private var footer: some View {
        HStack {
            Button {
                SoftwareUpdateController.shared.updater.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.triangle.2.circlepath")
            }

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

private struct AboutAppView: View {
    private let appInfo = AppInfo.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 5) {
                InfoRow(label: "Version", value: appInfo.versionText)
                InfoRow(label: "Developer", value: "野久知優希 (@coder_yuuki)")
                InfoRow(label: "License", value: "MIT")

                Text(appInfo.copyrightText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://github.com/coder-yuuki/GitTwig")!) {
                    Label("GitHub Repository", systemImage: "chevron.left.forwardslash.chevron.right")
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

            VStack(spacing: 2) {
                Button {
                    viewModel.moveRepository(repository, direction: -1)
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(.borderless)
                .disabled(isFirst)
                .help("Move up")

                Button {
                    viewModel.moveRepository(repository, direction: 1)
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(.borderless)
                .disabled(isLast)
                .help("Move down")
            }

            Button(role: .destructive) {
                viewModel.removeRepository(repository)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove repository")
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
