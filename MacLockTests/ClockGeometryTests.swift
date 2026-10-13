import CoreGraphics
import Foundation
import Testing

/// Frames below were captured from the real menu bar during the M0 spikes.
struct ClockGeometryTests {
    let primaryHeight: CGFloat = 1112
    let builtIn = CGRect(x: 0, y: 0, width: 1710, height: 1112)              // Cocoa coords
    let dell = CGRect(x: -125, y: 1112, width: 1920, height: 1080)           // above the built-in display

    let builtInItems = [
        CGRect(x: 1522, y: 0, width: 42, height: 39),
        CGRect(x: 1564, y: 0, width: 148, height: 39),   // clock
        CGRect(x: 1240, y: 0, width: 38, height: 39),
    ]
    let dellItems = [
        CGRect(x: 1605, y: -1080, width: 42, height: 30),
        CGRect(x: 1647, y: -1080, width: 148, height: 30),  // clock
    ]

    @Test func findsClockOnBuiltInDisplay() {
        let frame = ClockGeometry.clockFrame(items: builtInItems + dellItems, screen: builtIn, primaryHeight: primaryHeight)
        #expect(frame == CGRect(x: 1564, y: 1073, width: 148, height: 39))
    }

    @Test func findsClockOnExternalDisplay() {
        let frame = ClockGeometry.clockFrame(items: builtInItems + dellItems, screen: dell, primaryHeight: primaryHeight)
        #expect(frame == CGRect(x: 1647, y: 2162, width: 148, height: 30))
    }

    @Test func nilWhenMenuBarHidden() {
        // Full screen: no items on this screen at all.
        #expect(ClockGeometry.clockFrame(items: dellItems, screen: builtIn, primaryHeight: primaryHeight) == nil)
    }

    @Test func ignoresHiddenAndOddSizedItems() {
        let items = [
            CGRect(x: -4049, y: 0, width: 29, height: 39),   // item parked off-screen by Ice
            CGRect(x: 1166, y: 0, width: 544, height: 39),   // too wide to be the clock
        ]
        #expect(ClockGeometry.clockFrame(items: items, screen: builtIn, primaryHeight: primaryHeight) == nil)
    }

    @Test func overlayAddsSlackOnTheLeft() {
        let overlay = ClockGeometry.overlayFrame(for: CGRect(x: 1564, y: 1073, width: 148, height: 39))
        #expect(overlay == CGRect(x: 1558, y: 1073, width: 154, height: 39))
    }

    @Test(arguments: [
        (30.0, "Less than a minute left — stay focused."),
        (61.0, "2 min left — stay focused."),
        (23 * 60.0, "23 min left — stay focused."),
        (3600.0, "1h left — stay focused."),
        (5400.0, "1h 30m left — stay focused."),
    ])
    func focusMessage(remaining: Double, expected: String) {
        #expect(Countdown.focusMessage(remaining: remaining) == expected)
    }
}
