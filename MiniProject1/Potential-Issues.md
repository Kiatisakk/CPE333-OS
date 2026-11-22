# Potential issues and limits

- The VM build transcript ends with a hand-written marker saying it was stopped
  after about 2h37m.  It is evidence of progress, not a completed VM build and
  not a compiler failure.
- WSL's `uname -r` is the Microsoft WSL kernel.  The build driver therefore
  passes `KVER=6.8.0-139-generic` so the produced packages target the VM.
- The WSL build log contains package metadata warnings and messages about
  optional BTF generation.  The build command still records `[exit 0, 22358 s]`
  and lists the expected `.deb` files.
- The VM image package initially remained unconfigured because the image was
  installed before its `linux-modules` dependency.  `dpkg --configure -a`
  completed the package post-install work and generated the initramfs and GRUB
  entries.
- `results/vm/09_verify.txt` is the captured post-reboot verification step, but
  the repository has no separate transcript of the reboot command and SSH
  reconnect.  The report states this explicitly and does not manufacture one.
- The built image is unsigned (`linux-image-unsigned-*`) and is identified by
  ABI 999.  The supplied evidence verifies that it booted in the VM; it does
  not claim a production signing workflow.
- Captured screenshots are stored under `latex/figures/` and embedded in the
  final report as supplementary visual evidence.  The text logs remain the
  source of truth, and no placeholder or fabricated screenshots are used.
