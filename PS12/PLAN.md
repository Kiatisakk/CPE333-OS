# PS12 plan — File System and Implementation

Follows `.claude/skills/lab-os/SKILL.md` (steps 3–6). Reference pipeline: `PS04/` and `PS07/`.
Rule: every figure in the report is quoted from a captured run in `results/` at build time, never typed.

## Decisions (grilled 2026-11-19)

- Scope: all three labs.
- Title: **CPE 333 Operating Systems, 1/2026** — "Problem Session 12: File System and Implementation".
- Members: the four in `PS04/latex/main.tex`.
- No existing work; build on the pipeline.
- Body: show full transcripts (they are short); one subsection per sheet bullet.
- English report, formal register, brief.

## Sheet questions (verbatim, each must be answered in the PDF)

### Lab 1 — Symbolic and hard link (Linux / Windows)
1. Use the concept of general graph directory structure to create the link file by using `ln` on Linux and `mklink` on Windows.
2. Create hard/soft links to a source. After delete the source file, what's happen with the symbolic and hard link files?
3. Create level 1 link to source and create level 2 link from level 1. See what happen if you delete source or delete level 1.
4. Create a link to directory or folder. See if you can create link to folder. Moreover, if you could, create a link that create a loop back to upper-level folder. Then try `ls -R` and `dir /s` to list the folder recursively and see what happen.
5. Can you create a link on drive D: to source on drive C:?
- Question: write a report showing the experimental steps with Linux and Windows commands, describe what you do, discuss the results step by step, and answer the questions.

### Lab 2 — Named pipe (Linux only)
- `mkfifo pipeFile`; `ls -la pipeFile`; terminal 1 `cat > pipeFile`, terminal 2 `cat pipeFile`; type "hello linux" and more lines; `^D`.
- Question: what is the concept of this file type and why this experiment behaves this way.

### Lab 3 — Reading and writing files (Linux only)
- `echo hello > foo`; `strace cat foo`.
- Question: explain the output (focus on the four lines read/write/read/close). What do the numbers {3, 1, 6, 32768} represent?

## Environment facts (checked)

- Linux: WSL `Ubuntu`. Run as `MSYS_NO_PATHCONV=1 wsl -d Ubuntu -- bash ./script.sh` (not `bash -lc '…'`). Use a scratch dir on the Linux filesystem (e.g. `/tmp/ps12`), not `/mnt/c`, so `ln -s` and inode numbers behave natively.
- Windows: only drive C: exists. Shell is NOT elevated and Developer Mode is OFF, so `mklink` (file symlink) and `mklink /D` are expected to fail with "You do not have sufficient privilege" — capture that error as a real result; do not elevate. `mklink /H` (hard link) and `mklink /J` (junction) need no privilege — use them for the Windows side of items 2–4.
- Item 5 (D: → C:): create a temporary drive with `subst D: <scratch folder on C:>`, try `mklink /H`, `mklink /J`, `mklink` from D: to a source on C:, then `subst D: /d`. NOTE: subst maps onto the same NTFS volume, so a hard link may succeed where a real second volume would refuse it (hard links cannot cross volumes; junctions/symlinks can). The report must state this honestly. Also show the Linux analogue: `ln` (hard) from a different filesystem (e.g. `/tmp` → `/mnt/c/...` or `/dev/shm`) fails with "Invalid cross-device link", `ln -s` succeeds.
- Windows commands run via `cmd /c` from a `.cmd` script, e.g. `scripts/run_windows.cmd`, capturing to `results/`. Scratch dir under `%TEMP%\ps12`, deleted at the end. Always `subst D: /d` at the end even on failure.

## Layout

```
PS12/scripts/run_all.sh        Linux: lab1 (ln), lab2 (fifo), lab3 (strace); asserts each claim; exit 1 on failure
PS12/scripts/run_windows.cmd   Windows: mklink items + subst D:; captures transcript
PS12/scripts/run_all.ps1       optional wrapper: runs both
PS12/scripts/make_latex.py     adapt PS07's (needspace(), check_coverage(), termsmall)
PS12/scripts/build_pdf.ps1     copy from PS04/PS07 unchanged except paths/names
PS12/results/                  1_links_linux.txt, 1_links_windows.txt, 2_fifo.txt, 3_strace.txt
PS12/latex/                    main.tex, preamble.tex (PS07's), discussion/*.tex, generated/
```

## Assertions run_all.sh must check (exit 1 if any fails)

- Hard link shares the source inode; link count goes 1→2 (and 3 for level 2).
- After `rm source`: hard link still reads the content; symlink is dangling (`cat` fails, `ls -l` still shows `->`).
- Level 2 via symlink-to-symlink: deleting level 1 breaks level 2; deleting source breaks both. Level 2 via hard link: survives deleting source and level 1.
- `ln dir hardlink` fails ("hard link not allowed for directory"); `ln -s` to a directory works; a loop symlink to `..` makes `ls -R` NOT recurse (ls does not follow symlinks), while `ls -RL` / `find -L` reports "File system loop detected" (capture with `timeout`).
- Cross-filesystem `ln` fails with EXDEV; `ln -s` succeeds.
- FIFO: `ls -la` first char is `p`, size 0; reader blocks until a writer opens (show via timestamps); reader receives exactly the written lines in order; reader exits after writer closes (EOF).
- strace: the four lines exist; fd of `read` is 3 (openat returned 3); `write` fd is 1; return is 6 (= `wc -c foo`); last read returns 0. Capture the actual buffer size (may be 131072 on newer coreutils, not 32768) and quote whatever was captured — the discussion explains 32768/131072 as the requested buffer size, not a typed constant.

For `dir /s` with a junction loop: Windows `dir /s` follows junctions and recurses until path length limit — run it with output truncated (e.g. pipe through `find /c /v ""` for a line count plus first ~40 lines) so the transcript stays short.

## Done when

`run_all.sh` exits 0; `build_pdf.ps1` gives 0 overfull boxes; `python3 .claude/skills/lab-os/drift_check.py PS12` exits 0; each question above is answered in `latex/discussion/`. Do not commit — Claude reviews and commits.
