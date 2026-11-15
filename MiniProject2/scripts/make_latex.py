#!/usr/bin/env python3
"""Generate the LaTeX report body for CPE 333 Mini-Project 2.

    python scripts/make_latex.py

WHAT THIS WRITES
    latex/generated/*        always overwritten -- never edit these by hand
    latex/discussion/*.tex   written ONLY if absent -- the prose is safe

Sources and transcripts are pulled in with \\lstinputlisting at compile time.
The tables, and every figure the prose quotes (generated/numbers.tex), are
parsed out of results/ on every build, so no number is ever typed by hand.
It refuses to build while results/checks.txt records a failed check.
"""
import io
import os
import re
import shutil

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LATEX = os.path.join(ROOT, "latex")
GEN = os.path.join(LATEX, "generated")
DISC = os.path.join(LATEX, "discussion")

BUILD, REGIONS, TOUCH, FILEMAP, MOREREG, CHECKS = (
    "results/00_build.txt", "results/01_regions.txt", "results/02_touch.txt",
    "results/03_filemap.txt", "results/04_regions.txt", "results/checks.txt")
MODULE = "module/pfcount.c"

QUOTED = set()   # transcripts the document actually shows
KEYS = []        # discussion files the body inputs


def die(msg):
    raise SystemExit("make_latex.py: " + msg)


def lines_of(rel):
    with io.open(os.path.join(ROOT, rel), encoding="utf-8") as fh:
        return fh.read().splitlines()


# --------------------------------------------------------------- parsing ---
SUMMARY = {
    "regions": r"^  memory regions *: (\d+)$",
    "vkb":     r"^  total virtual space *: (\d+) kB",
    "vpages":  r"^  total virtual space *: \d+ kB \((\d+) pages\)$",
    "rss":     r"^  resident \(RSS\) *: \d+ kB \((\d+) pages\)$",
    "min":     r"^  minor faults *: (\d+) ",
    "maj":     r"^  major faults *: (\d+) ",
    "seen":    r"^    faults seen *: (\d+) ",
    "user":    r"^    faults seen .*\((\d+) user mode",
    "kernel":  r"^    faults seen .*, (\d+) kernel mode\)$",
    "dmin":    r"^    minor / major *: (\d+) / \d+$",
    "dmaj":    r"^    minor / major *: \d+ / (\d+)$",
}


def summaries(rel):
    """Every pfcount summary in a transcript, in order. Each is tagged with
    the last line the test program printed ("prog") and the last "--- part
    ---" heading ("part") before it."""
    out, prog, part, cur = [], "", "", None
    for line in lines_of(rel):
        if line.startswith("pid ") and line.rstrip().endswith(("thread", "threads")):
            cur = {"prog": prog, "part": part}
            out.append(cur)
        elif line.startswith(("# ", "---", "[")):
            cur = None
            if line.startswith("---"):
                part = line.strip("- ")
            elif line.startswith("["):
                prog = line
        elif cur is not None:
            for key, pat in SUMMARY.items():
                m = re.search(pat, line)
                if m:
                    cur[key] = int(m.group(1))
    for s in out:
        missing = set(SUMMARY) - set(s)
        if missing:
            die("summary in %s lacks %s" % (rel, sorted(missing)))
    if not out:
        die("no pfcount summary in %s" % rel)
    return out


def output_of(rel, command):
    """The output lines of the first "# <command...>" in a transcript."""
    lines = lines_of(rel)
    for i, line in enumerate(lines):
        if line.startswith("# ") and re.match(command, line[2:]):
            out = []
            for nxt in lines[i + 1:]:
                if nxt.startswith(("# ", "---")):
                    break
                out.append(nxt)
            return out
    die("no '%s' in %s" % (command, rel))


def kb(line):
    return int(re.search(r"(\d+) kB", line).group(1))


