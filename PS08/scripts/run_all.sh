#!/usr/bin/env bash
#
# Build every lock, run the experiments, capture transcripts into results/.
#
#   ./scripts/run_all.sh            (in WSL Ubuntu)
#
# Afterwards: python scripts/make_slides.py, then scripts/build_slides.ps1.
#
# Besides capturing, it CHECKS every claim the slides make and exits 1 if a
# run stops showing it.  Needs gcc-aarch64-linux-gnu and qemu-user for LL/SC.

set -u
cd "$(dirname "$0")/.." || exit 1
mkdir -p results bin

SECS=1          # length of one benchmark run
REPS=3          # runs per configuration; the slides use the median
fail=0

# ------------------------------------------------------------------ build ---
CFLAGS="-O2 -pthread"
build() {  # build <out> <cc> <extra flags> <lock source>
    $2 $CFLAGS $3 -o "bin/$1" src/bench.c "src/$4" || { echo "COMPILE FAILED: $1" >&2; exit 1; }
}
build peterson         gcc ""          1_peterson.c
build peterson_nofence gcc -DNO_FENCE  1_peterson.c
build llsc             gcc ""          2_llsc.c
build bakery           gcc ""          3_bakery.c
build tas              gcc ""          ref_tas.c
build mutex            gcc ""          ref_mutex.c
build llsc_arm64       aarch64-linux-gnu-gcc -static 2_llsc.c

# -Wall -Wextra as a separate compile that produces nothing we use.
for f in src/*.c; do
    for d in "" -DNO_FENCE; do
        gcc -Wall -Wextra -std=gnu11 $d -c -o /dev/null "$f" 2>>bin/warn.txt
    done
done
aarch64-linux-gnu-gcc -Wall -Wextra -std=gnu11 -c -o /dev/null src/2_llsc.c 2>>bin/warn.txt
if [ -s bin/warn.txt ]; then echo "UNEXPECTED WARNINGS:" >&2; cat bin/warn.txt >&2; fail=1; fi
rm -f bin/warn.txt

# -------------------------------------------------------------------- run ---
# run <header> <command...>  -- one block in the current transcript
run() {
    local h=$1; shift
    printf -- '--- %s ---\n$ %s\n' "$h" "$*"
    timeout 120 "$@" 2>&1 || echo "EXIT STATUS $?"
    printf '\n'
}

{
    for c in nproc "uname -r" "gcc --version" "aarch64-linux-gnu-gcc --version" "qemu-aarch64 --version"; do
        echo "\$ $c"; $c | head -1
    done
} > results/env.txt

echo ">>> 1: Peterson with and without the fence"
{
    for r in 1 2 3 4 5; do run "peterson_nofence all-cpus run $r" bin/peterson_nofence 2 $SECS; done
    for r in 1 2 3;     do run "peterson_nofence one-cpu run $r" taskset -c 0 bin/peterson_nofence 2 $SECS; done
    for r in 1 2 3 4 5; do run "peterson all-cpus run $r" bin/peterson 2 $SECS; done
} > results/1_peterson.txt

# What the compiler made of lock_acquire: the fence is one instruction.
disasm() {  # disasm <objdump> <binary>
    $1 -d --no-show-raw-insn --disassemble=lock_acquire "$2" |
        sed -n '/<lock_acquire>:/,$p' | sed 's/^ *//' | grep -v -e '^$' -e '^Disassembly of section'
}
{
    echo '$ objdump -d --disassemble=lock_acquire bin/peterson'
    disasm objdump bin/peterson
} > results/1_peterson_disasm.txt
disasm objdump bin/peterson_nofence > bin/nofence_disasm.txt

echo ">>> 2: LL/SC on AArch64 under qemu"
{
    for r in 1 2 3; do run "llsc arm64 run $r" qemu-aarch64 bin/llsc_arm64 4 $SECS; done
} > results/2_llsc.txt
{
    echo '$ aarch64-linux-gnu-objdump -d --disassemble=lock_acquire bin/llsc_arm64'
    disasm aarch64-linux-gnu-objdump bin/llsc_arm64
} > results/2_llsc_disasm.txt
disasm objdump bin/llsc > bin/llsc_x86_disasm.txt

echo ">>> bench: every lock at 1/2/4/8 threads, all CPUs and one CPU"
{
    for mode in all-cpus one-cpu; do
        pin=(); [ "$mode" = one-cpu ] && pin=(taskset -c 0)
        for lock in peterson llsc bakery tas mutex; do
            for t in 1 2 4 8; do
                [ "$lock" = peterson ] && [ "$t" -gt 2 ] && continue
                for r in $(seq 1 $REPS); do
                    run "$lock threads=$t $mode run $r" "${pin[@]}" bin/$lock $t $SECS
                done
            done
        done
    done
} > results/bench.txt

# ---------------------------------------------------------------- checks ---
echo
echo "===== checks ====="
check() {  # check <description> <condition-exit-status>
    if [ "$2" -eq 0 ]; then echo "  ok    $1"; else echo "  FAIL  $1" >&2; fail=1; fi
}
# lost <file> <header pattern> -- the lost= value of every matching block
lost() { awk -v p="$2" '/^--- /{on = ($0 ~ p)} on && /^total=/{sub(/.*lost=/, ""); print}' "$1"; }
blocks() { grep -c "^--- .*$2" "$1"; }

l=$(lost results/1_peterson.txt 'peterson_nofence all-cpus')
nbad=$(echo "$l" | awk '$1 > 0' | wc -l)
[ "$nbad" -eq 5 ]
check "Peterson without fence, 2 CPUs: updates lost in $nbad/5 runs" $?

l=$(lost results/1_peterson.txt 'peterson_nofence one-cpu')
[ "$(echo "$l" | awk '$1 == 0' | wc -l)" -eq 3 ]
check "Peterson without fence, one CPU: nothing lost in 3/3 runs" $?

l=$(lost results/1_peterson.txt 'peterson all-cpus')
[ "$(echo "$l" | awk '$1 == 0' | wc -l)" -eq 5 ]
check "Peterson with fence: nothing lost in 5/5 runs" $?

grep -Eq "mfence|lock or" results/1_peterson_disasm.txt && ! grep -Eq "mfence|lock or" bin/nofence_disasm.txt
check "the fence compiles to a full barrier (mfence or lock or), the no-fence build has none" $?

grep -q ldaxr results/2_llsc_disasm.txt && grep -q stxr results/2_llsc_disasm.txt
check "AArch64 lock_acquire uses ldaxr/stxr" $?

grep -q cmpxchg bin/llsc_x86_disasm.txt
check "x86 stand-in uses lock cmpxchg" $?

l=$(lost results/2_llsc.txt 'llsc arm64')
[ "$(echo "$l" | awk '$1 == 0' | wc -l)" -eq 3 ]
check "LL/SC on AArch64 (qemu, 4 threads): nothing lost in 3/3 runs" $?

n=$(blocks results/bench.txt 'run '); l=$(lost results/bench.txt '.')
[ "$(echo "$l" | awk '$1 == 0' | wc -l)" -eq "$n" ] && ! grep -q 'EXIT STATUS' results/bench.txt
check "bench: all $n runs finished with nothing lost" $?

python3 scripts/claims.py || fail=1

rm -f bin/nofence_disasm.txt bin/llsc_x86_disasm.txt
if [ "$fail" -ne 0 ]; then
    echo; echo "SOMETHING WENT WRONG -- do not build the slides from these results." >&2
    exit 1
fi
