#!/usr/bin/env python3
"""Generate the LaTeX report body for CPE 333 PS4.

    python3 scripts/make_latex.py

WHAT THIS WRITES
    latex/generated/*        always overwritten -- never edit these by hand
    latex/discussion/*.tex   written ONLY if absent -- the prose is safe

WHAT THIS NEVER TOUCHES
    latex/main.tex, latex/preamble.tex

Source files and transcripts are NOT copied into the .tex files: the document
pulls them out of ../src and ../results at compile time with \\lstinputlisting.

The address tables are likewise DERIVED from results/ every build rather than
typed by hand. That is the whole point of this generator: the report that
previously lived in PS04/report/ quoted addresses that appeared nowhere in its
own captured output, and a hand-typed table is exactly how that happens.
"""
import io
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LATEX = os.path.join(ROOT, "latex")
GEN = os.path.join(LATEX, "generated")
DISC = os.path.join(LATEX, "discussion")

BLOCK = re.compile(r"^--- (.+), run (\d+) ---$")
ADDR = re.compile(r"0x[0-9a-fA-F]+|\(nil\)")


# --------------------------------------------------------------- parsing ---
def parse(rel):
    """Every labelled block in a transcript.

    Returns [(label, run, first_line, last_line, [body lines])] with 1-based
    line numbers, so a block can be quoted with \\lstinputlisting rather than
    copied into the .tex.
    """
    path = os.path.join(ROOT, rel)
    with io.open(path, encoding="utf-8") as fh:
        lines = fh.read().splitlines()

    blocks, cur = [], None
    for i, line in enumerate(lines, 1):
        m = BLOCK.match(line)
        if m:
            if cur:
                blocks.append(cur)
            cur = [m.group(1), int(m.group(2)), i, i, []]
        elif cur:
            cur[3] = i
            cur[4].append(line)
    if cur:
        blocks.append(cur)

    # trim the blank lines each block ends with
    for b in blocks:
        while b[4] and not b[4][-1].strip():
            b[4].pop()
            b[3] -= 1
    return blocks


def one_run(rel, label, run=1):
    """(first, last) line numbers of one run, for \\lstinputlisting."""
    for lab, n, first, last, _ in parse(rel):
        if lab == label and n == run:
            return first, last
    raise SystemExit("make_latex.py: no block %r run %d in %s" % (label, run, rel))


def all_runs(rel, label):
    """(first, last) spanning every run of one build.

    The sheet says to copy the output into the report, so each subsection
    carries its build's runs in full. Between them the subsections account for
    every block in results/, which is why there is no appendix repeating them.
    """
    hits = [(first, last) for lab, _, first, last, _ in parse(rel) if lab == label]
    if not hits:
        raise SystemExit("make_latex.py: no blocks labelled %r in %s" % (label, rel))
    return hits[0][0], hits[-1][1]


def addr_after(rel, label, run, marker, offset=1):
    """The address `offset` lines below `marker` inside one block."""
    for lab, n, _, _, body in parse(rel):
        if lab != label or n != run:
            continue
        for i, line in enumerate(body):
            if marker in line:
                m = ADDR.search(body[i + offset])
                if m:
                    return m.group(0)
    raise SystemExit("make_latex.py: no %r after %r in %s" % (label, marker, rel))


def addr_in(rel, label, run, marker):
    """The address on the first line of a block matching `marker`."""
    for lab, n, _, _, body in parse(rel):
        if lab != label or n != run:
            continue
        for line in body:
            if marker in line:
                m = ADDR.search(line)
                if m:
                    return m.group(0)
    raise SystemExit("make_latex.py: no %r line in %s run %d" % (marker, label, run))


# --------------------------------------------------------------- helpers ---
def listing(rel, style, caption, extra=""):
    return ("\\lstinputlisting[style=%s%s,caption={%s}]{../%s}"
            % (style, extra, caption, rel))


def csrc(rel):
    return listing(rel, "csrc", "Source: \\texttt{%s}" % rel.replace("_", "\\_"))


QUOTED = set()   # (transcript, label) pairs the document actually shows


def needspace(lines):
    """Ask for enough room that a transcript is not split across a page break.

    A transcript reads as one continuous session, so a break through the middle
    of it is worse than a short page. Listings are \\scriptsize (about 0.62 of a
    normal baselineskip) and the caption costs about two more lines. Anything
    taller than a page cannot be kept together anyway, so above that the request
    is dropped rather than forcing a page it still will not fit on.
    """
    need = int(lines * 0.62) + 3
    if need > 40:
        return r"\headroom"
    return r"\Needspace*{%d\baselineskip}" % need


