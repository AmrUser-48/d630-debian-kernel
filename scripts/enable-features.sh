#!/bin/bash
# enable-features.sh — Dell Latitude D630 (T7250 / GMA X3100 / ICH8-M)

make x86_64_defconfig
# 2. Enable MCORE2 (needs X86_64 first)
# 3. Verify it stuck
grep "^CONFIG_MCORE2=" .config
# Must show: CONFIG_MCORE2=y   
scripts/config --enable MODULES
grep "^CONFIG_MODULES=" .config
# ============================================================
# No module system (all built-in, no .ko files)
# --- These are under "Removable kernel features for embedded systems" ---
scripts/config --enable EMBEDDED
scripts/config --enable CC_OPTIMIZE_FOR_PERFORMANCE
scripts/config --enable BASE_FULL
scripts/config --enable FUTEX
scripts/config --enable FUTEX_PI
scripts/config --enable EPOLL
scripts/config --enable SIGNALFD
scripts/config --enable TIMERFD
scripts/config --enable EVENTFD
scripts/config --enable SHMEM
scripts/config --enable AIO
scripts/config --enable ADVISE_SYSCALLS
scripts/config --enable MEMBARRIER
scripts/config --enable RSEQ
scripts/config --enable KALLSYMS
scripts/config --enable POSIX_TIMERS
scripts/config --enable SYSFS_SYSCALL
scripts/config --enable SGETMASK_SYSCALL
scripts/config --enable MULTIUSER
# --- Namespaces (Debian initrd uses mount/pid namespaces) ---
scripts/config --enable NAMESPACES
scripts/config --enable USER_NS
scripts/config --enable PID_NS
scripts/config --enable MOUNT_NS
scripts/config --enable NET_NS
scripts/config --enable UTS_NS
scripts/config --enable IPC_NS
scripts/config --enable CGROUPS
# --- Other things the Debian initrd needs ---
scripts/config --enable INOTIFY_USER
scripts/config --enable FHANDLE
scripts/config --enable UNIX
# --- DRM / GPU chain ---
scripts/config --enable DRM
scripts/config --enable DRM_KMS_HELPER
scripts/config --enable FB
scripts/config --enable DRM_I915
# --- USB chain ---
scripts/config --enable USB
scripts/config --enable USB_HCD
scripts/config --enable USB_EHCI_HCD
scripts/config --enable USB_UHCI_HCD
# --- Network chain ---
scripts/config --enable NET
scripts/config --enable INET
scripts/config --enable NETDEVICES
scripts/config --enable ETHERNET
scripts/config --enable TIGON3
# --- Input chain ---
scripts/config --enable INPUT
scripts/config --enable SERIO
scripts/config --enable SERIO_I8042
scripts/config --enable PSMOUSE
scripts/config --enable PSMOUSE_ALPS
scripts/config --enable PSMOUSE_SYNAPTICS
# --- I2C / SMBus chain ---
scripts/config --enable I2C
scripts/config --enable I2C_I801
# --- Storage chain ---
scripts/config --enable ATA
scripts/config --enable SATA
scripts/config --enable SATA_AHCI
scripts/config --enable LIBATA
# --- ACPI / Battery chain ---
scripts/config --enable ACPI
scripts/config --enable POWER_SUPPLY
scripts/config --enable ACPI_SBS
scripts/config --enable ACPI_SBSB
# --- WMI / Dell chain ---
scripts/config --enable WMI
scripts/config --enable ACPI_WMI
scripts/config --enable DMI
scripts/config --enable DELL_SMBIOS
scripts/config --enable DELL_WMI
# --- WiFi chain ---
scripts/config --enable CFG80211
scripts/config --enable MAC80211
scripts/config --enable IWLAGN
scripts/config --enable IWLWIFI
# --- nftables (full chain) ---
scripts/config --enable NETFILTER
scripts/config --enable NETFILTER_ADVANCED
scripts/config --enable NF_CONNTRACK
scripts/config --enable NF_CT_NETLINK
scripts/config --enable NF_NAT
scripts/config --enable NF_TABLES
# --- zram ---
scripts/config --enable BLOCK
scripts/config --enable ZRAM
# --- Initrd ---
scripts/config --enable BLK_DEV_INITRD   
# CPU — Core 2 Duo Merom (Socket P, dual-core)
scripts/config --enable SMP
scripts/config --enable X86_TSC
scripts/config --enable X86_TSC_SCHED_CLOCK
scripts/config --enable HPET_TIMER
scripts/config --enable MTRR
scripts/config --enable X86_PAT
scripts/config --enable X86_MCE
scripts/config --enable X86_MCE_INTEL
scripts/config --enable MICROCODE
scripts/config --enable MICROCODE_INTEL
scripts/config --enable MICROCODE_INTEL_EARLY
# PCI / AGP (ICH8-M + GMA X3100 on AGP)
scripts/config --enable PCI
scripts/config --enable PCI_HOST_BRIDGE
scripts/config --enable PCI_MSI
scripts/config --enable PCIEPORTBUS
scripts/config --enable AGP
scripts/config --enable AGP_INTEL
scripts/config --enable PNP
scripts/config --enable PNPACPI
# ACPI / Power / Laptop
scripts/config --enable ACPI_BUTTON
scripts/config --enable ACPI_VIDEO
scripts/config --enable ACPI_THERMAL
scripts/config --enable ACPI_EC
scripts/config --enable ACPI_CONTAINER
scripts/config --enable DMI_ID
scripts/config --enable DMI_SYSFS
# Dell WMI
scripts/config --enable WMI_BUILTIN
scripts/config --enable DELL_WMI_AIO
scripts/config --enable DELL_WMI_SMBIOS
scripts/config --enable ALIENWARE_WMI
# Storage — ICH8-M (SATA + legacy IDE)
scripts/config --enable ATA_PIIX
# Filesystems (built-in)
scripts/config --enable EXT4_FS
scripts/config --enable FAT_FS
scripts/config --enable VFAT_FS
scripts/config --enable NTFS_FS
scripts/config --enable NTFS3_FS
scripts/config --enable SQUASHFS
scripts/config --set-str SQUASHFS_COMPRESSOR "xz"
scripts/config --enable ISO9660_FS
scripts/config --enable UDF
# GPU — Intel GMA X3100 (i915, AGP path)
scripts/config --enable DRM_I915_DISPLAY
scripts/config --enable DRM_FBDEV_EMULATION
scripts/config --enable DRM_TTM
scripts/config --enable FB_SYS_FILLRECT
scripts/config --enable FB_SYS_COPYAREA
scripts/config --enable FB_SYS_IMAGEBLIT
scripts/config --enable BACKLIGHT_CLASSDEV
# Audio — IDT STAC9205 (HDA)
scripts/config --enable SOUND
scripts/config --enable SND
scripts/config --enable SND_PCI
scripts/config --enable SND_HDA
scripts/config --enable SND_HDA_INTEL
scripts/config --enable SND_HDA_CODEC_SIGMATEL
scripts/config --enable SND_PCM
scripts/config --enable SND_TIMER
scripts/config --enable SND_HDA_CODEC_REALTEK
scripts/config --enable SND_HDA_CODEC_CIRRUS
scripts/config --enable SND_HDA_CODEC_VIA
scripts/config --enable SND_HDA_CODEC_ANALOG
scripts/config --enable SND_HDA_CODEC_HDMI
scripts/config --enable SND_HDA_I915
scripts/config --enable SND_HWDEP
scripts/config --enable SND_RAWMIDI
scripts/config --enable SND_SEQUENCER
scripts/config --enable SND_OSSEMUL
scripts/config --enable SND_MIXER_OSS
scripts/config --enable SND_PCM_OSS
# USB — ICH8 (UHCI 1.1 + EHCI 2.0)
scripts/config --enable USB_EHCI_HCD_PCI
scripts/config --enable USB_UHCI_HCD_PCI
scripts/config --enable USB_STORAGE
scripts/config --enable USB_HID
scripts/config --enable USB_NET
scripts/config --enable USB_NET_RTL8152
scripts/config --enable USB_ACM
scripts/config --enable USB_SERIAL
# WiFi — Intel 3945ABG (iwlwifi)
scripts/config --enable IWLWIFI_LEDS
scripts/config --enable IWLWIFI_QOS
scripts/config --enable IWLWIFI_P2P
# Ethernet — Broadcom NetXtreme (tg3)
scripts/config --enable TUN
scripts/config --enable BRIDGE
# Input — PS/2 keyboard, ALPS/Synaptics touchpad, trackpoint
scripts/config --enable INPUT_EVDEV
scripts/config --enable INPUT_KEYBOARD
scripts/config --enable INPUT_MOUSE
scripts/config --enable INPUT_TOUCHSCREEN
scripts/config --enable INPUT_JOYSTICK
scripts/config --enable INPUT_POWERKEY
scripts/config --enable INPUT_SPARSE_KEYMAP
scripts/config --enable SERIO_LIBPS2
scripts/config --enable SERIO_RAW
scripts/config --enable SERIO_PCIPS2
scripts/config --enable INPUT_ATKBD
scripts/config --enable INPUT_MOUSEDEV
scripts/config --enable PSMOUSE_ELANTECH
scripts/config --enable PSMOUSE_FOCALTECH
scripts/config --enable PSMOUSE_VMMOUSE
scripts/config --enable PSMOUSE_SMBUS
# I2C / SMBus (touchpad, sensors, EC)
scripts/config --enable I2C_ALGOBIT
scripts/config --enable I2C_ALGOPCF
scripts/config --enable I2C_ALGOPCA
scripts/config --enable SMBUS
scripts/config --enable I2C_GPIO
scripts/config --enable I2C_MUX
scripts/config --enable I2C_MUX_GPO
# Network / nftables (from previous)
scripts/config --enable NF_TABLES_INET
scripts/config --enable NF_TABLES_IPV4
scripts/config --enable NF_TABLES_IPV6
scripts/config --enable NF_TABLES_ARP
scripts/config --enable NF_TABLES_NETDEV
scripts/config --enable NETFILTER_NETLINK
scripts/config --enable NF_NAT_IPV4
scripts/config --enable NF_NAT_IPV6
scripts/config --enable NFT_CT
scripts/config --enable NFT_LIMIT
scripts/config --enable NFT_COUNTER
scripts/config --enable NFT_LOG
scripts/config --enable NFT_REJECT
scripts/config --enable NFT_REJECT_INET
scripts/config --enable NFT_REJECT_IPV4
scripts/config --enable NFT_REJECT_IPV6
scripts/config --enable NFT_NAT
scripts/config --enable NFT_MASQ
scripts/config --enable NFT_MASQ_IPV4
scripts/config --enable NFT_MASQ_IPV6
scripts/config --enable NFT_REDIR
scripts/config --enable NFT_REDIR_IPV4
scripts/config --enable NFT_REDIR_IPV6
scripts/config --enable NFT_HASH
scripts/config --enable NFT_META
scripts/config --enable NFT_PAYLOAD
scripts/config --enable NFT_EXTHDR
scripts/config --enable NFT_TPROXY
scripts/config --enable NFT_SOCKET
scripts/config --enable NFT_NUMGEN
scripts/config --enable NFT_OBJREF
scripts/config --enable NFT_QUEUE
scripts/config --enable NFT_DUP_NETDEV
scripts/config --enable NFT_FWD_NETDEV
scripts/config --enable NFT_REJECT_NETDEV
scripts/config --enable NFT_SYNPROXY
scripts/config --enable NF_DEFRAG_IPV4
scripts/config --enable NF_DEFRAG_IPV6
scripts/config --enable NF_SOCKET_IPV4
scripts/config --enable NF_SOCKET_IPV6
scripts/config --enable NF_TPROXY_IPV4
scripts/config --enable NF_TPROXY_IPV6
scripts/config --enable NF_REJECT_IPV4
scripts/config --enable NF_REJECT_IPV6
scripts/config --enable NF_LOG_IPV4
scripts/config --enable NF_LOG_IPV6
scripts/config --enable NF_FLOW_TABLE
scripts/config --enable NF_FLOW_TABLE_INET
scripts/config --enable NETFILTER_XTABLES
scripts/config --enable NFT_COMPAT
scripts/config --enable IP_NF_IPTABLES
scripts/config --enable IP6_NF_IPTABLES
scripts/config --enable IP_SET
# IPv6
scripts/config --enable IPV6
scripts/config --enable IPV6_SIT
scripts/config --enable IPV6_TUNNEL
scripts/config --enable IPV6_TUNNEL6
scripts/config --enable IPV6_MULTIPLE_SOCKETS
# zram (lzo + lz4 + zstd)
scripts/config --enable LZO_COMPRESS
scripts/config --enable LZ4_COMPRESS
scripts/config --enable ZSTD_COMPRESS
scripts/config --enable ZSTD_DECOMPRESS
# Firmware
scripts/config --enable FW_LOADER
scripts/config --enable FW_LOADER_USER_HELPER
# Initrd decompressors (all)
scripts/config --enable BLK_DEV_INITRD
scripts/config --enable RD_GZIP
scripts/config --enable RD_XZ
scripts/config --enable RD_LZ4
scripts/config --enable RD_ZSTD
scripts/config --enable RD_LZO
# Kernel image compression
scripts/config --disable GZIP
scripts/config --enable KERNEL_XZ
# Console
scripts/config --enable PRINTK
scripts/config --enable EARLY_PRINTK
scripts/config --enable SERIAL_8250
scripts/config --enable SERIAL_8250_CONSOLE
# Essentials
scripts/config --enable BINFMT_ELF
scripts/config --enable BINFMT_SCRIPT
scripts/config --enable TTY
scripts/config --enable DEVTMPFS
scripts/config --enable DEVTMPFS_MOUNT
scripts/config --enable PROC_FS
scripts/config --enable SYSFS
scripts/config --enable TMPFS
# Play with Fire
scripts/config --enable X86_MSR
# CPU — Core 2 Duo Merom
scripts/config --enable X86_REBOOTFIXUPS
# PCI / AGP
scripts/config --enable DMI_SCAN_MACHINE_NON_EARLY_FALLBACK
# Dell WMI / Laptop drivers
scripts/config --enable DELL_RBTN
# Storage — ICH8-M
# GPU — Intel GMA X3100 (i915)
# NOTE: SOUND and SND_PCI are menuconfig gates — required!
# USB — ICH8 (UHCI + EHCI)
scripts/config --enable USB_NET_DRIVERS
scripts/config --enable USB_ETH_RNDIS
# WiFi — Intel 3945ABG
# Ethernet / Network
# nftables / Netfilter
# NOTE: NETFILTER is a menuconfig gate — required!
# Input — PS/2 keyboard, touchpad, gamepad
scripts/config --enable INPUT_JOYDEV
scripts/config --enable JOYSTICK_XPAD
scripts/config --enable HID
scripts/config --enable HID_PANTHERLORD
scripts/config --enable HID_PANTHERLORD_FF
# I2C / SMBus
# Removable features (REQUIRED for glibc / Debian initrd)
scripts/config --enable SYSCTL
scripts/config --enable MOUSE_PS2
scripts/config --enable MOUSE_PS2_ALPS
scripts/config --enable MOUSE_PS2_SYNAPTICS
scripts/config --enable MOUSE_PS2_SYNAPTICS_SMBUS
scripts/config --enable MOUSE_PS2_ELANTECH
scripts/config --enable MOUSE_PS2_FOCALTECH   
scripts/config --enable CRYPTO
scripts/config --enable CRYPTO_LZO
scripts/config --enable CRYPTO_LZ4
scripts/config --enable CRYPTO_ZSTD
scripts/config --enable ZRAM   
# CPU — Core 2 Duo Merom (T7250, 2.0 GHz, SSE3+SSSE3)
# Scheduling — low latency
scripts/config --enable PREEMPT
scripts/config --enable HZ_1000
scripts/config --enable HIGH_RES_TIMERS
# Storage — ICH8-M (SATA AHCI + legacy IDE)
# GPU — Intel GMA X3100 (i915, AGP)
# NOTE: SOUND and SND_PCI are menuconfig gates
# WiFi — Intel PRO/Wireless 3945ABG
# NOTE: NETFILTER is a menuconfig gate
scripts/config --enable MOUSE_PS2_FOCALTECH
scripts/config --enable MOUSE_PS2_VMMOUSE
# NOTE: CRYPTO is a gate, CRYPTO_* are the API versions
# Firmware (userspace helper, /lib/firmware in initrd)
# Removable features (REQUIRED for glibc / systemd / Debian)
# MCORE2 — needs 64BIT (not X86_64, that's auto-selected)
scripts/config --enable 64BIT
# ZRAM — needs CRYPTO gate + at least one CRYPTO_*
# USB_EHCI_HCD — needs USB + PCI
# DELL_WMI — needs WMI + ACPI_WMI + DMI
# HID_PANTHERLORD — needs HID + USB_HID
# JOYSTICK_XPAD — needs INPUT_JOYSTICK + USB_HID
# USB_ETH_RNDIS — needs USB_NET_DRIVERS (the gate)
scripts/config --enable NETFILTER_XT_MARK
scripts/config --enable NETFILTER_XT_TARGET_LOG
scripts/config --enable NETFILTER_XT_NAT
scripts/config --enable NETFILTER_XT_TARGET_MASQUERADE
scripts/config --enable NETFILTER_XT_MATCH_ADDRTYPE
scripts/config --enable NF_LOG_ARP
scripts/config --enable IP_NF_NAT
scripts/config --enable IP_NF_TARGET_MASQUERADE
scripts/config --enable X86_PKG_TEMP_THERMAL
scripts/config --enable EFIVAR_FS

