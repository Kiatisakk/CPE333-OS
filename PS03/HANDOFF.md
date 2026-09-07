# Handoff — CPE 333 PS3 (Process Manipulation and Monitoring)

**Working dir:** `C:\Users\kiati\Documents\CPE333-OS\PS03`
**Status:** Deliverable is **complete**. 11-page PDF, 0 overfull boxes, both screenshots in place, no placeholders left.

---

## What this is

University assignment, CPE 333 Operating Systems 1/2026 (KMUTT). Group of 4,
submitted to LEB2 **as a document** — no code file is submitted. Assignment
sheet: `PS03/PS3_OS_2026.pdf` (2 pages).

The sheet has 5 items. **The user cut items 3 and 4** (GUI process monitors on
Linux/Windows). The report covers **items 1, 2 and 5 only**. Do not add 3/4 back.

Prior work: PS02 is finished and delivered — see `PS02/HANDOFF.md`. Same
pipeline and conventions were reused here.

---

## Current state — everything is done

| Sheet item | Report section | Evidence |
|---|---|---|
| 1.1 `top` vs `ps` | §1.1 | `results/1_1_ps_top.txt` |
| 1.2 purpose of `nice` | §1.2 | `results/1_2_nice.txt` |
| 1.3 killing processes/jobs | §1.3 | `results/1_3_kill.txt` |
| 2 first situation (`&`) | §2.1 | `ss1_1.sh` + `results/2_1_fg_bg.txt` |
| 2 second situation (CTRL+Z/`fg`/`bg`) | §2.2 | `ss1_2.sh` + `results/2_2_jobctl.txt` |
| 5 STCF | §3 | `PS3.c` + `results/5_stcf.txt` + 2 screenshots |

Screenshots are in and verified against the transcripts:
`figures/code.png` (the `simulate_stfc()` function) and
`figures/Result_Terminal.png` (the three cases run in Ubuntu).

**Note:** the user renamed the built PDF to `latex/PS03.pdf` (presumably for
submission). `scripts/build_pdf.ps1` still writes `latex/main.pdf`, so a rebuild
produces `main.pdf` alongside it — re-copy/rename if a fresh build is needed.

---

## The pipeline — read this before changing anything

Three stages, run in order. Never hand-edit generated output.

```
wsl -d Ubuntu -- bash -c 'cd /mnt/c/Users/kiati/Documents/CPE333-OS/PS03 && ./scripts/run_all.sh'
python3 scripts/make_latex.py
powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1
```

1. **`scripts/run_all.sh`** — compiles `PS3.c`, runs every demo under
   `timeout -k 5 --foreground`, writes `results/*.txt`, then checks: no stray
   `ss1_*.sh` processes, no empty result files, screenshots present. **Exits 1
   on any failure** — do not build a report from a failed run.
2. **`scripts/make_latex.py`** — writes `latex/generated/body.tex` (wiped and
   rewritten every time). Creates stubs in `latex/discussion/` **only if
   absent** and prints `LEFT UNTOUCHED (your prose)` for the rest. The prose is
   never overwritten.
3. **`scripts/build_pdf.ps1`** — two pdfLaTeX passes (no `latexmk`: MiKTeX here
   has no Perl). Deletes a broken `main.pdf` on failure rather than leaving one
   that looks fine. Warns if screenshots are missing.

**Code and transcripts are never copied into `.tex`.** The document pulls them
from `../` and `../results` at compile time with `\lstinputlisting`, so the
report cannot drift from what was actually compiled and run. Keep it that way.

Safe to hand-edit: `latex/main.tex`, `latex/preamble.tex`,
`latex/discussion/*.tex`. Never: `latex/generated/*`.

---

## Hard-won details that are easy to break

**`PS3.c` — only `simulate_stfc()` and its helpers are ours.** The includes,
the `Process` struct and `main()` came with the skeleton and are unchanged
(verified by diffing against the original recovered from the session
transcript). `#include <string.h>` is unused but is **deliberately kept** —
it came with the skeleton, and the report states the includes are as provided.

**The algorithm is event-driven + min-heap, O(n log n).** The report's §3
intro compares three approaches; only the third exists in the file — the other
two are described for contrast, never implemented. Anyone reading the code
looking for them will not find them (a sentence in the intro says so).
Key invariants if you touch it:
- the heap stores **indices into `procs[]`**, not copies — there is exactly one
  record of a remaining time, so nothing needs syncing back;
- `qsort(procs, ...)` sorts the caller's array **in place**; `main()` does not
  use it afterwards, and this is documented in the function's comment;
- `by_arrival` and `runs_first` both tie-break on `pid` — this is the sheet's
  rule and case 3 is the only provided case that tests the remaining-time tie;
- a burst of 0 **must** be marked finished before the loop, or it looks like the
  shortest job forever and the loop never terminates. This was a real hang.