# --------------------------------------------------------------- figures ---
def numbers():
    """Every figure the prose quotes, as \\newcommand macros."""
    n = {}
    n["KernelRelease"] = output_of(BUILD, r"uname -r")[0]

    one = summaries(REGIONS)[0]
    maps = output_of(REGIONS, r"cat /proc/\d+/maps")
    diff = output_of(REGIONS, r"diff ")
    removed = [l[2:] for l in diff if l.startswith("< ")]
    if len(removed) != 1 or [l for l in diff if l.startswith("> ")]:
        die("experiment 1: expected exactly one line only in maps")
    vsys = [l for l in maps if l.startswith(removed[0])]
    if not vsys or not vsys[0].endswith("[vsyscall]"):
        die("experiment 1: the extra maps line is not [vsyscall]")
    n["OneRegions"] = one["regions"]
    n["OneMapsLines"] = len(maps)
    n["OneVsyscall"] = removed[0].split("-")[0]
    n["OneVirtualKB"] = one["vkb"]
    n["OneVmSize"] = kb(output_of(REGIONS, r"grep VmSize")[0])
    n["OneRssKB"] = one["rss"] * 4

    touch = summaries(TOUCH)
    n["TouchPages"] = int(re.search(r"mapped (\d+) pages", touch[0]["prog"]).group(1))
    n["TouchBufferKB"] = n["TouchPages"] * 4
    if not any(re.search(r" rw-p +%d kB$" % n["TouchBufferKB"], l) for l in lines_of(REGIONS)):
        die("experiment 1: no %d kB anonymous buffer in the region list" % n["TouchBufferKB"])
    n["TouchMinor"] = touch[-1]["dmin"]
    n["TouchSeen"] = touch[-1]["seen"]
    n["TouchStartupMinor"] = touch[0]["min"]
    n["TouchVirtualPages"] = touch[0]["vpages"]
    n["TouchRssGrowth"] = touch[-1]["rss"] - touch[0]["rss"]

    fa = int(output_of(FILEMAP, r"cat /sys/kernel/debug/fault_around_bytes")[0])
    n["FaultAroundBytes"] = fa
    n["FaultAroundPages"] = fa // 4096
    files = summaries(FILEMAP)
    cold = [s for s in files if s["part"].startswith("cold")][-1]
    warm = [s for s in files if s["part"].startswith("warm")][-1]
    n["FilePages"] = int(re.search(r"mapped (\d+) pages", cold["prog"]).group(1)
                         if "mapped" in cold["prog"] else
                         re.search(r"each of (\d+) pages", cold["prog"]).group(1))
    n["ColdMajor"], n["ColdMinor"], n["ColdSeen"] = cold["dmaj"], cold["dmin"], cold["seen"]
    n["WarmMajor"], n["WarmMinor"], n["WarmSeen"] = warm["dmaj"], warm["dmin"], warm["seen"]

    regs = summaries(MOREREG)
    before, mapped, unmapped = regs
    n["RegBefore"] = before["regions"]
    n["RegMapped"] = mapped["regions"]
    n["RegAdded"] = mapped["regions"] - before["regions"]
    n["RegVirtualAddedKB"] = mapped["vkb"] - before["vkb"]
    n["RegRssGrowth"] = mapped["rss"] - before["rss"]
    n["RegFaults"] = mapped["seen"]
    rssfile = [kb(l) for l in lines_of(MOREREG) if l.startswith("RssFile:")]
    rssanon = [kb(l) for l in lines_of(MOREREG) if l.startswith("RssAnon:")]
    n["RegRssFileGrowthKB"] = rssfile[1] - rssfile[0]
    n["RegRssAnonGrowthKB"] = rssanon[1] - rssanon[0]

    checks = lines_of(CHECKS)
    if any(l.startswith("FAIL") for l in checks):
        die("results/checks.txt records a failed check -- rerun and fix first")
    n["ChecksPassed"] = sum(1 for l in checks if l.startswith("ok"))
    return n, touch, cold, warm, regs


def numbers_tex(n):
    out = ["% GENERATED by scripts/make_latex.py from results/ -- DO NOT EDIT"]
    for key, val in n.items():
        out.append("\\newcommand{\\%s}{%s}" % (key, val))
    return "\n".join(out) + "\n"


# --------------------------------------------------------------- helpers ---
def needspace(lines, line_pt=9.5):
    """Keep a listing on one page: ask for its height, or give up if it could
    never fit. Heights are in body baselineskips (13.6pt); a page holds ~51.
    line_pt is the listing's own line height: 9.5 for \\scriptsize, 8.6 for
    the termsmall style."""
    need = int(lines * line_pt / 13.6 + 0.999) + 3
    return r"\headroom" if need > 51 else r"\Needspace*{%d\baselineskip}" % need


def transcript(rel, caption):
    QUOTED.add(rel)
    count = len(lines_of(rel))
    return "\n".join([
        needspace(count + 2, line_pt=8.6),
        "\\lstinputlisting[style=termsmall,caption={%s}]{../%s}" % (caption, rel)])


