#!/usr/bin/env bash
#
# Host-side driver for building the kernel in WSL instead of the VirtualBox VM.
# Runs in Git Bash on Windows.
#
#   scripts/wsl.sh setup          create the build user in the WSL distro
#   scripts/wsl.sh step <name>    run one step of vm_steps.sh, save its log
#   scripts/wsl.sh build-start    start the long build detached
#   scripts/wsl.sh build-status   is it still running? tail of its log
#   scripts/wsl.sh build-fetch    copy the build log into results/wsl/
#
# Why WSL: VirtualBox cannot use AMD-V while Hyper-V is on, and falls back to
# the Hyper-V API. Measured with the same source, .config, gcc 13.3 and six
# jobs, that compiled 15 objects/min in the VM against 130/min in WSL.
#
# The guide explicitly allows installing the packages "on your build system or
# a different target system with the same architecture", so the .debs built
# here are installed into the VM afterwards with scripts/vm.sh.

set -u
cd "$(dirname "$0")/.." || exit 1

DISTRO=Ubuntu-24.04-kernel
KVER=6.8.0-139-generic          # the VM's kernel -- see vm_steps.sh
OUT=results/wsl
mkdir -p "$OUT"

# MSYS would otherwise rewrite the Linux paths below into Windows ones.
export MSYS_NO_PATHCONV=1

# --exec, not --: with "--" wsl.exe hands the command line to the user's login
# shell to parse again, so a bash -c "..." argument loses its quoting a second
# time -- redirections and $! then act in the wrong shell. --exec runs the
# program directly with the arguments exactly as given.
as_root()    { wsl.exe -d "$DISTRO" -u root --exec "$@"; }
as_builder() { wsl.exe -d "$DISTRO" -u builder --cd /home/builder --exec "$@"; }

# Copy the step script into the distro. Running it from /mnt/c would be
# hazardous: bash reads a script as it goes, so editing the repo copy during a
# multi-hour build could make the running build execute garbage.
push_script() {
    as_builder cp "/mnt/c/Users/kiati/Documents/CPE333-OS/MiniProject1/scripts/vm_steps.sh" vm_steps.sh
}

log_for() {
    case $1 in
        env)      echo "$OUT/01_env.txt" ;;
        sources)  echo "$OUT/02_sources.txt" ;;
        packages) echo "$OUT/03_packages.txt" ;;
        source)   echo "$OUT/04_source.txt" ;;
        prepare)  echo "$OUT/05_prepare.txt" ;;
        abi)      echo "$OUT/06_abi.txt" ;;
        build)    echo "$OUT/07_build.txt" ;;
        *) echo "unknown step: $1" >&2; exit 2 ;;
    esac
}

case ${1:-} in

setup)
    as_root bash -c 'id builder >/dev/null 2>&1 || useradd -m -s /bin/bash builder;
                     echo "builder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-kernel-build;
                     chmod 440 /etc/sudoers.d/90-kernel-build;
                     id builder'
    ;;

step)
    name=${2:?step name}
    [ "$name" = build ] && { echo "use build-start for the build" >&2; exit 2; }
    log=$(log_for "$name")
    push_script
    as_builder env KVER="$KVER" bash vm_steps.sh "$name" 2>&1 | tr -d '\r' | tee "$log"
    rc=${PIPESTATUS[0]}
    echo ">>> $name: exit $rc -> $log"
    exit "$rc"
    ;;

build-start)
    push_script
    # setsid -f, not "... &": wsl.exe tears down its session as soon as this
    # command returns, and a plain background job is still in that session, so
    # it was killed before it got going. setsid -f forks into a new session
    # immediately, before this shell exits.
    as_builder bash -c "mkdir -p logs; KVER=$KVER setsid -f nohup bash vm_steps.sh build > logs/build.log 2>&1 < /dev/null; sleep 2; pgrep -af '[v]m_steps.sh build' || echo 'NOT RUNNING'"
    ;;

build-status)
    as_builder bash -c 'if pgrep -f "[v]m_steps.sh build" >/dev/null; then echo RUNNING; else echo FINISHED; fi;
                        echo "log lines: $(wc -l < logs/build.log)"; tail -5 logs/build.log; echo; uptime'
    ;;

build-pause|build-resume)
    # SIGSTOP freezes every process of the build where it stands; SIGCONT lets
    # them carry on from exactly there. Nothing is lost -- provided the distro
    # itself keeps running, i.e. no "wsl --shutdown" and no Windows restart in
    # between. The build was started with setsid, so all of it shares one
    # session id and can be signalled together.
    sig=STOP; [ "$1" = build-resume ] && sig=CONT
    as_builder bash -c "
        pid=\$(pgrep -f '[v]m_steps.sh build') || { echo 'no build running'; exit 1; }
        sid=\$(ps -o sid= -p \$pid | tr -d ' ')
        pkill -$sig -s \$sid
        sleep 3
        echo \"session \$sid: \$(ps -s \$sid -o stat= | cut -c1 | sort | uniq -c | tr '\n' ' ')(T = stopped)\"
        uptime"
    ;;

build-fetch)
    as_builder cat logs/build.log | tr -d '\r' > "$OUT/07_build.txt"
    echo ">>> build log -> $OUT/07_build.txt ($(wc -l < "$OUT/07_build.txt") lines)"
    ;;

*)
    sed -n '3,11p' "$0"
    exit 2
    ;;
esac
