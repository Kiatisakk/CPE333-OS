/* Peterson's algorithm: a software lock for two threads (ids 0 and 1).
 * Build with -DNO_FENCE for the textbook version without a memory fence. */
#include "lock.h"

#ifdef NO_FENCE
const char *lock_name = "peterson_nofence";
#define FENCE() __asm__ volatile("" ::: "memory")   /* compiler barrier only */
#else
const char *lock_name = "peterson";
#define FENCE() __atomic_thread_fence(__ATOMIC_SEQ_CST)   /* full barrier on x86 */
#endif
const int lock_max_threads = 2;

static volatile int flag[2];   /* flag[i] = 1: thread i wants in */
static volatile int turn;      /* whose turn it is to wait */

void lock_init(int nthreads) { (void)nthreads; flag[0] = flag[1] = 0; turn = 0; }

void lock_acquire(int self)
{
    int other = 1 - self;
    flag[self] = 1;            /* I want to enter ...        */
    turn = other;              /* ... but you go first       */
    FENCE();                   /* stores done before the loads */
    while (flag[other] == 1 && turn == other)
        ;                      /* spin: you want in, your turn */
}

void lock_release(int self)
{
    FENCE();
    flag[self] = 0;
}
