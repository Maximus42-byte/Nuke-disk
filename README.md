# nuke-disk.sh

A bash script to securely and irreversibly wipe an entire hard drive before giving away, selling, or disposing of a computer.

---

## ⚠️ Warning

**This script permanently destroys all data on the target disk.** There is no undo. Make sure you have backed up everything you want to keep before running it.

---

## Requirements

- A Linux live USB (e.g. Ubuntu 22.04) — you must boot from this, not from the disk you want to wipe
- Root / sudo access
- For NVMe drives: `nvme-cli` package (`sudo apt install nvme-cli`)
- For SATA SSDs: `hdparm` package (`sudo apt install hdparm`)
- For HDDs: `shred` (included in `coreutils`, present by default on most Linux systems)

---

## Usage

```bash
chmod +x nuke-disk.sh
sudo ./nuke-disk.sh /dev/sda        # HDD or SATA SSD
sudo ./nuke-disk.sh /dev/nvme0n1    # NVMe SSD
```

To find the correct device name, run:

```bash
lsblk
```

---

## How It Works

The script auto-detects the drive type and uses the appropriate wipe method:

| Drive Type | Detection | Method | Time |
|---|---|---|---|
| NVMe SSD | `/dev/nvme*` | `nvme format --ses=1` (cryptographic erase) | Seconds |
| SATA SSD | `/dev/sd*`, rotational=0 | `hdparm` ATA Secure Erase | Under a minute |
| HDD | `/dev/sd*`, rotational=1 | `shred` 3 random passes + 1 zero pass | Hours |

### NVMe SSD
Uses the drive's built-in cryptographic erase. Destroys the encryption key, making all data instantly and permanently unreadable. Completes in seconds regardless of drive size.

### SATA SSD
Uses the ATA Secure Erase command via `hdparm`. A firmware-level wipe that resets every storage cell. Handles the common "frozen" state automatically by triggering a suspend/resume cycle.

### HDD (Rotational)
Uses `shred` with 3 passes of random data followed by a final pass of zeros. Each pass overwrites every byte on the disk. Takes several hours on large drives.

---

## Safety Checks

The script includes the following safeguards before wiping:

- Must be run as root
- Requires exactly one argument (the target device)
- Verifies the target is a valid block device
- Refuses to wipe the disk the live system is running from
- Checks that no partitions on the target are currently mounted
- Shows disk details and requires typing `YES` to confirm (twice for NVMe)

---

## Example: Dual Boot System (Windows + Ubuntu)

If your machine has two disks — for example a 3.6TB HDD and a 931GB NVMe SSD — run the script twice:

```bash
sudo ./nuke-disk.sh /dev/sda        # wipes HDD (Windows + Ubuntu data)
sudo ./nuke-disk.sh /dev/nvme0n1    # wipes NVMe SSD (Windows C: drive)
```

Everything is destroyed: both operating systems, all files, bootloader, partition tables, and recovery partitions. The machine is returned to a blank state identical to a new computer.

---

## After Wiping

The disks are completely blank and fully functional. Whoever receives the machine can:

- Install a fresh copy of Windows
- Install a fresh copy of Ubuntu or any other Linux distribution
- Set up a dual boot again
- Use the drives as external or secondary storage

The hardware is not affected in any way — only the data is destroyed.

---

## Notes

- For SSDs, cryptographic erase and ATA Secure Erase are more effective than `shred` because they reach cells that overwrite-based tools cannot access due to wear levelling
- Multiple `shred` passes are a legacy recommendation from the 1990s; for modern HDDs, even a single pass is considered sufficient by NIST and DoD standards
- The script uses 3 passes for extra caution, but `shred -n 1 -z` would be sufficient for most use cases

---

## License

This script is provided as-is for personal use. Use at your own risk.