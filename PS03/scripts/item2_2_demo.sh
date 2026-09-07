#!/usr/bin/env bash
#
# PS3 item 2, second situation -- CTRL+Z, jobs, bg and fg on ./ss1_2.sh
#
# `set -m` turns on job control, which a script does not get by default. With it
# the shell puts each job in its own process group and `jobs`, `fg` and `bg`
# behave as they do at a prompt.
#
# A script has no keyboard, so it cannot press CTRL+Z. Instead a small watchdog
# is started first, which after a couple of seconds sends SIGTSTP to the process
# group of the foreground job -- which is exactly what the terminal driver does
# when CTRL+Z is pressed. The job really is running in the foreground when it is
# suspended, so the scenario is the real one and not an imitation of it.

set -u
cd "$(dirname "$0")/.." || exit 1
set -m

# Send `sig` to the process group of this script's ss1_*.sh child, after `delay`
# seconds. Used to stand in for a keypress.
# It is disowned straight away so that it does not occupy a job number: the
# script's own helper must not take %1 from the job the report is about.
poke() {
    local delay=$1 sig=$2
    (
        sleep "$delay"
        for p in $(pgrep -P $$ -x bash 2>/dev/null); do
            [ "$p" = "$BASHPID" ] && continue
            kill -"$sig" -"$p" 2>/dev/null && break
        done
    ) &
    disown $! 2>/dev/null || true
}

echo "--- 1. run it, then press CTRL+Z ---"
echo "\$ ./ss1_2.sh"
poke 3 TSTP                 # stands in for the CTRL+Z keypress
./ss1_2.sh                  # really runs in the FOREGROUND
echo "^Z"
sleep 1
sus_pid=$(pgrep -P $$ -x bash 2>/dev/null | head -1)
echo
echo "--- 2. what CTRL+Z did ---"
echo "\$ jobs"
jobs
echo "\$ ps -o pid,stat,args -p $sus_pid"
ps -o pid,stat,args -p "$sus_pid"
echo
echo "--- 3. bg: resume it, in the background ---"
echo "\$ bg %1"
bg %1
sleep 1
echo "\$ jobs"
jobs
echo "\$ ps -o pid,stat,args -p $sus_pid"
ps -o pid,stat,args -p "$sus_pid"
echo
echo "--- 4. fg: bring it back to the foreground ---"
echo "\$ fg %1"
poke 3 TERM                 # so this demonstration ends instead of waiting 1000s
fg %1                       # really runs; blocks until the job is gone
echo
echo "\$ jobs"
jobs
wait 2>/dev/null
