/*
 * PS2 item 5.3 -- the sender writes several messages before the receiver reads.
 *
 * A pipe is a byte stream, not a queue of messages.  The three write() calls do
 * not create three records; they append bytes to one buffer.  A single read()
 * with a large enough buffer returns all of them at once, and the returned byte
 * count equals the sum of the three writes -- there is no framing telling the
 * receiver where one message ended and the next began.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

#define MESSAGE_COUNT 3

int main(void)
{
    int fd[2];
    char msg[128];
    char buf[1024];

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (pipe(fd) == -1) { perror("pipe"); exit(1); }

    pid_t rc = fork();
    if (rc < 0) { perror("fork"); exit(1); }

    if (rc == 0) {
        close(fd[0]);

        int total = 0;
        for (int i = 1; i <= MESSAGE_COUNT; i++) {
            int n = snprintf(msg, sizeof msg,
                             "message %d from child PID: %d\n", i, (int) getpid());
            write(fd[1], msg, (size_t) n);
            total += n;
            printf("[child ] write() #%d sent %d bytes\n", i, n);
        }
        printf("[child ] %d separate write() calls, %d bytes in total\n",
                MESSAGE_COUNT, total);

        close(fd[1]);
        exit(0);
    }

    close(fd[1]);
    sleep(1);                       /* let all three writes land before reading */

    printf("[parent] calling read() ONCE with a %zu-byte buffer\n", sizeof buf);
    ssize_t got = read(fd[0], buf, sizeof buf - 1);
    if (got == -1) {
        perror("[parent] read");
        exit(1);
    }
    buf[got] = '\0';

    printf("[parent] a single read() returned %zd bytes:\n", got);
    printf("---- begin received data ----\n%s---- end received data ----\n", buf);

    close(fd[0]);
    wait(NULL);
    return 0;
}
