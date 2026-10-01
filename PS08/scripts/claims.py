"""Check the comparative claims the slides make about results/bench.txt.

Called by run_all.sh; exits 1 if any claim no longer holds.  Each claim
compares medians of the REPS runs, never a single run.
"""
import sys
from results import bench, median

B = bench()
fail = 0


def tp(lock, t, mode="all-cpus"):
    return median(B[(lock, t, mode)], "throughput")


def fair(lock, t, mode="all-cpus"):
    return median(B[(lock, t, mode)], "fairness")


def check(desc, ok):
    global fail
    print(f"  {'ok  ' if ok else 'FAIL'}  {desc}")
    fail |= not ok


MULTI = ("llsc", "mcs", "tas", "mutex")   # locks that run 8 threads

check("Peterson (2 threads) and MCS (2-8 threads) stay fair on all CPUs: median min/max >= 0.9",
      fair("peterson", 2) >= 0.9 and all(fair("mcs", t) >= 0.9 for t in (2, 4, 8)))
check("at 8 threads on all CPUs, MCS is the fairest lock",
      all(fair(l, 8) < fair("mcs", 8) for l in MULTI if l != "mcs"))
check("on all CPUs at 8 threads, mutex is the fastest lock",
      max(MULTI, key=lambda l: tp(l, 8)) == "mutex")
check("on one CPU, Peterson and MCS with 2+ threads run over 10x slower than mutex",
      all(tp(l, t, "one-cpu") < tp("mutex", t, "one-cpu") / 10
          for l, ts in (("peterson", (2,)), ("mcs", (2, 4, 8))) for t in ts))
check("on one CPU at 8 threads, TAS and LL/SC starve a thread (median min/max <= 0.1) but mutex does not (>= 0.5)",
      fair("tas", 8, "one-cpu") <= 0.1 and fair("llsc", 8, "one-cpu") <= 0.1
      and fair("mutex", 8, "one-cpu") >= 0.5)

sys.exit(fail)
