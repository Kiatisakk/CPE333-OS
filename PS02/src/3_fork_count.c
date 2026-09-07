/*
 * PS2 item 3 -- how many processes can we fork?
 *
 * Structure follows the Hint in the problem sheet: a recursive function where
 * the parent wait()s for its child and the child forks the next one.  At any
 * instant every ancestor is blocked in wait() and only the deepest process is
 * running, so the process count grows by one at a time (n) rather than by
 * doubling (2^n).  That is what keeps this from behaving like a fork bomb.
 *
 * No artificial limit is imposed: the program forks until fork() really fails.
 *
 * The count is also written to the file named by $FORK_COUNT_FILE, overwritten
 * on every successful fork.  Since the chain only ever goes deeper, that file
 * ends up holding the highest count reached.  This is needed because the
 * limiting resource may turn out to be memory, in which case the deepest
 * process is killed outright rather than getting an error back from fork(), and
 * would otherwise never get to report anything.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>

static const char *progress_path = NULL;

static void record(int successful_forks)
{
    char buf[32];
    int fd, n;

    if (progress_path == NULL) {
        return;
    }
    fd = open(progress_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd == -1) {
        return;
    }
    n = snprintf(buf, sizeof buf, "%d\n", successful_forks);
    if (write(fd, buf, (size_t) n) == -1) {
        /* best effort only */
    }
    close(fd);
}

/* If fork() ever does fail, the deepest process reports it and the chain unwinds. */
static void fork_deeper(int successful_forks)
{
    pid_t rc = fork();

    if (rc < 0) {
        printf("fork() failed: %s (errno=%d)\n", strerror(errno), errno);
        printf("successful fork() calls: %d\n", successful_forks);
        return;
    }

    if (rc == 0) {
        record(successful_forks + 1);
        fork_deeper(successful_forks + 1);
        exit(0);
    }

    wait(NULL);                      /* parent blocks until the chain unwinds */
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    progress_path = getenv("FORK_COUNT_FILE");
    record(0);
    fork_deeper(0);
    return 0;
}
