#!/usr/bin/env python3
"""Generate the LaTeX report scaffolding for CPE 333 PS2.

    python3 scripts/make_latex.py

WHAT THIS WRITES
    latex/generated/*        always overwritten -- never edit these by hand
    latex/discussion/*.tex   written ONLY if absent -- your prose is safe

WHAT THIS NEVER TOUCHES
    latex/main.tex, latex/preamble.tex

Code and transcripts are NOT copied into the .tex files: the document pulls them
out of ../src and ../results at compile time with \\lstinputlisting, so the
report cannot drift from what was actually compiled and run.
"""
import io
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LATEX = os.path.join(ROOT, "latex")
GEN = os.path.join(LATEX, "generated")
DISC = os.path.join(LATEX, "discussion")


# --------------------------------------------------------------- helpers ---
def lines_of(rel):
    path = os.path.join(ROOT, rel)
    if not os.path.exists(path):
        sys.stderr.write("MISSING: %s -- run scripts/run_all.sh first\n" % rel)
        return []
    with io.open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read().rstrip("\n").split("\n")


def head(rel, n):
    """First n lines."""
    return lines_of(rel)[:n]


def block(rel, pattern, n):
    """n lines starting at the first line containing `pattern`."""
    src = lines_of(rel)
    for i, line in enumerate(src):
        if pattern in line:
            return src[i:i + n]
    sys.stderr.write("WARNING: pattern %r not found in %s\n" % (pattern, rel))
    return []


ELISION = "        . . . . .  (trimmed -- full transcript in the appendix)  . . . . ."


def write_excerpt(name, chunks):
    """Join chunks with an elision marker and write latex/generated/<name>."""
    out = []
    for i, chunk in enumerate(chunks):
        if i:
            out.append("")
            out.append(ELISION)
            out.append("")
        out.extend(chunk)
    path = os.path.join(GEN, name)
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    return "generated/" + name


def tt(text):
    """\\texttt{} with LaTeX-special characters escaped."""
    for a, b in (("\\", "\\textbackslash "), ("_", "\\_"), ("%", "\\%"),
                 ("&", "\\&"), ("#", "\\#"), ("$", "\\$"),
                 ("{", "\\{"), ("}", "\\}")):
        text = text.replace(a, b)
    return "\\texttt{%s}" % text


def csrc(rel, label):
    return ("\\lstinputlisting[style=csrc,caption={Source: %s},label={lst:%s}]"
            "{../%s}" % (tt(rel), label, rel))


def shsrc(rel, label):
    return ("\\lstinputlisting[style=shsrc,caption={Source: %s},label={lst:%s}]"
            "{../%s}" % (tt(rel), label, rel))


def term(path_from_latex, caption):
    return ("\\lstinputlisting[style=term,caption={%s}]{%s}"
            % (caption, path_from_latex))


def result(rel, caption):
    """Include a results transcript in full, straight from results/."""
    return term("../" + rel, caption)


# ------------------------------------------------------------- structure ---
ITEMS = []

# ---- item 1 ---------------------------------------------------------------
ITEMS.append(dict(
    n=1,
    title="fork() with and without wait()",
    sources=[("src/1_1_fork_hello.c", "1-1"), ("src/1_2_fork_wait.c", "1-2")],
    howitworks=r"""
Both programs are transcribed from the Lecture~2 slides. Each prints a line,
calls \texttt{fork()}, and then takes a different branch in the parent and in the
child. 1.2 differs from 1.1 in one place only: its parent calls
\texttt{wait(NULL)} before printing, and reports what that call returned as
\texttt{wc}.
""",
    results=[
        ("full", "results/1_1_fork_hello.txt",
         "\\texttt{fork()} without \\texttt{wait()}"),
        ("full", "results/1_2_fork_wait.txt",
         "\\texttt{fork()} with \\texttt{wait()}"),
        ("full", "results/1_ordering.txt",
         "Which process printed first, counted over repeated runs of 1.1"),
    ],
    prompts=[
        r"\texttt{fork()} is called once and returns twice: explain how each "
        r"process discovers which one it is, and why the child does not restart "
        r"from \texttt{main()}.",
        r"In 1.2, what exactly makes the child's line always come first? What "
        r"does \texttt{wait()} return, and what is \texttt{wc} in the output?",
        r"The slide says 1.1's output ``is not deterministic'', yet over 300 runs "
        r"the parent printed first 300 times. Reconcile \emph{no guarantee} with "
        r"\emph{varies in practice}. What would have to change for the order to flip?",
        r"Under plain redirection \texttt{hello world} appears \textbf{twice}, but "
        r"line-buffered it appears once. Explain using stdio buffering and what "
        r"\texttt{fork()} copies. Is the C library or the kernel responsible?",
        r"Why does the destination of stdout change the program's behaviour?",
    ],
))

