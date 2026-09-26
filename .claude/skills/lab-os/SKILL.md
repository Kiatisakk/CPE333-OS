---
name: lab-os
description: Do one CPE 333 OS problem session end to end — read the sheet, grill, run real experiments, build the LaTeX report, commit.
disable-model-invocation: true
argument-hint: <path to the problem-session PDF>
---

# lab-os

One problem session, from sheet to pushed PDF. The report's credibility rests on one rule: **every figure in it is quoted from a captured run at build time**, never typed. Hold that and the rest is layout.

Reference implementation: `PS04/`. Read its `scripts/` and `latex/` before writing anything — reuse, don't reinvent. `PS02/HANDOFF.md` and `PS03/HANDOFF.md` record why the pipeline is shaped this way.

## Steps

### 1. Read the sheet

Read every page of the PDF (it is image-based: use `Read` with `pages`, text extraction returns nothing). List each item and sub-question verbatim. Check the lab folder for existing work — a teammate may have started; inventory it and compare its numbers against its own outputs before trusting any of it.

Done when: every question the sheet asks is listed, including each "Why or why not".

### 2. Grill

Run `/grilling`: rounds of numbered questions with a recommended answer each. Always on the first round:

- **Scope** — which items are in. The user cuts items (PS03 dropped 3–4).
- **Title block** — the sheet header is often stale (PS04 said "CPE 334, 1/2024"); recommend **CPE 333 Operating Systems, 1/2026**.
- **Members** — the four in `PS04/latex/main.tex`, unless the user adds names.
- **Existing work** — rebuild on the pipeline, or keep.

Later rounds: how much output goes in the body, subsection split, and anything the sheet leaves open. Settle from the sheet what it states plainly (run counts, flags) rather than asking.

Done when: the frontier is empty and the user confirms. Write the decisions into the plan.

### 3. Scaffold

```
PSxx/src/            the sheet's programs, numbered by item: 1_foo.c, 1_foo_variant.c
PSxx/scripts/        run_all.sh, make_latex.py, build_pdf.ps1  (adapt PS04's)
PSxx/results/        captured transcripts, one file per item
PSxx/latex/          main.tex, preamble.tex, discussion/, generated/
```

Copy `build_pdf.ps1` and `preamble.tex` from `PS04/` as they are; adapt `make_latex.py` and `run_all.sh`. Commit the lab folder as found before moving or deleting anything in it.

### 4. Run

`run_all.sh` runs in WSL Ubuntu, captures every transcript, and **asserts each claim the report will make** (e.g. "address identical across three runs", "realloc moved a") — exit 1 when one stops being true. Compile the measured binaries with the sheet's exact command; run `-Wall -Wextra` as a separate warnings-only compile.

Done when: `run_all.sh` exits 0 with every assertion passing.

### 5. Generate and write

`make_latex.py` pulls sources and transcripts in with `\lstinputlisting` (line ranges for a single run) and derives any comparison table by parsing `results/`. It rewrites `latex/generated/` every run and writes `latex/discussion/*.tex` only when absent. Keep PS04's `check_coverage()` (every captured block shown) and `needspace()` (a transcript moves to the next page whole).

Write the prose into `latex/discussion/`: formal report register, a few lines per subsection, opening with a direct answer when the sheet asks a yes/no question. Name undefined behaviour as undefined behaviour. Quote only stable values (a `-no-pie` address, a byte offset); leave run-varying numbers to the listings.

### 6. Build and verify

```
powershell -ExecutionPolicy Bypass -File PSxx\scripts\build_pdf.ps1
python3 .claude/skills/lab-os/drift_check.py PSxx
```

Done when: 0 overfull boxes, `drift_check.py` exits 0, and each sheet question from step 1 is answered somewhere in the PDF. Look at the rendered pages (`Read` the PDF) for stranded headings and split transcripts.

### 7. Commit

Commit and push. Commit bodies explain *why*; end with the attribution lines the session supplies.

## The user

- **Brevity.** They ask to cut again and again. Draft short; answer what the sheet asks and nothing about our tooling.
- **Layout requests** ("ขึ้นหน้าใหม่ไปเลย") become a flag in the generator, never a hand-placed `\clearpage` in generated output.
- **Thai** in chat, English in the report.
- **Cleanup** means only what the last action made by mistake — see the auto-memory note.

## Gotchas

- **Backslashes through a heredoc** into Python or LaTeX get mangled silently. Edit `.tex` and generator strings with the `Edit` tool.
- **`cd X && …` while already in `X`** fails the whole chain while a later line still prints success. Verify a write landed (`grep`, `wc -l`) before reporting it.
- **`wsl bash -lc '…'`** eats `$var` in loops: write the script to a file, run `MSYS_NO_PATHCONV=1 wsl -d Ubuntu -- bash ./script.sh`.
- **`pkill`/`pgrep`**: always `-x` and `-P $$`; a bare `-f` pattern matches its own shell. `pgrep -c` prints `0` *and* exits 1.
- **A PDF viewer** holding `main.pdf` blocks the build; `build_pdf.ps1` names the culprit — ask the user to close it.
- **Memory** is tight on this laptop (18 GB, Docker, WSL); long background jobs get killed. Keep watchers light.

## Mini-projects

A mini-project that needs a VM or a long build follows `MiniProject1/scripts/` (`vm.sh`, `wsl.sh`, `vm_steps.sh`): VirtualBox falls back to the Hyper-V API here and compiles ~9× slower than WSL, so build in WSL and install into the VM. Keys, passwords, disks and `.deb`s stay in `C:\Users\kiati\VMs`, outside the public repo.
