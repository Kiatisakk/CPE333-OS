# PS08: presentation revision

The implemented deck has 19 slides, with two presenters per algorithm: Peterson = Tithinan + Siriwan; LL/SC = Kiatisak + Worawut; MCS = Thanaboon + Chanon. The separate evaluation-criteria slide was removed; its explanation is in the opening speaking notes. Slide 18 contains references. Slide 19 is an English comparison with seven columns: Algorithm, Mechanism, Correctness/Progress, Fairness, Low Contention, High Contention, and Worst Case/Limitations.

The final slide assignments and Thai speaking notes are in `presenter-guide.md`. Build the current deck with `scripts/build_slides.ps1`; output files are `slides/PS08_Algorithm_Analysis.pptx` and `.pdf`. The 22-slide outline below records the initial proposal; it is superseded by the final 19-slide structure.

## Assignment basis

The assignment asks students to research Peterson's algorithm, LL/SC, and one additional lock, then analyze correctness and performance using the class metrics. The reference's slides 3–6 introduce a mechanism, show its code, analyze an interleaving, and discuss wasted spinning on one processor. Lecture 8 slide 4 defines the four criteria: mutual exclusion, absence of deadlock, fairness, and performance overhead with and without contention. Neither supplied deck requires a benchmark experiment.

The presentation should explain what the code guarantees and what causes its overhead. A measured implementation can be supplemental evidence, but the main explanation should stand on its own. In particular, x86 CAS measurements do not establish LL/SC performance.

## Suggested 22-slide structure

| Slide | Subject | Main content |
| --- | --- | --- |
| 1 | Problem Session 08: Lock Mechanisms | Required algorithms and MCS as the additional mechanism |
| 2 | Group | Existing six presenters and their sections |
| 3 | Evaluation criteria | Four lecture metrics; atomicity, memory ordering, scheduling, and eventual unlock assumptions |
| 4 | Peterson's Algorithm | Section and presenter |
| 5 | Peterson: Idea | Two flags, turn, short pseudocode; sequential-consistency assumption |
| 6 | Peterson: Mutual Exclusion | Interleaving with both threads competing; last writer of turn waits |
| 7 | Peterson: Progress and Fairness | At least one contender can proceed; bounded waiting under the algorithm's assumptions; two-thread limit |
| 8 | Peterson: Performance Cases | No contention, contended shared state, and spinning while the holder is preempted |
| 9 | Load-Linked / Store-Conditional | Section and presenter |
| 10 | LL/SC: Idea | Reservation, conditional store, acquire/release lock pseudocode |
| 11 | LL/SC: Mutual Exclusion | Two LL reads of zero; one successful SC invalidates the other reservation |
| 12 | LL/SC: Progress and Fairness | Retry, eventual-progress assumptions, no FIFO or bounded-waiting guarantee |
| 13 | LL/SC: Performance Cases | Uncontended pair, failed SC attempts under contention, and preempted-holder scenario |
| 14 | MCS Lock | Section and presenter |
| 15 | MCS: Idea | Tail exchange, one node per waiter, own-node spinning, handoff |
| 16 | MCS: Mutual Exclusion | Queue head enters; release wakes its successor |
| 17 | MCS: Progress and Fairness | FIFO by queue-enqueue order for the original CAS-release variant; required threads must run and release |
| 18 | MCS: Performance Cases | Queue overhead; local spinning under contention; preempted holder or designated successor |
| 19 | Performance Across Workloads | Cases across all three locks, explained by code and scheduling; no universal speed ranking |
| 20 | Comparison of Guarantees | Four criteria and mechanism requirements, without benchmark-derived fairness scores |
| 21 | Conclusion | Guarantees, shared-state costs, and consequences of spinning under scheduling |
| 22 | References | Assignment, lecture, OSTEP, Arm documentation, original MCS paper |

Keep the current presenter allocation: the throughput presenter explains workload cases, and the summary presenter compares guarantees.

## Replacement LL/SC content

### Idea

Proposed slide text:

- `flag = 0` means free. `flag = 1` means held.
- Load-Linked reads `flag` and establishes a reservation.
- Store-Conditional writes only while that reservation remains valid.
- The caller enters only after a successful conditional store.

