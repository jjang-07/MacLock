# MacLock Recovery

How to get out of a session manually if a bug ever locks you in. This needs your admin password, on purpose. It's meant for when something is actually broken.

## Debug builds: the easy way
Open the MacLock menu → **End session (debug only)**. That asks the daemon to end the session.

## Any build: end the session by hand
Run these in Terminal:

```sh
# 1. Stop the daemon (it owns the session)
sudo launchctl bootout system/com.maclock.daemon

# 2. Delete the saved session so it doesn't come back
sudo rm -f "/Library/Application Support/MacLock/state.json"

# 3. Quit the app (removes the clock overlay and stops app blocking)
pkill -x MacLock

# 4. Turn Do Not Disturb back off if needed
shortcuts run "MacLock Focus Off"
```

From M9 on, also remove the website block:

```sh
sudo sed -i '' '/# >>> MacLock/,/# <<< MacLock/d' /etc/hosts
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

## Uninstall the helper completely
1. **System Settings → General → Login Items & Extensions**: turn MacLock off.
2. Run `sudo launchctl bootout system/com.maclock.daemon` (if it's still loaded).
3. Run `sudo rm -rf "/Library/Application Support/MacLock"`.
4. Delete `MacLock.app`.

## Check what's going on
```sh
sudo launchctl print system/com.maclock.daemon | head -20   # is the daemon loaded?
sudo cat "/Library/Application Support/MacLock/state.json"  # current session, if any
/usr/bin/log show --last 10m --predicate 'subsystem BEGINSWITH "com.maclock"' --style compact
```
