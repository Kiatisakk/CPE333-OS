#!/usr/bin/env bash
# PS3 item 1.1 -- `ps` versus `top`.
#
# `top -b -n 1`: batch mode, one iteration. That is the only way to capture it;
# on screen it repaints continuously instead.
set -u

echo "\$ ps -ef | head -5          # one snapshot, then it exits"
ps -ef | head -5
echo
echo "\$ top -b -n 1 | head -6     # a live monitor, sampled once"
top -b -n 1 | head -6
