# Lab 5 — Virtualization: QuickNotes in a Vagrant VM

## Task 1 — Vagrant Up + Run QuickNotes Inside

### Vagrantfile

The submitted [`Vagrantfile`](../Vagrantfile) uses the public `bento/ubuntu-24.04` box.

### Evidence

`vagrant up` (first 10 lines):

```text
<!-- paste the real first 10 lines here -->
```

Go version inside the VM:

```text
<!-- paste: vagrant ssh -c 'go version' -->
```

Health endpoint inside the VM:

```text
<!-- paste: vagrant ssh -c 'curl -s http://127.0.0.1:8080/health' -->
```

Health endpoint from the host through the port forward:

```text
<!-- paste: curl -s http://localhost:18080/health -->
```

### Design answers

**a) Synced folders.** I chose the `virtualbox` synced-folder type and mounted the host's `app/` directory at `/opt/quicknotes/app` in the guest. It is simple for a Windows host and needs no separate NFS or SMB server configuration. The trade-off is that file I/O can be slower than a native filesystem, especially for projects with many small files.

**b) Networking.** The VM uses Vagrant's default NAT network and a forwarded port. Binding the host side to `127.0.0.1` makes QuickNotes available only from this computer; a bridged adapter would put the VM directly on the local network and could expose the course application to other devices.

**c) Provisioning.** I chose Vagrant's `shell` provisioner. The setup is short: it installs the exact Go archive, builds QuickNotes, and configures a systemd service, without adding the overhead of a configuration-management tool for one VM.

**d) Go version.** `1.24.5` identifies one immutable release with a fixed set of fixes and behaviour. A version such as `1.24` could resolve differently over time, so builds would be less reproducible.

## Task 2 — Snapshots: Save, Break, Restore

### Commands and evidence

```bash
# commands and their real output will be added after the snapshot exercise
```

Restore timing:

```text
<!-- paste real `time vagrant snapshot restore quicknotes-clean` output here -->
```

### Design answers

**e) Snapshots are not backups.** A snapshot depends on the original VM disk and the local VirtualBox files. It does not protect against loss of the host disk, corruption of the base disk, or a lost laptop, and it is not an off-machine copy of the data.

**f) Copy-on-write.** A new snapshot initially records only the disk blocks that later change, rather than immediately duplicating the whole virtual disk. Ten snapshots can therefore start small, but every changed block must be kept in the snapshot chain, so storage consumption grows over time.

**g) When snapshotting is an antipattern.** Long snapshot chains make disk usage, performance, and recovery more fragile and harder to reason about. For long-lived environments, reproducible provisioning and real backups are preferable; short snapshots are useful only for temporary experiments and rollback points.

## Bonus — VM vs Container Resource Baseline

| Dimension | Vagrant VM | Docker container |
|---|---:|---:|
| Cold start | <!-- VM result --> | <!-- container result --> |
| Idle RAM | <!-- VM result --> | <!-- container result --> |
| On-disk size | <!-- VM result --> | <!-- image result --> |
| Process count (guest) | <!-- VM result --> | <!-- container result --> |

<!-- Write the final 4–5 sentence comparison after taking the four measurements. -->
