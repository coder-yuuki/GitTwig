import AppKit
import SwiftUI

@main
struct GitTwigApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel: AppViewModel

    init() {
        if CommandLine.arguments.contains("--verify-packaged-resources") {
            guard let url = TwigIconResource.url(),
                  url.resolvingSymlinksInPath().path.hasPrefix(Bundle.main.bundleURL.resolvingSymlinksInPath().path + "/"),
                  TwigIconResource.image?.isValid == true else {
                fputs("Packaged icon is missing or invalid. Bundle: \(Bundle.main.bundleURL.path), resource: \(TwigIconResource.url()?.path ?? "missing"), valid: \(TwigIconResource.image?.isValid ?? false)\n", stderr)
                exit(1)
            }
            let renderer = ImageRenderer(content: TwigAppIcon(size: 64))
            guard let rendered = renderer.nsImage, rendered.isValid else {
                fputs("Packaged icon could not render.\n", stderr)
                exit(1)
            }
            print("Packaged icon loaded and rendered: \(url.path)")
            exit(0)
        }
        _viewModel = StateObject(wrappedValue: AppViewModel())
        _ = SoftwareUpdateController.shared
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView(viewModel: viewModel)
                .frame(width: 520, height: 640)
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
