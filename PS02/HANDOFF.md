# Handoff — CPE 333 PS2 (Process Creation & Pipes)

**Written:** 2026-08-23
**Workspace:** `C:\Users\kiati\Documents\CPE333-OS\PS02` (not a git repo)
**User language:** replies in Thai; code/comments/report in English (their choice)

---

## Existing artifacts — read these first, do not re-derive

| Path | What it holds |
|---|---|
| `..\..\..\.claude\plans\c-users-kiati-documents-cpe333-os-ps02-u-composed-moth.md` | Approved plan: full lab breakdown, every design decision and its rationale, verification criteria |
| `latex\main.tex` | Deliverable master doc. **Hand-edited** — group names go here |
| `latex\preamble.tex` | Packages + listing styles. **Hand-edited** |
| `latex\discussion\item{1..5}.tex` | **The user's prose.** Stubs written once, never regenerated |
| `latex\generated\*` | **Auto — do not edit.** Wiped and rewritten every run |
| `scripts\make_latex.py` | Regenerates `latex/generated/` and writes missing discussion stubs |
| `scripts\build_pdf.ps1` | Builds `latex/main.pdf` (pdflatex ×2) |
| `results\*.txt` | Real captured transcripts of every experiment |
| `UTF-8_PS2_2026.pdf` | The assignment |
| `UTF-8_Lecture2_ProcessAndProcessAPIs.pdf` | Slide source for item 1 (fork hello world; wait() example) |

The plan file lives outside this folder, under the user's `.claude\plans\` directory.
It still describes `REPORT.md`, which has since been retired — see below.

## The report is LaTeX now — `REPORT.md` is gone

`REPORT.md` and `scripts/make_report.py` were **deleted** on the user's explicit
instruction once the LaTeX build was verified. Do not resurrect them.

The LaTeX setup fixes the flaw the Markdown one had. Code and full transcripts are
**not copied** into the `.tex` files — the document pulls them from `../src` and
`../results` at compile time via `\lstinputlisting`, so it cannot drift. And the
generator writes `latex/discussion/*.tex` **only if absent**, so regenerating never
destroys the user's prose. It prints `LEFT UNTOUCHED (your prose)` to confirm.

Build (verified working: 25 pages, 0 overfull boxes):

```powershell
python3 scripts/make_latex.py                              # via WSL
powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1
```

