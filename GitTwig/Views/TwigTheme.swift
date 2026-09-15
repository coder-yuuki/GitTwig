import SwiftUI

/// Semantic colors keep text readable in both system appearances.
enum TwigTheme {
    static let leaf = adaptive(light: 0x166B50, dark: 0x6CDBAC)
    static let sky = adaptive(light: 0x285EA8, dark: 0x88BFFF)
    static let plum = adaptive(light: 0x7844A0, dark: 0xD0A1F5)
    static let amber = adaptive(light: 0x925700, dark: 0xF2C16E)

    static var header: LinearGradient {
        LinearGradient(
            colors: [leaf.opacity(0.17), sky.opacity(0.07)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 255) / 255,
                green: CGFloat((hex >> 8) & 255) / 255,
                blue: CGFloat(hex & 255) / 255,
                alpha: 1
            )
        })
    }
}
