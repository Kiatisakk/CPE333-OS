#!/usr/bin/env bash
# PS3 item 1.2 -- the two ways to nice a process.
set -u

echo "\$ sleep 120 &                    # started normally"
sleep 120 &
a=$!
echo "\$ nice -n 10 sleep 120 &         # started with a raised niceness"
nice -n 10 sleep 120 &
b=$!
sleep 1
echo "\$ ps -o pid,ni,comm -p $a -p $b"
ps -o pid,ni,comm -p "$a" -p "$b"
echo "\$ renice -n 5 -p $a              # raise it on a running process"
renice -n 5 -p "$a"
echo "\$ renice -n -5 -p $a             # lowering it needs privilege"
renice -n -5 -p "$a" 2>&1 || true

kill "$a" "$b" 2>/dev/null
wait 2>/dev/null
exit 0
