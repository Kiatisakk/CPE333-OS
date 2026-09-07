/*
 * PS2 item 5.2 -- the receiver reads before the sender sends anything.
 *
 * read() on a pipe with no data and at least one write end still open BLOCKS.
 * The parent calls read() at t=0; the child does not write until t=3.  The
 * timestamps printed either side of read() are the evidence: the call does not
 * return early, and it does not return an error -- it simply parks the process
 * until data arrives.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/wait.h>

#define CHILD_DELAY_SECONDS 3

static double now_seconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double) ts.tv_sec + (double) ts.tv_nsec / 1e9;
}

int main(void)
{
    int fd[2];
    char msg[128];
    char buf[256];

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (pipe(fd) == -1) { perror("pipe"); exit(1); }

    double t0 = now_seconds();

    pid_t rc = fork();
    if (rc < 0) { perror("fork"); exit(1); }

    if (rc == 0) {
        close(fd[0]);
        printf("[child ] t=%.3fs  sleeping %ds before writing\n",
                now_seconds() - t0, CHILD_DELAY_SECONDS);
        sleep(CHILD_DELAY_SECONDS);

        int n = snprintf(msg, sizeof msg, "Hello from child PID: %d\n", (int) getpid());
        write(fd[1], msg, (size_t) n);
        printf("[child ] t=%.3fs  wrote %d bytes\n", now_seconds() - t0, n);

        close(fd[1]);
        exit(0);
    }

    close(fd[1]);
    printf("[parent] t=%.3fs  calling read() -- pipe is still empty\n", now_seconds() - t0);

    ssize_t got = read(fd[0], buf, sizeof buf - 1);
    double t_return = now_seconds() - t0;

    if (got == -1) {
        perror("[parent] read");
    } else {
        buf[got] = '\0';
        printf("[parent] t=%.3fs  read() returned %zd bytes: %s", t_return, got, buf);
        printf("[parent] read() was blocked for about %.3f seconds\n", t_return);
    }

    close(fd[0]);
    wait(NULL);
    return 0;
}
