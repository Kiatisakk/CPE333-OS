/*
 * PS2 item 2.2 -- parent is dead while the child is still running.
 *
 * The parent lingers just long enough for one `ps -ef` snapshot to catch both
 * processes alive, then exits.  The child outlives it and becomes an orphan, so
 * the kernel re-parents it.  The child prints getppid() twice -- once while the
 * parent is alive and once after it has died -- and those two values are the
 * answer to "report the child's parent process ID" for this scenario.
 *
 * Note: an orphan is NOT a zombie.  It is alive and running.  It only becomes a
 * defunct entry when it itself exits, and its new parent reaps it immediately,
 * so `ps` will not catch this child as <defunct>.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define PARENT_LINGER_SECONDS 2   /* long enough for one snapshot with both alive */
#define CHILD_FIRST_WAIT      4   /* child re-checks its parent after this */
#define CHILD_SECOND_WAIT     4   /* child stays visible to `ps` for this long */

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    printf("[parent] pid=%d ppid=%d\n", (int) getpid(), (int) getppid());

    int rc = fork();
    if (rc < 0) {
        perror("fork");
        exit(1);
    }

    if (rc == 0) {
        printf("[child ] pid=%d ppid=%d  (parent is still alive)\n",
                (int) getpid(), (int) getppid());
        sleep(CHILD_FIRST_WAIT);
        printf("[child ] pid=%d ppid=%d  (parent has died -- re-parented)\n",
                (int) getpid(), (int) getppid());
        sleep(CHILD_SECOND_WAIT);
        printf("[child ] pid=%d exiting\n", (int) getpid());
        exit(0);
    }

    printf("[parent] forked child pid=%d; exiting in %ds without calling wait()\n",
            rc, PARENT_LINGER_SECONDS);
    sleep(PARENT_LINGER_SECONDS);
    return 0;
}
