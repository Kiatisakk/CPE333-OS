#!/usr/bin/env bash
#
# Build every PS4 program and run it, capturing the transcripts into results/.
#
#   ./scripts/run_all.sh
#
# Afterwards: python3 scripts/make_latex.py, then scripts/build_pdf.ps1.
#
# The sheet asks for items 1 and 2 to be run three times, then rebuilt with
# -no-pie and run again; item 3 is run without -no-pie only. All of it must
# happen on one machine, which is why this is a single script.
#
# It does not only capture output -- it also CHECKS the claims the report makes
# about that output. A report is worse than useless if it states something the
# run does not show, so a failed check stops the pipeline here.

set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p results bin

# Flags for the separate warnings-only compile; never used to build a binary
# that gets measured. See build() below.
CFLAGS="-Wall -Wextra -std=c11 -O0 -g"
fail=0

# --------------------------------------------------------------- helpers ---

# Sources that are SUPPOSED to warn. 2_extern_no_extern.c reads an
# uninitialised local on purpose -- that is the whole point of the sheet's step
# 2 -- so gcc's -Wuninitialized there is evidence, not a defect. Everything else
# must compile silently.
warns_on_purpose() {
    case $1 in
        2_extern_no_extern.c) return 0 ;;
        *) return 1 ;;
    esac
}

# build <exe> <source> [extra gcc flags]
#
# The binaries we actually measure are built with the sheet's own command and
# nothing else --
#     gcc -o <exe> <src>            (the compiler's default, a PIE)
#     gcc -no-pie -o <exe> <src>
# -- so nobody has to wonder whether an extra flag of ours changed the result.
# (It does not: -Wall -Wextra -std=c11 -O0 -g gives byte-identical addresses,
# checked directly. But the question is better removed than answered.)
#
# Warnings are still wanted, so -Wall -Wextra runs as a separate compile that
# produces no object we use. That is what surfaces the deliberate
# uninitialised read in item 2.
build() {
    local exe=$1 src=$2 extra=${3:-}
    # shellcheck disable=SC2086
    if ! gcc $extra -o "bin/$exe" "src/$src"; then
        echo "COMPILE FAILED: gcc $extra -o $exe src/$src" >&2
        fail=1
        return 1
    fi
    # shellcheck disable=SC2086
    gcc $CFLAGS -c -o /dev/null "src/$src" 2>"bin/$exe.warn"
    if [ -s "bin/$exe.warn" ]; then
        if warns_on_purpose "$src"; then
            echo "    (expected warning from $src -- reading x before it is set)"
        else
            echo "UNEXPECTED WARNINGS from $src $extra:" >&2
            cat "bin/$exe.warn" >&2
            fail=1
        fi
    fi
    return 0
}

# run <exe> <label> <run-number> -- appends one labelled block to $OUT
run() {
    local exe=$1 label=$2 n=$3
    printf -- '--- %s, run %s ---\n' "$label" "$n"
    "./bin/$exe"
    printf '\n'
}

# Pull the addresses that a labelled block printed, one per line.
#   addrs <file> <label-prefix> <line-pattern>
addrs() {
    awk -v lab="$1" -v pat="$2" '
        /^--- /   { inblock = (index($0, "--- " lab ",") == 1); next }
        inblock && $0 ~ pat {
            if (match($0, /0x[0-9a-f]+/)) print substr($0, RSTART, RLENGTH)
        }
    ' "$OUT"
}

# check <description> <expected: same|differ> <values...>
check() {
    local what=$1 mode=$2; shift 2
    local uniq
    uniq=$(printf '%s\n' "$@" | sort -u | wc -l)
    local total=$#
    if [ "$total" -eq 0 ]; then
        echo "  FAIL  $what -- no values found" >&2
        fail=1
        return
    fi
    if [ "$mode" = same ] && [ "$uniq" -eq 1 ]; then
        echo "  ok    $what (all $total identical: $1)"
    elif [ "$mode" = differ ] && [ "$uniq" -eq "$total" ]; then
        echo "  ok    $what ($total distinct values)"
    else
        echo "  FAIL  $what -- expected $mode, got $uniq distinct of $total: $*" >&2
        fail=1
    fi
}

# ============================================================= item 1 ======
OUT=results/1_static.txt
echo ">>> item 1: static storage class -> $OUT"
build 1_static          1_static.c
build 1_static_nopie    1_static.c            -no-pie
build 1_no_static       1_static_no_static.c
build 1_no_static_nopie 1_static_no_static.c  -no-pie

{
    for n in 1 2 3; do run 1_static          "1_static.c, default PIE"           "$n"; done
    for n in 1 2 3; do run 1_static_nopie    "1_static.c, -no-pie"               "$n"; done
    for n in 1 2 3; do run 1_no_static       "1_static_no_static.c, default PIE" "$n"; done
    for n in 1 2 3; do run 1_no_static_nopie "1_static_no_static.c, -no-pie"     "$n"; done
} > "$OUT" 2>&1

