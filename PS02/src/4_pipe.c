/*
 * PS2 item 4 -- pipe() + fork(), child sends, parent receives.
 *
 * pipe() fills fd[0] (read end) and fd[1] (write end).  fork() duplicates both
 * descriptors into the child, so four ends exist afterwards.  Each side closes
 * the end it does not use: the sender closes the read end, the receiver closes
 * the write end.  That is what makes the parent's read() see end-of-file once
 * the child is gone, instead of blocking forever on a pipe it holds open itself.
 *
 * Run with --race to remove the parent's usleep().  Without the usleep the order
 * of the first two lines is a genuine race between two runnable processes, and
 * the output will not always match the sheet's expected output.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

int main(int argc, char *argv[])
{
    int race = (argc > 1 && strcmp(argv[1], "--race") == 0);
    int fd[2];
    char msg[128];
    char buf[256];

    setvbuf(stdout, NULL, _IOLBF, 0);

    if (pipe(fd) == -1) {
        perror("pipe");
        exit(1);
    }

    pid_t rc = fork();
    if (rc < 0) {
        perror("fork");
        exit(1);
    }

    if (rc == 0) {
        /* ---- child: the SENDER, so it closes the read end ---- */
        close(fd[0]);

        printf("Child: Child PID: %d\n", (int) getpid());

        int n = snprintf(msg, sizeof msg, "Hello from child PID: %d\n", (int) getpid());
        if (write(fd[1], msg, (size_t) n) == -1) {
            perror("write");
            exit(1);
        }

        close(fd[1]);
        exit(0);
    }

    /* ---- parent: the RECEIVER, so it closes the write end ---- */
    close(fd[1]);

    if (!race) {
        usleep(50000);   /* give the child its turn, to match the expected output */
    }

    printf("Parent: Parent PID: %d\n", (int) getpid());

    ssize_t n = read(fd[0], buf, sizeof buf - 1);
    if (n == -1) {
        perror("read");
        exit(1);
    }
    buf[n] = '\0';
    printf("Parent: %s", buf);

    close(fd[0]);
    wait(NULL);
    return 0;
}
