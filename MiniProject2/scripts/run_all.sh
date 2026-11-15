#!/usr/bin/env bash
#
# CPE 333 Mini-Project 2 -- build pfcount, run every experiment, capture the
# transcripts the report quotes, and check every claim the report makes.
#
#   sudo bash scripts/run_all.sh        (inside the VM, from the project copy)
#
# Writes results/*.txt. Each check goes to results/checks.txt as "ok" or
# "FAIL"; the script exits 1 if any check fails.
#
# Transcripts use "#" as the prompt because everything here runs as root.
# The test programs stop themselves (SIGSTOP) at each stage, so every reading
# is taken while the process is not running and cannot change under us.

set -u
cd "$(dirname "$0")/.." || exit 1
export LC_ALL=C
export PATH="$PWD/tools:$PATH"

R=results
BIN=bin
DATA=/var/tmp/mp2_data.bin     # on disk, not tmpfs: it must be evictable
DATA_PAGES=2048
TOUCH_PAGES=1024

rm -rf "$R" "$BIN"
mkdir -p "$R" "$BIN"
CHECKS=$R/checks.txt
: > "$CHECKS"
FAILED=0

# ------------------------------------------------------------- helpers ---
T=/dev/null                          # the transcript being written

begin() { T=$R/$1; : > "$T"; }

# record <command>: record "# command" and its output in the transcript.
record() {
    printf '# %s\n' "$*" >> "$T"
    bash -c "$*" >> "$T" 2>&1
}

note() { printf '%s\n' "$*" >> "$T"; }

# check <description> <test command...>
check() {
    local what=$1
    shift
    if "$@"; then
        echo "ok    $what" >> "$CHECKS"
    else
        echo "FAIL  $what" >> "$CHECKS"
        FAILED=1
    fi
}

# Wait until <pid> is stopped (state T). Fails if it exits instead.
wait_stop() {
    local st
    for _ in $(seq 1 2000); do
        st=$(sed 's/.*) //' "/proc/$1/stat" 2>/dev/null | cut -d' ' -f1)
        [ "$st" = T ] && return 0
        [ -z "$st" ] && return 1
        sleep 0.01
    done
    return 1
}

# start <program> [args]: run it in the background with its output in the
# transcript, and wait for its first stop. Sets PID.
start() {
    note "# $(echo "./$(basename "$1")" "${@:2}") &"
    "$BIN/$(basename "$1")" "${@:2}" >> "$T" 2>&1 &
    PID=$!
    check "$(basename "$1") stops at its first stage" wait_stop "$PID"
}

# resume: let PID run to its next stop.
resume() {
    note "# kill -CONT $PID"
    kill -CONT "$PID"
    check "pid $PID stops at its next stage" wait_stop "$PID"
}

# finish: let PID run to the end.
finish() {
    kill -CONT "$PID"
    wait "$PID" 2>/dev/null
}

# snap: read /proc/pfcount once into REG VKB VPAGES RSS MIN MAJ SEEN DMIN DMAJ.
snap() {
    local s
    s=$(cat /proc/pfcount)
    REG=$(sed -n 's/^  memory regions *: \([0-9]*\).*/\1/p' <<< "$s")
    VKB=$(sed -n 's/^  total virtual space *: \([0-9]*\) kB.*/\1/p' <<< "$s")
    VPAGES=$(sed -n 's/^  total virtual space *: [0-9]* kB (\([0-9]*\) pages).*/\1/p' <<< "$s")
    RSS=$(sed -n 's/^  resident (RSS) *: [0-9]* kB (\([0-9]*\) pages).*/\1/p' <<< "$s")
    MIN=$(sed -n 's/^  minor faults *: \([0-9]*\).*/\1/p' <<< "$s")
    MAJ=$(sed -n 's/^  major faults *: \([0-9]*\).*/\1/p' <<< "$s")
    SEEN=$(sed -n 's/^    faults seen *: \([0-9]*\).*/\1/p' <<< "$s")
    DMIN=$(sed -n 's/^    minor \/ major *: \([0-9]*\) \/ [0-9]*.*/\1/p' <<< "$s")
    DMAJ=$(sed -n 's/^    minor \/ major *: [0-9]* \/ \([0-9]*\).*/\1/p' <<< "$s")
}

