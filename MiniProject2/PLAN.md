# Mini-Project 2 plan: Virtual Memory (Group 4)

## What the sheet asks

Topic "Virtual Memory: explore VMAs, page faults, residency, and demand paging."

- Create a page fault counter tool for a specific process.
- Get input as `process_id`.
- Show a summary containing: number of memory regions, total virtual address
  space, minor page faults, major page faults.
- Hints: tracepoint from a kernel module; `mm_struct`, `vm_area_struct`,
  `get_task_mm`; count the VMAs, compute each size from start and end, and
  compare with `/proc/<pid>/maps`.
- Deliverables: rebuilt kernel files, a 7-11 minute presentation with a demo,
  a report of at most 25 pages excluding the appendix.

## Decisions

| # | Decision |
|---|----------|
| Form | Loadable kernel module `pfcount`, built against the 6.8.0-999 headers inside the VM. No kernel rebuild. |
| Fault counts | Both: lifetime totals from `min_flt`/`maj_flt`, and faults seen since monitoring started from the tracepoints. |
| Extra field | Resident set size (RSS), to show demand paging. |
| Interface | `/proc/pfcount` (write a pid, read the summary), `/proc/pfcount_regions` (one line per VMA), and a `pfcount [-r] [-w] <pid>` command on top. |
| Targets | Three small C programs written for this project (below). |
| Experiments | All five (below). |
| Report | About 12 pages of body, the rest of the 25 is buffer. Two pages of theory with one diagram. Full source in the appendix. English. |
| Title block | CPE 333 Operating Systems, 1/2026. Mini-Project 2: Virtual Memory. Group 4. The six members of Mini-Project 1. |
| Screenshots | Capture now, decide later whether to embed. Try the VM console first (`VBoxManage controlvm ... screenshotpng`); fall back to a `demo.sh` the user runs and captures. |
| Git | Local commits only. No push until told. `MiniProject1/` is not touched. |
| Slides | A later round, built from the same `results/`. |

## Facts checked in the 6.8.0 source (WSL distro `Ubuntu-24.04-kernel`)

- The sheet's link (`include/trace/events/exceptions.h`) is the layout of newer
  kernels. In 6.8 the tracepoints are `page_fault_user` and `page_fault_kernel`
  in `arch/x86/include/asm/trace/exceptions.h`.
- Neither is exported to modules. `for_each_kernel_tracepoint` and
  `tracepoint_probe_register` are, so the module finds them by name.
- The probe receives `(address, regs, error_code)`. It does not say whether the
  fault was minor or major.
- `mm_account_fault()` in `mm/memory.c` does the classification: a fault is
  major when the handler returned `VM_FAULT_MAJOR` or had to retry, otherwise
  minor. Retried and failed faults are not counted. Faults taken on behalf of
  the process without a trap (`regs == NULL`) are counted but fire no tracepoint.
  So "faults seen" and "minor + major" are close but not the same quantity.
- `/proc/<pid>/stat` reports `signal->min_flt` plus every live thread's
  `min_flt`. The module sums the same way.
- `get_task_mm`, `mmput`, `find_get_pid`, `get_pid_task`, `mas_find` and the
  mmap-lock trace helpers are exported.
- The kernel has `CONFIG_LEGACY_VSYSCALL_XONLY=y`, so `/proc/<pid>/maps` ends
  with a `[vsyscall]` line that is not a VMA. The module's count is one lower.

## Module design

