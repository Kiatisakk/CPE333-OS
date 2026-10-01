/* Reference from Lecture 8 (slide 31): pthread_mutex, a futex-based
 * two-phase lock that sleeps instead of spinning when contended. */
#include <pthread.h>
#include "lock.h"

const char *lock_name = "mutex";
const int lock_max_threads = 0;

static pthread_mutex_t m = PTHREAD_MUTEX_INITIALIZER;

void lock_init(int nthreads) { (void)nthreads; }
void lock_acquire(int id) { (void)id; pthread_mutex_lock(&m); }
void lock_release(int id) { (void)id; pthread_mutex_unlock(&m); }
