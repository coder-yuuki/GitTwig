import Foundation

extension Date {
    var gitTwigRelativeText: String {
        let elapsed = max(0, Int(Date().timeIntervalSince(self)))

        if elapsed < 5 {
            return "just now"
        }
        if elapsed < 60 {
            return "\(elapsed)s ago"
        }

        let minutes = elapsed / 60
        if minutes < 60 {
            return "\(minutes)m ago"
        }

        let hours = minutes / 60
        if hours < 24 {
            return "\(hours)h ago"
        }

        let days = hours / 24
        return "\(days)d ago"
    }
}
