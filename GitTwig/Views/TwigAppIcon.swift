import SwiftUI

/// Uses the same artwork as the packaged application icon.
struct TwigAppIcon: View {
    var size: CGFloat

    var body: some View {
        Image("AppIcon.png", bundle: .module)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

