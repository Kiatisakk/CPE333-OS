#!/usr/bin/env bash
set -Eeuo pipefail

# Collect the Linux part of PS06 into one reproducible transcript.
# Run this script from Ubuntu/WSL. It deliberately refuses to reuse an
# existing /swapfile_ps6 so that a previous experiment cannot be overwritten.

export LC_ALL=C

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
RESULT_DIR="$ROOT_DIR/results"
OUTPUT="$RESULT_DIR/complete_linux_output.txt"
SWAP_FILE="/swapfile_ps6"
TMP_OUTPUT="$(mktemp "${TMPDIR:-/tmp}/ps06-linux.XXXXXX")"
SWAP_ENABLED=0
SWAP_CREATED=0

cleanup() {
    local status=$?
    if (( SWAP_ENABLED )); then
        sudo swapoff "$SWAP_FILE" >/dev/null 2>&1 || true
    fi
    if (( SWAP_CREATED )) && [[ -e "$SWAP_FILE" ]]; then
        sudo rm -f -- "$SWAP_FILE" >/dev/null 2>&1 || true
    fi
    if [[ -n "$TMP_OUTPUT" ]]; then
        rm -f -- "$TMP_OUTPUT"
    fi
    exit "$status"
}
trap cleanup EXIT INT TERM

mkdir -p -- "$RESULT_DIR"

if [[ -e "$SWAP_FILE" ]]; then
    printf 'Refusing to use existing %s. Remove it only after confirming it belongs to this experiment.\n' "$SWAP_FILE" >&2
    exit 1
fi

if ! command -v free >/dev/null 2>&1 || ! command -v vmstat >/dev/null 2>&1; then
    printf 'procps is required; installing it with apt...\n' >&2
    sudo apt-get update
    sudo apt-get install -y procps
fi

section() {
    local title=$1
    local command_text=$2
    shift 2
    {
        printf '\n%s\n' "$title"
        printf '$ %s\n' "$command_text"
        "$@"
    } >>"$TMP_OUTPUT"
}

section "FREE - BASIC" "free" free
section "FREE - HELP" "free --help" free --help
section "FREE - HUMAN READABLE" "free -h" free -h
section "FREE - FIVE SAMPLES, TWO SECONDS APART" "free -s 2 -c 5" free -s 2 -c 5

section "VMSTAT - BASIC" "vmstat" vmstat
section "VMSTAT - HELP" "vmstat --help" vmstat --help
section "VMSTAT - STATISTICS" "vmstat -s" vmstat -s
section "VMSTAT - FIVE SAMPLES, TWO SECONDS APART" "vmstat 2 5" vmstat 2 5

section "SWAP - BEFORE" "swapon --show" swapon --show
section "SWAP - BEFORE (FREE)" "free -h" free -h

{
    printf '\nSWAP - CREATE AND ENABLE 1 GIB FILE\n'
    printf '$ sudo fallocate -l 1G %s\n' "$SWAP_FILE"
    sudo fallocate -l 1G "$SWAP_FILE"
    SWAP_CREATED=1
    printf '$ sudo chmod 600 %s\n' "$SWAP_FILE"
    sudo chmod 600 "$SWAP_FILE"
    printf '$ sudo mkswap %s\n' "$SWAP_FILE"
    sudo mkswap "$SWAP_FILE"
    printf '$ sudo swapon %s\n' "$SWAP_FILE"
    sudo swapon "$SWAP_FILE"
    SWAP_ENABLED=1
} >>"$TMP_OUTPUT"

section "SWAP - AFTER INCREASE" "swapon --show" swapon --show
section "SWAP - AFTER INCREASE (FREE)" "free -h" free -h

{
    printf '\nSWAP - AFTER DECREASE\n'
    printf '$ sudo swapoff %s\n' "$SWAP_FILE"
    sudo swapoff "$SWAP_FILE"
    SWAP_ENABLED=0
    printf '$ swapon --show\n'
    swapon --show
    printf '$ free -h\n'
    free -h
    printf '$ sudo rm %s\n' "$SWAP_FILE"
    sudo rm -- "$SWAP_FILE"
    SWAP_CREATED=0
} >>"$TMP_OUTPUT"

mv -- "$TMP_OUTPUT" "$OUTPUT"
TMP_OUTPUT=""
printf 'Wrote %s\n' "$OUTPUT"
