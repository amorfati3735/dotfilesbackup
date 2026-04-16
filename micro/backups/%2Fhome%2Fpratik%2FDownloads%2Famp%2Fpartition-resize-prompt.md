# Prompt for AI — Partition Resize Guide

I need step-by-step help to expand my Linux partition by reclaiming space from my Windows partition and deleting unused Dell recovery partitions. I'll be doing everything from an EndeavourOS live USB using GParted.

## My Setup
- **Laptop**: Dell, single NVMe SSD (WD SN740 1TB, 953.9G total), dual-boot Windows 11 + EndeavourOS (Arch-based, rolling)
- **Boot mode**: UEFI, GPT partition table
- **Bootloader**: GRUB (EndeavourOS) at `\EFI\endeavouros\grubx64.efi`
- **Windows Boot Manager**: `\EFI\Microsoft\Boot\bootmgfw.efi`
- **Both bootloaders live on p1 (EFI partition)**
- **Live USB**: EndeavourOS Ganymede 2025.11.24, already flashed and ready

## Current Partition Layout (in disk order)

| # | Partition | Size | Type/FS | Label | UUID | What it is |
|---|-----------|------|---------|-------|------|------------|
| 1 | nvme0n1p1 | 300M | vfat (EFI) | ESP | ECC1-FBF6 | EFI System Partition — DO NOT TOUCH |
| 2 | nvme0n1p2 | 128M | (none) | — | — | Microsoft Reserved (MSR) — DO NOT TOUCH |
| 3 | nvme0n1p3 | 870.6G | NTFS | OS | 01DC61EE427D4950 | Windows C: drive — 761G used, 110G free — **SHRINK by ~50G** |
| 4 | nvme0n1p4 | 990M | NTFS | WINRETOOLS | — | Dell recovery tools — **DELETE** |
| 5 | nvme0n1p5 | 20.5G | NTFS | Image | — | Dell factory image — **DELETE** |
| 6 | nvme0n1p6 | 1.4G | NTFS | DELLSUPPORT | — | Dell SupportAssist — **DELETE** |
| 7 | nvme0n1p7 | 60G | ext4 | endeavouros | 6559a213-6849-4e45-8f1f-04ad7d6a5a49 | EndeavourOS root — 48G used, 8G free — **GROW to fill freed space** |

**p7 is the LAST partition on the disk.**

## Linux fstab (UUID-based, no changes needed if UUIDs stay the same)
```
UUID=ECC1-FBF6                            /boot/efi      vfat    fmask=0137,dmask=0027 0 2
UUID=6559a213-6849-4e45-8f1f-04ad7d6a5a49 /              ext4    noatime    0 1
tmpfs                                     /tmp           tmpfs   defaults,noatime,mode=1777 0 0
UUID=01DC61EE427D4950                     /mnt/windows   ntfs-3g defaults,windows_names  0 0
```

## The Plan — All Done From GParted on Live USB

### Step 1: Boot the live USB
- Boot into EndeavourOS live environment (not install)
- Open GParted, select `/dev/nvme0n1`
- Confirm NO partitions are mounted (they shouldn't be from live USB)

### Step 2: Shrink p3 (Windows NTFS, "OS", 870.6G)
- Right-click nvme0n1p3 → Resize/Move
- Shrink from the RIGHT side by ~50GB (new size ~820G)
- This creates ~50GB of unallocated space between p3 and p4

### Step 3: Delete p4, p5, p6 (Dell recovery, ~23GB total)
- Delete nvme0n1p4 (WINRETOOLS, 990M)
- Delete nvme0n1p5 (Image, 20.5G)
- Delete nvme0n1p6 (DELLSUPPORT, 1.4G)
- This merges all unallocated space into one ~73GB contiguous block, directly adjacent to p7

### Step 4: Expand p7 (Linux ext4, "endeavouros", 60G)
- Right-click nvme0n1p7 → Resize/Move
- Extend LEFTWARD into the unallocated space (drag the left edge left)
- New size should be ~133G

### Step 5: Apply all changes
- Click the green checkmark to apply all queued operations
- Wait for it to finish (may take a while for the NTFS shrink)

### Step 6: Reboot and verify
- Reboot into EndeavourOS — check `lsblk` and `df -h`
- Reboot into Windows — verify it boots and works

### Target end state
- p1 (EFI): 300M — unchanged
- p2 (MSR): 128M — unchanged
- p3 (Windows): ~820G
- p4/p5/p6: gone
- p7 (Linux): ~133G

## Important Notes
- **Windows must have been cleanly shut down** before doing this. If Windows was hibernated or used Fast Startup, the NTFS partition may be flagged dirty and GParted may warn about it. If so, I'd need to boot Windows first and do a clean shutdown (`shutdown /s /f /t 0` in CMD).
- The NTFS partition was last mounted read-write from Linux with no issues, which means it was already clean.
- GParted resizes ext4 in-place, so p7's UUID should stay the same — meaning no fstab or GRUB changes needed.
- p1 and p2 must NOT be touched at any point.

## Questions I May Ask You During the Process
- What if GParted shows warnings about the NTFS partition?
- What if the unallocated space doesn't merge into one contiguous block?
- What if the partition numbers change after deleting p4/p5/p6 — does that affect anything?
- What if GRUB doesn't boot after the resize — how do I fix it from the live USB?

Be explicit about which partition you mean at every step (use name, number, label, AND size). Flag any destructive or risky steps clearly.
