#!/usr/bin/env bash
#
# Run all Linux experiments for CPE 333 PS12 (Labs 1, 2, and 3), capturing
# transcripts into results/ and asserting every claim in PLAN.md.
#
#   MSYS_NO_PATHCONV=1 wsl -d Ubuntu -- bash ./PS12/scripts/run_all.sh
#
# Exits 1 if any assertion fails.

set -u
export LC_ALL=C

cd "$(dirname "$0")/.." || exit 1
PS12_DIR=$(pwd)
mkdir -p "$PS12_DIR/results"

if ! command -v strace >/dev/null 2>&1; then
    echo "ERROR: strace is not installed in WSL Ubuntu." >&2
    exit 1
fi

WORK=$(mktemp -d /tmp/ps12.XXXXXX)
XDEV=$(mktemp -d /dev/shm/ps12_xdev.XXXXXX)
trap 'rm -rf "$WORK" "$XDEV"' EXIT

fail=0
check() { # check <description> <condition-exit-status>
    if [ "$2" -eq 0 ]; then
        echo "  ok    $1"
    else
        echo "  FAIL  $1" >&2
        fail=1
    fi
}

# ============================================================ Lab 1 (Linux) ===
echo ">>> Lab 1 (Linux): links -> results/1_links_linux.txt"
L1="$WORK/lab1"
mkdir -p "$L1"

# Variables captured for assertions
ino_src="" ino_hard="" ino_sym=""
nlink_before="" nlink_after_hard="" nlink_after_l2=""
hard_after_rm_rc=1 hard_after_rm_txt=""
sym_after_rm_rc=0 sym_after_rm_ls=""
sym_l2_after_rm_l1_rc=0 sym_l1_after_rm_src_rc=0 sym_l2_after_rm_src_rc=0
hard_l2_after_rm_src_rc=1 hard_l2_after_rm_l1_rc=1 hard_l2_txt=""
dir_hard_rc=0 dir_hard_err=""
dir_sym_rc=1
ls_r_out="" find_l_out="" ls_rl_out=""
xdev_hard_rc=0 xdev_hard_err="" xdev_sym_rc=1 xdev_sym_txt=""

