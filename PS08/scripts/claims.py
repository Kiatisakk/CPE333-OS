"""Check the comparative claims the slides make about results/bench.txt.

Called by run_all.sh; exits 1 if any claim no longer holds.  Each claim
compares medians of the REPS runs, never a single run.
"""
import sys
from results import LOCKS, bench, median

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
check("at 1 thread (no contention), TAS and LL/SC are the two fastest locks",
      sorted(LOCKS, key=lambda l: -tp(l, 1))[:2] in (["tas", "llsc"], ["llsc", "tas"]))
check("on all CPUs, every spin lock (LL/SC, MCS, TAS) is slower at 8 threads than at 1",
      all(tp(l, 8) < tp(l, 1) for l in ("llsc", "mcs", "tas")))
check("on one CPU, every spin lock at its most threads shows severe imbalance (median min/max <= 0.1)",
      all(fair(l, 2 if l == "peterson" else 8, "one-cpu") <= 0.1
          for l in ("peterson", "llsc", "mcs", "tas")))
check("on one CPU, mutex at 8 threads keeps at least half its 1-thread throughput",
      tp("mutex", 8, "one-cpu") >= tp("mutex", 1, "one-cpu") / 2)
check("on one CPU, Peterson and MCS with 2+ threads run over 10x slower than mutex",
      all(tp(l, t, "one-cpu") < tp("mutex", t, "one-cpu") / 10
          for l, ts in (("peterson", (2,)), ("mcs", (2, 4, 8))) for t in ts))
check("on one CPU at 8 threads, TAS and the CAS spin lock show severe imbalance (median min/max <= 0.1) but mutex does not (>= 0.5)",
      fair("tas", 8, "one-cpu") <= 0.1 and fair("llsc", 8, "one-cpu") <= 0.1
      and fair("mutex", 8, "one-cpu") >= 0.5)

# the slides quote fewest-vs-most counts; the ratio alone can print 0.000 for a thread that got in
nz = [r for rs in B.values() for r in rs if r["fairness"] == 0 and min(r["counts"]) > 0]
print(f"  info  {len(nz)} runs print fairness 0.000 although every thread got in at least once")
check("the run-to-run spread of one-CPU throughput is reported, not hidden: some one-CPU setting varies >= 3x",
      any(max(r["throughput"] for r in B[k]) >= 3 * min(r["throughput"] for r in B[k])
          for k in B if k[2] == "one-cpu"))
check("every run window is about the requested 1 s (0.99 s to 1.5 s)",
      all(0.99 <= r["window"] < 1.5 for rs in B.values() for r in rs))

sys.exit(fail)