**Verification bar for `PS3.c` changes.** The three cases are not enough. The
established check is: compile with `-Wall -Wextra -pedantic`, confirm the three
cases, then **fuzz 150 random inputs against a reference implementation** plus
edge cases (pids out of order in the file, zero bursts, header-only file, a
single late arrival, 100 processes at heap capacity). Last run: 0 mismatches.
The simple tick-by-tick version makes a good reference — reconstruct it, put it
in the scratchpad, and delete it afterwards.

**Item 2 transcripts are genuine, and that matters.** A script has no keyboard,
so `item2_2_demo.sh` starts `./ss1_2.sh` in the **real foreground** and a
disowned watchdog sends `SIGTSTP` to its process group — the same signal the
terminal driver sends on CTRL+Z. `bg %1` and `fg %1` really execute. Only the
keypress is stood in for, and the report says so. An earlier version faked this
with `echo` and had to be rewritten; do not regress it.

**`pkill`/`pgrep` must stay scoped.** Always `-x` (whole name) and `-P $$` (own
children). A bare `pkill -f <pattern>` previously killed the auditing shell
itself, and `pkill -x sleep` killed unrelated `sleep` processes machine-wide.

**`pgrep -c` prints `0` and exits 1** when nothing matches — take its output and
ignore the status. A `|| echo 0` appends a second zero and breaks the `[` test.

---

## Layout rules already encoded in the generator

Do not fix these by hand in the `.tex`; the generator does them:

- `needspace(rel)` counts a transcript's lines and emits a sized
  `\Needspace*` so a transcript **moves to the next page whole** rather than
  splitting. Guard: over ~a page's worth, it gives up rather than forcing a
  blank page.
- `newpage=True` on the item 5 section emits `\clearpage` — §3 starts on its
  own page.
- `\screenshot` (in `preamble.tex`) caps **both** width and height
  (`0.85\textheight`, `keepaspectratio`) and measures the box with `\sbox`
  before `\Needspace`. Needed because `code.png` is 2.35× taller than it is
  wide and would otherwise run 37 cm off the page.
- A transcript caption of `None` means "the subsection heading already says it".

---

## Working style the user has asked for

- **Brevity above all.** They repeatedly asked to cut: "ขอกระชับ", "เนื้อหาไม่เยอะเลย".
  Prose was trimmed several times. Prefer fewer words over completeness.
- **Only what the sheet asks.** Explanations about *our* tooling (e.g. why
  `top -b -n 1` is needed to capture output) were cut as off-question.
- Report in Thai. Technical identifiers stay in English.
- They will say "ขึ้นหน้าใหม่ไปเลย" for page breaks and expect the fix to be
  general (in the generator), not a one-off `\clearpage` in the body.

## Traps specific to this repo

- **Backslash escaping through heredocs is a repeat offender.** Editing LaTeX
  (`\texttt`, `\&`) via `python3 - <<'PY'` has silently mangled content and
  produced false-positive "success" more than once. **Use the Edit tool for
  anything containing backslashes.**
- **`cd X && ...` where the shell is already in `X`** fails the whole chain
  while a following line still runs and prints success. This caused a rewrite of
  `PS3.c` to silently not happen, and a fuzz run to compare the old code against
  itself. Verify the file actually changed (`grep`/`wc -l`) before trusting a
  result.
- `wsl -d Ubuntu -- bash -lc '...'` mangles `$c` in loops. Write the script to a
  file and run `MSYS_NO_PATHCONV=1 wsl -d Ubuntu -- bash ./script.sh`.
- A PDF viewer holding `main.pdf` open blocks the build; `build_pdf.ps1` detects
  this and names likely culprits.
- Fuzzing leftovers (`_fz/`, `_old`, `_new`, `_old.c`) belong in the scratchpad,
  not `PS03/`. Some were left behind and have been cleaned up.

---

## Suggested skills

- **`mattpocock-skills:code-review`** — if `PS3.c` or the shell demos are
  changed further, review the diff against what the sheet actually asks for.
  The spec here is `PS03/PS3_OS_2026.pdf`, not a repo issue.
- **`mattpocock-skills:diagnosing-bugs`** — if the scheduler output stops
  matching the three expected schedules, or a demo script hangs. Both prior
  bugs (the zero-burst infinite loop, the dropped first slot) were of this shape.
- **`pdf`** — for re-reading the assignment sheet; it is image-based and plain
  text extraction returns nothing.
- No artifact/design skills apply — the deliverable is a LaTeX PDF for LEB2.

## If asked to do more

Most likely follow-ups, in order of likelihood:

1. **Re-take `figures/code.png`.** Long comments wrap mid-word
   (`Left unfini` / `shed it would always`). Cosmetic only; the user was told
   and did not consider it blocking.
2. **Trim further.** Every section has already been through 2–3 rounds; item 1
   cannot fit on one page (measured: ~28.8 cm of content vs 24.7 cm of page)
   without dropping one of the three required transcripts.
3. **Restore the simple tick-by-tick scheduler.** The user asked for the heap
   and was told the trade-off (+2 pages of listing). If they change their mind,
   the tick version is straightforward to write from the current code.
4. **Bring back items 3 and 4.** Would need new research and screenshots; they
   are explicitly out of scope right now.