{
    cd "$L1" || exit 1

    # --- Item 1 & 2: Create hard/soft links and delete source ---
    echo "--- lab1_item1_2: hard and symbolic links, deleting source ---"
    echo "$ echo 'hello os lab 12' > source.txt"
    echo "hello os lab 12" > source.txt
    echo "$ ls -li source.txt"
    ls -li source.txt
    nlink_before=$(stat -c '%h' source.txt)

    echo "$ ln source.txt hard_link.txt"
    ln source.txt hard_link.txt
    echo "$ ln -s source.txt sym_link.txt"
    ln -s source.txt sym_link.txt
    echo "$ ls -li source.txt hard_link.txt sym_link.txt"
    ls -li source.txt hard_link.txt sym_link.txt

    ino_src=$(stat -c '%i' source.txt)
    ino_hard=$(stat -c '%i' hard_link.txt)
    ino_sym=$(stat -c '%i' sym_link.txt)
    nlink_after_hard=$(stat -c '%h' source.txt)

    echo "$ rm source.txt"
    rm source.txt
    echo "$ ls -li hard_link.txt sym_link.txt"
    ls -li hard_link.txt sym_link.txt
    sym_after_rm_ls=$(ls -l sym_link.txt)

    echo "$ cat hard_link.txt"
    hard_after_rm_txt=$(cat hard_link.txt)
    hard_after_rm_rc=$?
    echo "$hard_after_rm_txt"

    echo "$ cat sym_link.txt"
    cat sym_link.txt 2>&1
    sym_after_rm_rc=$?
    echo ""

    # --- Item 3: Level 1 and Level 2 links ---
    echo "--- lab1_item3: level 1 and level 2 link chains ---"
    mkdir -p "$L1/lvl" && cd "$L1/lvl" || exit 1

    echo "# Symbolic link chain: src_s <- l1_sym <- l2_sym"
    echo "$ echo 'chain data' > src_s.txt"
    echo "chain data" > src_s.txt
    echo "$ ln -s src_s.txt l1_sym.txt && ln -s l1_sym.txt l2_sym.txt"
    ln -s src_s.txt l1_sym.txt && ln -s l1_sym.txt l2_sym.txt
    echo "$ ls -li src_s.txt l1_sym.txt l2_sym.txt"
    ls -li src_s.txt l1_sym.txt l2_sym.txt
    echo "$ cat l2_sym.txt"
    cat l2_sym.txt

    echo "$ rm l1_sym.txt   # delete level 1"
    rm l1_sym.txt
    echo "$ cat l2_sym.txt"
    cat l2_sym.txt 2>&1
    sym_l2_after_rm_l1_rc=$?

    echo "$ ln -s src_s.txt l1_sym.txt && rm src_s.txt   # restore level 1, delete source"
    ln -s src_s.txt l1_sym.txt && rm src_s.txt
    echo "$ cat l1_sym.txt"
    cat l1_sym.txt 2>&1
    sym_l1_after_rm_src_rc=$?
    echo "$ cat l2_sym.txt"
    cat l2_sym.txt 2>&1
    sym_l2_after_rm_src_rc=$?
    echo ""

    echo "# Hard link chain: src_h <-> l1_hard <-> l2_hard"
    echo "$ echo 'hard chain data' > src_h.txt"
    echo "hard chain data" > src_h.txt
    echo "$ ln src_h.txt l1_hard.txt && ln l1_hard.txt l2_hard.txt"
    ln src_h.txt l1_hard.txt && ln l1_hard.txt l2_hard.txt
    echo "$ ls -li src_h.txt l1_hard.txt l2_hard.txt"
    ls -li src_h.txt l1_hard.txt l2_hard.txt
    nlink_after_l2=$(stat -c '%h' src_h.txt)

    echo "$ rm src_h.txt   # delete source"
    rm src_h.txt
    echo "$ ls -li l1_hard.txt l2_hard.txt"
    ls -li l1_hard.txt l2_hard.txt
    echo "$ cat l2_hard.txt"
    cat l2_hard.txt
    hard_l2_after_rm_src_rc=$?

    echo "$ rm l1_hard.txt   # delete level 1"
    rm l1_hard.txt
    echo "$ ls -li l2_hard.txt"
    ls -li l2_hard.txt
    echo "$ cat l2_hard.txt"
    hard_l2_txt=$(cat l2_hard.txt)
    hard_l2_after_rm_l1_rc=$?
    echo "$hard_l2_txt"
    echo ""

    # --- Item 4: Directory links and loop ---
    echo "--- lab1_item4: directory links and loop traversal ---"
    mkdir -p "$L1/dirtest/parent/child" && cd "$L1/dirtest" || exit 1
    echo "inside parent" > parent/p.txt
    echo "inside child" > parent/child/c.txt

    echo "$ ln parent parent_hard"
    dir_hard_err=$(ln parent parent_hard 2>&1)
    dir_hard_rc=$?
    echo "$dir_hard_err"

    echo "$ ln -s parent parent_sym && ls -ld parent_sym && ls parent_sym"
    ln -s parent parent_sym
    dir_sym_rc=$?
    ls -ld parent_sym
    ls parent_sym

    echo "$ ln -s .. parent/child/loop"
    ln -s .. parent/child/loop
    echo "$ ls -l parent/child/loop"
    ls -l parent/child/loop

    echo "$ ls -R parent"
    ls_r_out=$(ls -R parent 2>&1)
    echo "$ls_r_out"

    echo "$ timeout 5 ls -RL parent"
    ls_rl_out=$(timeout 5 ls -RL parent 2>&1)
    echo "$ls_rl_out"

    echo "$ timeout 5 find -L parent"
    find_l_out=$(timeout 5 find -L parent 2>&1)
    echo "$find_l_out"
    echo ""

    # --- Item 5: Cross-filesystem link (Linux analogue of D: -> C:) ---
    echo "--- lab1_item5: cross-filesystem link (Linux analogue) ---"
    echo "cross-fs content" > "$L1/xsrc.txt"
    echo "$ df -T /tmp /dev/shm | awk 'NR==1 || NR>1 {print \$1, \$2, \$7}'"
    df -T /tmp /dev/shm | awk '{print $1, $2, $7}'
    echo "$ stat -c '%d %n' $L1/xsrc.txt $XDEV"
    stat -c '%d %n' "$L1/xsrc.txt" "$XDEV"

    echo "$ ln $L1/xsrc.txt $XDEV/xhard.txt"
    xdev_hard_err=$(ln "$L1/xsrc.txt" "$XDEV/xhard.txt" 2>&1)
    xdev_hard_rc=$?
    echo "$xdev_hard_err"

    echo "$ ln -s $L1/xsrc.txt $XDEV/xsym.txt && ls -l $XDEV/xsym.txt && cat $XDEV/xsym.txt"
    ln -s "$L1/xsrc.txt" "$XDEV/xsym.txt"
    xdev_sym_rc=$?
    ls -l "$XDEV/xsym.txt"
    xdev_sym_txt=$(cat "$XDEV/xsym.txt")
    echo "$xdev_sym_txt"
} > "$PS12_DIR/results/1_links_linux.txt"
cd "$PS12_DIR" || exit 1