# KERNEL_XZ conflicts with KERNEL_GZIP (defconfig default)
scripts/config --disable KERNEL_GZIP
scripts/config --disable KERNEL_LZO
scripts/config --disable KERNEL_LZ4
scripts/config --disable KERNEL_ZSTD
scripts/config --enable KERNEL_XZ

# PREEMPT conflicts with PREEMPT_VOLUNTARY (defconfig default)
scripts/config --disable PREEMPT_NONE
scripts/config --disable PREEMPT_VOLUNTARY
scripts/config --enable PREEMPT

# MCORE2 conflicts with GENERIC_CPU (defconfig default)
scripts/config --disable GENERIC_CPU
scripts/config --disable M32
scripts/config --disable M64
scripts/config --disable M72
scripts/config --disable M74
scripts/config --disable M7A
scripts/config --disable M7M
scripts/config --disable MPSC
scripts/config --disable MK8
scripts/config --disable MK10
scripts/config --disable MK12
scripts/config --disable MK8SSE3
scripts/config --disable MK10SSE
scripts/config --disable MK10SSE2
scripts/config --disable MK10H
scripts/config --disable MNEHALEM
scripts/config --disable MBARCELONA
scripts/config --disable MSILVERMONT
scripts/config --disable MSARUKANI
scripts/config --disable MATOMIC
scripts/config --disable MNETBURM
scripts/config --disable MPENRY
scripts/config --disable MCLERMONT
scripts/config --disable MBOBCAT
scripts/config --disable MBRISBANE
scripts/config --disable JAKARTACPU
scripts/config --disable MZEON
scripts/config --disable MZEN2
scripts/config --disable MZEN3
scripts/config --disable MZEN4
scripts/config --disable MZEN5
scripts/config --disable MZEN6
scripts/config --disable MZEN
scripts/config --disable MZENC
scripts/config --enable MCORE2   

