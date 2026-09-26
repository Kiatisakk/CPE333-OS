#!/usr/bin/env python3
"""Drift check for a lab report: every number in the PDF must come from results/.

    python3 .claude/skills/lab-os/drift_check.py PS05

Checks both directions for hex addresses (0x...): nothing in the PDF that was
never captured, nothing captured that the PDF never shows. Exits 1 on drift.
Needs pypdf (pip install pypdf).
"""
import glob
import os
import re
import sys

from pypdf import PdfReader

lab = sys.argv[1] if len(sys.argv) > 1 else "."
pdf = os.path.join(lab, "latex", "main.pdf")
if not os.path.exists(pdf):
    # the user renames the submitted copy (PS04.pdf); take the newest PDF there
    pdfs = glob.glob(os.path.join(lab, "latex", "*.pdf"))
    if not pdfs:
        sys.exit("no PDF in %s/latex" % lab)
    pdf = max(pdfs, key=os.path.getmtime)
print("checking", pdf)
text = "\n".join((p.extract_text() or "") for p in PdfReader(pdf).pages)
captured = "".join(open(f, encoding="utf-8", errors="replace").read()
                   for f in glob.glob(os.path.join(lab, "results", "**", "*.txt"),
                                      recursive=True))

HEX = re.compile(r"0x[0-9a-f]{4,}")
shown, caught = set(HEX.findall(text)), set(HEX.findall(captured))
invented = sorted(a for a in shown if a not in captured)
unshown = sorted(a for a in caught if a not in text)

print("pages: %d | addresses captured %d, shown %d"
      % (len(PdfReader(pdf).pages), len(caught), len(shown)))
print("in PDF but never captured:", invented or "none")
print("captured but not in PDF   :", unshown or "none")
sys.exit(1 if invented else 0)
