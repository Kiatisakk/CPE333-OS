/* Reference from Lecture 8 (slide 14): spin lock on Test-and-Set. */
#include "lock.h"

const char *lock_name = "tas";
const int lock_max_threads = 0;

static volatile int flag;

void lock_init(int nthreads) { (void)nthreads; flag = 0; }

void lock_acquire(int id)
{
    (void)id;
    while (__atomic_exchange_n(&flag, 1, __ATOMIC_ACQUIRE) == 1)
        ;   /* spin-lock */
}

void lock_release(int id) { (void)id; __atomic_store_n(&flag, 0, __ATOMIC_RELEASE); }