# ---- item 2 ---------------------------------------------------------------
ITEMS.append(dict(
    n=2,
    title="Zombies, orphans, and \\texttt{ps}",
    sources=[("src/2_1_zombie.c", "2-1"), ("src/2_2_orphan.c", "2-2")],
    howitworks=r"""
In 2.1 the child exits immediately while the parent sleeps without ever calling
\texttt{wait()}. In 2.2 the reverse: the parent exits first while the child keeps
running. Each child prints \texttt{getppid()} at the moments that matter --- in
2.2 both before and after its parent dies. Because both states are transient,
each program is run in the background and \texttt{ps -ef} is captured on a timer
rather than typed by hand.
""",
    results=[
        ("full", "results/2_ps_snapshot.txt",
         "Both scenarios, with \\texttt{ps} evidence captured on a timer"),
    ],
    prompts=[
        r"What is a \texttt{<defunct>} process? The snapshot also shows "
        r"\texttt{STAT}~=~\texttt{Z} --- what does that state mean?",
        r"\textbf{Cause:} which omission in \texttt{2\_1\_zombie.c} created the "
        r"zombie? What single line would have prevented it?",
        r"\textbf{Meaning:} the child has exited, so what is the kernel still "
        r"holding, and what has it already released?",
        r"\textbf{Consequence:} zombies are tiny. Why are they still a real "
        r"problem for a long-running program such as a server, and what does it "
        r"eventually run out of?",
        r"Report the child's PPID in \textbf{both} scenarios. In 2.2 it changed --- "
        r"state both numbers, and explain who changed it and when.",
        r"The orphan was adopted by \texttt{Relay(...)}, \textbf{not} by PID~1 "
        r"(\texttt{systemd}). Explain what a \emph{child subreaper} is and why WSL "
        r"differs from a plain Linux install, where the textbook answer is PID~1.",
        r"Why did scenario 2.2 never show a \texttt{<defunct>} entry, even though "
        r"the child does eventually exit? Contrast with 2.1.",
        r"Which scenario actually leaks a resource, and which is harmless? Is an "
        r"orphan a problem at all?",
    ],
))

# ---- item 3 ---------------------------------------------------------------
ITEMS.append(dict(
    n=3,
    title="How many processes can we fork?",
    sources=[("src/3_fork_count.c", "3")],
    howitworks=r"""
Following the Hint in the problem sheet, a recursive function forks until
\texttt{fork()} fails: the parent \texttt{wait()}s and only the child forks
onward, so exactly one process runs at a time and the count grows by one ($n$)
rather than doubling ($2^{n}$). No artificial limit is imposed --- the program
really does fork until it cannot fork any more.

Because the process that would report the total may be killed outright when
memory runs out, the count is also written to a file after every successful
fork, and read back from there.
The program is run three times --- on its own, with 200 extra \texttt{sleep}
processes running, and after killing those again. Each run is guarded by watching
free memory and stopping the whole process group before the kernel's own OOM
killer has to intervene, and the next run does not begin until the previous chain
has gone and its memory has been returned.
""",
    results=[
        ("full", "results/3_fork_limit.txt",
         "Three measurements: on its own, with 200 other processes running, "
         "and after killing them again"),
    ],
    prompts=[
        r"Which limit stopped the recursion --- the per-user process limit, memory "
        r"exhaustion, or PID exhaustion? The transcript reports \texttt{errno}; "
        r"name it and say what it means.",
        r"The three measurements were 463, 263, 463. Explain the drop of exactly "
        r"200. Is the limit counted \textbf{per program} or \textbf{per user}? "
        r"Which does our data prove?",
        r"Why does the count return to exactly its original value afterwards?",
        r"Explain why the recursive structure is safe where a loop that forks "
        r"without waiting would be a fork bomb.",
        r"These numbers come from an artificial cap of 500; the machine's real "
        r"\texttt{ulimit -u} is 35595. Why is the \emph{trend} across the three "
        r"measurements the finding here, rather than the absolute number?",
        r"This was measured under WSL2. Which parts of the result are portable to "
        r"a native Linux install or a VM, and which are not?",
    ],
))