# Note: because the block above ran in the current shell (brace group), all
# variables set inside it are visible here for assertions!

# ============================================================ Lab 2 (FIFO) ====
echo ">>> Lab 2 (Linux): named pipe -> results/2_fifo.txt"
L2="$WORK/lab2"
mkdir -p "$L2"

fifo_ls="" fifo_type="" fifo_size=""
t_reader_start=0 t_writer_open=0 t_reader_first=0 t_reader_end=0
fifo_reader_rc=1
fifo_received=""

{
    cd "$L2" || exit 1
    echo "--- lab2_fifo: mkfifo, ls -la, and two-terminal pipe transfer ---"
    echo "$ mkfifo pipeFile"
    mkfifo pipeFile
    echo "$ ls -la pipeFile"
    fifo_ls=$(ls -la pipeFile)
    echo "$fifo_ls"
    fifo_type="${fifo_ls:0:1}"
    fifo_size=$(stat -c '%s' pipeFile)
    echo ""

    echo "# Terminal 2 runs 'cat pipeFile' first (blocks until a writer opens pipeFile)"
    EVENTS="$L2/events.log"
    READER_RAW="$L2/reader_raw.txt"
    READER_RC_FILE="$L2/reader.rc"
    READER_T1_FILE="$L2/reader.t1"
    READER_TEND_FILE="$L2/reader.tend"
    : > "$EVENTS"
    : > "$READER_RAW"

    t_reader_start=$(date +%s)
    printf '[%s] terminal 2$ cat pipeFile\n' "$(date +%H:%M:%S)" >> "$EVENTS"

    (
        cat pipeFile | {
            first=1
            while IFS= read -r line; do
                if [ "$first" -eq 1 ]; then
                    date +%s > "$READER_T1_FILE"
                    first=0
                fi
                printf '%s\n' "$line" >> "$READER_RAW"
                printf '[%s] terminal 2 (recv): %s\n' "$(date +%H:%M:%S)" "$line" >> "$EVENTS"
            done
        }
        rc=${PIPESTATUS[0]}
        echo "$rc" > "$READER_RC_FILE"
        date +%s > "$READER_TEND_FILE"
    ) &
    reader_pid=$!

    # Wait 2 seconds to demonstrate that the reader stays blocked before writer opens
    sleep 2

    t_writer_open=$(date +%s)
    printf '[%s] terminal 1$ cat > pipeFile\n' "$(date +%H:%M:%S)" >> "$EVENTS"
    # Terminal 1 types like a person watching terminal 2: send a line, wait
    # until it shows up there, then type the next. Without the wait the two
    # loggers race and the transcript can print a send before the previous recv.
    wait_recv() {   # wait_recv N -- until the reader has N lines (max ~5 s)
        local i
        for i in $(seq 100); do
            [ "$(wc -l < "$READER_RAW")" -ge "$1" ] && return 0
            sleep 0.05
        done
        return 1
    }
    {
        n=0
        for msg in 'hello linux' 'named pipe line 2' 'named pipe line 3'; do
            printf '[%s] terminal 1 (send): %s\n' "$(date +%H:%M:%S)" "$msg" >> "$EVENTS"
            printf '%s\n' "$msg"
            n=$((n + 1))
            wait_recv "$n"
            sleep 1
        done
        printf '[%s] terminal 1: ^D (EOF, writer closes pipeFile)\n' "$(date +%H:%M:%S)" >> "$EVENTS"
    } | cat > pipeFile

    wait "$reader_pid"

    fifo_reader_rc=$(cat "$READER_RC_FILE")
    t_reader_first=$(cat "$READER_T1_FILE")
    t_reader_end=$(cat "$READER_TEND_FILE")
    fifo_received=$(cat "$READER_RAW")
    printf '[%s] terminal 2: EOF received, cat pipeFile exited (status %s)\n' \
        "$(date -d "@$t_reader_end" +%H:%M:%S)" "$fifo_reader_rc" >> "$EVENTS"
    cat "$EVENTS"
} > "$PS12_DIR/results/2_fifo.txt"
cd "$PS12_DIR" || exit 1

