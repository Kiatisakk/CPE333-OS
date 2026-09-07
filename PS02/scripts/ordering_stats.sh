#!/usr/bin/env bash
#
# PS2 item 1 -- which process actually prints first?
#
# The lecture slide says the output of 1.1 "is not deterministic".  That is a
# statement about what the OS guarantees, which is not the same as saying the
# order varies in practice.  One run cannot tell the two apart, so this counts
# which process printed first over many runs, under three conditions.
#
# stdbuf -oL keeps stdout line-buffered, matching what happens on a terminal.

set -u
cd "$(dirname "$0")/.."

RUNS=${1:-500}

tally() {                       # tally <label> [command prefix...]
    local label="$1"; shift
    local parent=0 child=0 line
    for _ in $(seq 1 "$RUNS"); do
        line=$("$@" stdbuf -oL ./bin/1_1_fork_hello 2>/dev/null | sed -n 2p)
        case "$line" in
            *parent*) parent=$((parent + 1)) ;;
            *child*)  child=$((child + 1)) ;;
        esac
    done
    printf '%-24s parent first: %4d   child first: %4d\n' "$label" "$parent" "$child"
}

echo "Which process printed the second line, over $RUNS runs of 1.1 in each condition"
echo

tally "idle machine" env

echo "(starting $(nproc) busy loops to contend for the CPU)"
for _ in $(seq 1 "$(nproc)"); do
    ( while :; do :; done ) &
done
load=$(jobs -p)
tally "machine under load" env
kill $load 2>/dev/null
wait 2>/dev/null

tally "pinned to one CPU" taskset -c 0
