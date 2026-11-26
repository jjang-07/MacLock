#!/bin/bash
# Re-runs M11 tests 2 and 5. During a session the daemon relaunches the app faster than `open --args`
# can, so test commands go into the app's preferences instead, picked up by whichever launch wins.
APP=/Applications/MacLock.app
log() { echo "[$(date +%H:%M:%S)] $*"; }
daemon_log() { /usr/bin/log show --last "$1" --info --predicate 'subsystem BEGINSWITH "com.maclock"' --style compact 2>/dev/null | sed -E 's/^([0-9-]+ [0-9:.]+).*\] /\1 /' | grep -a -E "$2"; }
session_active() { grep -q ">>> MacLock" /etc/hosts; }
# command_app <key> <type> <value>: e.g. command_app extend-seconds -int 60
command_app() { local key=$1; shift; defaults write com.maclock.app "$key" "$@" || exit 1; pkill -x MacLock; sleep 1.5; pgrep -x MacLock >/dev/null || open "$APP"; sleep 7; defaults delete com.maclock.app "$key"; }

session_active && { log "a session is running; not testing"; exit 1; }
pgrep -x MacLock >/dev/null || { open "$APP"; sleep 3; }

log "TEST 2: schedule in 1 min for 2 min; deleting it while it runs must be refused"
defaults write com.maclock.app test-schedule-length -int 2; command_app test-schedule-in -int 1
grep -o '"name":"Test"[^}]*' "/Library/Application Support/MacLock/config.json" | head -1
for i in $(seq 1 50); do session_active && break; sleep 3; done
session_active && log "schedule session started" || { log "FAIL schedule didn't start"; exit 1; }
command_app remove-schedules -bool YES
daemon_log 20s "Test config change|Refused change"
grep -q '"name":"Test"' "/Library/Application Support/MacLock/config.json" && log "PASS schedule still there" || log "FAIL schedule was deleted"
while session_active; do sleep 2; done; log "schedule session ended"
command_app remove-schedules -bool YES
defaults delete com.maclock.app test-schedule-length 2>/dev/null
daemon_log 20s "Test config change"

log "TEST 5: 1-minute session, extended by 1 minute"
pkill -x MacLock; sleep 1.5; open "$APP" --args -start-seconds 60; sleep 5
t0=$(date +%s)
command_app extend-seconds -int 60
daemon_log 20s "Extended"
while session_active; do sleep 1; done
log "session lasted $(( $(date +%s) - t0 + 12 ))s in total (expect ~120)"
log "ALL DONE"