def excerpt(rel, first_pat, last_func_pat, caption):
    """Lines of a C file from the comment block above the line matching
    first_pat to the closing brace of the function whose header matches
    last_func_pat. Line numbers are the file's own."""
    lines = lines_of(rel)
    first = next(i for i, l in enumerate(lines) if re.match(first_pat, l))
    while first > 0 and re.match(r"^(/\*| \*)", lines[first - 1]):
        first -= 1
    start_last = next(i for i, l in enumerate(lines) if re.match(last_func_pat, l))
    last = next(i for i in range(start_last, len(lines)) if lines[i] == "}")
    first, last = first + 1, last + 1           # 1-based for listings
    return "\n".join([
        needspace(last - first + 3),
        "\\lstinputlisting[style=csrc,firstline=%d,lastline=%d,firstnumber=%d,"
        "caption={%s, lines %d--%d}]{../%s}"
        % (first, last, first, caption, first, last, rel)])


def source(rel, caption):
    """A C program listing that never breaks inside a function header: it is
    split before main(), and the second half asks for room for main() whole."""
    lines = lines_of(rel)
    cut = next(i for i, l in enumerate(lines, 1) if l.startswith("int main("))
    return "\n".join([
        "\\lstinputlisting[style=csrc,lastline=%d]{../%s}" % (cut - 1, rel),
        needspace(len(lines) - cut + 1),
        "\\lstinputlisting[style=csrc,firstline=%d,firstnumber=%d,caption={%s}]{../%s}"
        % (cut, cut, caption, rel)])


def whole(rel, caption, style="csrc", extra=""):
    return "\\lstinputlisting[style=%s%s,caption={%s}]{../%s}" % (style, extra, caption, rel)


def table(cols, head, rows, caption):
    # Rows, rules, header and caption, so the caption never leaves its table.
    out = [needspace(len(rows) + 5, line_pt=12), r"\begin{center}", r"\small",
           r"\begin{tabular}{@{}%s@{}}" % cols,
           r"\toprule", " & ".join(head) + r" \\", r"\midrule"]
    out += [" & ".join(str(c) for c in row) + r" \\" for row in rows]
    out += [r"\bottomrule", r"\end{tabular}",
            r"\captionof{table}{%s}" % caption, r"\end{center}"]
    return "\n".join(out)


def check_coverage():
    """Every transcript in results/ must appear in the document."""
    have = {"results/" + f for f in os.listdir(os.path.join(ROOT, "results"))
            if f.endswith(".txt")}
    missing = sorted(have - QUOTED)
    if missing:
        die("captured but never shown: %s" % missing)


