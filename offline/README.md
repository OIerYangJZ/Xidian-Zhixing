# Offline deployment bundles

This directory is intentionally empty in Git. Generate target-compatible files on a connected Ubuntu 22.04 x86-64 build host:

```bash
sudo ./scripts/prepare_offline_debs_ubuntu2204.sh
./scripts/prepare_offline_wheels.sh
```

Upload the generated directories to `/home/ubuntu/treehole/offline/` with WinSCP/SFTP. Do not generate or copy Python wheels from macOS ARM.