# ============================================================= item 2 ======
OUT2=results/2_extern.txt
echo ">>> item 2: extern storage class -> $OUT2"
build 2_extern           2_extern.c
build 2_extern_nopie     2_extern.c           -no-pie
build 2_no_extern        2_extern_no_extern.c
build 2_no_extern_nopie  2_extern_no_extern.c -no-pie

{
    for n in 1 2 3; do run 2_extern          "2_extern.c, default PIE"          "$n"; done
    for n in 1 2 3; do run 2_extern_nopie    "2_extern.c, -no-pie"              "$n"; done
    for n in 1 2 3; do run 2_no_extern       "2_extern_no_extern.c, default PIE" "$n"; done
    for n in 1 2 3; do run 2_no_extern_nopie "2_extern_no_extern.c, -no-pie"     "$n"; done
} > "$OUT2" 2>&1

# ============================================================= item 3 ======
# The sheet runs this one WITHOUT -no-pie, and does not ask for three runs.
OUT3=results/3_memory.txt
echo ">>> item 3: memory allocation -> $OUT3"
build 3_memory        3_memory.c
build 3_memory_with_b 3_memory_with_b.c

{
    run 3_memory        "3_memory.c, default PIE"        1
    run 3_memory_with_b "3_memory_with_b.c, default PIE" 1
} > "$OUT3" 2>&1

# ============================================================== checks =====
echo
echo "===== checks ====="

OUT=results/1_static.txt
echo "item 1:"
# shellcheck disable=SC2046
check "static y under -no-pie keeps one address across runs" same \
      $(addrs "1_static.c, -no-pie" "address of y")
# sort -u first: each run prints the address three times, once per loop
# iteration, and those repeats are the point of the previous check, not this one
check "static y under PIE is relocated each run" differ \
      $(addrs "1_static.c, default PIE" "address of y" | sort -u)
# Three runs give three addresses per run (one per loop iteration); within a
# single run they must all be the same variable, which the "same" check on the
# -no-pie set already covers. Here the point is that the stack still moves.
check "auto y stays on the stack and still moves under -no-pie" differ \
      $(addrs "1_static_no_static.c, -no-pie" "address of y" | sort -u)

OUT=results/2_extern.txt
echo "item 2:"
check "global x under -no-pie keeps one address across runs" same \
      $(addrs "2_extern.c, -no-pie" "Address of x")
check "global x under PIE is relocated each run" differ \
      $(addrs "2_extern.c, default PIE" "Address of x" | sort -u)

# With extern deleted, main() has its own local x; display() still sees the
# global. The two addresses inside one run must therefore differ.
main_a=$(addrs "2_extern_no_extern.c, default PIE" "in main function" | head -1)
disp_a=$(addrs "2_extern_no_extern.c, default PIE" "in display function" | head -1)
if [ -n "$main_a" ] && [ -n "$disp_a" ] && [ "$main_a" != "$disp_a" ]; then
    echo "  ok    local x in main shadows the global ($main_a vs $disp_a)"
else
    echo "  FAIL  expected main's x to differ from display's x, got $main_a / $disp_a" >&2
    fail=1
fi

OUT=results/3_memory.txt
echo "item 3:"
# In the plain build a's block is adjacent to the top of the heap, so realloc
# can grow it in place. With b allocated in between it cannot, and must move.
plain_malloc=$(awk '/^--- 3_memory.c,/,0' "$OUT" | awk '/After malloc Pointer a/{getline; sub(/^>>/, "", $1); print $1}' | head -1)
plain_realloc=$(awk '/^--- 3_memory.c,/,0' "$OUT" | awk '/After realloc Pointer a/{getline; sub(/^>>/, "", $1); print $1}' | head -1)
withb_malloc=$(awk '/^--- 3_memory_with_b.c,/,0' "$OUT" | awk '/After malloc Pointer a/{getline; sub(/^>>/, "", $1); print $1}' | head -1)
withb_realloc=$(awk '/^--- 3_memory_with_b.c,/,0' "$OUT" | awk '/After realloc Pointer a/{getline; sub(/^>>/, "", $1); print $1}' | head -1)

if [ "$plain_malloc" = "$plain_realloc" ]; then
    echo "  ok    without b, realloc grew a in place ($plain_malloc)"
else
    echo "  FAIL  expected a to stay put without b, got $plain_malloc -> $plain_realloc" >&2
    fail=1
fi
if [ "$withb_malloc" != "$withb_realloc" ]; then
    echo "  ok    with b allocated, realloc moved a ($withb_malloc -> $withb_realloc)"
else
    echo "  FAIL  expected a to move with b allocated, it stayed at $withb_malloc" >&2
    fail=1
fi

# ---------------------------------------------------------------- tidy -----
for f in results/1_static.txt results/2_extern.txt results/3_memory.txt; do
    [ -s "$f" ] || { echo "EMPTY: $f" >&2; fail=1; }
done
rm -f bin/*.warn

echo
ls -l results/

if [ "$fail" -ne 0 ]; then
    echo
    echo "SOMETHING WENT WRONG -- do not build the report from these results." >&2
    exit 1
fi
