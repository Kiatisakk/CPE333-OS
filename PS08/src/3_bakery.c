/* Lamport's bakery algorithm: a software lock for N threads.
 * Each thread takes a number like a ticket in a bakery; the smallest number
 * enters first, ties broken by thread id. */
#include "lock.h"

#define N 64
#define FENCE() __atomic_thread_fence(__ATOMIC_SEQ_CST)

const char *lock_name = "bakery";
const int lock_max_threads = N;

static volatile int choosing[N];        /* 1 while thread i picks a number */
static volatile unsigned number[N];     /* 0 = not waiting */
static int n;

void lock_init(int nthreads) { n = nthreads; }

void lock_acquire(int i)
{
    choosing[i] = 1;
    FENCE();
    unsigned max = 0;
    for (int j = 0; j < n; j++)
        if (number[j] > max) max = number[j];
    number[i] = max + 1;        /* take the next number */
    FENCE();
    choosing[i] = 0;
    FENCE();

    for (int j = 0; j < n; j++) {
        while (choosing[j])
            ;                   /* j is still picking */
        while (number[j] != 0 &&
               (number[j] < number[i] ||
                (number[j] == number[i] && j < i)))
            ;                   /* j is ahead of me */
    }
}

void lock_release(int i)
{
    FENCE();
    number[i] = 0;
}