# ------------------------------------------------------------- structure ---
def build_body(touch, cold, warm, regs):
    out = ["% GENERATED by scripts/make_latex.py -- DO NOT EDIT", ""]

    def prose(key):
        KEYS.append(key)
        out.extend([r"\input{discussion/%s}" % key, ""])

    def head(cmd, title):
        out.extend([r"\headroom", "\\%s{%s}" % (cmd, title), ""])

    head("section", "Introduction")
    prose("intro")
    head("section", "Background")
    prose("background")

    head("section", "Design and Implementation")
    prose("design")
    head("subsection", "Attaching to the Page Fault Tracepoints")
    prose("design_tp")
    out.append(excerpt(MODULE, r"^static void on_user_fault", r"^static void find_tracepoint",
                       r"The probes and the tracepoint lookup, \texttt{module/pfcount.c}"))
    out.append(excerpt(MODULE, r"^static int __init pfcount_init", r"^static int __init pfcount_init",
                       r"Attaching at load time, \texttt{module/pfcount.c}"))
    out.append("")
    head("subsection", "Counting Regions, Residency and Faults")
    prose("design_count")
    out.append(excerpt(MODULE, r"^static void group_faults", r"^static unsigned long rss_pages",
                       r"Fault totals and resident pages, \texttt{module/pfcount.c}"))
    out.append(excerpt(MODULE, r"^static int summary_show", r"^static int summary_show",
                       r"The summary, \texttt{module/pfcount.c}"))
    out.append("")
    head("subsection", "Building and Loading")
    prose("build")
    out += [transcript(BUILD, r"Building and loading the module, \texttt{results/00\_build.txt}"), ""]

    head("section", "Experiments")
    prose("experiments")

    head("subsection", r"Regions Against \texttt{/proc/<pid>/maps}")
    prose("exp1")
    out += [transcript(REGIONS, r"Regions of \texttt{1\_touch} before it touches its buffer, "
                                r"\texttt{results/01\_regions.txt}"), ""]

    head("subsection", "Demand Paging and Minor Faults")
    prose("exp2")
    out += [transcript(TOUCH, r"\texttt{1\_touch} at each stage, \texttt{results/02\_touch.txt}"), ""]
    rows = []
    for s in touch:
        m = re.search(r"touched (\d+) of", s["prog"])
        rows.append((m.group(1) if m else "0", s["dmin"], s["dmaj"], s["seen"]))
    out += [table("rrrr", ["Pages touched", "Minor faults", "Major faults", "Faults seen"], rows,
                  r"Faults of \texttt{1\_touch} since monitoring started"), ""]

    head("subsection", "Major Faults and the Page Cache")
    prose("exp3")
    out += [transcript(FILEMAP, r"\texttt{2\_filemap} with a cold and a warm page cache, "
                                r"\texttt{results/03\_filemap.txt}"), ""]
    out += [table("lrrrr", ["Page cache", "Major faults", "Minor faults", "Faults seen", "RSS (pages)"],
                  [("cold", cold["dmaj"], cold["dmin"], cold["seen"], cold["rss"]),
                   ("warm", warm["dmaj"], warm["dmin"], warm["seen"], warm["rss"])],
                  r"Reading every page of the file once"), ""]

    head("subsection", "Regions Come and Go")
    prose("exp4")
    out += [transcript(MOREREG, r"\texttt{3\_regions} before mapping, after mapping, after "
                                r"unmapping, \texttt{results/04\_regions.txt}"), ""]
    out += [table("lrrrr", ["Stage", "Regions", "Virtual (kB)", "RSS (pages)", "Faults seen"],
                  [(st, s["regions"], s["vkb"], s["rss"], s["seen"])
                   for st, s in zip(["before", "mapped", "unmapped"], regs)],
                  r"\texttt{3\_regions} at each stage"), ""]

    head("subsection", "Residency")
    prose("exp5")
    rows = []
    for s in touch:
        m = re.search(r"touched (\d+) of", s["prog"])
        rows.append((m.group(1) if m else "0", s["vpages"], s["rss"],
                     s["rss"] - touch[0]["rss"], s["dmin"]))
    out += [table("rrrrr", ["Pages touched", "Virtual (pages)", "RSS (pages)", "RSS growth",
                            "Minor faults"], rows,
                  r"Virtual size and resident set of \texttt{1\_touch}, from "
                  r"\texttt{results/02\_touch.txt}"), ""]

    head("section", "Conclusion")
    prose("conclusion")
    return "\n".join(out) + "\n"


def build_appendix():
    out = ["% GENERATED by scripts/make_latex.py -- DO NOT EDIT", ""]
    out += [r"\section{Source Code}", ""]
    out += [whole(MODULE, r"\texttt{module/pfcount.c}"), ""]
    out += [needspace(12), whole("module/Makefile", r"\texttt{module/Makefile}",
                                 extra=",language=make"), ""]
    out += [whole("tools/pfcount", r"\texttt{tools/pfcount}", style="shsrc"), ""]
    for prog in ("1_touch", "2_filemap", "3_regions"):
        out += [source("src/%s.c" % prog, r"\texttt{src/%s.c}" % prog.replace("_", r"\_")), ""]
    out += [whole("scripts/run_all.sh", r"\texttt{scripts/run\_all.sh}", style="shsrc"), ""]
    out += [r"\section{Checks}", "", r"\input{discussion/checks}", ""]
    KEYS.append("checks")
    QUOTED.add(CHECKS)
    out += [whole(CHECKS, r"Every check \texttt{run\_all.sh} made, \texttt{results/checks.txt}",
                  style="termsmall"), ""]
    return "\n".join(out) + "\n"


def build_discussion_stubs():
    """Written ONCE. Existing files are left completely alone."""
    created = []
    for key in KEYS:
        path = os.path.join(DISC, "%s.tex" % key)
        if not os.path.exists(path):
            with io.open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write("%% Discussion for %s -- never overwritten by make_latex.py.\n\n"
                         "\\todoprose{Not written yet.}\n" % key)
            created.append(key)
    if created:
        print("created discussion stubs: %s" % ", ".join(created))


def write(name, text):
    with io.open(os.path.join(GEN, name), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def main():
    n, touch, cold, warm, regs = numbers()
    if os.path.isdir(GEN):
        shutil.rmtree(GEN)
    os.makedirs(GEN)
    os.makedirs(DISC, exist_ok=True)
    write("numbers.tex", numbers_tex(n))
    write("body.tex", build_body(touch, cold, warm, regs))
    write("appendix.tex", build_appendix())
    check_coverage()
    build_discussion_stubs()


if __name__ == "__main__":
    main()
