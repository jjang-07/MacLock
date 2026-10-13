import CoreGraphics
import Foundation

/// Pure geometry for finding the menu bar clock. See Spikes/RESULTS.md for how these rules were found.
enum ClockGeometry {
    /// Picks the clock among menu bar item frames (CoreGraphics coords: origin top-left of the primary display).
    /// The clock is the item touching the screen's top edge whose right edge sits at the screen's right edge.
    /// - Parameters:
    ///   - items: frames of "Control Center" windows at layer 25.
    ///   - screen: the screen's frame in Cocoa coords (origin bottom-left of the primary display).
    ///   - primaryHeight: height of the primary display, for flipping between coordinate systems.
    /// - Returns: the clock's frame in Cocoa coords, or nil if not visible (e.g. menu bar hidden in full screen).
    static func clockFrame(items: [CGRect], screen: CGRect, primaryHeight: CGFloat) -> CGRect? {
        let cgTop = primaryHeight - screen.maxY
        let clock = items.first {
            abs($0.minY - cgTop) < 2
                && abs($0.maxX - screen.maxX) < 6
                && (80...260).contains($0.width)
        }
        return clock.map { CGRect(x: $0.minX, y: primaryHeight - $0.maxY, width: $0.width, height: $0.height) }
    }

    /// Used before the clock has ever been detected on a screen.
    static func fallbackFrame(screen: CGRect) -> CGRect {
        CGRect(x: screen.maxX - 150, y: screen.maxY - 39, width: 150, height: 39)
    }

    /// A few points of slack on the left, so the overlay still covers the clock if its text gets
    /// wider (e.g. 9:59 → 10:00) before the next re-layout.
    static func overlayFrame(for clock: CGRect) -> CGRect {
        CGRect(x: clock.minX - 6, y: clock.minY, width: clock.width + 6, height: clock.height)
    }
}

extension Countdown {
    /// Message shown when the blocked clock is clicked.
    static func focusMessage(remaining: TimeInterval) -> String {
        let minutes = Int((remaining / 60).rounded(.up))
        switch minutes {
        case ...1: return "Less than a minute left — stay focused."
        case ..<60: return "\(minutes) min left — stay focused."
        default:
            let h = minutes / 60, m = minutes % 60
            return m == 0 ? "\(h)h left — stay focused." : "\(h)h \(m)m left — stay focused."
        }
    }
}
