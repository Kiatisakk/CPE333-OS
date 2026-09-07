#!/usr/bin/env bash
# PS3 item 1.3 -- four ways of naming what to kill.
set -u

gone() { ps -p "$1" >/dev/null 2>&1 && echo "  still alive" || echo "  (no such process)"; }

echo "--- by PID ---"
sleep 300 & p=$!
echo "\$ sleep 300 &                    # pid $p"
echo "\$ kill $p                       # SIGTERM (15): asks it to stop"
kill "$p"; wait "$p" 2>/dev/null; gone "$p"
sleep 300 & q=$!
echo "\$ sleep 300 &                    # pid $q"
echo "\$ kill -9 $q                    # SIGKILL (9): cannot be caught"
kill -9 "$q"; wait "$q" 2>/dev/null; gone "$q"

# A subshell, so that the job numbering starts again at %1: bash keeps counting
# upwards for the life of a shell, and two jobs have already been used above.
echo "--- by job number ---"
(
    set -m
    sleep 300 &
    echo "\$ jobs"; jobs
    echo "\$ kill %1                      # %n names a job, not a process"
    kill %1; wait "$!" 2>/dev/null
    echo "  (no jobs left)"
)

echo "--- by name, several at once ---"
sleep 300 & sleep 300 & sleep 300 &
sleep 1
echo "\$ pgrep -x -P \$\$ sleep | wc -l"; pgrep -x -P $$ sleep | wc -l
echo "\$ pkill -x -P \$\$ sleep          # only this shell's own children"
pkill -x -P $$ sleep; sleep 1
echo "\$ pgrep -x -P \$\$ sleep | wc -l"; pgrep -x -P $$ sleep | wc -l

pkill -x -P $$ sleep 2>/dev/null
exit 0
