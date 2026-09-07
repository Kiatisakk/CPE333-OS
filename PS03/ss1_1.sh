#!/usr/bin/env bash
#
# PS3 item 2, first situation: a script that occupies 10 seconds. The sheet's
# NOTE suggests looping with a one-second sleep rather than one long sleep, so
# that progress stays visible while it runs.

printf 'ss1_1.sh (pid %s):' "$$"
for i in $(seq 1 10); do
    printf ' tick %d' "$i"
    sleep 1
done
printf ' finished\n'
