import SwiftUI

struct RepositorySwitcherView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isShowingSwitcher: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.repositories) { repository in
                    Button {
                        viewModel.selectRepository(repository)
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isShowingSwitcher = false
                        }
                    } label: {
                        RepositoryRowView(
                            repository: repository,
                            summary: viewModel.summary(for: repository),
                            isSelected: repository.id == viewModel.selectedRepositoryID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 180)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct RepositoryRowView: View {
    var repository: Repository
    var summary: RepositorySummary?
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(repository.displayName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(repository.path)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(summary?.branchName ?? "...")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .trailing)

            Text(summary?.statusText ?? "")
                .font(.caption.monospaced().weight(.semibold))
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .background(isSelected ? Color.accentColor.opacity(0.10) : Color.clear)
    }
}
