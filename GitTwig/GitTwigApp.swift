import AppKit
import SwiftUI

@main
struct GitTwigApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = AppViewModel()
    private let softwareUpdateController = SoftwareUpdateController.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(viewModel: viewModel)
                .frame(width: 520, height: 480)
                .onAppear {
                    Task {
                        await viewModel.refreshAll()
                    }
                }
        } label: {
            MenuBarLabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
