#!/usr/bin/env bash
#
# Build PS3 and run every experiment, capturing each transcript into results/.
#
#   ./scripts/run_all.sh
#
# Afterwards: python3 scripts/make_latex.py, then scripts/build_pdf.ps1.

set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p results

fail=0

# Run one capture with a time limit and check it actually finished.
#
# --foreground lets the timeout reach a job that job control has put in its own
# process group, and -k follows up with SIGKILL if SIGTERM is ignored. Without
# these, item2_demo.sh's suspended job survives a timeout and is left running
# for the rest of its 1000 seconds.
capture() {
    local out=$1 secs=$2; shift 2
    printf '>>> %-38s -> %s\n' "$*" "$out"
    timeout -k 5 --foreground "$secs" "$@" > "$out" 2>&1
    local rc=$?
    if [ "$rc" -eq 124 ]; then
        echo "    TIMED OUT after ${secs}s -- $out is truncated" >&2
        fail=1
    elif [ "$rc" -ne 0 ]; then
        echo "    exited with status $rc" >&2
        fail=1
    fi
}

echo ">>> building PS3"
gcc -std=c11 -Wall -Wextra -O0 -g -o PS3 PS3.c || exit 1
chmod +x ss1_1.sh ss1_2.sh scripts/*.sh 2>/dev/null

capture results/1_1_ps_top.txt    60  ./scripts/item1_1_demo.sh
capture results/1_2_nice.txt      60  ./scripts/item1_2_demo.sh
capture results/1_3_kill.txt      60  ./scripts/item1_3_demo.sh
capture results/2_1_fg_bg.txt     120 ./scripts/item2_1_demo.sh
capture results/2_2_jobctl.txt    120 ./scripts/item2_2_demo.sh

printf '>>> %-38s -> %s\n' "./PS3 over the three cases" "results/5_stcf.txt"
{
    for c in 1 2 3; do
        echo "\$ ./PS3 case$c.csv"
        ./PS3 "case$c.csv" || { echo "    PS3 FAILED on case$c" >&2; fail=1; }
        echo
    done
} > results/5_stcf.txt 2>&1

echo
echo "===== checks ====="

# Ground truth for leftovers. `pgrep -x` matches the process NAME, which for a
# shebang script is "bash" -- it can never match ss1_1.sh, so checking that way
# would always report zero however much was left running. Match the argument
# vector instead, and anchor it so this script cannot match itself.
# `pgrep -c` prints 0 AND exits 1 when nothing matches, so take its output and
# ignore its status; a `|| echo 0` here would append a second zero.
strays=$(pgrep -c -f '(^|/)bash \./ss1_[12]\.sh$' 2>/dev/null)
strays=${strays:-0}
echo "stray ss1_*.sh          : $strays"
[ "$strays" -eq 0 ] || fail=1

for f in results/1_1_ps_top.txt results/1_2_nice.txt results/1_3_kill.txt \
         results/2_1_fg_bg.txt results/2_2_jobctl.txt results/5_stcf.txt; do
    if [ ! -s "$f" ]; then
        echo "EMPTY: $f" >&2
        fail=1
    fi
done

# The report asks for screenshots. A build that silently ships the red
# placeholder boxes is the easiest way to lose marks here.
missing=""
for f in figures/code.png figures/Result_Terminal.png; do
    [ -f "$f" ] || missing="$missing $f"
done
if [ -n "$missing" ]; then
    echo "screenshots still needed:$missing"
else
    echo "screenshots             : present"
fi

echo
ls -l results/

if [ "$fail" -ne 0 ]; then
    echo
    echo "SOMETHING WENT WRONG -- do not build the report from these results." >&2
    exit 1
fi
