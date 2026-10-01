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


check("Peterson (2 threads) and Bakery (2-8 threads) stay fair on all CPUs: median min/max >= 0.9",
      fair("peterson", 2) >= 0.9 and all(fair("bakery", t) >= 0.9 for t in (2, 4, 8)))
check("Bakery is the fairest lock at 8 threads on all CPUs",
      all(fair(l, 8) < fair("bakery", 8) for l in ("tas", "llsc", "mutex")))
check("on all CPUs at 8 threads, mutex is fastest and Bakery slowest",
      max(("mutex", "tas", "llsc", "bakery"), key=lambda l: tp(l, 8)) == "mutex"
      and min(("mutex", "tas", "llsc", "bakery"), key=lambda l: tp(l, 8)) == "bakery")
check("Bakery throughput falls as threads are added (2 -> 4 -> 8)",
      tp("bakery", 2) > tp("bakery", 4) > tp("bakery", 8))
check("on one CPU, Peterson and Bakery with 2+ threads run < 1/100 of mutex",
      all(tp(l, t, "one-cpu") < tp("mutex", t, "one-cpu") / 100
          for l, ts in (("peterson", (2,)), ("bakery", (2, 4, 8))) for t in ts))
check("on one CPU at 8 threads, TAS and LL/SC starve a thread (median min/max <= 0.1) but mutex does not (>= 0.5)",
      fair("tas", 8, "one-cpu") <= 0.1 and fair("llsc", 8, "one-cpu") <= 0.1
      and fair("mutex", 8, "one-cpu") >= 0.5)

sys.exit(fail)
