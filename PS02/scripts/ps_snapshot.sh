#!/usr/bin/env bash
#
# PS2 item 2 -- run both scenarios and capture `ps -ef` evidence at the moments
# when the interesting state actually exists.  Both states are transient, which
# is why this is scripted rather than typed by hand.
#
# The bracket trick in the grep patterns (e.g. '[2]_1_zombie') stops grep from
# matching its own command line in the ps output.

set -u
cd "$(dirname "$0")/.."

hdr() { printf '\n===================== %s =====================\n' "$*"; }

hdr "system context"
echo "PID 1 on this system:"
ps -p 1 -o pid,ppid,comm
echo
echo "shell running this script: pid=$$"

hdr "2.1  child is DEAD while the parent is still RUNNING"
./bin/2_1_zombie &
zombie_job=$!
sleep 3

echo
echo "--- ps -ef at t=3s (parent sleeping, child already exited) ---"
ps -ef | head -1
ps -ef | grep '[2]_1_zombie'
echo
echo "--- same rows, PPID made explicit ---"
ps -eo pid,ppid,stat,comm | head -1
ps -eo pid,ppid,stat,comm | grep '[2]_1_zombie'

wait "$zombie_job"
echo
echo "--- ps -ef after the parent exited ---"
ps -ef | grep '[2]_1_zombie' || echo "(nothing left: init reaped the zombie when the parent died)"

hdr "2.2  parent is DEAD while the child is still RUNNING"
./bin/2_2_orphan &
sleep 1

echo
echo "--- ps -ef at t=1s (parent and child both alive) ---"
ps -ef | head -1
ps -ef | grep '[2]_2_orphan'

sleep 4
echo
echo "--- who adopted the orphan? ---"
orphan=$(pgrep -x 2_2_orphan | head -1)
if [ -n "${orphan:-}" ]; then
    adopter=$(ps -o ppid= -p "$orphan" | tr -d ' ')
    echo "orphan pid=$orphan  new ppid=$adopter  comm=$(cat /proc/"$adopter"/comm 2>/dev/null)"
    echo "for comparison, PID 1 is: $(cat /proc/1/comm)"
    echo "=> the adopter is NOT PID 1: WSL's per-session Relay process is a child subreaper"
fi
echo
echo "--- ps -ef at t=5s (parent gone, child re-parented) ---"
ps -ef | head -1
ps -ef | grep '[2]_2_orphan' || echo "(nothing)"
echo
echo "--- same rows, PPID made explicit ---"
ps -eo pid,ppid,stat,comm | head -1
ps -eo pid,ppid,stat,comm | grep '[2]_2_orphan' || echo "(nothing)"

sleep 5
echo
echo "--- ps -ef after the child finally exited ---"
ps -ef | grep '[2]_2_orphan' || echo "(nothing left: the new parent reaped it immediately)"
