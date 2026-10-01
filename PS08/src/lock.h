/* The interface every lock in this session implements; bench.c drives it. */
#ifndef LOCK_H
#define LOCK_H

extern const char *lock_name;
extern const int lock_max_threads;     /* 0 = any number */

void lock_init(int nthreads);
void lock_acquire(int id);             /* id = 0 .. nthreads-1 */
void lock_release(int id);

#endif
