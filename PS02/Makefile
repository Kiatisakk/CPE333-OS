# CPE 333 -- Problem Session 2: Process Creation & Pipes
#
# -Wno-unused-parameter is needed only because items 1.1 and 1.2 are transcribed
# verbatim from the lecture slides, which declare main(int argc, char *argv[])
# without using either parameter.

CC      := gcc
CFLAGS  := -std=c11 -D_DEFAULT_SOURCE -Wall -Wextra -Wno-unused-parameter -O0 -g

SRCDIR  := src
BINDIR  := bin

SRCS    := $(wildcard $(SRCDIR)/*.c)
BINS    := $(patsubst $(SRCDIR)/%.c,$(BINDIR)/%,$(SRCS))

.PHONY: all clean

all: $(BINS)

$(BINDIR)/%: $(SRCDIR)/%.c | $(BINDIR)
	$(CC) $(CFLAGS) -o $@ $<

$(BINDIR):
	mkdir -p $(BINDIR)

clean:
	rm -rf $(BINDIR)
