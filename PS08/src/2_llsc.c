/* Spin lock built on Load-Linked / Store-Conditional (OSTEP 28.8).
 * On AArch64 LL/SC are the ldaxr/stxr instructions.  x86 has no LL/SC, so
 * the x86 build uses compare-and-swap in the same loop as a stand-in. */
#include "lock.h"

const char *lock_name = "llsc";
const int lock_max_threads = 0;

static volatile int flag;      /* 0 = free, 1 = held */

#if defined(__aarch64__)
static inline int LoadLinked(volatile int *p)
{
    int v;
    __asm__ volatile("ldaxr %w0, [%1]"
                     : "=r"(v) : "r"(p) : "memory");
    return v;
}

static inline int StoreConditional(volatile int *p, int v)
{
    int fail;                  /* stxr: 0 = stored, 1 = failed */
    __asm__ volatile("stxr %w0, %w2, [%1]"
                     : "=&r"(fail) : "r"(p), "r"(v) : "memory");
    return !fail;
}
#else
static inline int LoadLinked(volatile int *p) { return *p; }
static inline int StoreConditional(volatile int *p, int v)
{
    int expect = 0;            /* succeed only if the lock is still free */
    return __atomic_compare_exchange_n(p, &expect, v, 0,
                                       __ATOMIC_ACQUIRE, __ATOMIC_RELAXED);
}
#endif

void lock_init(int nthreads) { (void)nthreads; flag = 0; }

void lock_acquire(int id)
{
    (void)id;
    while (1) {
        while (LoadLinked(&flag))
            ;                  /* spin until it is zero */
        if (StoreConditional(&flag, 1))
            return;            /* no store in between: ours */
        /* else another thread won: try again */
    }
}

void lock_release(int id)
{
    (void)id;
    __atomic_store_n(&flag, 0, __ATOMIC_RELEASE);
}
