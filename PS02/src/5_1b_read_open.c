/*
 * PS2 item 5.1 (b) -- the sender tries to read back its own message, this time
 * WITHOUT closing the read end.
 *
 * A pipe is not a mailbox addressed to anyone.  It is one shared buffer, and
 * whichever process reads first takes the bytes.  Here the child writes and then
 * immediately reads, so it consumes its own message; the parent gets nothing.
 *
 * The parent's read() is protected by alarm(): a SIGALRM handler installed
 * WITHOUT SA_RESTART makes a blocked read() return EINTR instead of restarting,
 * so this program can never hang the test run.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <signal.h>
#include <unistd.h>
#include <sys/wait.h>

#define PARENT_PATIENCE_SECONDS 5

static void on_alarm(int sig) { (void) sig; }

int main(void)
{
    int fd[2];
    char msg[128];
    char buf[256];
    struct sigaction sa;

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (pipe(fd) == -1) { perror("pipe"); exit(1); }

    pid_t rc = fork();
    if (rc < 0) { perror("fork"); exit(1); }

    if (rc == 0) {
        /* sender -- deliberately keeps fd[0] open */
        int n = snprintf(msg, sizeof msg, "Hello from child PID: %d\n", (int) getpid());
        write(fd[1], msg, (size_t) n);
        printf("[child ] wrote %d bytes into the pipe (read end left OPEN)\n", n);

        ssize_t got = read(fd[0], buf, sizeof buf - 1);
        if (got == -1) {
            printf("[child ] read() failed: %s\n", strerror(errno));
        } else {
            buf[got] = '\0';
            printf("[child ] read back its OWN message (%zd bytes): %s", got, buf);
        }

        close(fd[0]);
        close(fd[1]);
        exit(0);
    }

    /* receiver */
    close(fd[1]);

    memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_alarm;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;                        /* no SA_RESTART -> read() returns EINTR */
    sigaction(SIGALRM, &sa, NULL);

    usleep(300000);                         /* make sure the child reads first */
    printf("[parent] now calling read(), giving up after %ds\n", PARENT_PATIENCE_SECONDS);
    alarm(PARENT_PATIENCE_SECONDS);

    ssize_t got = read(fd[0], buf, sizeof buf - 1);
    alarm(0);

    if (got == -1 && errno == EINTR) {
        printf("[parent] read() was still blocked after %ds -- the message is gone\n",
                PARENT_PATIENCE_SECONDS);
    } else if (got == -1) {
        printf("[parent] read() failed: %s\n", strerror(errno));
    } else if (got == 0) {
        printf("[parent] read() returned 0 (EOF): all write ends closed, nothing to read\n");
    } else {
        buf[got] = '\0';
        printf("[parent] received %zd bytes: %s", got, buf);
    }

    close(fd[0]);
    wait(NULL);
    return 0;
}
