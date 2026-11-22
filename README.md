# CPE 333 — Operating Systems (KMUTT)

Coursework, problem sessions, mini-projects, and study materials for **CPE 333 Operating Systems** at King Mongkut's University of Technology Thonburi (KMUTT).

## Repository Structure

### Mini-Projects (Group 4)

| Directory | Topic | Summary |
| :--- | :--- | :--- |
| [`MiniProject1/`](MiniProject1/) | **Custom Linux Kernel Build** | Building and installing a custom Ubuntu Linux kernel (ABI `999`), including VM/WSL build workflow, package transfer, `dpkg` dependency repair, and verification. |
| [`MiniProject2/`](MiniProject2/) | **Virtual Memory & Page Fault Counter (`pfcount`)** | Loadable Linux kernel module (`pfcount`) tracking per-process VMAs, RSS, and minor/major page faults via `page_fault_user`/`page_fault_kernel` tracepoints, exposed through `/proc/pfcount`, `/proc/pfcount_regions`, and a CLI wrapper. |

### Problem Sessions

| Directory | Topic | Summary |
| :--- | :--- | :--- |
| [`PS02/`](PS02/) | **Processes & Process APIs** | Process creation, management, and C experiments with LaTeX report. |
| [`PS03/`](PS03/) | **CPU Scheduling** | C scheduling simulation across multiple workload cases (`case1.csv`–`case3.csv`), plots, and report. |
| [`PS04/`](PS04/) | **Memory Allocation** | Memory management concepts and contiguous allocation experiments with report. |
| [`PS06/`](PS06/) | **Virtual Memory & Swap** | Linux virtual memory and temporary swapfile experiments (`free`, `vmstat`, `swapon`) with automated collection and LaTeX report. |
| [`PS07/`](PS07/) | **Concurrency & Threads** | Multithreaded ticket-booking race condition experiments and report. |
| [`PS08/`](PS08/) | **Lock Mechanisms** | Implementation, benchmarking, and presentation comparing Peterson's algorithm, LL/SC (CAS proxy), and MCS locks. |
| [`PS10/`](PS10/) | **Synchronization & Deadlock** | Beamer presentation comparing the Dining Philosophers and Cigarette Smokers problems. |
| [`PS12/`](PS12/) | **File Systems, IPC & `strace`** | Hard/symbolic links, named pipes (FIFO), and system call tracing (`strace`) report. |

## Tech Stack & Tools

- **Systems Programming:** C, POSIX Threads, Linux Kernel Modules (Linux 6.8)
- **Environment:** Ubuntu 24.04 (VM / WSL2), GCC, Make, `strace`
- **Automation & Analysis:** Bash, PowerShell, Python
- **Documentation:** LaTeX (`pdfLaTeX`, Beamer)
