# MacLock

**A macOS focus app that locks away your distractions for a set amount of time, and can't be talked out of it.**

Pick a length, or let a schedule start one for you, and MacLock blocks Notification Center, distracting apps and websites, and your notifications until the timer runs out. There's no Stop button. Quitting the app, force-quitting it, or restarting your Mac doesn't end a session.

MacLock started with one habit: clicking the date and time in the menu bar to check messages, even when nothing was there. So it goes further than most blockers. It covers that clock, the keyboard shortcut, and every other way into Notification Center.

---

## Features

### What a session locks
| | How |
|---|---|
| **Notification Center** | An invisible overlay covers the menu bar clock on every display, including in full screen. The 🌐/fn + N shortcut is swallowed, and a watchdog closes the panel within about 30 ms if it opens any other way. |
| **Apps** | Blocked apps are force-quit the moment they launch, before their window can appear. Apps that are already open are asked to quit when the session starts. |
| **Websites** | Blocked across the whole system, in every browser, including the `www.` and `m.` versions. |
| **Notifications** | Do Not Disturb stays on for the whole session. |

### The hard lock
- **No early exit.** Once a session starts, it runs until the timer ends. You can only make it **longer** (+15 min).
- **Survives quitting and crashes.** If MacLock is quit or killed, it relaunches in under a second.
- **Survives restarts.** The session picks up again as soon as you log in.
- **Clock-proof.** Changing the system date or time doesn't shorten a session.
- **Rules can only get stricter mid-session.** You can add apps and websites to block during a session, but you can't remove any. Schedules can't be changed while they're running or within 10 minutes of starting.

### Schedules
Recurring lock windows, such as *weekdays 9:00–12:00*. They can run overnight, such as *22:00–01:00*. When a window opens, MacLock starts a session, or extends the one you're in, so a schedule never cuts a session short.

### Stats
Today's, this week's and all-time focus time, your current and longest streaks, and a 14-day chart. The menu bar popover shows a quick summary, such as *Today: 2h 15m · 🔥 4-day streak*.

### Lightweight
MacLock reacts to system events instead of constantly checking, so it uses about **0% CPU**, even during a session.

---

