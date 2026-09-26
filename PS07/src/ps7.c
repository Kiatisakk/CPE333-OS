/*
 * PS7 -- a race condition in a concert ticket-booking system.
 *
 * The hall has SEATS seats. Several booking threads sell tickets from one
 * shared counter, seats_left, with no synchronisation. Each sale checks that a
 * seat is free, then writes back one fewer. When two threads read the same
 * value, both sell a ticket and both write the same result, so one decrement
 * is lost and more tickets are sold than the hall holds.
 *
 *   gcc -o ps7 ps7.c -lpthread
 *   ./ps7 1          one booking thread                       (task 1)
 *   ./ps7 4          four threads, no forced context switch   (task 2)
 *   ./ps7 4 yield    four threads, yielding mid-update         (task 3)
 */
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SEATS       1000000
#define MAX_THREADS 16

/* The shared variable. volatile so that every access is a real load or store
 * from memory, as the source reads, rather than a value the compiler keeps in
 * a register across iterations. */
static volatile int seats_left = SEATS;

static int force_switch;       /* set by the "yield" argument */

typedef struct {
    int  id;
    long sold;                 /* private to one thread: needs no locking */
} Booker;

static void *book(void *arg)
{
    Booker *me = arg;

    for (;;) {
        if (seats_left <= 0)               /* check: is a seat free?      */
            break;

        if (force_switch) {
            int reg = seats_left;          /* load memory into a register */
            reg = reg - 1;                 /* decrement the register      */
            sched_yield();                 /* force a context switch      */
            seats_left = reg;              /* store the register back     */
        } else {
            seats_left = seats_left - 1;   /* act: take the seat          */
        }
        me->sold++;
    }
    return NULL;
}

int main(int argc, char *argv[])
{
    int nthreads = argc > 1 ? atoi(argv[1]) : 4;
    force_switch = argc > 2 && strcmp(argv[2], "yield") == 0;

    if (nthreads < 1 || nthreads > MAX_THREADS) {
        fprintf(stderr, "usage: %s [threads 1-%d] [yield]\n", argv[0], MAX_THREADS);
        return 1;
    }

    pthread_t tid[MAX_THREADS];
    Booker    booker[MAX_THREADS];

    printf("%d booking thread(s), %d seats, forced context switch: %s\n",
           nthreads, SEATS, force_switch ? "yes" : "no");

    for (int i = 0; i < nthreads; i++) {
        booker[i].id = i + 1;
        booker[i].sold = 0;
        pthread_create(&tid[i], NULL, book, &booker[i]);
    }

    long total = 0;
    for (int i = 0; i < nthreads; i++) {
        pthread_join(tid[i], NULL);
        printf("  thread %d sold %ld tickets\n", booker[i].id, booker[i].sold);
        total += booker[i].sold;
    }

    printf("tickets sold: %ld for %d seats, seats left: %d\n",
           total, SEATS, seats_left);
    if (total == SEATS)
        printf("result: correct\n");
    else
        printf("result: OVERSOLD by %ld tickets\n", total - SEATS);
    return 0;
}
