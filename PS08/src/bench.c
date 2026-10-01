/*
 * Lock benchmark shared by every lock in this session.
 *
 *   ./<lock> <threads> <seconds>
 *
 * Each thread loops { lock; counter = counter + 1; unlock; } until the main
 * thread raises `stop`, and counts its own acquisitions.  One run measures
 * all four metrics from Lecture 8:
 *   mutual exclusion  counter must equal the sum of acquisitions (lost = 0)
 *   absence of deadlock  every thread returns and the run ends
 *   fairness          per-thread counts, min/max ratio
 *   performance       acquisitions per second
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include "lock.h"

#define MAX_THREADS 64

static volatile long counter;          /* the shared variable; plain, not atomic */
static atomic_int stop;
static pthread_barrier_t start;
static long acquired[MAX_THREADS];

static void *worker(void *arg)
{
    int id = (int)(long)arg;
    long n = 0;

    pthread_barrier_wait(&start);
    while (!stop) {
        lock_acquire(id);
        counter = counter + 1;          /* critical section */
        lock_release(id);
        n++;
    }
    acquired[id] = n;
    return NULL;
}

static double now(void)
{
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec / 1e9;
}

int main(int argc, char *argv[])
{
    if (argc != 3) {
        fprintf(stderr, "usage: %s <threads> <seconds>\n", argv[0]);
        return 2;
    }
    int nthreads = atoi(argv[1]);
    double secs = atof(argv[2]);
    if (nthreads < 1 || nthreads > MAX_THREADS ||
        (lock_max_threads && nthreads > lock_max_threads)) {
        fprintf(stderr, "%s: %d threads not supported\n", lock_name, nthreads);
        return 2;
    }

    pthread_t t[MAX_THREADS];
    lock_init(nthreads);
    pthread_barrier_init(&start, NULL, nthreads + 1);
    for (int i = 0; i < nthreads; i++)
        pthread_create(&t[i], NULL, worker, (void *)(long)i);

    pthread_barrier_wait(&start);
    double t0 = now();
    usleep((useconds_t)(secs * 1e6));
    atomic_store(&stop, 1);
    for (int i = 0; i < nthreads; i++)
        pthread_join(t[i], NULL);
    double elapsed = now() - t0;

    long total = 0, lo = acquired[0], hi = acquired[0];
    cpu_set_t cpus;
    sched_getaffinity(0, sizeof cpus, &cpus);
    printf("lock=%s threads=%d cpus=%d\n", lock_name, nthreads, CPU_COUNT(&cpus));
    for (int i = 0; i < nthreads; i++) {
        printf("  thread %d: %ld acquisitions\n", i, acquired[i]);
        total += acquired[i];
        if (acquired[i] < lo) lo = acquired[i];
        if (acquired[i] > hi) hi = acquired[i];
    }
    printf("total=%ld counter=%ld lost=%ld\n", total, counter, total - counter);
    printf("elapsed=%.3f s  throughput=%.0f acq/s  fairness(min/max)=%.3f\n",
           elapsed, total / elapsed, hi ? (double)lo / hi : 0.0);
    return 0;
}
