/*
 * 3_regions.c -- memory regions come and go with mmap and munmap.
 *
 *   ./3_regions
 *
 * Maps K regions of 16 pages each, then unmaps them. Each region is placed
 * at a fixed address with a one-region gap after it, so no two of them (and
 * none of them with an existing mapping) can merge into a single VMA. The
 * regions are never touched, so they cost no page faults and no RSS.
 */
#include <signal.h>
#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>

#define K		8
#define REGION_PAGES	16
#define BASE		0x600000000000UL	/* far from every other mapping */

static void pause_here(void)
{
	fflush(stdout);
	raise(SIGSTOP);
}

int main(void)
{
	long len = REGION_PAGES * sysconf(_SC_PAGESIZE);

	printf("[regions] nothing mapped yet\n");
	pause_here();

	for (int i = 0; i < K; i++) {
		void *at = (void *)(BASE + 2UL * i * len);

		if (mmap(at, len, PROT_READ | PROT_WRITE,
			 MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED_NOREPLACE,
			 -1, 0) != at) {
			perror("mmap");
			return 1;
		}
	}
	printf("[regions] mapped %d regions of %d pages from %#lx\n",
	       K, REGION_PAGES, BASE);
	pause_here();

	for (int i = 0; i < K; i++)
		munmap((void *)(BASE + 2UL * i * len), len);
	printf("[regions] unmapped all %d\n", K);
	pause_here();
	return 0;
}