# against_proc <tag>: the module's figures for PID agree with /proc.
against_proc() {
    local tag=$1 stat maps_n vmsize smaps_rss sizes
    snap
    read -r -a stat <<< "$(sed 's/.*) //' "/proc/$PID/stat")"
    # After "comm) ", field 3 (state) is index 0, so field N is index N-3.
    maps_n=$(grep -vc '\[vsyscall\]' "/proc/$PID/maps")
    vmsize=$(awk '/^VmSize/ {print $2}' "/proc/$PID/status")
    smaps_rss=$(awk '/^Rss:/ {print $2}' "/proc/$PID/smaps_rollup")
    check "$tag: minor faults $MIN = /proc/pid/stat field 10 (${stat[7]})" [ "$MIN" = "${stat[7]}" ]
    check "$tag: major faults $MAJ = /proc/pid/stat field 12 (${stat[9]})" [ "$MAJ" = "${stat[9]}" ]
    check "$tag: regions $REG = maps lines without [vsyscall] ($maps_n)" [ "$REG" = "$maps_n" ]
    check "$tag: region list = maps address column without [vsyscall]" \
        cmp -s <(grep -v '\[vsyscall\]' "/proc/$PID/maps" | cut -d' ' -f1) \
               <(cut -d' ' -f1 /proc/pfcount_regions)
    sizes=$(awk '{s += $3} END {print s}' /proc/pfcount_regions)
    check "$tag: virtual size $VKB kB = sum of region sizes ($sizes kB)" [ "$VKB" = "$sizes" ]
    check "$tag: virtual size $VKB kB = VmSize ($vmsize kB)" [ "$VKB" = "$vmsize" ]
    check "$tag: RSS $((RSS * 4)) kB = smaps_rollup Rss ($smaps_rss kB)" [ "$((RSS * 4))" = "$smaps_rss" ]
}

# --------------------------------------------------------------- build ---
begin 00_build.txt
record 'uname -r'
record 'gcc --version | head -1'
record 'make -C module'
for prog in 1_touch 2_filemap 3_regions; do
    record "gcc -O2 -o $BIN/$prog src/$prog.c"
done
record 'gcc -Wall -Wextra -fsyntax-only src/*.c'
rmmod pfcount 2>/dev/null
record 'insmod module/pfcount.ko'
record 'cat /proc/sys/kernel/tainted'
record 'dmesg | grep -E "soft lockup -|taints kernel|tainting kernel" | sed "s/^\[ *[0-9.]*\] //"'
record 'dmesg | grep "pfcount: attached" | tail -1 | sed "s/^\[ *[0-9.]*\] //"'
record 'ls -l /proc/pfcount /proc/pfcount_regions'
check "kernel is 6.8.0-999-generic" [ "$(uname -r)" = 6.8.0-999-generic ]
check "pfcount.ko built" [ -f module/pfcount.ko ]
check "pfcount loaded" grep -q '^pfcount ' /proc/modules
check "test programs compile without warnings under -Wall -Wextra" \
    bash -c "gcc -Wall -Wextra -fsyntax-only src/*.c 2>&1 | grep -q . && exit 1 || exit 0"

# -------------------------------------- experiment 1: regions vs maps ---
begin 01_regions.txt
start 1_touch $TOUCH_PAGES
record "pfcount -r $PID"
record "cat /proc/$PID/maps"
record "diff <(cut -d' ' -f1 /proc/$PID/maps) <(cut -d' ' -f1 /proc/pfcount_regions)"
record "grep VmSize /proc/$PID/status"
against_proc "exp1 1_touch"
check "exp1: maps has exactly one line more, [vsyscall]" \
    [ "$(diff <(cut -d' ' -f1 "/proc/$PID/maps") <(cut -d' ' -f1 /proc/pfcount_regions) | grep -c '^<')" = 1 ]
kill -KILL "$PID"
wait "$PID" 2>/dev/null

# ------------------- experiments 2 and 5: demand paging, minor faults ---
begin 02_touch.txt
start 1_touch $TOUCH_PAGES
record "pfcount $PID"
against_proc "exp2 stage 0"
RSS0=$RSS V0=$VPAGES
for touched in $((TOUCH_PAGES / 4)) $((TOUCH_PAGES / 2)) $TOUCH_PAGES; do
    resume
    record "pfcount $PID"
    against_proc "exp2 $touched touched"
    check "exp2 $touched touched: minor since start $DMIN in [$touched, $touched+4]" \
        test "$DMIN" -ge "$touched" -a "$DMIN" -le $((touched + 4))
    check "exp2 $touched touched: no major faults ($DMAJ)" [ "$DMAJ" = 0 ]
    check "exp2 $touched touched: faults seen $SEEN = minor + major ($DMIN + $DMAJ)" \
        [ "$SEEN" = $((DMIN + DMAJ)) ]
    check "exp5 $touched touched: virtual size unchanged ($VPAGES = $V0 pages)" [ "$VPAGES" = "$V0" ]
    check "exp5 $touched touched: RSS grew by the minor faults ($RSS - $RSS0 = $DMIN)" \
        [ $((RSS - RSS0)) = "$DMIN" ]
