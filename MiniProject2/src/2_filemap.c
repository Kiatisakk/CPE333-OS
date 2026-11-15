/*
 * 2_filemap.c -- major and minor faults on a file mapping.
 *
 *   ./2_filemap <file>
 *
 * Maps the file read-only and reads one byte from every page. When the file
 * is not in the page cache, each first access has to wait for the disk: a
 * major fault. When it is cached, the page only has to be mapped: a minor
 * fault. MADV_RANDOM turns off read-ahead, so the disk is read one page per
 * fault rather than in large batches.
 */
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

static void pause_here(void)
{
	fflush(stdout);
	raise(SIGSTOP);
}

int main(int argc, char **argv)
{
	long page = sysconf(_SC_PAGESIZE);
	volatile unsigned long sum = 0;
	struct stat st;
	long pages;
	char *p;
	int fd;

	if (argc != 2) {
		fprintf(stderr, "usage: %s <file>\n", argv[0]);
		return 2;
	}
	fd = open(argv[1], O_RDONLY);
	if (fd < 0 || fstat(fd, &st) < 0) {
		perror(argv[1]);
		return 1;
	}
	pages = st.st_size / page;
	p = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
	if (p == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	madvise(p, st.st_size, MADV_RANDOM);
	printf("[filemap] mapped %ld pages of %s, read none\n", pages, argv[1]);
	pause_here();

	for (long i = 0; i < pages; i++)
		sum += p[i * page];
	printf("[filemap] read one byte from each of %ld pages\n", pages);
	pause_here();

	munmap(p, st.st_size);
	close(fd);
	return 0;
}
