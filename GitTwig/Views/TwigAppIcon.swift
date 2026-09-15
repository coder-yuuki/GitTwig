import SwiftUI

/// Resolve packaged resources explicitly: SwiftPM's generated Bundle.module
/// may look beside the .app instead of inside Contents/Resources.
enum TwigIconResource {
    static func url(in bundle: Bundle = .main) -> URL? {
        let roots = [bundle.resourceURL, bundle.bundleURL].compactMap { $0 }
        for root in roots {
            let resourceBundle = root.appendingPathComponent("GitTwig_GitTwig.bundle")
            if let resources = Bundle(url: resourceBundle),
               let url = resources.url(forResource: "AppIcon", withExtension: "png") {
                return url
            }
        }
        return nil
    }

    static let image: NSImage? = url().flatMap { NSImage(contentsOf: $0) }
}

/// Missing artwork must never terminate the app.
struct TwigAppIcon: View {
    var size: CGFloat

    var body: some View {
        Group {
            if let image = TwigIconResource.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                Image(systemName: "point.3.connected.trianglepath.dotted")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(TwigTheme.leaf)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
