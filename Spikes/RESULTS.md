# M0 Spike Results (2026-10-10, macOS 26.6.2, built-in Retina + Dell P2725HE)

| # | Spike | Result | What worked |
|---|---|---|---|
| 1 | Clock overlay blocks clicks | ✅ | Borderless `.nonactivatingPanel`, level `mainMenuWindow + 2`, `[.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]`, `hidesOnDeactivate = false`. Fill alpha `0.004` (invisible; fully clear pixels would let clicks pass through). 24/24 clicks blocked while invisible, including in full screen. |
| 2 | Finding the clock | ✅ No Accessibility permission needed | `CGWindowListCopyWindowInfo`: owner `"Control Center"`, layer `25`, top edge touching the screen's top, right edge within 6pt of the screen's right edge, width 80–260. Clock is 148pt wide; 39pt tall on the notch display, 30pt on the external one. |
| 3 | Detect / close Notification Center | ✅ | **Open signature:** owner `"Notification Center"`, layer `21`, covering a whole screen. **Close:** posting Escape (keycode 53) usually works; `killall NotificationCenter` is the fallback. Do both at once. Poll every 0.1s → visible for about 0.1–0.2s. |
| 4 | Right-edge trackpad swipe | ➖ Not needed | User's swipe doesn't open NC (defaults value is `3`, but it has no effect here). The watchdog covers it anyway. |
| 5 | DND through Shortcuts | ✅ | `shortcuts run "MacLock Focus On"` / `"MacLock Focus Off"` exit 0 and toggle DND. DND state can't be read back without Full Disk Access (`~/Library/DoNotDisturb/DB` is protected), so rely on the exit code. |

## Lessons (feed into M3/M4)
- **Never tear the overlay down during a session.** In full screen the menu bar is hidden and detection finds nothing. The first version removed the overlay at that point, and clicks got through when the menu bar slid back down.
- **Cache the last detected clock rect per display** (`CGDirectDisplayID`) and keep using it while detection fails. Before the first detection, fall back to 150×39 at the screen's top-right corner.
- Re-layout every 0.5s and on `activeSpaceDidChange`, `didActivateApplication` and `didChangeScreenParameters`; call `orderFrontRegardless()` every time.
- Requirement from the user: **no glimpse at all.** The overlay is the real defense; the watchdog is only a backup for non-click routes (keyboard shortcuts, hot corners).
- Posting Escape through `CGEvent` may need Accessibility permission when it runs from the app (Terminal already had it during the spikes). `killall` needs no permission, so it's the dependable path.

Reference implementation: `overlay_spike.swift` (`--debug` turns on the red tint).
