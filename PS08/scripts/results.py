"""Parse the transcripts in results/ -- shared by claims.py and make_slides.py,
so the slides and the checks read the numbers the same way."""
import re
import statistics
from pathlib import Path

RESULTS = Path(__file__).resolve().parent.parent / "results"

LOCKS = ["peterson", "llsc", "mcs", "tas", "mutex"]
THREADS = [1, 2, 4, 8]
MODES = ["all-cpus", "one-cpu"]


def blocks(name):
    """Every '--- header ---' block of results/<name> as (header, body)."""
    text = (RESULTS / name).read_text()
    return re.findall(r"^--- (.*?) ---\n(.*?)(?=^--- |\Z)", text, re.M | re.S)


def parse(body):
    run = {"counts": [int(n) for n in re.findall(r"thread \d+: (\d+) acq", body)]}
    for key in ("total", "counter", "lost"):
        run[key] = int(re.search(rf"\b{key}=(-?\d+)", body).group(1))
    run["throughput"] = float(re.search(r"throughput=(\d+)", body).group(1))
    run["fairness"] = float(re.search(r"min/max\)=([\d.]+)", body).group(1))
    run["window"] = float(re.search(r"window=([\d.]+)", body).group(1))
    run["cpus"] = int(re.search(r"cpus=(\d+)", body).group(1))
    return run


def runs(name, pattern):
    """Parsed runs of results/<name> whose header matches the regex."""
    return [parse(b) for h, b in blocks(name) if re.search(pattern, h)]


def bench():
    """{(lock, threads, mode): [run, ...]} from results/bench.txt."""
    out = {}
    for h, b in blocks("bench.txt"):
        m = re.match(r"(\w+) threads=(\d+) (\S+) run", h)
        out.setdefault((m[1], int(m[2]), m[3]), []).append(parse(b))
    return out


def median(rs, key):
    return statistics.median(r[key] for r in rs)


def env():
    """Key facts of the machine, from results/env.txt."""
    text = (RESULTS / "env.txt").read_text()
    return {
        "nproc": re.search(r"^\$ nproc\n(\d+)", text, re.M).group(1),
        "kernel": re.search(r"^\$ uname -r\n(\S+)", text, re.M).group(1),
        "gcc": re.search(r"^gcc \(.*?\) (\S+)", text, re.M).group(1),
        "qemu": re.search(r"qemu-aarch64 version (\S+)", text).group(1),
    }