**`latexmk` does not work here** — MiKTeX 25.12 is installed but has no Perl script
engine. `build_pdf.ps1` calls `pdflatex` twice instead. Engine is **pdfLaTeX**
(the user's choice), so **Thai characters will fail to build**; `preamble.tex`
carries a commented XeLaTeX + Leelawadee UI block and `build_pdf.ps1 -Xe` switches
to it if Thai names are ever needed.

## Status: complete and verified

All 10 programs build clean under `-Wall -Wextra`, all experiments run for real in
WSL2 Ubuntu, all results captured. Verification criteria in the plan file are met.

The one deliberate omission: **the Discussion sections are left blank on purpose.**
The user writes those themselves — an explicit decision, not an oversight. Each
`latex/discussion/item*.tex` holds a yellow `\todoprose` box listing the questions
that section must answer. Do not fill them in unless the user asks.

Remaining for the user: fill in group members in `latex/main.tex` + write the 5
discussion files + rebuild the PDF for LEB2 submission.

## Open question — unanswered

The last thing asked of the user, still unanswered:

> Should the uncapped fork experiment (see below) be added to the report as a
> sub-section of item 3? (It would mean a new `\subsection` in `make_latex.py`'s
> item-3 entry plus a transcript under `results/`.)

Do not assume an answer. Ask again if it becomes relevant.

## Environment facts (already verified, don't re-check)

- WSL2 Ubuntu, `gcc 15.2.0`, 8 CPUs, kernel `6.18.33.2-microsoft-standard-WSL2`
- Invoke as: `wsl.exe -d Ubuntu -e bash -lc 'cd /mnt/c/Users/kiati/Documents/CPE333-OS/PS02 && ...'`
- `ulimit -u` = 35595; `pid_max` = 4194304; no cgroup pids limit
- WSL memory allocation 8.9 GB; host physical RAM 17.9 GB; no `.wslconfig` present
- PID 1 is `systemd`, but orphans reparent to the session's `Relay(...)` process
  (a child subreaper) — this is WSL-specific and is documented as a caveat in the report

## Three findings that must not be lost

These came out of running the code and are already reflected in the report's
discussion prompts. They matter because each contradicts a naive expectation.

1. **Item 1.1's output order never actually varies here.** The slide says it "is not
   deterministic", but measured over 300 runs the parent printed first 300/300
   (`results/1_ordering_stats.txt`). The genuine flip is visible in
   `results/4_pipe_race.txt`. Do not let the report claim the 1.1 order varies —
   the user's own data does not show that.

2. **`hello world` prints twice under plain redirection**, once with line buffering.
   `fork()` copies the not-yet-flushed stdio buffer. Both variants are captured in
   `results/1_1_fork_hello.txt`.

3. **Orphans do not go to PID 1 on WSL.** They go to `Relay(...)`. Evidence is
   captured in `results/2_ps_snapshot.txt`.

## Uncapped fork experiment — results and a hard safety lesson

`src/3_fork_count.c` takes an argument: no arg = cap 500 (the report's numbers,
463/263/463, unchanged), `<N>` = cap N, `none` = no artificial cap.

`scripts/uncapped_probe.sh` runs the uncapped case with a memory guard and
process-group cleanup. It is **deliberately not wired into `run_all.sh`** — it must
never run unattended. It was written but has not yet been run end to end; the numbers
below come from a supervised interactive probe of the same experiment.

- Memory cost per forked process is **not constant** — it rises: ~552 kB at n≈965,
  ~2.64 MB marginal at n≈3,000–3,750.
- **Empirical ceiling on this machine: ~4,100 processes**, memory-bound. The guard
  stopped it at 4,106 with 897 MB free.
- `RLIMIT_NPROC` (35,595) is **unreachable here** — would need ≳90 GB against 17.9 GB
  physical. The real limit is RAM, not the configured process limit.
- Forking slows to ~5 processes/sec at n≈3,000. A cap-10,000 run took 645 s and never
  got there.

**Safety lesson — this cost real time to recover from:**

`pkill -9 -x 3_fork_count` **cannot** kill this chain. It loses a race: the deepest
process forks a replacement between pkill's scan and its signal, so the chain
regenerates from the survivor. Six passes failed; `SIGSTOP`-then-kill also failed
(7 unstopped survivors each pass, growing by 8).

What worked, first try:

```bash
# find the group, then kill the whole group atomically (leading '-' on the PGID)
ps -u $(id -u) -o pgid=,comm= | awk '$2=="3_fork_count"{print $1}' | sort -u
kill -KILL -<PGID>
```

PGID is inherited across `fork()` and survives reparenting, so it catches every
member at once. **If you run anything uncapped, know the PGID before you start.**

Machine was returned to baseline afterwards (6 processes, 8.3 GB free) — verified.

## Working conventions established with this user

- They chose the recommended option every time when given options with a rationale.
- Present options with a clear recommendation and the reasoning; don't survey.
- Be explicit when the data does **not** support a claim they might want to make —
  they valued the corrections about the 1.1 ordering and the bad extrapolation.
- Never hand-edit `latex/generated/*`; change `src/`/`results/` and re-run
  `make_latex.py`. Regenerating is now **safe** — discussion prose is never touched.
- `results/*.txt` are captured transcripts. Regenerate them with `scripts/run_all.sh`,
  never by editing.

## Suggested skills

- **`mattpocock-skills:grilling`** — how this session ran. Use it before any new
  chunk of work: interrogate the frontier of open decisions in rounds, numbered
  questions with a recommended answer each, wait for answers. It is why the plan
  had no loose ends.
- **`mattpocock-skills:domain-modeling`** — if the work grows enough to need pinned
  terminology (zombie / orphan / defunct / subreaper / byte-stream framing) or an
  ADR for a decision like "discussion stays unwritten".
- **`pdf`** — if anything further needs extracting from the two source PDFs. The
  report PDF itself is built by `scripts/build_pdf.ps1`, not by this skill.
- **`mattpocock-skills:writing-for-agents`** — only if editing this handoff or
  adding project instructions.

Do **not** reach for `mattpocock-skills:tdd` or `diagnosing-bugs`; nothing here is
failing and the programs are teaching artifacts, not production code.
