#!/usr/bin/env bash
#
# Screenshots of pfcount on the VM's own console (tty1). Runs in Git Bash.
#
#   scripts/shots.sh
#
# Types the commands into the console with VBoxManage and saves what the
# screen shows to screenshots/*.png. Expects run_all.sh to have run, so the
# module is loaded and ~/mp2/bin holds the test programs. The password goes
# in with keyboardputfile, straight from the file outside the repository, so
# it never appears on a command line.

set -u
cd "$(dirname "$0")/.." || exit 1

VB="/c/Program Files/Oracle/VirtualBox/VBoxManage.exe"
VM=cpe333-kernel
PW=/c/Users/kiati/VMs/kernel-vm-setup/password.txt
OUT=screenshots
mkdir -p "$OUT"

enter()    { "$VB" controlvm "$VM" keyboardputscancode 1c 9c; }
line()     { "$VB" controlvm "$VM" keyboardputstring "$1"; enter; sleep "${2:-2}"; }
password() { "$VB" controlvm "$VM" keyboardputfile "$(cygpath -w "$PW")"; enter; sleep 4; }
shot()     { "$VB" controlvm "$VM" screenshotpng "$(cygpath -w "$PWD/$OUT/$1.png")" && echo "-> $OUT/$1.png"; }

# ---- log in and become root
enter; sleep 2
line builder 3
password
line 'sudo -i' 3
password
line 'cd /home/builder/mp2 && export PATH=$PWD/tools:$PATH'

# ---- 1: the module is loaded
line 'clear; uname -r; lsmod | grep pfcount; dmesg | grep pfcount: | tail -1; ls -l /proc/pfcount*' 3
shot 01_module

# ---- 2: demand paging -- before and after touching every page
line 'clear; ./bin/1_touch 1024 &' 3
line 'pfcount $!' 3
shot 02_touch_none
line 'kill -CONT $!; sleep 1; kill -CONT $!; sleep 1; kill -CONT $!; sleep 1' 5
line 'clear; pfcount $!' 3
shot 03_touch_all
line 'kill -CONT $!' 3

# ---- 3: the module's regions against /proc/<pid>/maps
line 'clear; ./bin/1_touch 1024 &' 3
line 'pfcount $! | head -3; wc -l < /proc/$!/maps' 3
line 'diff <(cut -d" " -f1 /proc/$!/maps) <(cut -d" " -f1 /proc/pfcount_regions)' 3
shot 04_maps_diff
line 'kill -KILL $!' 2

# ---- 4: major faults with a cold page cache
line 'dd if=/dev/urandom of=/var/tmp/shot.bin bs=4096 count=2048 status=none' 8
line 'sync; echo 3 > /proc/sys/vm/drop_caches' 5
line 'clear; ./bin/2_filemap /var/tmp/shot.bin &' 4
line 'pfcount $! > /dev/null; kill -CONT $!; sleep 6; pfcount $!' 10
shot 05_major_cold
line 'kill -CONT $!; rm -f /var/tmp/shot.bin' 2

# ---- leave the console as found
line 'clear; logout' 2
line 'logout' 2
