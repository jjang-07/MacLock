# MacLock — Implementation Plan

A macOS focus app that hard-locks distractions for a set time. You can't end a session early: quitting, force-quitting or rebooting won't stop it.

## Requirements (agreed)

| Area | Decision |
|---|---|
| Strictness | Hard lock with no escape hatch in Release builds |
| Notification Center | Block clicks on the menu bar clock, turn off the right-edge swipe, and close the panel if it opens anyway |
| Apps | User-chosen apps (Messages, Discord, …) are terminated whenever they launch |
| Websites | Blocked system-wide through `/etc/hosts`, managed by a privileged helper |
| Notifications | Do Not Disturb stays on for the whole session |
| UI | Menu bar icon (countdown, quick start) plus a Settings window (lists, schedules, stats) |
| Extras | Schedules, focus stats, "23 min left, stay focused" note when the blocked clock is clicked |
| Target | macOS 26, Xcode 27, Swift 6, SwiftUI. Personal use first, Developer ID distribution later. No App Store, because the sandbox can't allow this. |

## Architecture

```
┌──────────────────────── MacLock.app (user session, not sandboxed) ────────────────────────┐
│  MenuBarExtra (countdown, start)     Settings window (blocklists, schedules, stats)        │
│  Enforcers (run while a session is active):                                                │
│    ClockBlocker      – invisible panel over the clock on every display; click → toast      │
│    NCWatchdog        – detects an open Notification Center panel and closes it             │
│    AppBlocker        – NSWorkspace launch observer → terminate / forceTerminate            │
│    FocusController   – turns DND on/off via the Shortcuts CLI                              │
│  Relaunched by a LaunchAgent (KeepAlive) when quit or killed                               │
└──────────────────────────────────────────┬─────────────────────────────────────────────────┘
                                           │ NSXPCConnection (code-signing-checked)
┌──────────────────────────────────────────▼─────────────────────────────────────────────────┐
│  MacLockDaemon (root, LaunchDaemon registered via SMAppService.daemon)                     │
│    Session authority  – source of truth for start/end; persisted root-only                 │
│    HostsBlocker       – writes/removes a marked block in /etc/hosts, flushes DNS, watches  │
│    Scheduler          – starts sessions from schedules                                     │
│    StatsLog           – records completed sessions                                         │
│    Tamper checks      – rewrites hosts if edited; ignores system clock jumps               │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

**Key principle:** only the daemon decides whether a session is active. The app asks the daemon and enforces what it's told, so killing the app ends nothing. When the app relaunches, it asks again and resumes enforcing.

### Targets / folders
```
MacLock.xcodeproj
MacLock/            SwiftUI app (menu bar + settings + enforcers)
MacLockDaemon/      command-line tool, embedded at Contents/MacOS/MacLockDaemon
Shared/             XPC protocol, models (Session, Schedule, Blocklist), constants
Resources/          com.maclock.daemon.plist  → Contents/Library/LaunchDaemons/
                    com.maclock.agent.plist   → Contents/Library/LaunchAgents/
Spikes/             throwaway feasibility experiments (Milestone 0)
```

### Development safety (important)
A hard lock with no escape is risky while the code is still buggy, because a bug could lock you out.
- In `DEBUG` builds only, add an **escape hatch** (a menu item plus `MacLockDaemon --dev-reset`) guarded by `#if DEBUG`. Release builds don't include it.
- Use 1–2 minute sessions while testing.
- Keep a written recovery recipe (in `RECOVERY.md`, Milestone 7): `sudo launchctl bootout system/com.maclock.daemon`, remove the hosts block, delete the state file.

---

## Milestones

Each milestone produces something that builds, runs and can be tested on its own. Finish its **"Done when"** checks before moving on.

### M0 — Feasibility spikes ✅ DONE — see `Spikes/RESULTS.md`
The Notification Center pieces rely on undocumented macOS behavior, so check each one before building on it. Write small throwaway scripts or apps in `Spikes/`.
1. **Clock overlay:** a borderless `NSPanel` placed above the menu bar level (try `CGWindowLevelForKey(.mainMenuWindow) + 1` and `.statusBar + 1`), with `canJoinAllSpaces`, `stationary` and `fullScreenAuxiliary`, over the clock's rectangle. Does it swallow clicks? Does it hold up in full-screen apps?
2. **Finding the clock:** use the Accessibility API on the `com.apple.controlcenter` process's menu bar items and find the clock item's frame. Fallback: a fixed-width region at the right edge of the menu bar.
3. **Detecting and closing NC:** can we detect the open panel (`CGWindowListCopyWindowInfo` filtered to the `NotificationCenter` owner, or an AX observer)? Can we close it (send Escape, or `killall NotificationCenter`, which respawns)?
4. **Right-edge swipe:** do `defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 0` (and the `com.apple.driver.AppleBluetoothMultitouch.trackpad` domain) take effect without logging out? If not, the watchdog from spike 3 covers the gap.
5. **DND:** create the Shortcuts "MacLock Focus On" / "MacLock Focus Off" (using the *Set Focus* action) and check that `shortcuts run "MacLock Focus On"` works from code.