# ============================================================ Lab 3 (strace) ==
echo ">>> Lab 3 (Linux): strace cat foo -> results/3_strace.txt"
L3="$WORK/lab3"
mkdir -p "$L3"

foo_bytes=0
strace_gnu="$L3/strace_gnu.txt"
strace_uutils="$L3/strace_uutils.txt"
{
    cd "$L3" || exit 1
    echo "--- lab3_strace_gnucat: echo hello > foo and strace gnucat foo ---"
    echo "$ echo hello > foo"
    echo hello > foo
    echo "$ wc -c foo"
    wc -c foo
    foo_bytes=$(wc -c < foo)
    echo "$ gnucat --version | head -n 1"
    gnucat --version | head -n 1
    echo "$ strace gnucat foo | cat   # stdout to a pipe, read/write as on a terminal"
    strace gnucat foo 2> "$strace_gnu" | cat > "$L3/gnucat.out"
    cat "$strace_gnu"
    echo "# stdout of 'gnucat foo':"
    cat "$L3/gnucat.out"
    echo ""

    echo "--- lab3_strace_uutils: strace cat foo (Ubuntu default uutils coreutils) ---"
    echo "$ cat --version"
    cat --version
    echo "$ strace cat foo > cat.out   # excerpt from openat(\"foo\") to exit"
    strace cat foo > "$L3/cat.out" 2> "$strace_uutils"
    sed -n '/openat.*"foo"/,$p' "$strace_uutils"
    echo "# stdout of 'cat foo':"
    cat "$L3/cat.out"
} > "$PS12_DIR/results/3_strace.txt"
cd "$PS12_DIR" || exit 1

# ============================================================ Assertions ======
echo
echo "===== assertions ====="

# Lab 1 assertions
[ "$ino_src" = "$ino_hard" ] && [ "$ino_src" != "$ino_sym" ]
check "Lab 1.2: hard link shares source inode ($ino_src == $ino_hard), symlink has own inode ($ino_sym)" $?

[ "$nlink_before" -eq 1 ] && [ "$nlink_after_hard" -eq 2 ] && [ "$nlink_after_l2" -eq 3 ]
check "Lab 1.2/1.3: link count progresses 1 -> 2 -> 3 ($nlink_before -> $nlink_after_hard -> $nlink_after_l2)" $?

[ "$hard_after_rm_rc" -eq 0 ] && [ "$hard_after_rm_txt" = "hello os lab 12" ]
check "Lab 1.2: after rm source, hard link still reads content" $?

[ "$sym_after_rm_rc" -ne 0 ] && echo "$sym_after_rm_ls" | grep -q -- '-> source.txt'
check "Lab 1.2: after rm source, symlink is dangling (cat fails, ls -l shows ->)" $?

[ "$sym_l2_after_rm_l1_rc" -ne 0 ] && [ "$sym_l1_after_rm_src_rc" -ne 0 ] && [ "$sym_l2_after_rm_src_rc" -ne 0 ]
check "Lab 1.3: symlink chain breaks on rm level 1 (l2 fails) and on rm source (l1 & l2 fail)" $?

[ "$hard_l2_after_rm_src_rc" -eq 0 ] && [ "$hard_l2_after_rm_l1_rc" -eq 0 ] && [ "$hard_l2_txt" = "hard chain data" ]
check "Lab 1.3: hard link level 2 survives deleting source and level 1" $?

[ "$dir_hard_rc" -ne 0 ] && echo "$dir_hard_err" | grep -qi "hard link not allowed for directory"
check "Lab 1.4: ln dir hardlink fails with 'hard link not allowed for directory'" $?