def _term(rel, label, caption, first, last):
    QUOTED.add((rel, label))
    return "%s\n%s" % (needspace(last - first + 1),
                       listing(rel, "term", caption,
                               ",firstline=%d,lastline=%d" % (first, last)))


def run_listing(rel, label, caption, run=1):
    first, last = one_run(rel, label, run)
    return _term(rel, label, caption, first, last)


def runs_listing(rel, label, caption):
    """Every run of one build, quoted straight out of the transcript."""
    first, last = all_runs(rel, label)
    return _term(rel, label, caption, first, last)


def check_coverage():
    """Every captured run must appear somewhere in the report.

    There is no appendix, so the subsections are the only place output is
    shown. If a build were ever added to run_all.sh and not to the document,
    its runs would silently never reach the report -- this turns that into an
    error instead.
    """
    missing = []
    for rel in (R1, R2, R3):
        for label in dict.fromkeys(lab for lab, _, _, _, _ in parse(rel)):
            if (rel, label) not in QUOTED:
                missing.append("%s: %s" % (rel, label))
    if missing:
        raise SystemExit("make_latex.py: captured but never shown in the "
                         "report:\n  " + "\n  ".join(missing))


def addr_table(caption, rows, headers=None):
    """rows = [(row label, [addr, ...])]; headers defaults to Run 1..Run n."""
    n = len(rows[0][1])
    if headers is None:
        headers = ["Run %d" % (i + 1) for i in range(n)]
    out = [r"\begin{center}", r"\small",
           r"\begin{tabular}{@{}l" + "l" * n + r"@{}}",
           r"\toprule",
           "Build & " + " & ".join(headers) + r" \\",
           r"\midrule"]
    for label, values in rows:
        cells = " & ".join(r"\texttt{%s}" % v for v in values)
        out.append("%s & %s \\\\" % (label, cells))
    out += [r"\bottomrule", r"\end{tabular}",
            r"\captionof{table}{%s}" % caption, r"\end{center}"]
    return "\n".join(out)


# ------------------------------------------------------------- structure ---
R1 = "results/1_static.txt"
R2 = "results/2_extern.txt"
R3 = "results/3_memory.txt"

L1P, L1N = "1_static.c, default PIE", "1_static.c, -no-pie"
L1PA, L1NA = "1_static_no_static.c, default PIE", "1_static_no_static.c, -no-pie"
L2P, L2N = "2_extern.c, default PIE", "2_extern.c, -no-pie"
L2PA, L2NA = "2_extern_no_extern.c, default PIE", "2_extern_no_extern.c, -no-pie"
L3, L3B = "3_memory.c, default PIE", "3_memory_with_b.c, default PIE"