# ---- item 4 ---------------------------------------------------------------
ITEMS.append(dict(
    n=4,
    title="A pipe between parent and child",
    sources=[("src/4_pipe.c", "4")],
    howitworks=r"""
\texttt{pipe(fd)} creates one kernel buffer with a read end (\texttt{fd[0]}) and
a write end (\texttt{fd[1]}); \texttt{fork()} duplicates both, so each side
closes the end it does not use. The child prints its PID, writes its message and
exits; the parent prints its own PID, reads the message and prints it.
""",
    results=[
        ("full", "results/4_pipe.txt",
         "The child sends, the parent receives"),
    ],
    prompts=[
        r"Immediately after \texttt{fork()} there are four descriptors onto one "
        r"pipe. List them, and say which process closes which and why.",
        r"What would happen if the parent forgot to close \texttt{fd[1]}? Trace it "
        r"through to the symptom the user would see.",
        r"Line~3 is \textbf{always} after line~1, but line~2's position is not "
        r"fixed. Explain why one ordering is guaranteed by the mechanism and the "
        r"other is not.",
        r"The submitted run uses \texttt{usleep()} to force the expected order. Is "
        r"that \emph{solving} the ordering problem or \emph{hiding} it? What would "
        r"real synchronisation look like, and why is a fixed sleep a bad way to "
        r"synchronise in general?",
        r"Compare the \texttt{-{}-race} transcript with the ordering counts from "
        r"item~1. Both are races, but item 4's flipped and 1.1's never did. Suggest "
        r"why the parent's \texttt{close()} call before printing might matter.",
    ],
))

# ---- item 5 ---------------------------------------------------------------
ITEMS.append(dict(
    n=5,
    title="Pipe edge cases",
    sources=[("src/5_1a_read_closed.c", "5-1a"), ("src/5_1b_read_open.c", "5-1b"),
             ("src/5_2_read_first.c", "5-2"), ("src/5_3_multi_message.c", "5-3")],
    howitworks=r"""
Four small variants of the item~4 program, each changing one thing.
\textbf{5.1} is tested twice because the outcome depends on whether the sender
still holds the read end: (a) keeps the \texttt{close()} from item~4, (b)
deliberately leaves it open. In \textbf{5.2} the parent reads at $t=0$ while the
child does not write until $t=3$, with timestamps printed either side of the
call. In \textbf{5.3} the child sends three messages before the parent performs a
single \texttt{read()}.
""",
    results=[
        ("full", "results/5_1a_read_closed.txt",
         "Item 5.1(a) --- sender reads with the read end closed."),
        ("full", "results/5_1b_read_open.txt",
         "Item 5.1(b) --- sender reads with the read end left open."),
        ("full", "results/5_2_read_first.txt",
         "Item 5.2 --- receiver reads before the sender writes."),
        ("full", "results/5_3_multi_message.txt",
         "Item 5.3 --- three writes, one read."),
    ],
    prompts=[
        r"\textbf{5.1a:} the sender's \texttt{read()} failed with \texttt{EBADF}, "
        r"not with ``pipe is empty''. Why is the error about the \emph{descriptor} "
        r"rather than the pipe's contents?",
        r"\textbf{5.1b:} with the read end open, the child read back its own "
        r"message. What does this prove about who a pipe's data is ``addressed'' "
        r"to? Is a pipe unidirectional by enforcement, or only by convention?",
        r"\textbf{5.1b:} the parent's \texttt{read()} returned \textbf{0} rather "
        r"than blocking. What does 0 mean, what condition produced it, and why is "
        r"that different from the blocking seen in 5.2?",
        r"\textbf{5.2:} \texttt{read()} blocked for 3.004~s. Why block rather than "
        r"return 0 or an error? How does a reader distinguish ``no data \emph{yet}'' "
        r"from ``no data \emph{ever}''?",
        r"\textbf{5.2:} what would have changed with \texttt{O\_NONBLOCK}?",
        r"\textbf{5.3:} three writes of 31 bytes produced one \texttt{read()} "
        r"returning 93. What does this prove about message boundaries? Contrast a "
        r"pipe with a message queue.",
        r"\textbf{5.3:} if the receiver needed the three messages back as three "
        r"separate items, what would sender and receiver have to agree on? Name a "
        r"framing strategy.",
        r"Across 5.1--5.3, summarise the rules a correct pipe user must follow.",
    ],
))