**Done when:** each spike has a written yes/no result plus the exact values that worked. Update this plan if anything fails.

### M1 — Project skeleton ✅ DONE
- Create the Xcode project: macOS App target in SwiftUI, deployment target macOS 26, **App Sandbox off**, Hardened Runtime on, signed with your Apple ID's development team.
- `LSUIElement = YES` (no Dock icon). Add a `MenuBarExtra` with a lock icon, a `Settings` scene and a Quit item.
- Add the `Shared/` group and the `MacLockDaemon` target (an empty `main.swift` for now).

**Done when:** the lock icon shows in the menu bar, Settings opens, and both targets build.

Notes from M1:
- Settings is a regular `Window(id: "settings")` opened with `openWindow` + `NSApp.activate()`. `SettingsLink` did nothing in this menu-bar-only app.
- The user runs **Ice** (menu bar manager), which hides new menu bar icons. Onboarding (M13) should tell users to make MacLock always visible.
- Signed "to run locally" (ad-hoc). M7 needs a real Apple Development certificate (add your Apple ID in Xcode → Settings → Accounts).

### M2 — Session model and timer (app-only, soft for now)
- `Shared/Session.swift`: `Session { id, start, end, source(manual|schedule) }`.
- `SessionStore` (`@Observable`, MainActor): start(duration), remaining time, a `isActive` flag.
- Menu bar popover: presets (25 / 50 / 90 min), a custom duration picker and a Start button. While a session runs, the menu bar shows `🔒 23:41` and a progress view, and there's no Stop button (except the DEBUG escape).

**Done when:** a 1-minute session counts down in the menu bar and ends by itself.

### M3 — Clock blocker + feedback toast
- `ClockBlocker`: port `Spikes/overlay_spike.swift`. One invisible panel per display, fitted to the clock through `CGWindowList` (no Accessibility needed). Cache the last rect per display, **never remove panels during a session**, re-layout every 0.5s and on space/app/screen changes.
- When the overlay is clicked, show a small toast just below it: "23 min left — stay focused." It fades after about 2 seconds.

**Done when:** clicking the clock during a session shows the toast instead of Notification Center, on every display and in full-screen apps; after the session the clock works again.

