#!/bin/bash
# M11 live test. Waits until no session is running (never touches the user's own session), then:
# installs the build, adds a schedule starting in ~2 min for 2 min, checks the daemon starts a
# session for it, checks the running schedule can't be deleted, checks the session ends with the
# window, then deletes the schedule, and finally checks "+15 min" extends a 1-minute session.
APP=/Applications/MacLock.app
log() { echo "[$(date +%H:%M:%S)] $*"; }
daemon_log() { /usr/bin/log show --last "$1" --info --predicate 'subsystem BEGINSWITH "com.maclock"' --style compact 2>/dev/null | sed -E 's/^([0-9-]+ [0-9:.]+).*\] /\1 /' | grep -a -E "$2"; }
session_active() { grep -q ">>> MacLock" /etc/hosts; }   # the hosts block is present exactly during a session
relaunch() { pkill -x MacLock; sleep 1.5; open "$APP" --args "$@"; }

log "waiting for the current session to end"
while session_active; do sleep 5; done
log "no session; installing"
old=$(pgrep -x MacLockDaemon); pkill -x MacLock; sleep 1
rm -rf "$APP" && cp -R build/cli/debug/MacLock.app /Applications/ && codesign --verify --deep --strict "$APP" || { log "FAIL install"; exit 1; }
for i in $(seq 1 30); do n=$(pgrep -x MacLockDaemon); [ -n "$n" ] && [ "$n" != "$old" ] && break; sleep 1; done
log "daemon $old -> $(pgrep -x MacLockDaemon)"

log "TEST 1: schedule starting in 2 min, 2 min long"
relaunch -test-schedule-in 2 -test-schedule-length 2
sleep 6; daemon_log 20s "Test config change"
grep -o '"schedules":\[[^]]*\]' "/Library/Application Support/MacLock/config.json"
for i in $(seq 1 60); do session_active && break; sleep 3; done
if session_active; then log "PASS session started by the schedule"; else log "FAIL no session within 3 min"; fi
daemon_log 4m "for a schedule"
sleep 3; echo "  overlays: $(swift Spikes/maclock_windows.swift | wc -l | tr -d ' ')"

log "TEST 2: deleting the running schedule must be refused"
relaunch -remove-schedules YES; sleep 6
daemon_log 20s "Test config change|Refused change"

log "TEST 3: session must end when the window ends"
while session_active; do sleep 2; done
log "session ended"; daemon_log 5m "Website block now covers 0"

log "TEST 4: after the window, the schedule can be deleted"
relaunch -remove-schedules YES; sleep 6
daemon_log 20s "Test config change"
grep -o '"schedules":\[[^]]*\]' "/Library/Application Support/MacLock/config.json"

log "TEST 5: extending a 1-minute session by 1 minute (same path as +15 min)"
relaunch -start-seconds 60; sleep 5
relaunch -extend-seconds 60; sleep 8
daemon_log 30s "Started|Extended"
while session_active; do sleep 2; done; log "extended session ended"; log "ALL DONE"
