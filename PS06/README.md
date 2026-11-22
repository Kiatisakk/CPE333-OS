# PS06

Operating Systems Problem Session 6: Virtual Memory.

This directory contains a reproducible report template, a Linux collection
script, captured figures, and the LaTeX build. Run the Linux experiment on your
own Ubuntu/WSL installation, then replace the figures and update the discussion
numbers with the values from your machine.

## Contents

- `latex/main.tex`: report root (hand-edited)
- `latex/preamble.tex`: packages and listing styles (hand-edited)
- `latex/discussion/`: prose, one file per subsection (hand-edited, never
  overwritten by the generator)
- `latex/generated/`: report body (DO NOT EDIT, rewritten by
  `scripts/make_latex.py`)
- `figures/`: Linux terminal and Windows Resource Monitor screenshots
- `results/complete_linux_output.txt`: cleaned Linux command output
- `scripts/collect_linux.sh`: collects the Linux commands and the temporary swap experiment
- `scripts/render_terminal_figures.py`: renders the collected transcript as terminal figures
- `scripts/make_latex.py`: rebuilds `latex/generated/body.tex`
- `scripts/build_pdf.ps1`: builds `latex/main.pdf` with pdfLaTeX

## Collect the Linux experiment

Open Ubuntu/WSL and run:

```bash
cd /mnt/c/Users/kiati/Documents/CPE333-OS/PS06
chmod +x scripts/collect_linux.sh
./scripts/collect_linux.sh
```

The script records `free`, `vmstat`, and `swapon` output in
`results/complete_linux_output.txt`. It creates `/swapfile_ps6`, enables it,
records the increased swap total, disables it, and removes it. It refuses to
run if that path already exists. Keep the terminal visible while running the
script and capture the required screenshots at the corresponding stages.

After collecting the output, render the five Linux figures with:

```powershell
python scripts\render_terminal_figures.py
```

## Collect the Windows part

From PowerShell run `resmon`, select the **Memory** tab, and capture the
interface showing the Physical Memory bar, process table, and graphs. Save it as
`figures/windows_memory.png`. Record Hardware Reserved, In Use, Modified,
Standby, Free, Available, Cached, Total, Installed, and the usage percentage in
`latex/discussion/item3_3.tex`.

Save the Linux screenshots as `free_overview.png`, `free_samples.png`,
`vmstat_overview.png`, `vmstat_samples.png`, and `swap_experiment.png` under
`figures/`. Update the numeric summaries in the corresponding files under
`latex/discussion/` so the prose matches your new transcript and images.

## Build the report

```powershell
python scripts/make_latex.py
powershell -ExecutionPolicy Bypass -File scripts\build_pdf.ps1
```
