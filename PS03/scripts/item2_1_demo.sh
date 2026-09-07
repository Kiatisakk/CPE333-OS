#!/usr/bin/env bash
#
# PS3 item 2, first situation -- ./ss1_1.sh versus ./ss1_1.sh &
#
# `set -m` turns on job control, which a script does not get by default. With it
# the shell puts each job in its own process group and `jobs` behaves as it does
# at a prompt.

set -u
cd "$(dirname "$0")/.." || exit 1
set -m

echo "--- 1. in the foreground ---"
echo "\$ date +%T ; ./ss1_1.sh ; date +%T"
date +%T
./ss1_1.sh
date +%T

echo
echo "--- 2. in the background ---"
echo "\$ date +%T ; ./ss1_1.sh &"
date +%T
./ss1_1.sh &
bg_pid=$!
sleep 2
echo    # the ticks are still coming; start the next output on its own line
echo "\$ jobs"
jobs
echo "\$ ps -o pid,ppid,stat,etime,args -p $bg_pid"
ps -o pid,ppid,stat,etime,args -p "$bg_pid"
echo "\$ wait ; date +%T          # only now block until it finishes"
wait "$bg_pid" 2>/dev/null
date +%T
