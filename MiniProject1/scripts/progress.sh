#!/usr/bin/env bash
# Live progress of the kernel build, for watching by hand inside WSL:
#   bash ~/progress.sh
# Refreshes every 20 seconds. Ctrl+C stops watching -- the build carries on.
LOG=$HOME/logs/build.log
count() { grep -cE "$1" "$LOG"; }
while :; do
    clear
    if pgrep -f "[v]m_steps.sh build" >/dev/null; then state=RUNNING; else state=FINISHED; fi
    printf 'Kernel build -- %s   (%s)\n\n' "$state" "$(date +%T)"
    printf '  1. compile sources        %6s / ~18275\n' "$(count '^  (CC|AS)( \[M\])? .*[^d]\.o$')"
    printf '  2. .mod.o per module      %6s / 6275\n'   "$(count '^  CC \[M\] .*\.mod\.o$')"
    printf '  3. link .ko per module    %6s / 6275\n'   "$(count '^  LD \[M\] .*\.ko$')"
    printf '  4. BTF per module         %6s / 6275\n'   "$(count '^  BTF \[M\] ')"
    printf '  5. .deb packages          %6s\n\n'        "$(ls "$HOME"/kernel/*.deb 2>/dev/null | wc -l)"
    errs=$(grep -cE 'error:|\*\*\* ' "$LOG")
    printf '  errors in log: %s\n\n--- last lines ---\n' "$errs"
    tail -6 "$LOG" | cut -c1-110
    [ "$state" = FINISHED ] && { echo; grep '^\[exit' "$LOG"; break; }
    sleep 20
done
