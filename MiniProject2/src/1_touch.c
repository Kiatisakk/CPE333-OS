/*
 * 1_touch.c -- demand paging with anonymous memory.
 *
 *   ./1_touch [pages]          (default 1024 pages = 4 MiB)
 *
 * Maps a private anonymous region, then writes one byte to each page in
 * three steps: a quarter, half, then all of the pages. The process stops
 * itself (SIGSTOP) after mapping and after each step, so the counters can be
 * read while it is not running; SIGCONT resumes it.
 */
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

static void pause_here(void)
{
	fflush(stdout);
	raise(SIGSTOP);
}

int main(int argc, char **argv)
{
	long n = argc > 1 ? atol(argv[1]) : 1024;
	long page = sysconf(_SC_PAGESIZE);
	long marks[] = { n / 4, n / 2, n };
	long done = 0;
	char *buf;

	buf = mmap(NULL, n * page, PROT_READ | PROT_WRITE,
		   MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
	if (buf == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	/* One fault per 4 KiB page: no transparent huge pages here. */
	madvise(buf, n * page, MADV_NOHUGEPAGE);
	printf("[touch] mapped %ld pages, touched none\n", n);
	pause_here();

	for (int s = 0; s < 3; s++) {
		for (; done < marks[s]; done++)
			buf[done * page] = 1;
		printf("[touch] touched %ld of %ld pages\n", done, n);
		pause_here();
	}
	munmap(buf, n * page);
	return 0;
}
