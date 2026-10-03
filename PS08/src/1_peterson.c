/* Peterson's algorithm: a software lock for two threads (ids 0 and 1).
 *
 * Default build: flag and turn are _Atomic with the default seq_cst order,
 * so the algorithm's sequential-consistency assumption holds in C11.
 * -DDEMO_FENCE / -DDEMO_NOFENCE build the textbook volatile version, with
 * and without a full fence.  Those are data races in C11; they only
 * demonstrate what GCC does on x86 and prove nothing about other targets. */
#include "lock.h"

#if defined(DEMO_NOFENCE)
const char *lock_name = "peterson_nofence";
#define FENCE() __asm__ volatile("" ::: "memory")   /* compiler barrier only */
typedef volatile int shared_t;
#elif defined(DEMO_FENCE)
const char *lock_name = "peterson_fence";
#define FENCE() __atomic_thread_fence(__ATOMIC_SEQ_CST)   /* full barrier on x86 */
typedef volatile int shared_t;
#else
const char *lock_name = "peterson";
#define FENCE() ((void)0)           /* seq_cst stores already order the loads */
typedef _Atomic int shared_t;
#endif
const int lock_max_threads = 2;

static shared_t flag[2];        /* flag[i] = 1: thread i wants in */
static shared_t turn;           /* whose turn it is to wait */

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
    flag[self] = 0;
}
