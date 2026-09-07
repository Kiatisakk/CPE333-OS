#!/usr/bin/env python3
"""Generate the LaTeX report body for CPE 333 PS3.

    python3 scripts/make_latex.py

WHAT THIS WRITES
    latex/generated/*        always overwritten -- never edit these by hand
    latex/discussion/*.tex   written ONLY if absent -- the prose is safe

WHAT THIS NEVER TOUCHES
    latex/main.tex, latex/preamble.tex

Code and transcripts are NOT copied into the .tex files: the document pulls
them out of ../ and ../results at compile time with \\lstinputlisting, so the
report cannot drift from what was actually compiled and run.
"""
import io
import os
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LATEX = os.path.join(ROOT, "latex")
GEN = os.path.join(LATEX, "generated")
DISC = os.path.join(LATEX, "discussion")


# --------------------------------------------------------------- helpers ---
def tt(text):
    """\\texttt{} with LaTeX-special characters escaped."""
    for a, b in (("\\", "\\textbackslash "), ("_", "\\_"), ("%", "\\%"),
                 ("&", "\\&"), ("#", "\\#"), ("$", "\\$"),
                 ("{", "\\{"), ("}", "\\}")):
        text = text.replace(a, b)
    return "\\texttt{%s}" % text


def listing(rel, style, caption):
    return ("\\lstinputlisting[style=%s,caption={%s}]{../%s}"
            % (style, caption, rel))


def csrc(rel):
    return listing(rel, "csrc", "Source: %s" % tt(rel))


def shsrc(rel):
    return listing(rel, "shsrc", "Source: %s" % tt(rel))


def needspace(rel):
    """Reserve enough room that a transcript is not split across a page break.

    A transcript reads as one continuous session, so a break through the middle
    of it is worse than a short page. \\Needspace* asks for the whole thing;
    if it does not fit, the listing moves to the next page intact.

    Listings are \\scriptsize (about 0.62 of a normal baselineskip) and the
    caption costs about two more lines. Anything taller than a page cannot be
    kept together anyway, so above that the request is dropped rather than
    pushing a listing onto a page it still cannot fit on.
    """
    path = os.path.join(ROOT, rel)
    try:
        with io.open(path, encoding="utf-8", errors="replace") as fh:
            lines = sum(1 for _ in fh)
    except IOError:
        return r"\headroom"
    need = int(lines * 0.62) + 3
    if need > 40:
        return r"\headroom"
    return r"\Needspace*{%d\baselineskip}" % need


def term(rel, caption):
    # caption=None: the subsection heading already says what the transcript is,
    # so a caption underneath would only repeat it.
    if caption is None:
        return "\\lstinputlisting[style=term]{../%s}" % rel
    return listing(rel, "term", caption)


# ------------------------------------------------------------- structure ---
SECTIONS = []

SECTIONS.append(dict(
    key="item1",
    title="Commands for manipulating and monitoring processes",
    intro="",
    blocks=[],
    subs=[
        dict(key="item1_1",
             title=r"The difference between \texttt{top} and \texttt{ps}",
             blocks=[("results", "results/1_1_ps_top.txt",
                      r"\texttt{ps} and \texttt{top} on the same machine")]),
        dict(key="item1_2",
             title=r"The purpose of \texttt{nice}, and how to nice a process",
             blocks=[("results", "results/1_2_nice.txt",
                      "Niceness set at start-up, then changed on a running process")]),
        dict(key="item1_3",
             title="Killing processes and jobs",
             blocks=[("results", "results/1_3_kill.txt",
                      "Four ways of naming the target")]),
    ],
))

SECTIONS.append(dict(
    key="item2",
    title="Foreground, background, and job control",
    intro="",
    blocks=[],
    subs=[
        dict(key="item2_1",
             title=r"First situation: \texttt{./ss1\_1.sh} versus "
                   r"\texttt{./ss1\_1.sh \&}",
             intro=r"""
\texttt{ss1\_1.sh} occupies ten seconds. Following the sheet's NOTE it loops
with a one-second sleep and prints each tick rather than sleeping once for ten,
so that it is visible whether the shell is blocked waiting for it. One
difference from an interactive session is noted in the transcript itself: bash
prints its \texttt{[1] <pid>} launch notice only when interactive, so that line
does not appear.
""",
             blocks=[("source-sh", "ss1_1.sh", None),
                     ("results", "results/2_1_fg_bg.txt",
                      "The same script run both ways")]),
        dict(key="item2_2",
             title=r"Second situation: \textsc{ctrl+z}, \texttt{jobs}, "
                   r"\texttt{bg} and \texttt{fg}",
             intro=r"""
\texttt{ss1\_2.sh} sleeps for 1000 seconds, long enough to suspend and resume.
A script has no keyboard and so cannot press \textsc{ctrl+z}: below, the script
is genuinely started in the foreground and a small watchdog sends
\texttt{SIGTSTP} to its process group a few seconds later --- exactly what the
terminal driver does when \textsc{ctrl+z} is pressed. The job is therefore a
real foreground job being really suspended; only the keypress is stood in for.
""",
             blocks=[("source-sh", "ss1_2.sh", None),
                     ("results", "results/2_2_jobctl.txt",
                      "Suspending the job, then resuming it with "
                      "\\texttt{bg} and with \\texttt{fg}")]),
    ],
))

