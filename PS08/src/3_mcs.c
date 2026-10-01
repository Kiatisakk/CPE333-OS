/* MCS queue lock (Mellor-Crummey and Scott, 1991).
 * Waiting threads form a linked list; each spins on its OWN node and is
 * woken by the thread ahead of it.  Linux's qspinlock is built on it. */
#include <stddef.h>
#include "lock.h"

const char *lock_name = "mcs";
const int lock_max_threads = 64;

struct node {
    struct node *next;          /* the thread queued behind me */
    int locked;                 /* 1 = keep waiting */
} __attribute__((aligned(64)));  /* one cache line per node */

static struct node qnode[64];   /* one node per thread */
static struct node *tail;       /* last in the queue; NULL = lock free */

#define LOAD(p)     __atomic_load_n(p, __ATOMIC_ACQUIRE)
#define STORE(p, v) __atomic_store_n(p, v, __ATOMIC_RELEASE)

void lock_init(int nthreads) { (void)nthreads; tail = NULL; }

void lock_acquire(int id)
{
    struct node *me = &qnode[id];
    me->next = NULL;
    me->locked = 1;
    struct node *prev = __atomic_exchange_n(&tail, me, __ATOMIC_ACQ_REL);
    if (prev != NULL) {         /* queue not empty: */
        STORE(&prev->next, me); /* link in behind prev */
        while (LOAD(&me->locked))
            ;                   /* spin on MY node only */
    }
}

void lock_release(int id)
{
    struct node *me = &qnode[id];
    struct node *next = LOAD(&me->next);
    if (next == NULL) {
        struct node *expect = me;
        if (__atomic_compare_exchange_n(&tail, &expect, NULL, 0,
                                        __ATOMIC_RELEASE, __ATOMIC_RELAXED))
            return;             /* nobody waiting: lock is free */
        while ((next = LOAD(&me->next)) == NULL)
            ;                   /* a waiter is still linking in */
    }
    STORE(&next->locked, 0);    /* hand the lock to the next thread */
}