# ------------------------------------------------------------------ build ---
def build_body():
    out = []
    out.append("% GENERATED by scripts/make_latex.py -- DO NOT EDIT")
    out.append("")
    out.append(r"\section*{Environment}")
    out.append(r"""
All programs were compiled and run under WSL2 Ubuntu with
\texttt{gcc 15.2.0}, using
\texttt{-std=c11 -D\_DEFAULT\_SOURCE -Wall -Wextra -O0 -g}.
All output shown is real captured output.
""")

    for it in ITEMS:
        out.append("")
        out.append(r"\headroom")
        out.append(r"\section{%s}" % it["title"])
        out.append("")
        out.append(r"\headroom")
        out.append(r"\subsection*{Source}")
        for rel, label in it["sources"]:
            out.append(shsrc(rel, label) if rel.endswith(".sh") else csrc(rel, label))
            out.append("")
        # Short overview after the listing: the assignment asks for the source
        # "with overview explanation of how it works". Detail stays in the
        # source comments; this is only the summary.
        out.append(r"\headroom")
        out.append(r"\subsection*{How it works}")
        out.append(it["howitworks"].strip())
        out.append("")
        out.append(r"\headroom")
        out.append(r"\subsection*{Results}")
        for kind, ref, caption in it["results"]:
            if kind == "full":
                out.append(result(ref, caption))
            else:
                out.append(term("generated/" + ref, caption))
            out.append("")
        out.append(r"\headroom")
        out.append(r"\subsection*{Discussion}")
        out.append(r"\input{discussion/item%d}" % it["n"])
        out.append("")

    path = os.path.join(GEN, "body.tex")
    with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")


def build_discussion_stubs():
    """Written ONCE. Existing files are left completely alone."""
    created, kept = [], []
    for it in ITEMS:
        path = os.path.join(DISC, "item%d.tex" % it["n"])
        if os.path.exists(path):
            kept.append(os.path.basename(path))
            continue
        body = [
            "%% Discussion for item %d -- YOUR PROSE GOES HERE." % it["n"],
            "%% scripts/make_latex.py will NEVER overwrite this file.",
            "%%",
            "%% Delete the \\todoprose block below once you have written this section.",
            "",
            r"\todoprose{Answer the following in your own words. These are the",
            r"questions the problem sheet asks, plus the points our own results",
            r"force us to explain.",
            r"\begin{enumerate}\itemsep2pt",
        ]
        for p in it["prompts"]:
            body.append(r"  \item %s" % p)
        body += [r"\end{enumerate}}", ""]
        with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(body) + "\n")
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
        print("created discussion stubs : %s" % ", ".join(created))
    if kept:
        print("LEFT UNTOUCHED (your prose): %s" % ", ".join(kept))
    print("\nnext:  powershell -ExecutionPolicy Bypass -File scripts\\build_pdf.ps1")


if __name__ == "__main__":
    main()
