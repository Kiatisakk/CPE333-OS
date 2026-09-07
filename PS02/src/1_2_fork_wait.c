/*
 * PS2 item 1.2 -- the same program as 1.1, with the parent's branch modified as
 * shown on the Lecture 2 slide "wait(): Example Usage".
 *
 * wait(NULL) suspends the parent until the child terminates, so the child's
 * line is now guaranteed to be printed before the parent's.  <sys/wait.h> is
 * added because wait() is declared there; everything else is as on the slide.
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

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
        int wc = wait(NULL);
        printf("hello, I am parent of %d (wc:%d) (pid:%d)\n",
                rc, wc, (int) getpid());
    }
    return 0;
}
