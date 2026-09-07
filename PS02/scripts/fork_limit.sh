#!/usr/bin/env bash
#
# PS2 item 3 -- how many processes can we fork, and how does that change when
# other programs are already running?
#
# Three measurements, as item 3.2 requires:
#   1. the program on its own
#   2. with 200 extra long-lived processes owned by the same user
#   3. after those 200 have been killed again
#
# No artificial limit is placed on the program: it forks until it cannot fork
# any more.  On this machine that means it runs the system out of memory long
# before the per-user process limit of 35595 is reached.
#
# Two things make that survivable:
#
#   * A memory guard.  A watchdog watches MemAvailable and stops the run before
#     the kernel's OOM killer has to choose a victim of its own.
#   * Process-group kill.  `pkill` cannot stop this chain: it loses a race,
#     because the deepest process forks a replacement between pkill's scan and
#     its signal, so the chain regenerates from the survivor.  Killing the whole
#     process group is atomic.  Job control (set -m) puts each run in its own
#     group, and the watchdog is started while forking is still cheap.
#
# The count is read from the program's progress file, because when memory runs
# out the process that would have reported it is killed rather than being told
# that fork() failed.

set -u
cd "$(dirname "$0")/.."
set -m                                  # each background job gets its own PGID

BIN=./bin/3_fork_count
LOAD=200
FLOOR_MB=${FLOOR_MB:-800}               # stop the run below this much free memory
POLL=2

avail_mb()   { awk '/MemAvailable/ {printf "%.0f", $2/1024}' /proc/meminfo; }
user_procs() { ps -u "$(id -u)" --no-headers 2>/dev/null | wc -l; }

measure() {
    local f out flag start elapsed low
    f=$(mktemp /tmp/forkcount.XXXXXX)   # /tmp, not /mnt/c: one write per fork
    out=$(mktemp /tmp/forkout.XXXXXX)
    flag=$(mktemp /tmp/forkguard.XXXXXX)
    : > "$flag"

    FORK_COUNT_FILE="$f" "$BIN" > "$out" 2>&1 &
    local storm=$!

    # Watchdog: forked now, while forking is still cheap, so it can still kill
    # the group later when this user can no longer create processes at all.
    # It records the lowest free memory seen, and says so if it is the one that
    # stopped the run -- otherwise we would not know whether the count reported
    # is where fork() failed or merely where we intervened.
    ( low=999999
      while kill -0 "$storm" 2>/dev/null; do
          m=$(avail_mb)
          [ "$m" -lt "$low" ] && low=$m
          if [ "$m" -lt "$FLOOR_MB" ]; then
              echo "guard $low" > "$flag"
              kill -KILL -"$storm" 2>/dev/null
              break
          fi
          sleep "$POLL"
      done
      grep -q guard "$flag" 2>/dev/null || echo "self $low" > "$flag" ) &
    local guard=$!

    start=$(date +%s)
    wait "$storm" 2>/dev/null
    elapsed=$(( $(date +%s) - start ))
    wait "$guard" 2>/dev/null

    echo "successful fork() calls: $(cat "$f" 2>/dev/null)"
    if grep -q '^guard' "$flag" 2>/dev/null; then
        low=$(awk '{print $2}' "$flag")
        echo "stopped by: the memory guard, with free memory down to ${low} MB"
        echo "            (so this count is a floor, not the true ceiling)"
    elif grep -q 'fork() failed' "$out" 2>/dev/null; then
        echo "stopped by: $(grep -h 'fork() failed' "$out")"
    else
        echo "stopped by: the chain died without reporting (lowest free memory $(awk '{print $2}' "$flag") MB)"
    fi
    echo "run took ${elapsed}s"
    rm -f "$f" "$out" "$flag"
    settle
}

# Wait until the previous chain has completely gone and its memory has been
# returned.  Killing 4000-odd processes is not instantaneous, and starting the
# next measurement early would compare it against the leftovers of the last one
# instead of against the background load we actually care about.
settle() {
    local waited=0
    while [ "$(pgrep -x 3_fork_count | wc -l)" -gt 0 ] && [ "$waited" -lt 240 ]; do
        sleep 2; waited=$((waited + 2))
    done
    while [ "$(avail_mb)" -lt "$((BASELINE_MB - 200))" ] && [ "$waited" -lt 360 ]; do
        sleep 2; waited=$((waited + 2))
    done
    echo "settled after ${waited}s: $(user_procs) processes, $(avail_mb) MB free"
}

BASELINE_MB=$(avail_mb)

echo "per-user process limit (ulimit -u): $(ulimit -u)   -- not reached on this machine"
echo "no artificial limit: the program forks until it cannot fork any more"
echo "memory guard: run is stopped below ${FLOOR_MB} MB free"
echo

echo "===== measurement 1: the program on its own ====="
echo "processes already owned by this user: $(user_procs)   free memory: $(avail_mb) MB"
measure
echo

echo "===== spawning $LOAD background 'sleep' processes ====="
PIDS=()
for _ in $(seq 1 "$LOAD"); do
    sleep 3000 &
    PIDS+=($!)
done
sleep 1
echo "processes now owned by this user: $(user_procs)   free memory: $(avail_mb) MB"
echo

echo "===== measurement 2: with $LOAD other processes running ====="
measure
echo

echo "===== killing the $LOAD background processes ====="
kill "${PIDS[@]}" 2>/dev/null
wait "${PIDS[@]}" 2>/dev/null
sleep 2
echo "processes now owned by this user: $(user_procs)   free memory: $(avail_mb) MB"
echo

echo "===== measurement 3: after killing them again ====="
measure
