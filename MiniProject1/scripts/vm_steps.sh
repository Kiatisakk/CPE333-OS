#!/usr/bin/env bash
#
# CPE 333 Mini-Project 1 -- the kernel build, one step at a time, inside the VM.
#
#   bash vm_steps.sh <step>
#
# Each step follows "How to build an Ubuntu Linux kernel"
# (https://ubuntu.com/kernel/docs/how-to/develop-customise/build-kernel/)
# and prints every command before running it, then its exit status and how long
# it took. The host captures that output verbatim as the report's evidence.
#
# The only change made to the kernel is the one the guide asks for: the ABI
# number is set to 999 so the new kernel can be told apart from Canonical's.

set -u
export DEBIAN_FRONTEND=noninteractive
WORK="$HOME/kernel"

# The kernel version whose source is fetched. The guide writes $(uname -r),
# which is right when building on the machine that will run the kernel. When
# building in WSL, uname -r names Microsoft's WSL kernel instead, so the target
# VM's version is passed in explicitly: KVER=6.8.0-139-generic.
KVER=${KVER:-$(uname -r)}

# run <command...> -- echo it, run it, report exit status and elapsed time.
run() {
    printf '\n$ %s\n' "$*"
    local start=$SECONDS
    bash -c "$*"
    local rc=$?
    printf '[exit %d, %d s]\n' "$rc" "$((SECONDS - start))"
    return "$rc"
}

# The kernel source tree apt source unpacked, e.g. ~/kernel/linux-hwe-6.8-6.8.0
srcdir() {
    find "$WORK" -mindepth 1 -maxdepth 1 -type d -name 'linux*' | head -1
}

# Which debian.<flavour>/changelog is the live one. The guide edits
# debian.master/changelog for the generic kernel and debian.<derivative>/changelog
# otherwise; debian/debian.env names the right directory either way.
changelog() {
    local d
    d=$(sed -n 's/^DEBIAN=//p' "$(srcdir)/debian/debian.env")
    echo "$(srcdir)/${d:-debian.master}/changelog"
}

step=${1:-}
case $step in

env)
    run 'uname -r'
    run 'lsb_release -ds'
    run 'nproc'
    run 'free -h'
    run 'df -h /'
    ;;

swap)
    # Not a step in the guide. A normal Ubuntu Server install creates a swap
    # file; VirtualBox's unattended template sets its size to 0, so this VM has
    # none. The build runs six compile jobs in 8 GB for hours, and an OOM kill
    # near the end would waste all of it -- so restore the usual swap file.
    run 'swapon --show; free -h | grep Swap'
    run 'sudo fallocate -l 4G /swap.img && sudo chmod 600 /swap.img && sudo mkswap /swap.img && sudo swapon /swap.img'
    run 'grep -q "^/swap.img" /etc/fstab || echo "/swap.img none swap sw 0 0" | sudo tee -a /etc/fstab'
    run 'swapon --show; free -h | grep Swap'
    ;;

sources)
    # "Set up build environment": enable the deb-src entries. On 24.04 these
    # live in the deb822 file ubuntu.sources, as "Types: deb".
    run 'grep -n "^Types:" /etc/apt/sources.list.d/ubuntu.sources'
    run "sudo sed -i 's/^Types: deb\$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources"
    run 'grep -n "^Types:" /etc/apt/sources.list.d/ubuntu.sources'
    ;;

packages)
    # "Install required packages", verbatim from the guide.
    run 'sudo apt update'
    run "sudo apt build-dep -y linux linux-image-unsigned-${KVER}"
    run 'sudo apt install -y fakeroot llvm libncurses-dev dwarves'
    ;;

source)
    # "Get kernel source for version installed on build machine"
    mkdir -p "$WORK" && cd "$WORK" || exit 1
    run "apt source linux-image-unsigned-${KVER}"
    run 'ls -1'
    ;;

prepare)
    # "Prepare the kernel source"
    cd "$(srcdir)" || exit 1
    run 'pwd'
    run 'chmod a+x debian/scripts/* && chmod a+x debian/scripts/misc/* && fakeroot debian/rules clean'
    ;;

abi)
    # "Modify ABI number": the number after the dash becomes 999.
    cd "$(srcdir)" || exit 1
    cl=$(changelog)
    run "cat debian/debian.env"
    run "head -1 ${cl#$(srcdir)/}"
    run "sed -i '1s/-[0-9][0-9]*\\./-999./' ${cl#$(srcdir)/}"
    run "head -1 ${cl#$(srcdir)/}"
    ;;

build)
    # "Build the kernel". Long; the host starts this detached from SSH.
    cd "$(srcdir)" || exit 1
    run 'fakeroot debian/rules clean && fakeroot debian/rules binary'
    run 'ls -1 ../*.deb'
    ;;

install)
    # "Install the new kernel": the four packages the guide names.
    cd "$(srcdir)/.." || exit 1
    ver=$(sed -n '1s/^[^(]*(\([0-9.]*\)-999\..*/\1-999/p' "$(changelog)")
    run "ls -1 *.deb"
    run "sudo dpkg -i linux-headers-${ver}_*_all.deb"
    run "sudo dpkg -i linux-headers-${ver}-generic_*.deb"
    run "sudo dpkg -i linux-image-unsigned-${ver}-generic_*.deb"
    run "sudo dpkg -i linux-modules-${ver}-generic_*.deb"
    ;;

configure)
    # Not in the guide. Its install order puts linux-image-unsigned before
    # linux-modules, but the image package depends on the modules package, so
    # dpkg unpacks the image and leaves it unconfigured ("iU"). Installing the
    # modules afterwards does not go back and configure it, so the image's
    # postinst -- which builds the initramfs and adds the GRUB entry -- never
    # runs, and a reboot would not reach the new kernel. dpkg --configure -a
    # finishes every package left in that state.
    run "dpkg -l | grep -- '-999' | awk '{print \$1, \$2}'"
    run 'ls -1 /boot | grep -- -999'
    run 'sudo dpkg --configure -a'
    run "dpkg -l | grep -- '-999' | awk '{print \$1, \$2}'"
    run 'ls -1 /boot | grep -- -999'
    run "sudo grep -E \"^\\s*menuentry .*6\\.8\\.0-999\" /boot/grub/grub.cfg | cut -c1-90"
    ;;

verify)
    # "Test the new kernel": after the reboot, uname -r must match the changelog.
    run 'uname -r'
    run "head -1 $(changelog)"
    run "dpkg -l | grep -- '-999'"
    run 'ls -1 /boot/vmlinuz*'
    ;;

*)
    echo "usage: $0 env|swap|sources|packages|source|prepare|abi|build|install|verify" >&2
    exit 2
    ;;
esac