done
finish

# --------------------------------------------- experiment 3: major faults ---
begin 03_filemap.txt
record 'cat /sys/kernel/debug/fault_around_bytes'
record "dd if=/dev/urandom of=$DATA bs=4096 count=$DATA_PAGES status=none"
record 'sync; echo 3 > /proc/sys/vm/drop_caches'
note "--- cold page cache ---"
start 2_filemap "$DATA"
record "pfcount $PID"
snap
RSS0=$RSS
resume
record "pfcount $PID"
against_proc "exp3 cold"
check "exp3 cold: faults seen $SEEN = minor + major ($DMIN + $DMAJ)" [ "$SEEN" = $((DMIN + DMAJ)) ]
check "exp3 cold: RSS grew by the file's pages ($RSS - $RSS0 = $DATA_PAGES)" [ $((RSS - RSS0)) = "$DATA_PAGES" ]
check "exp3 cold: major faults $DMAJ >= 90% of $DATA_PAGES pages" \
    [ "$DMAJ" -ge $((DATA_PAGES * 9 / 10)) ]
finish
note "--- warm page cache (same file, second run) ---"
start 2_filemap "$DATA"
record "pfcount $PID"
snap
RSS0=$RSS
resume
record "pfcount $PID"
against_proc "exp3 warm"
check "exp3 warm: faults seen $SEEN = minor + major ($DMIN + $DMAJ)" [ "$SEEN" = $((DMIN + DMAJ)) ]
check "exp3 warm: RSS grew by the file's pages ($RSS - $RSS0 = $DATA_PAGES)" [ $((RSS - RSS0)) = "$DATA_PAGES" ]
check "exp3 warm: no major faults ($DMAJ)" [ "$DMAJ" = 0 ]
FA_PAGES=$(( $(cat /sys/kernel/debug/fault_around_bytes) / 4096 ))
check "exp3 warm: one minor fault per $FA_PAGES pages (fault-around): $DMIN = $DATA_PAGES / $FA_PAGES" \
    [ "$DMIN" = $((DATA_PAGES / FA_PAGES)) ]
finish
rm -f "$DATA"

# ------------------------------------ experiment 4: regions come and go ---
begin 04_regions.txt
start 3_regions
record "pfcount $PID"
record "grep -E 'Rss(Anon|File)' /proc/$PID/status"
against_proc "exp4 before"
REG0=$REG V0=$VPAGES RSS0=$RSS
ANON0=$(awk '/^RssAnon/ {print $2}' "/proc/$PID/status")
resume
record "pfcount $PID"
record "grep -E 'Rss(Anon|File)' /proc/$PID/status"
record "grep '^6000' /proc/pfcount_regions"
against_proc "exp4 mapped"
check "exp4 mapped: regions $REG = $REG0 + 8" [ "$REG" = $((REG0 + 8)) ]
check "exp4 mapped: virtual pages $VPAGES = $V0 + 128" [ "$VPAGES" = $((V0 + 128)) ]
# The new regions are never touched, so they hold no pages. RSS still grows a
# little: the program's code that runs for the first time (mmap, printf) is
# faulted in from libc, and those are file pages, not anonymous ones.
new_rss=$(awk '/^6000/ {on = 1; next} /^[0-9a-f]+-/ {on = 0} on && /^Rss:/ {s += $2} END {print s + 0}' "/proc/$PID/smaps")
check "exp4 mapped: the 8 new regions hold no resident pages (smaps Rss $new_rss kB)" [ "$new_rss" = 0 ]
anon=$(awk '/^RssAnon/ {print $2}' "/proc/$PID/status")
check "exp4 mapped: anonymous RSS unchanged ($anon = $ANON0 kB)" [ "$anon" = "$ANON0" ]
resume
record "pfcount $PID"
against_proc "exp4 unmapped"
check "exp4 unmapped: regions back to $REG0 ($REG)" [ "$REG" = "$REG0" ]
check "exp4 unmapped: virtual pages back to $V0 ($VPAGES)" [ "$VPAGES" = "$V0" ]
finish

# ------------------------------------------------------------- summary ---
echo "checks: $(grep -c '^ok' "$CHECKS") ok, $(grep -c '^FAIL' "$CHECKS") failed"
grep '^FAIL' "$CHECKS"
exit "$FAILED"