- **Load**: look up the two tracepoints by name, create the two `/proc` files
  (mode 0600, root only, since they expose any process's layout).
- **Write a pid**: resolve it to the thread-group `struct pid` and hold that
  reference (not the task), zero the live counters, snapshot the lifetime
  totals, register the probes. Writing `0` stops monitoring.
- **Probe**: `if (task_tgid(current) == target) atomic64_inc(...)`, one counter
  per tracepoint. Comparing the `struct pid` pointer is safe against pid reuse.
- **Read the summary**: `get_task_mm`, `mmap_read_lock`, walk with
  `for_each_vma`, count regions and sum `vm_end - vm_start`; read `get_mm_rss`;
  sum the fault totals over the thread group; print the live counters and the
  minor/major delta since the snapshot.
- **Unload**: unregister the probes, `tracepoint_synchronize_unregister`, remove
  the `/proc` files, drop the pid reference.

Output, as approved:

```
$ sudo pfcount 1234
pid 1234 (touch), 1 thread
  memory regions       : 19
  total virtual space  : 2712 kB (678 pages)
  resident (RSS)       : 1408 kB (352 pages)
  minor faults         : 131   since process start
  major faults         : 0     since process start
  since monitoring started:
    faults seen        : 13    (12 user mode, 1 kernel mode)
    minor / major      : 13 / 0
```

`-r` appends the region list (`start-end perms size`), `-w` refreshes every
second. A repeated call with the same pid reads on without resetting.

## Test programs

Each stops itself with `raise(SIGSTOP)` between stages, so the script can read
the counters while nothing is running and then send `SIGCONT`.

- `1_touch.c`: anonymous `mmap` of N pages with `MADV_NOHUGEPAGE`, then touches
  them in stages (0, N/4, N/2, N).
- `2_filemap.c`: `mmap` of an M-page file with `MADV_RANDOM`, reads one byte per
  page.
- `3_regions.c`: maps K regions with alternating protections so they cannot
  merge, then unmaps them.

## Experiments and what `run_all.sh` asserts

1. **Regions against `maps`** (all three programs): the region list equals
   columns 1-2 of `/proc/<pid>/maps` without `[vsyscall]`; the count is
   `maps` lines minus one; the total equals the sum of the sizes and `VmSize`.
2. **Demand paging, minor faults** (`1_touch`): touching N pages raises the
   minor count by N (asserted as N to N plus a small slack), major stays 0;
   lifetime totals equal fields 10 and 12 of `/proc/<pid>/stat`.
3. **Major faults** (`2_filemap`): after `drop_caches` the major count rises;
   on a second run with a warm cache it does not.
4. **Regions change** (`3_regions`): count rises by K and falls back; the total
   follows.
5. **Residency** (`1_touch`): virtual size constant across stages, RSS grows by
   the pages touched; RSS equals field 2 of `/proc/<pid>/statm`.

The script exits 1 when any assertion fails. Exact figures in the report are
read from `results/` at build time.

## Layout

```
MiniProject2/
  module/      pfcount.c, Makefile
  tools/       pfcount
  src/         1_touch.c  2_filemap.c  3_regions.c
  scripts/     vm.sh  run_all.sh  make_latex.py  build_pdf.ps1  shots.sh
  results/     one transcript per step and experiment
  screenshots/ captured, not embedded yet
  latex/       main.tex  preamble.tex  discussion/  generated/  figures/
```

`vm.sh` and `build_pdf.ps1` come from `MiniProject1/scripts/`;
`make_latex.py` (`needspace`, `source`, `check_coverage`) and `preamble.tex`
from `PS07/`.

## Report outline

1. Introduction: the task (half a page).
2. Background: address space and VMAs (`mm_struct`, the maple tree,
   `vm_area_struct`), demand paging, minor against major faults, how Linux
   counts them. One diagram. (2 pages)
3. Design and implementation: interface, VMA walk, fault totals, attaching to
   the tracepoints and why by name, build and load. Key excerpts only. (3 pages)
4. Experiments 1-5, each with its transcript and a short reading. (6 pages)
5. Conclusion and limits. (half a page)

Appendix: full source of the module, the command, and the three programs.

## Order of work

0. Commit the sheet as found. Scaffold. Start the VM headless; assert
   `uname -r` is `6.8.0-999-generic` and the headers are installed.
1. Module and `pfcount` command; build in the VM; smoke-test on `sleep`.
2. Test programs and `run_all.sh`; all assertions pass; transcripts in `results/`.
3. Console screenshots; judge them; `demo.sh` if they are not good enough.
4. `make_latex.py`, prose, diagram; build; verify 0 overfull boxes, every
   figure matches `results/`, body within 25 pages, every sheet item answered.
5. Local commit. Shut the VM down.

## Risks

- `lock_task_sighand` may not be usable from a module; fall back to an RCU walk
  of the thread group.
- `mm->total_vm` may differ from the summed VMA sizes; if so the report shows
  both and explains the difference instead of asserting equality.
- Fault counts between two stops can include a few faults outside the measured
  loop; the assertion allows a small slack and the report quotes the measured
  figure.
- The module is unsigned and taints the kernel; the report says so.
- The VM takes 8 GB of an 18 GB laptop: Docker closed while it runs.
