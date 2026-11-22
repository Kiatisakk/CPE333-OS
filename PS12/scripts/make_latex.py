#!/usr/bin/env python3
"""Generate the LaTeX report body for CPE 333 PS12.

    python3 scripts/make_latex.py

WHAT THIS WRITES
    latex/generated/*        always overwritten -- never edit these by hand
    latex/discussion/*.tex   written ONLY if absent -- the prose is safe

All transcripts are pulled in with \\lstinputlisting at compile time, and all
summary tables and captured constants are parsed out of results/ on every build,
so no figure in the report is ever typed by hand.
"""
import io
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LATEX = os.path.join(ROOT, "latex")
GEN = os.path.join(LATEX, "generated")
DISC = os.path.join(LATEX, "discussion")

BLOCK = re.compile(r"^--- ([a-z0-9_]+): (.+) ---$")

QUOTED = set()   # (rel, label) pairs the document actually shows


# --------------------------------------------------------------- parsing ---
def parse(rel):
    """[(label, desc, first_line, last_line, body)] with 1-based line numbers."""
    with io.open(os.path.join(ROOT, rel), encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    blocks, cur = [], None
    for i, line in enumerate(lines, 1):
        m = BLOCK.match(line)
        if m:
            if cur:
                blocks.append(cur)
            cur = [m.group(1), m.group(2), i, i, []]
        elif cur:
            cur[3] = i
            cur[4].append(line)
    if cur:
        blocks.append(cur)
    for b in blocks:
        while b[4] and not b[4][-1].strip():
            b[4].pop()
            b[3] -= 1
    return blocks


def get_block(rel, label):
    for lab, desc, first, last, body in parse(rel):
        if lab == label:
            return first, last, body
    raise SystemExit("make_latex.py: no block %r in %s" % (label, rel))


def parse_captured_values():
    """Extract dynamic figures directly from results/ so prose never hard-codes them."""
    vals = {}

    # Lab 1 Windows dir /s line count
    _, _, w4 = get_block(R_WIN, "win_item4")
    m = next((re.search(r"total lines produced by dir /s parent: (\d+)", l) for l in w4
              if "total lines produced by dir /s parent:" in l), None)
    if not m:
        raise SystemExit("make_latex.py: could not parse dir /s line count from %s" % R_WIN)
    vals["winDirLines"] = "{:,}".format(int(m.group(1)))

    # Lab 3 gnucat four key lines
    _, _, g3 = get_block(R_STRACE, "lab3_strace_gnucat")
    m_open = next((re.match(r'^openat\(.*"foo".*\)\s*=\s*(\d+)$', l) for l in g3
                   if re.match(r'^openat\(.*"foo".*\)\s*=\s*(\d+)$', l)), None)
    m_r1 = next((re.match(r'^read\((\d+), "hello\\n", (\d+)\)\s*=\s*(\d+)$', l) for l in g3
                 if re.match(r'^read\((\d+), "hello\\n", (\d+)\)\s*=\s*(\d+)$', l)), None)
    m_w1 = next((re.match(r'^write\((\d+), "hello\\n", (\d+)\)\s*=\s*(\d+)$', l) for l in g3
                 if re.match(r'^write\((\d+), "hello\\n", (\d+)\)\s*=\s*(\d+)$', l)), None)
    m_r2 = next((re.match(r'^read\((\d+), "", (\d+)\)\s*=\s*(\d+)$', l) for l in g3
                 if re.match(r'^read\((\d+), "", (\d+)\)\s*=\s*(\d+)$', l)), None)
    m_cl = next((re.match(r'^close\((\d+)\)\s*=\s*(\d+)$', l) for l in g3
                 if re.match(r'^close\((\d+)\)\s*=\s*(\d+)$', l)), None)
    if not all([m_open, m_r1, m_w1, m_r2, m_cl]):
        raise SystemExit("make_latex.py: missing expected Lab 3 syscalls in %s" % R_STRACE)

    vals["straceReadFd"] = m_r1.group(1)
    vals["straceBufSize"] = m_r1.group(2)
    vals["straceBufKiB"] = str(int(m_r1.group(2)) // 1024)
    vals["straceBytes"] = m_r1.group(3)
    vals["straceWriteFd"] = m_w1.group(1)
    vals["straceEofRet"] = m_r2.group(3)
    vals["straceCloseRet"] = m_cl.group(2)

    # Lab 3 uutils splice chunk size
    _, _, u3 = get_block(R_STRACE, "lab3_strace_uutils")
    m_sp = next((re.match(r'^splice\(3, NULL, 5, NULL, (\d+), 0\)\s*=\s*(\d+)$', l) for l in u3
                 if re.match(r'^splice\(3, NULL, 5, NULL, (\d+), 0\)\s*=\s*(\d+)$', l)), None)
    if not m_sp:
        raise SystemExit("make_latex.py: missing expected uutils splice line in %s" % R_STRACE)
    vals["uutilsSpliceSize"] = m_sp.group(1)
    vals["uutilsSpliceMiB"] = str(int(m_sp.group(1)) // (1024 * 1024))

    return vals


# --------------------------------------------------------------- helpers ---
def listing(rel, style, caption, extra=""):
    return ("\\lstinputlisting[style=%s%s,caption={%s}]{../%s}"
            % (style, extra, caption, rel))


def needspace(lines, line_pt=9.5):
    """Keep a listing on one page: ask for its height, or give up if it could
    never fit. Heights are in body baselineskips (13.6pt); a page holds ~51.
    line_pt is the listing's own line height: 9.5 for \\scriptsize, 8.6 for
    the termsmall style."""
    need = int(lines * line_pt / 13.6 + 0.999) + 3
    return r"\headroom" if need > 51 else r"\Needspace*{%d\baselineskip}" % need


def block_listing(rel, label, caption, style="term", reserve=True):
    first, last, _ = get_block(rel, label)
    QUOTED.add((rel, label))
    nlines = last - first + 1
    # Automatically step down to termsmall for tall blocks so they fit on one page
    if style == "term" and nlines > 42:
        style = "termsmall"
    line_pt = 8.6 if style == "termsmall" else 9.5
    lst = listing(rel, style, caption, ",firstline=%d,lastline=%d" % (first, last))
    if reserve:
        return "%s\n%s" % (needspace(nlines, line_pt=line_pt), lst)
    return lst


def block_lines(rel, label):
    first, last, _ = get_block(rel, label)
    return last - first + 1


def screenshot_fig(filename, caption, covers=None, width=r"0.92\linewidth"):
    rel = "results/screenshots/" + filename
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        raise SystemExit("make_latex.py: missing screenshot %s" % rel)
    if covers:
        QUOTED.add(covers)
    return "\n".join([
        r"\Needspace*{18\baselineskip}",
        r"\begin{center}",
        r"\includegraphics[width=%s]{../%s}" % (width, rel),
        r"\captionof{figure}{%s}" % caption,
        r"\end{center}",
    ])


def strace_table(vals):
    """Derived summary of the four key syscalls and numbers from 3_strace.txt."""
    fd = vals["straceReadFd"]
    wfd = vals["straceWriteFd"]
    nb = vals["straceBytes"]
    bs = vals["straceBufSize"]
    bs_kib = vals["straceBufKiB"]
    out = [
        r"\Needspace*{14\baselineskip}",
        r"\begin{center}",
        r"\small",
        r"\begin{tabular}{@{}llp{8.2cm}@{}}",
        r"\toprule",
        r"Number & Observed in & Meaning \\",
        r"\midrule",
        r"\texttt{%s} & \texttt{openat}, \texttt{read}, \texttt{close} & "
        r"File descriptor assigned to \texttt{foo} (lowest unused slot after \texttt{0}=stdin, "
        r"\texttt{1}=stdout, \texttt{2}=stderr). \\" % fd,
        r"\texttt{%s} & \texttt{write(%s, \ldots)} & "
        r"File descriptor of standard output (\texttt{stdout}). \\" % (wfd, wfd),
        r"\texttt{%s} & \texttt{read} return, \texttt{write} count/return & "
        r"Byte count of \texttt{foo} (\texttt{hello\textbackslash n}: 5 ASCII letters plus 1 newline, matching \texttt{wc -c foo}). \\" % nb,
        r"\texttt{%s} & \texttt{read(%s, \ldots, %s)} & "
        r"Maximum buffer size (\SI-free: %s\,KiB) requested by GNU \texttt{cat} 9.7; plays the same role as \texttt{32768} (32\,KiB) on older \texttt{cat} builds. \\" % (bs, fd, bs, bs_kib),
        r"\bottomrule",
        r"\end{tabular}",
        r"\captionof{table}{Lab 3 syscall parameters derived from \texttt{results/3\_strace.txt}}",
        r"\end{center}",
    ]
    return "\n".join(out).replace(r"(\SI-free: ", "(")


def check_coverage():
    """Every transcript file and every labelled block in results/ must appear in the report."""
    files = sorted("results/" + f for f in os.listdir(os.path.join(ROOT, "results"))
                   if f.endswith(".txt"))
    missing = []
    for rel in files:
        blocks = parse(rel)
        if not blocks:
            missing.append("%s (no labelled blocks)" % rel)
            continue
        for lab, _, _, _, _ in blocks:
            if (rel, lab) not in QUOTED:
                missing.append("%s: %s" % (rel, lab))
    if missing:
        raise SystemExit("make_latex.py: captured but never shown:\n  " + "\n  ".join(missing))


# ------------------------------------------------------------- structure ---
R_LIN = "results/1_links_linux.txt"
R_WIN = "results/1_links_windows.txt"
R_FIFO = "results/2_fifo.txt"
R_STRACE = "results/3_strace.txt"

KEYS = [
    "lab1_item1_2",
    "lab1_item3",
    "lab1_item4",
    "lab1_item5",
    "lab2_fifo",
    "lab3_strace",
]


def build_values(vals):
    lines = ["% GENERATED by scripts/make_latex.py -- DO NOT EDIT"]
    for k, v in sorted(vals.items()):
        lines.append(r"\newcommand{\%s}{%s}" % (k, v))
    with io.open(os.path.join(GEN, "values.tex"), "w", encoding="utf-8",
                 newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")


def build_body(vals):
    out = [
        "% GENERATED by scripts/make_latex.py -- DO NOT EDIT",
        r"\input{generated/values}",
        "",
    ]

    def sec(title, newpage=False, reserve_block=None):
        if newpage:
            out.append(r"\clearpage")
        if reserve_block:
            rel, lab, style = reserve_block
            lpt = 8.6 if style == "termsmall" else 9.5
            out.append(needspace(block_lines(rel, lab) + 6, line_pt=lpt))
        out.extend([r"\headroom", r"\section{%s}" % title, ""])

    def sub(title, key, blocks, newpage=False, reserve_block=None):
        if newpage:
            out.append(r"\clearpage")
        if reserve_block:
            rel, lab, style = reserve_block
            lpt = 8.6 if style == "termsmall" else 9.5
            out.append(needspace(block_lines(rel, lab) + 6, line_pt=lpt))
        out.extend([r"\headroom", r"\subsection{%s}" % title, ""])
        out.extend(blocks)
        out.extend([r"\input{discussion/%s}" % key, ""])

    # ------------------------------------------------------------ Lab 1 ---
    sec("Lab 1: Symbolic and Hard Links (Linux and Windows)")

    sub("Creating Hard and Symbolic Links and Deleting the Source",
        "lab1_item1_2", [
            screenshot_fig("lab1_item1_2_linux.png",
                           r"Linux terminal screenshot: creating hard/symbolic links and deleting \texttt{source.txt}",
                           covers=(R_LIN, "lab1_item1_2")), "",
            screenshot_fig("lab1_item1_2_windows.png",
                           r"Windows Command Prompt screenshot: \texttt{mklink} and \texttt{mklink /H} before and after \texttt{del source.txt}",
                           covers=(R_WIN, "win_item1_2")), "",
        ])

    sub("Multi-Level Links (Level 1 and Level 2)",
        "lab1_item3", [
            screenshot_fig("lab1_item3_linux.png",
                           r"Linux terminal screenshot: level-1 and level-2 symbolic and hard link chains",
                           covers=(R_LIN, "lab1_item3")), "",
            screenshot_fig("lab1_item3_windows.png",
                           r"Windows Command Prompt screenshot: level-1 and level-2 symbolic and hard link chains",
                           covers=(R_WIN, "win_item3")), "",
        ])

    sub("Links to Directories and Recursive Loop Traversal",
        "lab1_item4", [
            screenshot_fig("lab1_item4_linux.png",
                           r"Linux terminal screenshot: directory links, loop symlink, \texttt{ls -R}, \texttt{ls -RL}, and \texttt{find -L}",
                           covers=(R_LIN, "lab1_item4")), "",
            screenshot_fig("lab1_item4_windows.png",
                           r"Windows Command Prompt screenshot: \texttt{mklink /D}, \texttt{/H}, \texttt{/J}, junction loop, and \texttt{dir /s}",
                           covers=(R_WIN, "win_item4")), "",
        ])

    sub("Cross-Drive and Cross-Filesystem Links (Drive D: to Drive C:)",
        "lab1_item5", [
            screenshot_fig("lab1_item5_windows.png",
                           r"Windows Command Prompt screenshot: \texttt{subst D:} to a folder on \texttt{C:} and \texttt{mklink} tests",
                           covers=(R_WIN, "win_item5")), "",
            screenshot_fig("lab1_item5_linux.png",
                           r"Linux terminal screenshot: cross-filesystem \texttt{ln} (EXDEV) vs.\ \texttt{ln -s} between \texttt{/tmp} and \texttt{/dev/shm}",
                           covers=(R_LIN, "lab1_item5")), "",
        ])

    # ------------------------------------------------------------ Lab 2 ---
    sec("Lab 2: Linux's File Type --- Named Pipe (FIFO)", newpage=True)
    out.extend([
        screenshot_fig("lab2_fifo_linux.png",
                       r"Linux terminal screenshot: \texttt{mkfifo pipeFile}, \texttt{ls -la}, and two-terminal FIFO transfer",
                       covers=(R_FIFO, "lab2_fifo")), "",
        screenshot_fig("lab2_fifo_diagram.png",
                       r"Named pipe (FIFO) architecture and 3-phase blocking/streaming/EOF execution flow",
                       width=r"0.96\linewidth"), "",
        r"\input{discussion/lab2_fifo}", "",
    ])

    # ------------------------------------------------------------ Lab 3 ---
    sec(r"Lab 3: Reading and Writing Files (\texttt{strace})", newpage=True)
    out.extend([
        screenshot_fig("lab3_strace_gnucat_linux.png",
                       r"Linux terminal screenshot: \texttt{strace gnucat foo} showing \texttt{openat}, \texttt{read}, \texttt{write}, \texttt{read} (EOF), and \texttt{close}",
                       covers=(R_STRACE, "lab3_strace_gnucat")), "",
        screenshot_fig("lab3_strace_uutils_linux.png",
                       r"Linux terminal screenshot: \texttt{strace cat foo} on Ubuntu default \texttt{uutils} \texttt{cat} using \texttt{splice()}",
                       covers=(R_STRACE, "lab3_strace_uutils")), "",
        strace_table(vals), "",
        r"\input{discussion/lab3_strace}", "",
    ])

    check_coverage()
    with io.open(os.path.join(GEN, "body.tex"), "w", encoding="utf-8",
                 newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


def build_discussion_stubs():
    """Written ONCE. Existing files are left completely alone."""
    created, kept = [], []
    for key in KEYS:
        path = os.path.join(DISC, "%s.tex" % key)
        if os.path.exists(path):
            kept.append(os.path.basename(path))
            continue
        with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("%% Discussion for %s -- never overwritten by make_latex.py.\n\n"
                     "\\todoprose{Not written yet.}\n" % key)
        created.append(os.path.basename(path))
    return created, kept


def main():
    if os.path.isdir(GEN):
        shutil.rmtree(GEN)
    os.makedirs(GEN)
    os.makedirs(DISC, exist_ok=True)
    vals = parse_captured_values()
    build_values(vals)
    build_body(vals)
    created, kept = build_discussion_stubs()
    if created:
        print("created discussion stubs   : %s" % ", ".join(created))
    if kept:
        print("LEFT UNTOUCHED (your prose): %s" % ", ".join(kept))
    print("generated latex/generated/body.tex and values.tex successfully.")


if __name__ == "__main__":
    main()