## Requirements
- macOS 26 (Tahoe) or later
- An admin account, needed once to approve MacLock's background helper
- *Optional:* two Shortcuts for Do Not Disturb (see [Setup](#setup))

## Installation
1. Download **MacLock.dmg** from [Releases](https://github.com/jjang-07/MacLock/releases), open it, and drag **MacLock** into **Applications**.
2. Open MacLock. A 🔓 lock icon appears in the menu bar.
3. Follow the first-launch setup below.

> **Using a menu bar manager** like Ice or Bartender? New icons often start out hidden. Move MacLock to the always-visible section so you can see the countdown.

## Setup
The first time you open MacLock, a short setup guide walks you through these. You can also check them later under **Settings → General**:

| Step | Why | Where |
|---|---|---|
| **Allow the background helper** (required) | It owns the session, so quitting MacLock can't end it, and it blocks websites. | System Settings → General → Login Items & Extensions → turn on **MacLock** |
| **Allow Accessibility** (recommended) | Blocks the 🌐/fn + N shortcut and closes Notification Center instantly. | System Settings → Privacy & Security → Accessibility → turn on **MacLock** |
| **Do Not Disturb Shortcuts** (optional) | macOS has no API for Focus modes, so MacLock runs two Shortcuts you create once. | In **Shortcuts**, create **MacLock Focus On** (action *Set Focus*: Do Not Disturb, on) and **MacLock Focus Off** (Do Not Disturb, off) |

---

## Using MacLock
- **Start a session:** click the menu bar icon, pick **25m**, **50m** or **90m**, or set a custom length, and press **Start**. The icon turns into 🔒 with a live countdown.
- **Add time:** **+15 min** in the popover. You can't take time away.
- **Click the blocked clock:** a small note shows how long is left, for example *23 min left — stay focused.*
- **Choose what to block:** **Settings → Blocking**. Add apps with **Add App…** and websites by typing a domain such as `reddit.com`. Pasting a full URL works too.
- **Schedules:** **Settings → Schedules → Add Schedule…**
- **Stats:** **Settings → Stats**

**Default blocklist:** Messages, FaceTime and Discord; YouTube, Reddit, Instagram, TikTok, X/Twitter and Facebook. You can change all of these between sessions.

---

## How it works

```
┌─────────────── MacLock.app (your user account) ──────────────┐
│ Menu bar UI · Settings · Stats                                │
│ Enforcers, active only during a session:                      │
│   ClockBlocker        invisible overlay over the menu bar     │
│                       clock on every display                  │
│   ShortcutBlocker     CGEventTap that swallows 🌐/fn + N       │
│   NotificationCenter  closes the panel if it opens            │
│     Watchdog          (Accessibility events)                  │
│   AppBlocker          force-quits blocked apps as they launch │
│   FocusController     Do Not Disturb through Shortcuts        │
└──────────────────────────────┬────────────────────────────────┘
                               │ XPC (code-signature checked)
┌──────────────────────────────▼────────────────────────────────┐
│ MacLockDaemon (root LaunchDaemon, registered via SMAppService) │
│   Session authority   the only source of truth for sessions;  │
│                       saved to a root-only file               │
│   Supervisor          relaunches the app if it's quit,        │
│                       undoes system-clock changes, runs       │
│                       schedules                               │
│   Hosts blocker       keeps the website block in /etc/hosts   │
│                       during sessions, undoes manual edits    │
│   Config store        blocklists and schedules, root-owned    │
│   Stats log           records each completed session          │
└────────────────────────────────────────────────────────────────┘
```

**The key design choice:** only the root helper decides whether a session is running. The app just asks it and enforces whatever it's told. That's why quitting the app, editing its preferences, or killing its process can't end a session: the helper owns the session and brings the app straight back.

Some technical notes:
- **Notification Center has no public API.** MacLock finds the clock with CoreGraphics window-list data and detects the open panel by its window owner and layer. These details are undocumented, so they're re-checked on every macOS release. The findings behind them are in [`Spikes/RESULTS.md`](Spikes/RESULTS.md).
- **Website blocking** adds a clearly marked section to `/etc/hosts` during a session and removes it afterwards. MacLock never touches anything outside its markers, and it only ever writes plain, validated domain names there.
- **Clock-proof timing:** the helper compares the wall clock with a monotonic clock that can't be changed, and shifts the session by any jump it detects.

**Built with:** Swift 6 (strict concurrency) · SwiftUI · AppKit · XPC · launchd / `SMAppService` · CoreGraphics · Accessibility API · Swift Charts · Swift Testing

---

## Building from source
You only need the **Command Line Tools**, not Xcode (`xcode-select --install`), plus an **Apple Development** signing certificate in your keychain.

```sh
git clone https://github.com/jjang-07/MacLock.git
cd MacLock

scripts/test.sh                 # run the unit tests
scripts/build.sh                # debug build   → build/cli/debug/MacLock.app
scripts/build.sh release        # release build → build/cli/release/MacLock.app

cp -R build/cli/debug/MacLock.app /Applications/    # helpers must run from /Applications
```

After the first install, the helper restarts itself whenever you install a new build. `MacLock.xcodeproj` also works if you prefer Xcode.

**Debug builds** add tools for development: an **End session (debug only)** button, and launch options such as `--args -start-seconds 60`. Release builds don't include any of these.

### Project layout
```
MacLock/          menu bar app, settings, and the enforcers (MacLock/Enforcement/)
MacLockDaemon/    root helper: sessions, supervisor, website blocking, config, stats
Shared/           code used by both: models, rules, XPC protocol (all unit-tested)
MacLockTests/     Swift Testing suite
LaunchServices/   launchd plist for the helper
scripts/          Xcode-free build and test scripts
Spikes/           the experiments used to prove out undocumented macOS behavior
```

---

## Limitations
MacLock is designed to make breaking a session **slow and annoying, never effortless**. It's not meant to be impossible to break:
- **You're an admin on your own Mac.** With Terminal and your password you could unload the helper. [`RECOVERY.md`](RECOVERY.md) documents exactly how, for when something has genuinely gone wrong.
- **Browsers cache connections.** A website added *in the middle of* a session may keep loading in an already-open tab until you quit and reopen the browser. This applies to Chromium-based browsers in particular. Sites on your list when the session starts are blocked right away.
- **Do Not Disturb depends on your Shortcuts.** If you had Do Not Disturb on before a session, it's turned off when the session ends.
- **Undocumented macOS behavior.** The Notification Center blocking depends on internals that a macOS update could change.

## Privacy
Everything stays on your Mac. MacLock has no accounts, no analytics and no network requests. Your blocklists, schedules and stats are stored locally in `/Library/Application Support/MacLock/`.

## If you're ever stuck
See [`RECOVERY.md`](RECOVERY.md) for how to end a session by hand, remove the website block, or fully uninstall MacLock.