def build_body():
    y = lambda lab, n: addr_in(R1, lab, n, "address of y")          # noqa: E731
    x = lambda lab, n, w: addr_in(R2, lab, n, "in %s function" % w)  # noqa: E731

    out = ["% GENERATED by scripts/make_latex.py -- DO NOT EDIT", ""]

    def sec(title):
        out.extend([r"\headroom", r"\section{%s}" % title, ""])

    def sub(title, key, blocks):
        out.extend([r"\headroom", r"\subsection{%s}" % title, ""])
        out.extend(blocks)
        out.append(r"\input{discussion/%s}" % key)
        out.append("")

    # ---------------------------------------------------------- item 1 ---
    sec("Static Storage Class")
    sub(r"The original program", "item1_1", [
        csrc("src/1_static.c"), "",
        runs_listing(R1, L1P, "All three runs of the original program"), "",
    ])
    sub(r"With \texttt{static} removed", "item1_2", [
        csrc("src/1_static_no_static.c"), "",
        runs_listing(R1, L1PA, "All three runs after removing \\texttt{static}"), "",
    ])
    sub(r"Compiled with \texttt{-no-pie}", "item1_3", [
        runs_listing(R1, L1N,
                     "The original program rebuilt with \\texttt{-no-pie}"), "",
        runs_listing(R1, L1NA,
                     "The \\texttt{static}-less program with \\texttt{-no-pie}"), "",
        r"\headroom",
        addr_table(
            "Address of \\texttt{y} in each of the three runs",
            [(r"\texttt{static}, default PIE", [y(L1P, n) for n in (1, 2, 3)]),
             (r"\texttt{static}, \texttt{-no-pie}", [y(L1N, n) for n in (1, 2, 3)]),
             (r"no \texttt{static}, default PIE", [y(L1PA, n) for n in (1, 2, 3)]),
             (r"no \texttt{static}, \texttt{-no-pie}", [y(L1NA, n) for n in (1, 2, 3)])]),
        "",
    ])

    # ---------------------------------------------------------- item 2 ---
    sec("Extern Storage Class")
    sub(r"The original program", "item2_1", [
        csrc("src/2_extern.c"), "",
        runs_listing(R2, L2P, "All three runs of the original program"), "",
    ])
    sub(r"With \texttt{extern} removed from \texttt{main()}", "item2_2", [
        csrc("src/2_extern_no_extern.c"), "",
        runs_listing(R2, L2PA,
                     "All three runs after removing \\texttt{extern}"), "",
    ])
    sub(r"Compiled with \texttt{-no-pie}", "item2_3", [
        runs_listing(R2, L2N,
                     "The original program rebuilt with \\texttt{-no-pie}"), "",
        runs_listing(R2, L2NA,
                     "The \\texttt{extern}-less program with \\texttt{-no-pie}"), "",
        r"\headroom",
        addr_table(
            "Address of \\texttt{x} in each of the three runs",
            [(r"global \texttt{x}, default PIE", [x(L2P, n, "main") for n in (1, 2, 3)]),
             (r"global \texttt{x}, \texttt{-no-pie}", [x(L2N, n, "main") for n in (1, 2, 3)]),
             (r"local \texttt{x} in \texttt{main}, default PIE",
              [x(L2PA, n, "main") for n in (1, 2, 3)]),
             (r"local \texttt{x} in \texttt{main}, \texttt{-no-pie}",
              [x(L2NA, n, "main") for n in (1, 2, 3)])]),
        "",
    ])

    # ---------------------------------------------------------- item 3 ---
    sec("Memory Allocation")
    sub(r"The original program", "item3_1", [
        csrc("src/3_memory.c"), "",
        run_listing(R3, L3, "The program as given"), "",
    ])
    sub(r"With the allocation of \texttt{b} enabled", "item3_2", [
        csrc("src/3_memory_with_b.c"), "",
        run_listing(R3, L3B, "The same program with \\texttt{b} allocated"), "",
        r"\headroom",
        addr_table(
            "Where \\texttt{a} lives before and after \\texttt{realloc()}",
            [(r"without \texttt{b}",
              [addr_after(R3, L3, 1, "After malloc Pointer a"),
               addr_after(R3, L3, 1, "After realloc Pointer a")]),
             (r"with \texttt{b}",
              [addr_after(R3, L3B, 1, "After malloc Pointer a"),
               addr_after(R3, L3B, 1, "After realloc Pointer a")])],
            headers=[r"After \texttt{malloc}", r"After \texttt{realloc}"]),
        "",
    ])

    check_coverage()

    # No appendix: between them the subsections above already quote every
    # block in results/, so an appendix would only repeat them.

    with io.open(os.path.join(GEN, "body.tex"), "w",
                 encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


KEYS = ["item1_1", "item1_2", "item1_3",
        "item2_1", "item2_2", "item2_3",
        "item3_1", "item3_2"]


def build_discussion_stubs():
    """Written ONCE. Existing files are left completely alone."""
    created, kept = [], []
    for key in KEYS:
        path = os.path.join(DISC, "%s.tex" % key)
        if os.path.exists(path):
            kept.append(os.path.basename(path))
            continue
        with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("%% Discussion for %s -- prose goes here.\n"
                     "%% scripts/make_latex.py will NEVER overwrite this file.\n\n"
                     "\\todoprose{Not written yet.}\n" % key)
        created.append(os.path.basename(path))
    return created, kept


def main():
    if os.path.isdir(GEN):
        shutil.rmtree(GEN)
    os.makedirs(GEN)
    os.makedirs(DISC, exist_ok=True)

    build_body()
    created, kept = build_discussion_stubs()

    print("regenerated latex/generated/ (%d files)" % len(os.listdir(GEN)))
    if created:
        print("created discussion stubs   : %s" % ", ".join(created))
    if kept:
        print("LEFT UNTOUCHED (your prose): %s" % ", ".join(kept))
    print("\nnext:  powershell -ExecutionPolicy Bypass -File scripts\\build_pdf.ps1")


if __name__ == "__main__":
    main()