SECTIONS.append(dict(
    key="item5",
    title="Simulating STCF",
    # The code listing and its three-way comparison are long enough that
    # starting them at the foot of a page strands the heading. Own page.
    newpage=True,
    intro=r"""
STCF --- Shortest Time-to-Completion First --- is the preemptive form of
shortest-job-first: the CPU is re-assigned at every time unit, so a process that
arrives with less work remaining than the one running takes it away immediately.

Three ways to simulate it, for $n$ processes over a timeline of length $T$ ---
the sum of the bursts, which is unrelated to $n$:

\begin{itemize}\setlength{\itemsep}{3pt}\setlength{\parskip}{0pt}
  \item \textbf{Linear array, tick by tick --- $O(T \cdot n)$.} Step one time
        unit at a time, scanning all $n$ for the least remaining. Simple, but
        the same scan is repeated $T$ times.
  \item \textbf{Tick by tick with a min-heap --- $O(T + n\log n)$.} A heap
        ordered by \texttt{(remaining, pid)} makes the process to run the root,
        and decrementing the root keeps it the root, so a tick costs $O(1)$ and
        only arrivals and completions disturb the heap. Still tied to $T$.
  \item \textbf{Event-driven with a min-heap --- $O(n\log n)$; used here.} The
        schedule can only change when a process arrives or the running one
        finishes, so the root is run straight through to the next such event
        rather than re-examined every unit. At most $2n$ heap operations, and
        no dependence on how long the bursts are.
\end{itemize}

Printing follows the same idea: a slot is emitted only when the owner changes,
which merges the output into ranges and produces the \texttt{IDLE} gaps. Only
the third of the three was implemented; the other two are described above for
comparison and are not in the file. \texttt{simulate\_stfc()} and the min-heap
and slot helpers it calls were written for this task, while the includes, the
\texttt{Process} struct and \texttt{main()} came with the skeleton.
""",
    blocks=[
        ("source-c", "PS3.c", None),
        ("screenshot", "code.png",
         "The \\texttt{simulate\\_stfc()} function"),
        ("results", "results/5_stcf.txt",
         "All three cases"),
        ("screenshot", "Result_Terminal.png",
         "Running the three provided cases"),
    ],
))


# ------------------------------------------------------------------ build ---
def emit_blocks(out, blocks):
    for kind, ref, caption in blocks:
        if kind == "source-c":
            out.append(csrc(ref))
        elif kind == "source-sh":
            out.append(shsrc(ref))
        elif kind == "results":
            out.append(needspace(ref))
            out.append(term(ref, caption))
        elif kind == "screenshot":
            out.append(r"\screenshot{%s}{%s}" % (ref, caption))
        out.append("")


def prose_keys():
    """Every discussion file the document \\input{}s, in order."""
    keys = []
    for sec in SECTIONS:
        subs = sec.get("subs")
        keys.extend([s["key"] for s in subs] if subs else [sec["key"]])
    return keys


def build_body():
    out = ["% GENERATED by scripts/make_latex.py -- DO NOT EDIT", ""]

    for sec in SECTIONS:
        if sec.get("newpage"):
            out.append(r"\clearpage")
        out.append(r"\headroom")
        out.append(r"\section{%s}" % sec["title"])
        out.append("")
        if sec["intro"].strip():
            out.append(sec["intro"].strip())
            out.append("")

        emit_blocks(out, sec["blocks"])

        subs = sec.get("subs")
        if subs:
            # A subsection carries its own heading, so its prose follows the
            # transcript directly -- no "Discussion" heading to repeat.
            for sub in subs:
                out.append(r"\headroom")
                out.append(r"\subsection{%s}" % sub["title"])
                out.append("")
                if sub.get("intro", "").strip():
                    out.append(sub["intro"].strip())
                    out.append("")
                emit_blocks(out, sub["blocks"])
                out.append(r"\input{discussion/%s}" % sub["key"])
                out.append("")
        else:
            out.append(r"\headroom")
            out.append(r"\subsection*{Discussion}")
            out.append(r"\input{discussion/%s}" % sec["key"])
            out.append("")

    path = os.path.join(GEN, "body.tex")
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


def build_discussion_stubs():
    """Written ONCE. Existing files are left completely alone."""
    created, kept = [], []
    for key in prose_keys():
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
    os.makedirs(os.path.join(ROOT, "figures"), exist_ok=True)

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
