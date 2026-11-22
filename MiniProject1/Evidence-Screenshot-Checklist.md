# Evidence and screenshot checklist

The report uses the captured terminal transcripts under `results/vm/` and
`results/wsl/`. The PDF listings are generated from those logs by
`scripts/make_evidence.ps1`; the full logs remain the source of truth.

- [x] VM baseline, swap, source setup, preparation, ABI change, installation, package configuration, and post-reboot verification logs are present.
- [x] WSL baseline, source setup, package installation, preparation, ABI change, and completed build logs are present.
- [x] The VM partial build is described as stopped by hand after about 2h37m.
- [x] The WSL build completion and `[exit 0, 22358 s]` record are included.
- [x] The image dependency issue and `dpkg --configure -a` repair are shown.
- [x] `uname -r` verification is shown after the VM reboot workflow.
- [x] Captured screenshots under `latex/figures/` are embedded: WSL package outputs, GRUB's retained ABI-999/ABI-139 kernels, and post-reboot VM verification.
