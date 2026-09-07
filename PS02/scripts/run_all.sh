#!/usr/bin/env bash
#
# Build everything and run every experiment, capturing each transcript under
# results/.  Every run is wrapped in `timeout` so a mistake can never hang.

set -u
cd "$(dirname "$0")/.."

mkdir -p results
make --no-print-directory all || exit 1
echo

run() {                       # run <result-file> <timeout> <command...>
    local out="results/$1"; shift
    local secs="$1"; shift
    printf '>>> %-28s -> results/%s\n' "$1" "$(basename "$out")"
    {
        echo "\$ $*"
        echo
        timeout "$secs" "$@" 2>&1
        local st=$?
        echo
        echo "[exit status: $st]"
    } > "$out"
}

# ---- item 1: fork() with and without wait() -------------------------------
# One run of each, line-buffered (stdbuf -oL) so stdout behaves exactly as it
# does on a terminal.  Without it, redirecting to a file makes stdout fully
# buffered and fork() duplicates the unflushed buffer, which prints the first
# line twice -- an artefact of the capture, not of the program.
{
    echo "$ ./bin/1_1_fork_hello"
    timeout 10 stdbuf -oL ./bin/1_1_fork_hello 2>&1
} > results/1_1_fork_hello.txt

{
    echo "$ ./bin/1_2_fork_wait"
    timeout 10 stdbuf -oL ./bin/1_2_fork_wait 2>&1
} > results/1_2_fork_wait.txt
echo ">>> item 1                     -> results/1_1_fork_hello.txt, results/1_2_fork_wait.txt"

# ---- item 2: zombies and orphans ------------------------------------------
# Captured by direct redirection so the transcript holds only the experiment's
# own output, with no wrapper command line or exit status around it.
printf '>>> %-28s -> results/%s
' "item 2" "2_ps_snapshot.txt"
timeout 60 ./scripts/ps_snapshot.sh > results/2_ps_snapshot.txt 2>&1

# ---- item 3: how many processes can we fork -------------------------------
run 3_fork_limit.txt 180 ./scripts/fork_limit.sh

# ---- item 4: pipe between parent and child --------------------------------
run 4_pipe.txt 20 ./bin/4_pipe

# ---- item 5: pipe edge cases ----------------------------------------------
run 5_1a_read_closed.txt   20 ./bin/5_1a_read_closed
run 5_1b_read_open.txt     20 ./bin/5_1b_read_open
run 5_2_read_first.txt     20 ./bin/5_2_read_first
run 5_3_multi_message.txt  20 ./bin/5_3_multi_message

echo
echo "===== leftovers check ====="
# -x matches the process NAME exactly; -f would also match this script's own
# command line and report a leftover that does not exist.
echo "stray sleep processes:      $(pgrep -x sleep | wc -l)"
echo "stray 3_fork_count:         $(pgrep -x 3_fork_count | wc -l)"
echo "stray 2_2_orphan:           $(pgrep -x 2_2_orphan | wc -l)"
echo
echo "===== results ====="
ls -l results/
