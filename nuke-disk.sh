#!/usr/bin/env bash
set -euo pipefail
#===========================================================================
# nuke-disk.sh - Securely & irreversibly wipe an entire hard drive.
#
#   !! MUST be run from a live USB (not from the installed OS) !!
#
# Usage:  sudo ./nuke-disk.sh  /dev/sda        (most common internal disk)
#         sudo ./nuke-disk.sh  /dev/nvme0n1    (for NVMe systems)
#===========================================================================

die() { echo "ERROR: $*" >&2; exit 1; }
confirm() {
    local prompt="$1"
    local answer
    read -r -p "$prompt (YES/NO): " answer
    [[ "$answer" == "YES" ]] || die "Aborted by user."
}

# --- Basic checks ---------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    die "Run this as root (sudo)."
fi

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <whole-disk-device>"
    echo "Example: $0 /dev/sda"
    exit 1
fi

DEVICE="$1"
[[ -b "$DEVICE" ]] || die "$DEVICE is not a block device."

# Refuse to wipe the device we are currently running from (live USB safety)
ROOT_DEVICE=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//' | sed 's/p[0-9]*$//')
if [[ "$DEVICE" == "$ROOT_DEVICE" ]]; then
    die "$DEVICE appears to be the current live system disk. Refusing to self-destruct."
fi

# Check if any partition on the target disk is mounted
if mount | grep -q "^$DEVICE"; then
    die "Some partitions on $DEVICE are still mounted. Unmount them first."
fi

# Show target details
echo "===== TARGET DEVICE: $DEVICE ====="
lsblk "$DEVICE"
echo
echo "WARNING: This will permanently destroy ALL data on $DEVICE"
echo "         (including Windows, Ubuntu, recovery partitions – everything)."
confirm "Type YES to start the irreversible wipe"

# --- Determine drive type and wipe ----------------------------------------
if [[ "$DEVICE" == /dev/nvme* ]]; then
    echo "[*] NVMe SSD detected – using 'nvme format' with cryptographic erase."
    command -v nvme &>/dev/null || die "Install nvme-cli first: sudo apt install nvme-cli"
    confirm "Really start NVMe secure erase?"
    nvme format "$DEVICE" --ses=1   # 1 = cryptographic erase
    echo "NVMe secure erase completed."

elif [[ "$DEVICE" == /dev/sd* || "$DEVICE" == /dev/hd* ]]; then
    # Determine if SSD or HDD
    rotational=1
    if [[ -f /sys/block/$(basename "$DEVICE")/queue/rotational ]]; then
        rotational=$(cat /sys/block/$(basename "$DEVICE")/queue/rotational)
    fi

    if [[ $rotational -eq 0 ]]; then
        echo "[*] SATA SSD detected – using ATA Secure Erase."
        command -v hdparm &>/dev/null || die "Install hdparm: sudo apt install hdparm"

        # Handle frozen state (common on laptops)
        if hdparm -I "$DEVICE" 2>/dev/null | grep -qi "frozen"; then
            echo "[*] Disk is frozen. Attempting to unfreeze by suspending..."
            echo -n mem > /sys/power/state 2>/dev/null || true
            sleep 2
            if hdparm -I "$DEVICE" 2>/dev/null | grep -qi "frozen"; then
                die "Still frozen. Do a full suspend/resume (close lid / 'systemctl suspend') and re-run."
            fi
            echo "[*] Disk unfrozen."
        fi

        # Set a temporary password (required by the ATA security command)
        echo "[*] Setting temporary ATA password..."
        hdparm --user-master u --security-set-pass p "$DEVICE" || die "Failed to set ATA password."

        confirm "Start ATA Secure Erase (enhanced)?"
        echo "[*] Issuing enhanced secure erase..."
        hdparm --user-master u --security-erase-enhanced p "$DEVICE" || {
            echo "[!] Enhanced erase failed, trying normal secure erase..."
            hdparm --user-master u --security-erase p "$DEVICE"
        }
        echo "ATA Secure Erase finished."

    else
        echo "[*] Rotational HDD detected – overwriting with shred (3 random passes + zeros)."
        command -v shred &>/dev/null || die "Install shred (coreutils): sudo apt install coreutils"
        confirm "Start HDD wipe?"
        shred -v -n 3 -z "$DEVICE"
        echo "HDD wipe complete."
    fi
else
    die "Unsupported device type: $DEVICE"
fi

echo "========================================="
echo "All data on $DEVICE has been destroyed."
echo "The disk is now blank and ready for partitioning / new OS installation."