Conceptual pseudocode:

```text
lock():
    repeat:
        while LL_acquire(flag) != 0:
            spin
    until SC(flag, 1) succeeds

unlock():
    store_release(flag, 0)
```

`LL_acquire` and `store_release` explicitly state the ordering required for protected data. Define SC's result as success/failure here. AArch64's raw STXR status uses zero for success, so it should not be confused with a textbook helper that returns true for success.

Visual: free/held state and a short code excerpt. Hardware names can be a small annotation or speaker-note detail.

### Mutual exclusion

Use an interleaving in the style of reference slide 5:

| Step | Thread A | Thread B | Effect |
| --- | --- | --- | --- |
| 1 | LL reads 0 | | A establishes a reservation |
| 2 | | LL reads 0 | B also establishes a reservation |
| 3 | SC writes 1 successfully | | A enters; B's reservation becomes invalid |
| 4 | | SC fails | B stays outside and retries |
| 5 | Release stores 0 | | A leaves |
| 6 | | Fresh LL reads 0, then SC succeeds | B can enter |

The key explanation is that reading zero does not grant ownership. The successful SC claims the lock. Include the unlock step so the audience can follow a complete acquisition and release.

### Progress and fairness

Proposed slide text:

- A failed SC returns to a fresh LL attempt.
- Progress assumes the holder runs and releases the lock, and the exclusive loop can eventually succeed.
- Waiters have no queue or fixed entry order.
- This simple spin lock provides no bounded-waiting guarantee. A contender can repeatedly lose.

Put reservation loss and possible spurious failure in the explanation of retries. Keep the LL-to-SC sequence short, subject to the architecture's rules. Do not call the loop lock-free: a suspended lock holder can block every waiter.

### Performance cases

| Case | What the code does | Cost or consequence |
| --- | --- | --- |
| No contention | LL sees zero; SC succeeds on the first attempt | Acquisition has a short instruction path without waiting |
| Multiple contenders on multiple cores | Waiters read the shared flag; when free they compete to write it | Failed attempts retry; modifications invalidate reservations and involve shared-memory coherence |
| Long critical section | The flag remains held while others execute the wait loop | Waiters consume CPU cycles for longer |
| One CPU with a preempted holder | A waiter runs while the holder is unable to execute | The waiter spins until scheduling lets the holder run and unlock |

Visual for the scheduling case: A acquires; scheduler switches to B; B spins; scheduler runs A again; A releases; B can acquire. This is a qualitative execution scenario, not a measured timeline.

LL/SC is architecture-specific. That limits native implementation choices on this x86 machine, but does not prevent explaining the algorithm or analyzing these cases from its code and documented semantics.

## Deck changes from the existing 34-slide version

- Condense the evaluation introduction to the four lecture metrics and assumptions. Move the benchmark loop, output-reading example, environment setup, and experiment methodology out of the main narrative.
- Replace each lock's throughput graph with code-path and scheduling cases.
- Replace empirical fairness ratios with waiting-order guarantees and their assumptions.
- Use interleavings and queue diagrams for correctness. Avoid presenting `lost = 0` as the argument for mutual exclusion.
- Replace the all-CPU/one-CPU graphs and variation slide with a workload-case comparison and a guarantee table.
- Use short algorithm pseudocode on the main slides. Keep inline assembly, disassembly, and optional experiments in supplementary material only if useful.

## Cross-lock points that must stay accurate

- Peterson depends on suitable memory ordering. `volatile` alone does not establish the required concurrency semantics.
- LL/SC retries on lost reservations, and this spin lock does not impose an entry order.
- MCS reduces coherence contention by letting each waiter spin on its own node. Its queue does not cause waiting threads to sleep or transfer CPU time to the lock holder.
- MCS FIFO follows queue insertion order. It does not promise equal acquisition counts within an arbitrary time window.
- A preempted MCS successor can stall later waiters even after the previous holder releases.
- Short critical sections with running holders can favor spinning. Long waits, oversubscription, and preemption can make spinning costly. No mechanism is universally fastest from this analysis alone.

Primary-source support is recorded in `algorithm-behavior.md` alongside this proposal.
