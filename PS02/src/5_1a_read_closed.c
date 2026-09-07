/*
 * PS2 item 5.1 (a) -- the sender tries to read back its own message, having
 * closed the read end as item 4 requires.
 *
 * fd[0] is no longer a valid descriptor in the child, so read() fails
 * immediately with EBADF.  Nothing is consumed from the pipe and the parent
 * still receives the message normally.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <sys/wait.h>

int main(void)
{
    int fd[2];
    char msg[128];
    char buf[256];

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (pipe(fd) == -1) { perror("pipe"); exit(1); }

    pid_t rc = fork();
    if (rc < 0) { perror("fork"); exit(1); }

    if (rc == 0) {
        /* sender, read end properly closed */
        close(fd[0]);

        int n = snprintf(msg, sizeof msg, "Hello from child PID: %d\n", (int) getpid());
        write(fd[1], msg, (size_t) n);
        printf("[child ] wrote %d bytes into the pipe\n", n);

        printf("[child ] now trying to read() back from fd[0], which it closed...\n");
        ssize_t got = read(fd[0], buf, sizeof buf - 1);
        if (got == -1) {
            printf("[child ] read() failed: %s (errno=%d)\n", strerror(errno), errno);
        } else {
            buf[got] = '\0';
            printf("[child ] read() unexpectedly returned %zd bytes: %s", got, buf);
        }

        close(fd[1]);
        exit(0);
    }

    /* receiver */
    close(fd[1]);
    usleep(200000);                 /* let the child finish its attempt first */

    ssize_t got = read(fd[0], buf, sizeof buf - 1);
    if (got == -1) {
        perror("[parent] read");
    } else {
        buf[got] = '\0';
        printf("[parent] received %zd bytes: %s", got, buf);
    }

    close(fd[0]);
    wait(NULL);
    return 0;
}
