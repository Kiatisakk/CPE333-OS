#!/usr/bin/env bash
#
# Host-side driver for Mini-Project 2. Runs in Git Bash on Windows.
#
#   scripts/vm.sh run          copy the project into the VM, run run_all.sh
#                              there as root, and bring results/ back
#   scripts/vm.sh sh <cmd>     run a command in the VM
#
# The VM is cpe333-kernel from Mini-Project 1, booted into the 6.8.0-999
# kernel built there. Its SSH key lives outside this repository, in
# C:\Users\kiati\VMs; only 127.0.0.1:2222 is forwarded to it.

set -u
cd "$(dirname "$0")/.." || exit 1

KEY=/c/Users/kiati/VMs/kernel-vm-setup/id_ed25519
KNOWN=/c/Users/kiati/VMs/kernel-vm-setup/known_hosts
SSH=(ssh -i "$KEY" -p 2222 -o UserKnownHostsFile="$KNOWN"
     -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10
     -o ServerAliveInterval=30 builder@127.0.0.1)

case ${1:-} in

run)
    # A fresh copy each time, so nothing stale from an earlier run survives.
    # sudo: the previous run made its results and binaries as root.
    tar -cf - module src tools scripts |
        "${SSH[@]}" 'sudo rm -rf mp2 && mkdir mp2 && tar -C mp2 -xf -' || exit 1
    "${SSH[@]}" 'sudo bash mp2/scripts/run_all.sh'
    rc=$?
    rm -rf results
    "${SSH[@]}" 'tar -C mp2 -cf - results' | tar -xf - || exit 1
    echo ">>> run_all.sh: exit $rc; results/ has $(ls results | wc -l) files"
    exit "$rc"
    ;;

sh)
    shift
    "${SSH[@]}" "$@"
    ;;

*)
    sed -n '3,11p' "$0"
    exit 2
    ;;
esac
