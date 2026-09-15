import SwiftUI

struct EmptyStateView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            TwigAppIcon(size: 80)

            VStack(spacing: 6) {
                Text("No repositories yet.")
                    .font(.headline)
                Text("Add a Git repository to start viewing its graph.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.addRepository()
            } label: {
                Label("Add Repository", systemImage: "folder.badge.plus")
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()
        }
        .padding(24)
    }
}
