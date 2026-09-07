/*
 * PS2 item 1.1 -- the fork() "hello world" example, transcribed verbatim from
 * the Lecture 2 slide "fork(): Hello World".
 *
 * The parent does NOT wait for the child, so after fork() returns there are two
 * runnable processes and the scheduler decides which one prints first.  The
 * order of the last two lines is therefore not deterministic.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

int
main(int argc, char *argv[])
{
    printf("hello world (pid:%d)\n", (int) getpid());
    int rc = fork();
    if (rc < 0) {
        // fork failed; exit
        fprintf(stderr, "fork failed\n");
        exit(1);
    } else if (rc == 0) {
        // child (new process)
        printf("hello, I am child (pid:%d)\n", (int) getpid());
    } else {
        // parent goes down this path (original process)
        printf("hello, I am parent of %d (pid:%d)\n",
                rc, (int) getpid());
    }
    return 0;
}
