#!/bin/bash
# ==============================================================================
# Dell Latitude D630 (Intel Core 2 Duo T7250 / GM965) Kernel Configurator Script
# Uses the kernel tree's `scripts/config` utility to enable core hardware features
# and their strict Kconfig dependencies.
# ==============================================================================

set -e

# Ensure we are inside a kernel source directory containing scripts/config
if [ ! -f "scripts/config" ]; then
    echo "Error: scripts/config not found. Run this script from the root of a Linux kernel source tree."
    exit 1
fi

CONFIG_FILE="${1:-.config}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Kernel config file '$CONFIG_FILE' not found."
    exit 1
fi

echo "Applying Dell Latitude D630 feature flags to $CONFIG_FILE using scripts/config..."

# Helper function
set_opt() {
    local opt="$1"
    local val="$2"
    if [ "$val" = "y" ]; then
        scripts/config --file "$CONFIG_FILE" --enable "$opt"
    elif [ "$val" = "m" ]; then
        scripts/config --file "$CONFIG_FILE" --module "$opt"
    elif [ "$val" = "n" ]; then
        scripts/config --file "$CONFIG_FILE" --disable "$opt"
    else
        scripts/config --file "$CONFIG_FILE" --set-str "$opt" "$val"
    fi
}

# 1. CPU Architecture (Core 2 / Merom)
set_opt "MCORE2" "y"
set_opt "GENERIC_CPU" "n"
set_opt "X86_MCE" "y"

# 2. Audio (Intel HDA + Sigmatel STAC9205 codec for D630)
set_opt "SOUND" "y"
set_opt "SND" "y"
set_opt "SND_TIMER" "y"
set_opt "SND_PCM" "y"
set_opt "SND_HWDEP" "y"
set_opt "SND_RAWMIDI" "y"
set_opt "SND_JACK" "y"
set_opt "SND_JACK_INPUT_DEV" "y"
set_opt "SND_HDA" "y"
set_opt "SND_HDA_INTEL" "y"
set_opt "SND_HDA_CODEC_SIGMATEL" "y"
set_opt "SND_HDA_GENERIC" "y"

# 3. Graphics & Display (Intel GM965 / GMA X3100)
set_opt "AGP" "y"
set_opt "AGP_INTEL" "y"
set_opt "DRM" "y"
set_opt "DRM_KMS_HELPER" "y"
set_opt "DRM_I915" "y"
set_opt "DRM_I915_GVT" "n"
set_opt "FB" "y"
set_opt "FB_EFI" "y"

# 4. Wi-Fi & Networking (Intel PRO/Wireless 3945ABG)
set_opt "NET" "y"
set_opt "WIRELESS" "y"
set_opt "CFG80211" "m"
set_opt "MAC80211" "m"
set_opt "NET_CORE" "y"
set_opt "ETHERNET" "y"
set_opt "NET_VENDOR_INTEL" "y"
set_opt "E1000" "m"             # Intel PRO/1000 Gigabit Ethernet on D630 docking/built-in
set_opt "WLAN" "y"
set_opt "WLAN_VENDOR_INTEL" "y"
set_opt "IWLWIFI" "m"
set_opt "IWLDVM" "m"            # Required for 3945/4965 legacy cards

# 5. Storage & SATA (AHCI)
set_opt "BLOCK" "y"
set_opt "ATA" "y"
set_opt "SATA_AHCI" "y"
set_opt "SCSI" "y"
set_opt "BLK_DEV_SD" "y"

# 6. Input Devices (Synaptics Touchpad & DualPoint TrackPoint)
set_opt "INPUT" "y"
set_opt "INPUT_MOUSE" "y"
set_opt "MOUSE_PS2" "y"
set_opt "MOUSE_PS2_ALPS" "y"
set_opt "MOUSE_PS2_SYNAPTICS" "y"
set_opt "MOUSE_PS2_TRACKPOINT" "y"
set_opt "MOUSE_PS2_SMBUS" "y"
set_opt "INPUT_EVDEV" "y"
set_opt "KEYBOARD_ATKBD" "y"

# 7. Power Management & ACPI
set_opt "ACPI" "y"
set_opt "ACPI_AC" "m"
set_opt "ACPI_BATTERY" "m"
set_opt "ACPI_BUTTON" "m"
set_opt "ACPI_VIDEO" "m"
set_opt "CPU_FREQ" "y"
set_opt "CPU_FREQ_GOV_USERSPACE" "y"
set_opt "X86_ACPI_CPUFREQ" "m"
set_opt "THERMAL" "y"

# 8. Filesystems & Core System
set_opt "EXT4_FS" "y"
set_opt "DEVTMPFS" "y"
set_opt "DEVTMPFS_MOUNT" "y"
set_opt "CGROUPS" "y"
set_opt "NAMESPACES" "y"
set_opt "ZRAM" "y"

# Resolve dependencies & defaults
make olddefconfig

echo "Successfully configured Dell Latitude D630 hardware features in $CONFIG_FILE!"
