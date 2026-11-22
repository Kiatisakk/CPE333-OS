# Implementation summary

The Mini-Project 1 report is in `latex/` and follows the PS02-PS04 layout:

- `latex/main.tex` contains the document shell and the complete six-member author block.
- `latex/preamble.tex` contains the shared A4, listings, caption, and page-breaking style.
- `latex/generated/body.tex` contains the report prose, Canonical guide link, environment table, transcript listings, and embedded evidence figures.
- `latex/figures/` contains the three captured WSL/VM screenshots embedded in the report.
- `scripts/make_evidence.ps1` derives small evidence excerpts from the full verified logs.
- `scripts/build_pdf.ps1` regenerates the excerpts and builds `latex/MiniProject1.pdf` with two pdfLaTeX passes.
- `Evidence-Screenshot-Checklist.md` records which logs are used and states that no screenshots were invented.
- `Potential-Issues.md` records evidence and reproducibility limits.

The report covers the complete observed flow: VM baseline and swap setup, source repositories and package installation, source retrieval and cleanup, ABI 999 modification, VM partial build, successful WSL build, package transfer and installation, dependency repair with `dpkg --configure -a`, reboot, and `uname` verification. The final PDF is 13 A4 pages and builds with zero overfull or underfull boxes.
