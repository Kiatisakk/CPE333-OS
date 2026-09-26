#!/usr/bin/env bash
#
# Build ps7.c and run the three tasks, capturing transcripts into results/.
#
#   ./scripts/run_all.sh
#
# Afterwards: python3 scripts/make_latex.py, then scripts/build_pdf.ps1.
#
# Besides capturing, it CHECKS the claims the report makes -- task 1 always
# correct, tasks 2 and 3 oversold with totals that differ between runs -- and
# exits 1 if the run does not show them.

set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p results bin

RUNS=7
fail=0

# The measured binary is built with the sheet's own command, nothing added.
# -Wall -Wextra runs as a separate compile that produces nothing we use.
(cd bin && gcc -o ps7 ../src/ps7.c -lpthread) || { echo "COMPILE FAILED" >&2; exit 1; }
if ! gcc -Wall -Wextra -std=c11 -c -o /dev/null src/ps7.c 2>bin/warn.txt || [ -s bin/warn.txt ]; then
    echo "UNEXPECTED WARNINGS:" >&2; cat bin/warn.txt >&2; fail=1
fi

# task <n> <file> <args...> -- run ./ps7 RUNS times into one transcript
task() {
    local n=$1 out=$2; shift 2
    echo ">>> task $n: ./ps7 $* x$RUNS -> $out"
    {
        for r in $(seq 1 "$RUNS"); do
            printf -- '--- task %s, run %d ---\n$ ./ps7 %s\n' "$n" "$r" "$*"
            (cd bin && timeout 120 ./ps7 "$@")
            printf '\n'
        done
    } > "$out" 2>&1
}

task 1 results/task1.txt 1
task 2 results/task2.txt 4
task 3 results/task3.txt 4 yield

# ---------------------------------------------------------------- checks ---
echo
echo "===== checks ====="
sold() { grep -o 'tickets sold: [0-9]*' "$1" | awk '{print $3}'; }

check() {  # check <description> <condition-exit-status>
    if [ "$2" -eq 0 ]; then echo "  ok    $1"; else echo "  FAIL  $1" >&2; fail=1; fi
}

t1=$(sold results/task1.txt); t2=$(sold results/task2.txt); t3=$(sold results/task3.txt)
[ "$(echo "$t1" | wc -l)" -eq "$RUNS" ] && [ "$(echo "$t2" | wc -l)" -eq "$RUNS" ] && [ "$(echo "$t3" | wc -l)" -eq "$RUNS" ]
check "every run finished and printed a total" $?

[ "$(grep -c 'result: correct' results/task1.txt)" -eq "$RUNS" ]
check "task 1: one thread sells exactly 1000000 tickets in all $RUNS runs" $?

d2=$(echo "$t2" | sort -u | wc -l); o2=$(grep -c 'OVERSOLD' results/task2.txt)
[ "$o2" -ge 1 ] && [ "$d2" -ge 2 ]
check "task 2: oversold in $o2/$RUNS runs, $d2 distinct totals" $?

d3=$(echo "$t3" | sort -u | wc -l); o3=$(grep -c 'OVERSOLD' results/task3.txt)
[ "$o3" -eq "$RUNS" ] && [ "$d3" -ge 2 ]
check "task 3: oversold in $o3/$RUNS runs, $d3 distinct totals" $?

m2=$(echo "$t2" | awk '{s+=$1} END {printf "%d", s/NR}')
m3=$(echo "$t3" | awk '{s+=$1} END {printf "%d", s/NR}')
[ "$m3" -gt "$m2" ]
check "task 3 oversells more on average than task 2 ($m3 vs $m2 sold)" $?

rm -f bin/warn.txt
if [ "$fail" -ne 0 ]; then
    echo; echo "SOMETHING WENT WRONG -- do not build the report from these results." >&2
    exit 1
fi