echo olddefconfig
make olddefconfig
echo ============================================================================
echo verify
echo ============================================================================
# Re-verify:
for sym in \
  X86_64 MCORE2 SMP CC_OPTIMIZE_FOR_PERFORMANCE \
  PCI PCI_HOST_BRIDGE AGP AGP_INTEL \
  ACPI ACPI_BUTTON ACPI_VIDEO ACPI_WMI WMI WMI_BUILTIN \
  DMI DMI_ID DELL_WMI DELL_SMBIOS DELL_RBTN \
  ATA ATA_PIIX SATA SATA_AHCI LIBATA \
  EXT4_FS VFAT_FS NTFS3_FS SQUASHFS \
  DRM DRM_I915 DRM_I915_DISPLAY DRM_KMS_HELPER DRM_FBDEV_EMULATION FB BACKLIGHT_CLASSDEV \
  SOUND SND SND_PCI SND_PCM SND_HDA SND_HDA_INTEL SND_HDA_CODEC_SIGMATEL SND_HDA_I915 \
  USB USB_EHCI_HCD USB_EHCI_HCD_PCI USB_UHCI_HCD USB_UHCI_HCD_PCI \
  USB_STORAGE USB_HID USB_NET USB_NET_DRIVERS USB_USBNET USB_NET_RNDIS_HOST \
  CFG80211 MAC80211 IWLAGN IWLWIFI \
  NET INET NETDEVICES ETHERNET TIGON3 \
  NETFILTER NETFILTER_ADVANCED NETFILTER_NETLINK NF_CONNTRACK NF_TABLES NF_TABLES_INET \
  INPUT INPUT_EVDEV INPUT_KEYBOARD INPUT_MOUSE INPUT_JOYSTICK INPUT_JOYDEV \
  SERIO SERIO_I8042 MOUSE_PS2 MOUSE_PS2_ALPS MOUSE_PS2_SYNAPTICS \
  HID USB_HID HID_PANTHERLORD HID_PANTHERLORD_FF JOYSTICK_XPAD USB_ARCH_HAS_HCD \
  I2C I2C_I801 SMBUS \
  BLOCK CRYPTO CRYPTO_LZO CRYPTO_LZ4 CRYPTO_ZSTD ZSMALLOC ZRAM \
  FW_LOADER FW_LOADER_USER_HELPER \
  BLK_DEV_INITRD RD_GZIP RD_XZ RD_LZ4 RD_ZSTD RD_LZO \
  KERNEL_XZ \
  PRINTK EARLY_PRINTK SERIAL_8250 SERIAL_8250_CONSOLE \
  BINFMT_ELF BINFMT_SCRIPT TTY DEVTMPFS DEVTMPFS_MOUNT PROC_FS SYSFS TMPFS \
  MODULES FUTEX EPOLL SHMEM UNIX INOTIFY_USER AIO POSIX_TIMERS \
  NAMESPACES CGROUPS SYSCTL MULTIUSER KALLSYMS \
  PREEMPT HZ_1000 HIGH_RES_TIMERS \
  IPV6; do
  val=$(grep "^CONFIG_${sym}=" .config)
  echo "$sym: $val"
done
echo ============================================================================
echo Modules
echo ============================================================================
grep =m .config