[ "$dir_sym_rc" -eq 0 ]
check "Lab 1.4: ln -s to a directory succeeds" $?

# ls -R should list parent and parent/child, and NOT list parent/child/loop:
echo "$ls_r_out" | grep -q '^parent/child:$' && ! echo "$ls_r_out" | grep -q '^parent/child/loop:$'
check "Lab 1.4: ls -R does not follow loop symlink" $?

echo "$find_l_out" | grep -qi "File system loop detected"
check "Lab 1.4: find -L reports 'File system loop detected'" $?

[ "$xdev_hard_rc" -ne 0 ] && echo "$xdev_hard_err" | grep -qi "Invalid cross-device link"
check "Lab 1.5: cross-filesystem hard link fails with EXDEV ('Invalid cross-device link')" $?

[ "$xdev_sym_rc" -eq 0 ] && [ "$xdev_sym_txt" = "cross-fs content" ]
check "Lab 1.5: cross-filesystem symlink succeeds and reads target" $?

# Lab 2 assertions
[ "$fifo_type" = "p" ] && [ "$fifo_size" -eq 0 ]
check "Lab 2: ls -la shows file type 'p' and size 0" $?

[ $((t_writer_open - t_reader_start)) -ge 1 ] && [ "$t_reader_first" -ge "$t_writer_open" ]
check "Lab 2: reader blocked until writer opened (start=$t_reader_start, writer=$t_writer_open, first_recv=$t_reader_first)" $?

expected_fifo=$(printf 'hello linux\nnamed pipe line 2\nnamed pipe line 3')
[ "$fifo_received" = "$expected_fifo" ]
check "Lab 2: reader received all written lines in exact order" $?

# The prose says each line appears in terminal 2 as soon as it is typed, so
# the transcript must read send, recv, send, recv, ... with no send between.
send_recv=$(grep -oE 'terminal [12] \((send|recv)\)' "$PS12_DIR/results/2_fifo.txt" \
            | sed 's/.*(\(.*\))/\1/' | paste -sd' ')
[ "$send_recv" = "send recv send recv send recv" ]
check "Lab 2: transcript alternates send/recv for every line ($send_recv)" $?

[ "$fifo_reader_rc" -eq 0 ] && [ "$t_reader_end" -ge "$t_reader_first" ]
check "Lab 2: reader exited cleanly (status 0) on writer EOF" $?

# Lab 3 assertions
[ "$foo_bytes" -eq 6 ]
check "Lab 3: wc -c foo equals 6 bytes ('hello\\n')" $?

grep -qE '^openat\(.*"foo".*\) *= *3$' "$strace_gnu"
check "Lab 3: gnucat openat(\"foo\", ...) returns fd 3" $?

read1_line=$(grep -E '^read\(3, *"hello\\n", *[0-9]+\) *= *6$' "$strace_gnu" | head -n 1)
[ -n "$read1_line" ]
check "Lab 3: gnucat read(3, \"hello\\n\", <bufsize>) = 6 captured" $?

bufsize=$(echo "$read1_line" | sed -nE 's/^read\(3, "hello\\n", ([0-9]+)\) *= *6$/\1/p')
[ -n "$bufsize" ] && [ "$bufsize" -gt 0 ]
check "Lab 3: captured gnucat read buffer size = $bufsize bytes" $?

grep -qE '^write\(1, *"hello\\n", *6\) *= *6$' "$strace_gnu"
check "Lab 3: gnucat write(1, \"hello\\n\", 6) = 6 captured" $?

grep -qE "^read\(3, *\"\", *${bufsize}\) *= *0$" "$strace_gnu"
check "Lab 3: gnucat second read(3, \"\", $bufsize) = 0 (EOF) captured" $?

grep -qE '^close\(3\) *= *0$' "$strace_gnu"
check "Lab 3: gnucat close(3) = 0 captured" $?

grep -qE '^openat\(.*"foo".*\) *= *3$' "$strace_uutils" && grep -qE '^splice\(3, .*\) *= *6$' "$strace_uutils"
check "Lab 3: default uutils cat opens foo on fd 3 and splices 6 bytes" $?

if [ "$fail" -ne 0 ]; then
    echo >&2
    echo "SOMETHING WENT WRONG -- do not build the report from these results." >&2
    exit 1
fi

echo
echo "ALL ASSERTIONS PASSED."
exit 0
