#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_PROCESSES 100

// you may change this if needed
typedef struct {
    int pid;        // process id (int)
    int arrival;    // arrival time
    int burst;      // burst time
    int remaining;  // remaining burst time
    int finished;   // 0 = not finished, 1 = done
} Process;


/* A negative pid means the CPU had nothing to run. */
static void print_slot(int pid, int from, int to) {
    if (pid < 0)
        printf("[%d-%d]: IDLE\n", from, to);
    else
        printf("[%d-%d]: P%d\n", from, to, pid);
}

/* The stretch being printed, held open until somebody else takes the CPU so
 * that consecutive stretches with the same owner merge into one slot. */
typedef struct {
    int pid;
    int from;
    int open;
} Slot;

static void slot_take(Slot *s, int pid, int at) {
    if (s->open && s->pid == pid)
        return;                     /* same owner: keep extending */
    if (s->open)
        print_slot(s->pid, s->from, at);
    s->pid = pid;
    s->from = at;
    s->open = 1;
}

static void slot_end(Slot *s, int at) {
    if (s->open)
        print_slot(s->pid, s->from, at);
    s->open = 0;
}

/* Ready queue: a min-heap of indices into procs[], ordered by
 * (remaining, pid) -- the sheet's rule, so the next process to run is the
 * root. Indices, not copies, so a remaining time is only ever recorded once. */
typedef struct {
    int v[MAX_PROCESSES];
    int n;
} Heap;

static int runs_first(const Process *p, int a, int b) {
    if (p[a].remaining != p[b].remaining)
        return p[a].remaining < p[b].remaining;
    return p[a].pid < p[b].pid;
}

static void heap_push(Heap *h, const Process *p, int idx) {
    int i = h->n++;
    h->v[i] = idx;
    while (i > 0) {                             /* sift up */
        int parent = (i - 1) / 2;
        if (!runs_first(p, h->v[i], h->v[parent]))
            break;
        int tmp = h->v[i]; h->v[i] = h->v[parent]; h->v[parent] = tmp;
        i = parent;
    }
}

static int heap_pop(Heap *h, const Process *p) {
    int top = h->v[0];
    h->v[0] = h->v[--h->n];
    int i = 0;
    for (;;) {                                  /* sift down */
        int l = 2 * i + 1, r = 2 * i + 2, best = i;
        if (l < h->n && runs_first(p, h->v[l], h->v[best])) best = l;
        if (r < h->n && runs_first(p, h->v[r], h->v[best])) best = r;
        if (best == i)
            break;
        int tmp = h->v[i]; h->v[i] = h->v[best]; h->v[best] = tmp;
        i = best;
    }
    return top;
}

static int by_arrival(const void *a, const void *b) {
    const Process *x = (const Process *)a, *y = (const Process *)b;
    if (x->arrival != y->arrival)
        return x->arrival < y->arrival ? -1 : 1;
    return x->pid < y->pid ? -1 : (x->pid > y->pid);
}

/*
 * STCF -- Shortest Time-to-Completion First, preemptive.
 *
 * The schedule can only change when a process arrives or the running one
 * finishes, so the chosen process is run through to whichever comes first
 * instead of re-deciding at every time unit: O(n log n), not O(T*n).
 *
 * procs[] is sorted in place; the caller's order is not preserved.
 */
void simulate_stfc(Process *procs, int n) {
    if (n <= 0)
        return;

    qsort(procs, (size_t)n, sizeof(procs[0]), by_arrival);

    /* A burst of zero is done before it starts. Left unfinished it would always
     * look like the shortest job, be chosen every time, and never end. */
    int done = 0;
    for (int i = 0; i < n; i++) {
        if (procs[i].remaining <= 0 && !procs[i].finished) {
            procs[i].finished = 1;
            done++;
        }
    }

    Heap ready;
    ready.n = 0;
    Slot slot = { -1, 0, 0 };
    int next = 0;                   /* the next process to arrive */
    int t = 0;

    while (done < n) {
        while (next < n && procs[next].arrival <= t) {
            if (!procs[next].finished)
                heap_push(&ready, procs, next);
            next++;
        }

        if (ready.n == 0) {         /* idle through to the next arrival */
            if (next >= n)
                break;              /* unreachable, but never hang */
            slot_take(&slot, -1, t);
            t = procs[next].arrival;
            continue;
        }

        int cur = heap_pop(&ready, procs);
        slot_take(&slot, procs[cur].pid, t);

        int run = procs[cur].remaining;
        if (next < n && procs[next].arrival - t < run)
            run = procs[next].arrival - t;    /* stop for the arrival */

        t += run;
        procs[cur].remaining -= run;

        if (procs[cur].remaining > 0) {
            heap_push(&ready, procs, cur);    /* interrupted, not finished */
        } else {
            procs[cur].finished = 1;
            done++;
        }
    }

    slot_end(&slot, t);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <csvfile>\n", argv[0]);
        return 1;
    }

    FILE *fp = fopen(argv[1], "r");
    if (!fp) {
        perror("Error opening file");
        return 1;
    }

    Process procs[MAX_PROCESSES];
    int n = 0;
    char line[256];

    // skip header line
    fgets(line, sizeof(line), fp);

    // read each row
    // you may change this if needed
    while (fgets(line, sizeof(line), fp) && n < MAX_PROCESSES) {
        int pid, arrival, burst;
        if (sscanf(line, "%d,%d,%d", &pid, &arrival, &burst) == 3) {
            procs[n].pid = pid;
            procs[n].arrival = arrival;
            procs[n].burst = burst;
            procs[n].remaining = burst;
            procs[n].finished = 0;
            n++;
        }
    }
    fclose(fp);

    simulate_stfc(procs, n);

    return 0;
}
