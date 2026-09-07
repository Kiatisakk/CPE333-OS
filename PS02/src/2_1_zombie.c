/*
 * PS2 item 2.1 -- child is dead while the parent is still running.
 *
 * The child exits immediately.  The parent never calls wait(), so the kernel
 * cannot release the child's process table entry: it keeps the exit status
 * around for a parent that never asks for it.  During the parent's sleep(),
 * `ps -ef` shows the child as <defunct>.
 *
 * The child prints its own getppid() before exiting -- that is the answer to
 * "report the child's parent process ID" for this scenario.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define PARENT_LINGER_SECONDS 10

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);   /* line-buffered, so redirection cannot reorder */

    printf("[parent] pid=%d ppid=%d\n", (int) getpid(), (int) getppid());

    int rc = fork();
    if (rc < 0) {
        perror("fork");
        exit(1);
    }

    if (rc == 0) {
        printf("[child ] pid=%d ppid=%d -- exiting immediately\n",
                (int) getpid(), (int) getppid());
        exit(0);
    }

    printf("[parent] forked child pid=%d; sleeping %ds WITHOUT calling wait()\n",
            rc, PARENT_LINGER_SECONDS);
    printf("[parent] run `ps -ef` now: child %d should appear as <defunct>\n", rc);
    sleep(PARENT_LINGER_SECONDS);
    printf("[parent] waking up and exiting; the zombie is now reaped by init\n");
    return 0;
}
