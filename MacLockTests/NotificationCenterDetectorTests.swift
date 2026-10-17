import Testing

/// Window entries captured during the M0 spikes.
struct NotificationCenterDetectorTests {
    typealias W = NotificationCenterDetector.WindowInfo

    let desktopWidgets = [
        W(owner: "Notification Center", layer: -2147483601),
        W(owner: "Notification Center", layer: -2147483602),
    ]

    @Test func closedWhenOnlyWidgetsShow() {
        #expect(!NotificationCenterDetector.isOpen(desktopWidgets + [W(owner: "Control Center", layer: 25)]))
    }

    @Test func openWhenPanelLayerAppears() {
        #expect(NotificationCenterDetector.isOpen(desktopWidgets + [W(owner: "Notification Center", layer: 21)]))
    }

    @Test func otherAppsAtLayer21DontCount() {
        #expect(!NotificationCenterDetector.isOpen([W(owner: "Dock", layer: 21)]))
    }
}
