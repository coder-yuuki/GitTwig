import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        Image(systemName: "point.3.connected.trianglepath.dotted")
            .symbolRenderingMode(.hierarchical)
            .accessibilityLabel(viewModel.menuBarTitle())
            .help(viewModel.menuBarTitle())
    }
}
