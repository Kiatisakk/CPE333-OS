#!/usr/bin/env bash
#
# Host-side driver for the Mini-Project 1 build VM. Runs in Git Bash on Windows.
#
#   scripts/vm.sh step <name>     run one step of vm_steps.sh, save its log
#   scripts/vm.sh build-start     start the long build detached from SSH
#   scripts/vm.sh build-status    is the build still running? tail of its log
#   scripts/vm.sh build-fetch     copy the finished build log into results/
#   scripts/vm.sh reboot          reboot the VM and wait for SSH to return
#   scripts/vm.sh sh <command>    run an arbitrary command in the VM
#
# The VM (cpe333-kernel) and its SSH key live outside this repository, in
# C:\Users\kiati\VMs. Only 127.0.0.1:2222 is forwarded to it.

set -u
cd "$(dirname "$0")/.." || exit 1

KEY=/c/Users/kiati/VMs/kernel-vm-setup/id_ed25519
KNOWN=/c/Users/kiati/VMs/kernel-vm-setup/known_hosts
USER_AT=builder@127.0.0.1
SSH=(ssh -i "$KEY" -p 2222 -o UserKnownHostsFile="$KNOWN"
     -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10
     -o ServerAliveInterval=30 "$USER_AT")
SCP=(scp -q -i "$KEY" -P 2222 -o UserKnownHostsFile="$KNOWN"
     -o StrictHostKeyChecking=accept-new)

mkdir -p results/vm

# Step name -> log file. The number is the order the report presents them in.
log_for() {
    case $1 in
        env)      echo results/vm/01_env.txt ;;
        swap)     echo results/vm/01a_swap.txt ;;
        sources)  echo results/vm/02_sources.txt ;;
        packages) echo results/vm/03_packages.txt ;;
        source)   echo results/vm/04_source.txt ;;
        prepare)  echo results/vm/05_prepare.txt ;;
        abi)      echo results/vm/06_abi.txt ;;
        build)    echo results/vm/07_build.txt ;;
        install)  echo results/vm/08_install.txt ;;
        configure) echo results/vm/08a_configure.txt ;;
        verify)   echo results/vm/09_verify.txt ;;
        *) echo "unknown step: $1" >&2; exit 2 ;;
    esac
}

push_script() {
    "${SCP[@]}" scripts/vm_steps.sh "$USER_AT:vm_steps.sh"
}

case ${1:-} in

step)
    name=${2:?step name}
    [ "$name" = build ] && { echo "use build-start for the build" >&2; exit 2; }
    log=$(log_for "$name")
    push_script
    # The log is written on the host as the output arrives, so a dropped SSH
    # connection still leaves everything up to that point.
    "${SSH[@]}" "bash vm_steps.sh $name" 2>&1 | tr -d '\r' | tee "$log"
    rc=${PIPESTATUS[0]}
    echo ">>> $name: exit $rc -> $log"
    exit "$rc"
    ;;

build-start)
    push_script
    # setsid + nohup: the build must outlive this SSH session by hours.
    "${SSH[@]}" 'mkdir -p logs && setsid nohup bash vm_steps.sh build > logs/build.log 2>&1 < /dev/null & echo started, pid $!'
    ;;

build-status)
    # "[v]m_steps" rather than "vm_steps": this command line itself contains the
    # pattern, so without the bracket pgrep matches its own shell and the build
    # looks as if it is running forever.
    "${SSH[@]}" 'if pgrep -f "[v]m_steps.sh build" >/dev/null; then echo RUNNING; else echo FINISHED; fi;
                 echo "elapsed log lines: $(wc -l < logs/build.log)"; tail -5 logs/build.log;
                 echo; uptime; df -h / | tail -1'
    ;;

build-fetch)
    "${SCP[@]}" "$USER_AT:logs/build.log" results/vm/07_build.txt
    tr -d '\r' < results/vm/07_build.txt > results/vm/07_build.tmp && mv results/vm/07_build.tmp results/vm/07_build.txt
    echo ">>> build log -> results/vm/07_build.txt ($(wc -l < results/vm/07_build.txt) lines)"
    ;;

reboot)
    "${SSH[@]}" 'sudo systemctl reboot' 2>/dev/null
    echo "rebooting; waiting for SSH..."
    sleep 15
    for _ in $(seq 1 60); do
        if "${SSH[@]}" true 2>/dev/null; then echo "back up"; exit 0; fi
        sleep 5
    done
    echo "VM did not come back within 5 minutes" >&2
    exit 1
    ;;

sh)
    shift
    "${SSH[@]}" "$@"
    ;;

*)
    sed -n '3,12p' "$0"
    exit 2
    ;;
esac