### M4 — Notification Center watchdog + swipe disable
- `NCWatchdog`: poll every 0.1s for a `"Notification Center"` window at layer 21. When one appears, post Escape **and** `killall NotificationCenter` at the same time. This is the backup for keyboard shortcuts and hot corners; the overlay is the main defense.
- Swipe gesture: no changes needed (it doesn't open NC on this machine; the watchdog covers it anyway).

**Done when:** you can't keep Notification Center open for more than a split second during a session by any method.

### M5 — App blocker
- `AppBlocker`: subscribe to `NSWorkspace.didLaunchApplicationNotification`. If the bundle ID is on the blocklist, call `terminate()`, then `forceTerminate()` after 2 seconds. At session start, sweep the apps already running.
- For now, keep the blocklist in `UserDefaults` (it moves to the daemon in M10). Default list: Messages (`com.apple.MobileSMS`) and FaceTime.

**Done when:** opening Messages during a session closes it immediately, and Messages opens normally after the session.

### M6 — Do Not Disturb
- `FocusController`: run `/usr/bin/shortcuts run "MacLock Focus On|Off"` with `Process`, and check its exit status.
- First-run onboarding: detect whether the shortcuts exist (`shortcuts list`). If they don't, explain how to create them, or ship `.shortcut` files to import. (Both already exist on this Mac.) DND state can't be read back, so trust the exit code.

**Done when:** DND turns on when a session starts and off when it ends.

### M7 — Privileged daemon + XPC (the hard lock starts here)
- `MacLockDaemon`: an `NSXPCListener(machServiceName: "com.maclock.daemon")` with a `MacLockDaemonProtocol` in `Shared/`: `startSession(duration)`, `currentSession()`, `debugReset()` (`#if DEBUG` only).
- Check that only the real app can connect, using `listener.setConnectionCodeSigningRequirement(...)` with your team ID.
- Register the daemon from the app with `SMAppService.daemon(plistName: "com.maclock.daemon.plist")`. You approve it once in System Settings → General → Login Items. (Keep the app in `/Applications` from now on.)
- Session state is saved to `/Library/Application Support/MacLock/state.json` (owned by root, mode 600).
- `SessionStore` now *asks* the daemon instead of keeping its own timer, polling and pushing updates over XPC.
- Write `RECOVERY.md`.

**Done when:** you start a session, quit MacLock, reopen it, and the session is still running with the right time left.

### M8 — Survive quit, kill and reboot
- Add the LaunchAgent (`SMAppService.agent(plistName: "com.maclock.agent.plist")`) with `KeepAlive = true`, pointing at the app binary, so launchd relaunches the app within seconds if you quit or force-quit it.
- The app's Quit menu item is hidden or disabled during sessions.
- **Clock tampering:** the daemon tracks elapsed time with a monotonic clock (`ContinuousClock`) and saves the remaining seconds about every 10 seconds. Moving the system date forward doesn't end the session early. Decide (and write down) whether time keeps counting while the Mac is powered off; the recommendation is that it does, using wall time but rejecting jumps forward.
- On boot the daemon reloads its state and continues the session.

**Done when:** force-quitting brings the app back within about 5 seconds with all enforcers active; a reboot in the middle of a session resumes the lock after login; changing the system clock doesn't end the session.

### M9 — Website blocking
- `HostsBlocker` (in the daemon): at session start, add a block between `# >>> MacLock` / `# <<< MacLock` markers mapping each domain and its `www.` version to `0.0.0.0` and `::`. Remove it at session end. Then flush DNS with `dscacheutil -flushcache` and `killall -HUP mDNSResponder`.
- On every daemon start, reconcile: if no session is active, make sure the block is gone. This prevents websites from staying blocked by accident.
- Watch `/etc/hosts` with `DispatchSource` and put the block back if it's edited during a session.
- Known gaps (document them): browsers using DNS-over-HTTPS, and tabs that were already open with live connections. Mitigations: tell the user to turn off "Secure DNS" in their browser, and optionally reload or quit browsers at session start. A packet-filter (`pf`) rule is a possible upgrade later.

**Done when:** youtube.com doesn't load in Safari or Chrome during a session, loads afterwards, and editing hosts mid-session gets reverted.

### M10 — Settings window
- Tabs: **Blocking** (an app picker from `/Applications` plus a list of website domains), **Schedules**, **Stats**, **General** (permissions status, reinstall the helper).
- Blocklists move into the daemon's config so a non-root user can't edit them; the app reads and writes them over XPC.
- **During a session, the lock can only get stricter:** you can add apps or sites, but you can't remove any, and session length can only go up.

**Done when:** blocklists changed in Settings take effect, and removing an item during a session is refused.

### M11 — Schedules
- `Schedule { days: Set<Weekday>, start: time, end: time, enabled }`, stored in the daemon.
- The daemon checks every 30 seconds and starts a session with `source = .schedule` when a schedule window opens. If a manual session is already running, the session is extended to whichever end comes later.
- Same rule as M10: a schedule can't be disabled or deleted within 10 minutes of its start time or while it's active.
- Optional: notify the user 5 minutes before a scheduled lock starts.

**Done when:** a schedule set 2 minutes in the future starts a lock by itself, even if the app was quit.

### M12 — Focus stats
- The daemon adds each completed session to `sessions.jsonl` (start, end, source, duration).
- Stats tab:
  - today, this week and all-time focus hours
  - current and longest streak (days with at least one completed session)
  - a Swift Charts bar chart of the last 14 days
- Menu bar popover footer: "Today: 2h 15m · 🔥 4-day streak".

**Done when:** stats show correct totals after a few test sessions.

### M13 — Hardening & polish
- Onboarding flow for first launch: helper approval, Accessibility, Shortcuts, browser DNS advice.
- **Self-healing:** if the LaunchAgent gets unregistered, the daemon re-launches the app in the user's session (`launchctl asuser <uid> open -a MacLock`).
- Removing MacLock in the middle of a session: the daemon keeps enforcing the hosts block until the end time, then cleans up after itself.
- Strip the DEBUG escape hatch and test a Release build end to end.
- App icon and menu bar icon states.

**Done when:** a full day of real use with no bugs or bypasses you notice.

### M14 — (Later) Distribution
- Paid Apple Developer account → Developer ID signing → notarization (`notarytool`) → a DMG. Optionally Sparkle for updates.
- Re-check the clock overlay and NC watchdog on each new macOS release, since they rely on undocumented behavior.

---

## Honest limitations
- You're an admin on your own Mac, so with Terminal and `sudo` you *could* get around the lock (for example by unloading the daemon). The goal is to make getting around it slow and annoying, not impossible. Optional upgrade later: hand admin rights to a separate account whose password you don't know during sessions.
- The Notification Center blocking relies on undocumented macOS behavior (window owner names and layers) and could break with an OS update. Re-run `Spikes/overlay_spike --debug` after each macOS update.
- Do Not Disturb depends on the user-created Shortcuts.
