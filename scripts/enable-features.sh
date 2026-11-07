#!/bin/bash
# enable-features.sh — Dell Latitude D630 (T7250 / GMA X3100 / ICH8-M)
# Run from kernel source root, after `make tinyconfig`
#set -e
# --- These are under "Removable kernel features for embedded systems" ---
scripts/config --enable EMBEDDED
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
scripts/config --enable NET
scripts/config --enable INET
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

# ============================================================
# CPU — Core 2 Duo Merom (Socket P, dual-core)
# ============================================================
scripts/config --enable X86_64
scripts/config --enable MCORE2
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

# ============================================================
# PCI / AGP (ICH8-M + GMA X3100 on AGP)
# ============================================================
scripts/config --enable PCI
scripts/config --enable PCI_HOST_BRIDGE
scripts/config --enable PCI_MSI
scripts/config --enable PCIEPORTBUS
scripts/config --enable AGP
scripts/config --enable AGP_INTEL
scripts/config --enable PNP
scripts/config --enable PNPACPI

# ============================================================
# ACPI / Power / Laptop
# ============================================================
scripts/config --enable ACPI
scripts/config --enable ACPI_BUTTON
scripts/config --enable ACPI_VIDEO
scripts/config --enable ACPI_THERMAL
scripts/config --enable ACPI_EC
scripts/config --enable ACPI_CONTAINER
scripts/config --enable ACPI_SBS
scripts/config --enable ACPI_SBSB
scripts/config --enable ACPI_WMI
scripts/config --enable POWER_SUPPLY
scripts/config --enable DMI
scripts/config --enable DMI_ID
scripts/config --enable DMI_SYSFS

# ============================================================
# Dell WMI
# ============================================================
scripts/config --enable WMI
scripts/config --enable WMI_BUILTIN
scripts/config --enable DELL_SMBIOS
scripts/config --enable DELL_WMI
scripts/config --enable DELL_WMI_AIO
scripts/config --enable DELL_WMI_SMBIOS
scripts/config --enable ALIENWARE_WMI

# ============================================================
# Storage — ICH8-M (SATA + legacy IDE)
# ============================================================
scripts/config --enable ATA
scripts/config --enable ATA_PIIX
scripts/config --enable SATA
scripts/config --enable SATA_AHCI
scripts/config --enable LIBATA

# ============================================================
# Filesystems (built-in)
# ============================================================
scripts/config --enable EXT4_FS
scripts/config --enable FAT_FS
scripts/config --enable VFAT_FS
scripts/config --enable NTFS_FS
scripts/config --enable NTFS3_FS
scripts/config --enable SQUASHFS
scripts/config --set-str SQUASHFS_COMPRESSOR "xz"
scripts/config --enable ISO9660_FS
scripts/config --enable UDF

# ============================================================
# GPU — Intel GMA X3100 (i915, AGP path)
# ============================================================
scripts/config --enable DRM
scripts/config --enable DRM_I915
scripts/config --enable DRM_I915_DISPLAY
scripts/config --enable DRM_KMS_HELPER
scripts/config --enable DRM_FBDEV_EMULATION
scripts/config --enable DRM_TTM
scripts/config --enable FB
scripts/config --enable FB_SYS_FILLRECT
scripts/config --enable FB_SYS_COPYAREA
scripts/config --enable FB_SYS_IMAGEBLIT
scripts/config --enable BACKLIGHT_CLASSDEV

# ============================================================
# Audio — IDT STAC9205 (HDA)
# ============================================================
scripts/config --enable SOUND
scripts/config --enable SND
scripts/config --enable SND_PCI
scripts/config --enable SND_HDA
scripts/config --enable SND_HDA_INTEL
scripts/config --enable SND_HDA_CODEC_SIGMATEL
scripts/config --enable SND_PCM
scripts/config --enable SND_TIMER
scripts/config --enable SND_PCM
scripts/config --enable SND_TIMER
scripts/config --enable SND_HDA
scripts/config --enable SND_HDA_INTEL
scripts/config --enable SND_HDA_CODEC_SIGMATEL
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

# ============================================================
# USB — ICH8 (UHCI 1.1 + EHCI 2.0)
# ============================================================
scripts/config --enable USB
scripts/config --enable USB_EHCI_HCD
scripts/config --enable USB_UHCI_HCD
scripts/config --enable USB_EHCI_HCD_PCI
scripts/config --enable USB_UHCI_HCD_PCI
scripts/config --enable USB_STORAGE
scripts/config --enable USB_HID
scripts/config --enable USB_NET
scripts/config --enable USB_NET_RTL8152
scripts/config --enable USB_ACM
scripts/config --enable USB_SERIAL

# ============================================================
# WiFi — Intel 3945ABG (iwlwifi)
# ============================================================
scripts/config --enable CFG80211
scripts/config --enable MAC80211
scripts/config --enable IWLAGN
scripts/config --enable IWLWIFI
scripts/config --enable IWLWIFI_LEDS
scripts/config --enable IWLWIFI_QOS
scripts/config --enable IWLWIFI_P2P

# ============================================================
# Ethernet — Broadcom NetXtreme (tg3)
# ============================================================
scripts/config --enable NET
scripts/config --enable NETDEVICES
scripts/config --enable ETHERNET
scripts/config --enable TIGON3
scripts/config --enable TUN
scripts/config --enable BRIDGE

# ============================================================
# Input — PS/2 keyboard, ALPS/Synaptics touchpad, trackpoint
# ============================================================
scripts/config --enable INPUT
scripts/config --enable INPUT_EVDEV
scripts/config --enable INPUT_KEYBOARD
scripts/config --enable INPUT_MOUSE
scripts/config --enable INPUT_TOUCHSCREEN
scripts/config --enable INPUT_JOYSTICK
scripts/config --enable INPUT_POWERKEY
scripts/config --enable INPUT_SPARSE_KEYMAP
scripts/config --enable SERIO
scripts/config --enable SERIO_I8042
scripts/config --enable SERIO_LIBPS2
scripts/config --enable SERIO_RAW
scripts/config --enable SERIO_PCIPS2
scripts/config --enable INPUT_ATKBD
scripts/config --enable INPUT_MOUSEDEV
scripts/config --enable PSMOUSE
scripts/config --enable PSMOUSE_ALPS
scripts/config --enable PSMOUSE_SYNAPTICS
scripts/config --enable PSMOUSE_ELANTECH
scripts/config --enable PSMOUSE_FOCALTECH
scripts/config --enable PSMOUSE_VMMOUSE
scripts/config --enable PSMOUSE_SMBUS
scripts/config --enable INPUT_TOUCHSCREEN

# ============================================================
# I2C / SMBus (touchpad, sensors, EC)
# ============================================================
scripts/config --enable I2C
scripts/config --enable I2C_ALGOBIT
scripts/config --enable I2C_ALGOPCF
scripts/config --enable I2C_ALGOPCA
scripts/config --enable I2C_I801
scripts/config --enable SMBUS
scripts/config --enable I2C_GPIO
scripts/config --enable I2C_MUX
scripts/config --enable I2C_MUX_GPO

# ============================================================
# Network / nftables (from previous)
# ============================================================
scripts/config --enable NET
scripts/config --enable INET
scripts/config --enable NETFILTER
scripts/config --enable NETFILTER_ADVANCED
scripts/config --enable NF_TABLES
scripts/config --enable NF_TABLES_INET
scripts/config --enable NF_TABLES_IPV4
scripts/config --enable NF_TABLES_IPV6
scripts/config --enable NF_TABLES_ARP
scripts/config --enable NF_TABLES_NETDEV
scripts/config --enable NETFILTER_ADVANCED
scripts/config --enable NETFILTER_NETLINK
scripts/config --enable NF_CONNTRACK
scripts/config --enable NF_CT_NETLINK
scripts/config --enable NF_NAT
scripts/config --enable NF_NAT_IPV4
scripts/config --enable NF_NAT_IPV6
scripts/config --enable NF_TABLES
scripts/config --enable NF_TABLES_INET
scripts/config --enable NF_TABLES_IPV4
scripts/config --enable NF_TABLES_IPV6
scripts/config --enable NF_TABLES_NETDEV
scripts/config --enable NF_TABLES_ARP
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
scripts/config --set-int IP_SET_MAX 256

# ============================================================
# IPv6
# ============================================================
scripts/config --enable IPV6
scripts/config --enable IPV6_SIT
scripts/config --enable IPV6_TUNNEL
scripts/config --enable IPV6_TUNNEL6
scripts/config --enable IPV6_MULTIPLE_SOCKETS

# ============================================================
# zram (lzo + lz4 + zstd)
# ============================================================
scripts/config --enable ZRAM
scripts/config --enable LZO_COMPRESS
scripts/config --enable LZ4_COMPRESS
scripts/config --enable ZSTD_COMPRESS
scripts/config --enable ZSTD_DECOMPRESS

# ============================================================
# Firmware
# ============================================================
scripts/config --enable FW_LOADER
scripts/config --enable FW_LOADER_USER_HELPER

# ============================================================
# Initrd decompressors (all)
# ============================================================
scripts/config --enable BLK_DEV_INITRD
scripts/config --enable RD_GZIP
scripts/config --enable RD_XZ
scripts/config --enable RD_LZ4
scripts/config --enable RD_ZSTD
scripts/config --enable RD_LZO

# ============================================================
# Kernel image compression
# ============================================================
scripts/config --disable GZIP
scripts/config --enable KERNEL_XZ

# ============================================================
# Console
# ============================================================
scripts/config --enable PRINTK
scripts/config --enable EARLY_PRINTK
scripts/config --set-str EARLY_PRINTK "ttyS0,115200"
scripts/config --enable SERIAL_8250
scripts/config --enable SERIAL_8250_CONSOLE

# ============================================================
# Essentials
# ============================================================
scripts/config --enable BINFMT_ELF
scripts/config --enable BINFMT_SCRIPT
scripts/config --enable TTY
scripts/config --enable DEVTMPFS
scripts/config --enable DEVTMPFS_MOUNT
scripts/config --enable PROC_FS
scripts/config --enable SYSFS
scripts/config --enable TMPFS

# ============================================================
# Play with Fire
# ============================================================
scripts/config --enable X86_MSR

# ============================================================
# Final
# ============================================================
make olddefconfig   

#!/bin/bash
# enable-features.sh — Dell Latitude D630
# Run from kernel source root, after `make tinyconfig`
set -e

# ============================================================
# CPU — Core 2 Duo Merom
# ============================================================
scripts/config --enable X86_64
scripts/config --enable MCORE2
scripts/config --enable SMP
scripts/config --enable X86_TSC
scripts/config --enable X86_TSC_SCHED_CLOCK
scripts/config --enable HPET_TIMER
scripts/config --enable MTRR
scripts/config --enable X86_PAT
scripts/config --enable X86_MCE
scripts/config --enable X86_MCE_INTEL
scripts/config --enable X86_MSR
scripts/config --enable X86_REBOOTFIXUPS
scripts/config --enable MICROCODE
scripts/config --enable MICROCODE_INTEL
scripts/config --enable MICROCODE_INTEL_EARLY

# ============================================================
# PCI / AGP
# ============================================================
scripts/config --enable PCI
scripts/config --enable PCI_HOST_BRIDGE
scripts/config --enable PCI_MSI
scripts/config --enable PCIEPORTBUS
scripts/config --enable AGP
scripts/config --enable AGP_INTEL
scripts/config --enable PNP
scripts/config --enable PNPACPI

# ============================================================
# ACPI / Power / Laptop
# ============================================================
scripts/config --enable ACPI
scripts/config --enable ACPI_BUTTON
scripts/config --enable ACPI_VIDEO
scripts/config --enable ACPI_THERMAL
scripts/config --enable ACPI_EC
scripts/config --enable ACPI_CONTAINER
scripts/config --enable ACPI_SBS
scripts/config --enable ACPI_SBSB
scripts/config --enable ACPI_WMI
scripts/config --enable POWER_SUPPLY
scripts/config --enable DMI
scripts/config --enable DMI_ID
scripts/config --enable DMI_SYSFS
scripts/config --enable DMI_SCAN_MACHINE_NON_EARLY_FALLBACK

# ============================================================
# Dell WMI / Laptop drivers
# ============================================================
scripts/config --enable WMI
scripts/config --enable WMI_BUILTIN
scripts/config --enable DELL_SMBIOS
scripts/config --enable DELL_WMI
scripts/config --enable DELL_WMI_AIO
scripts/config --enable DELL_WMI_SMBIOS
scripts/config --enable DELL_RBTN
scripts/config --enable ALIENWARE_WMI

# ============================================================
# Storage — ICH8-M
# ============================================================
scripts/config --enable ATA
scripts/config --enable ATA_PIIX
scripts/config --enable SATA
scripts/config --enable SATA_AHCI
scripts/config --enable LIBATA

# ============================================================
# Filesystems (built-in)
# ============================================================
scripts/config --enable EXT4_FS
scripts/config --enable FAT_FS
scripts/config --enable VFAT_FS
scripts/config --enable NTFS_FS
scripts/config --enable NTFS3_FS
scripts/config --enable SQUASHFS
scripts/config --set-str SQUASHFS_COMPRESSOR "xz"
scripts/config --enable ISO9660_FS
scripts/config --enable UDF

# ============================================================
# GPU — Intel GMA X3100 (i915)
# ============================================================
scripts/config --enable DRM
scripts/config --enable DRM_I915
scripts/config --enable DRM_I915_DISPLAY
scripts/config --enable DRM_KMS_HELPER
scripts/config --enable DRM_FBDEV_EMULATION
scripts/config --enable DRM_TTM
scripts/config --enable FB
scripts/config --enable FB_SYS_FILLRECT
scripts/config --enable FB_SYS_COPYAREA
scripts/config --enable FB_SYS_IMAGEBLIT
scripts/config --enable BACKLIGHT_CLASSDEV

# ============================================================
# Audio — IDT STAC9205 (HDA)
# NOTE: SOUND and SND_PCI are menuconfig gates — required!
# ============================================================
scripts/config --enable SOUND
scripts/config --enable SND
scripts/config --enable SND_PCI
scripts/config --enable SND_PCM
scripts/config --enable SND_TIMER
scripts/config --enable SND_HDA
scripts/config --enable SND_HDA_INTEL
scripts/config --enable SND_HDA_CODEC_SIGMATEL
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

# ============================================================
# USB — ICH8 (UHCI + EHCI)
# ============================================================
scripts/config --enable USB
scripts/config --enable USB_EHCI_HCD
scripts/config --enable USB_UHCI_HCD
scripts/config --enable USB_EHCI_HCD_PCI
scripts/config --enable USB_UHCI_HCD_PCI
scripts/config --enable USB_STORAGE
scripts/config --enable USB_HID
scripts/config --enable USB_NET
scripts/config --enable USB_NET_DRIVERS
scripts/config --enable USB_NET_RTL8152
scripts/config --enable USB_ACM
scripts/config --enable USB_SERIAL
scripts/config --enable USB_ETH_RNDIS

# ============================================================
# WiFi — Intel 3945ABG
# ============================================================
scripts/config --enable CFG80211
scripts/config --enable MAC80211
scripts/config --enable IWLAGN
scripts/config --enable IWLWIFI
scripts/config --enable IWLWIFI_LEDS
scripts/config --enable IWLWIFI_QOS
scripts/config --enable IWLWIFI_P2P

# ============================================================
# Ethernet / Network
# ============================================================
scripts/config --enable NET
scripts/config --enable INET
scripts/config --enable NETDEVICES
scripts/config --enable ETHERNET
scripts/config --enable TIGON3
scripts/config --enable TUN
scripts/config --enable BRIDGE

# ============================================================
# nftables / Netfilter
# NOTE: NETFILTER is a menuconfig gate — required!
# ============================================================
scripts/config --enable NETFILTER
scripts/config --enable NETFILTER_ADVANCED
scripts/config --enable NETFILTER_NETLINK
scripts/config --enable NF_CONNTRACK
scripts/config --enable NF_CT_NETLINK
scripts/config --enable NF_NAT
scripts/config --enable NF_NAT_IPV4
scripts/config --enable NF_NAT_IPV6
scripts/config --enable NF_TABLES
scripts/config --enable NF_TABLES_INET
scripts/config --enable NF_TABLES_IPV4
scripts/config --enable NF_TABLES_IPV6
scripts/config --enable NF_TABLES_NETDEV
scripts/config --enable NF_TABLES_ARP
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
scripts/config --set-int IP_SET_MAX 256

# ============================================================
# IPv6
# ============================================================
scripts/config --enable IPV6
scripts/config --enable IPV6_SIT
scripts/config --enable IPV6_TUNNEL
scripts/config --enable IPV6_TUNNEL6
scripts/config --enable IPV6_MULTIPLE_SOCKETS

# ============================================================
# Input — PS/2 keyboard, touchpad, gamepad
# ============================================================
scripts/config --enable INPUT
scripts/config --enable INPUT_EVDEV
scripts/config --enable INPUT_KEYBOARD
scripts/config --enable INPUT_MOUSE
scripts/config --enable INPUT_TOUCHSCREEN
scripts/config --enable INPUT_JOYSTICK
scripts/config --enable INPUT_JOYDEV
scripts/config --enable INPUT_POWERKEY
scripts/config --enable INPUT_SPARSE_KEYMAP
scripts/config --enable SERIO
scripts/config --enable SERIO_I8042
scripts/config --enable SERIO_LIBPS2
scripts/config --enable SERIO_RAW
scripts/config --enable SERIO_PCIPS2
scripts/config --enable INPUT_ATKBD
scripts/config --enable INPUT_MOUSEDEV
scripts/config --enable PSMOUSE
scripts/config --enable PSMOUSE_ALPS
scripts/config --enable PSMOUSE_SYNAPTICS
scripts/config --enable PSMOUSE_ELANTECH
scripts/config --enable PSMOUSE_FOCALTECH
scripts/config --enable PSMOUSE_VMMOUSE
scripts/config --enable PSMOUSE_SMBUS
scripts/config --enable JOYSTICK_XPAD
scripts/config --enable HID
scripts/config --enable USB_HID
scripts/config --enable HID_PANTHERLORD
scripts/config --enable HID_PANTHERLORD_FF

# ============================================================
# I2C / SMBus
# ============================================================
scripts/config --enable I2C
scripts/config --enable I2C_ALGOBIT
scripts/config --enable I2C_ALGOPCF
scripts/config --enable I2C_ALGOPCA
scripts/config --enable I2C_I801
scripts/config --enable SMBUS
scripts/config --enable I2C_GPIO
scripts/config --enable I2C_MUX
scripts/config --enable I2C_MUX_GPO

# ============================================================
# zram (lzo + lz4 + zstd)
# ============================================================
scripts/config --enable BLOCK
scripts/config --enable ZRAM
scripts/config --enable LZO_COMPRESS
scripts/config --enable LZ4_COMPRESS
scripts/config --enable ZSTD_COMPRESS
scripts/config --enable ZSTD_DECOMPRESS

# ============================================================
# Firmware
# ============================================================
scripts/config --enable FW_LOADER
scripts/config --enable FW_LOADER_USER_HELPER

# ============================================================
# Initrd decompressors (all)
# ============================================================
scripts/config --enable BLK_DEV_INITRD
scripts/config --enable RD_GZIP
scripts/config --enable RD_XZ
scripts/config --enable RD_LZ4
scripts/config --enable RD_ZSTD
scripts/config --enable RD_LZO

# ============================================================
# Kernel image compression
# ============================================================
scripts/config --disable GZIP
scripts/config --enable KERNEL_XZ

# ============================================================
# Console
# ============================================================
scripts/config --enable PRINTK
scripts/config --enable EARLY_PRINTK
scripts/config --set-str EARLY_PRINTK "ttyS0,115200"
scripts/config --enable SERIAL_8250
scripts/config --enable SERIAL_8250_CONSOLE

# ============================================================
# Essentials
# ============================================================
scripts/config --enable BINFMT_ELF
scripts/config --enable BINFMT_SCRIPT
scripts/config --enable TTY
scripts/config --enable DEVTMPFS
scripts/config --enable DEVTMPFS_MOUNT
scripts/config --enable PROC_FS
scripts/config --enable SYSFS
scripts/config --enable TMPFS

# ============================================================
# Removable features (REQUIRED for glibc / Debian initrd)
# ============================================================
scripts/config --enable EMBEDDED
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
scripts/config --enable NAMESPACES
scripts/config --enable USER_NS
scripts/config --enable PID_NS
scripts/config --enable MOUNT_NS
scripts/config --enable NET_NS
scripts/config --enable UTS_NS
scripts/config --enable IPC_NS
scripts/config --enable CGROUPS
scripts/config --enable INOTIFY_USER
scripts/config --enable FHANDLE
scripts/config --enable UNIX
scripts/config --enable SYSCTL

scripts/config --enable MOUSE_PS2
scripts/config --enable MOUSE_PS2_ALPS
scripts/config --enable MOUSE_PS2_SYNAPTICS
scripts/config --enable MOUSE_PS2_SYNAPTICS_SMBUS
scripts/config --enable MOUSE_PS2_ELANTECH
scripts/config --enable MOUSE_PS2_FOCALTECH   







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

scripts/config --enable MOUSE_PS2
scripts/config --enable MOUSE_PS2_ALPS
scripts/config --enable MOUSE_PS2_SYNAPTICS
scripts/config --enable MOUSE_PS2_SYNAPTICS_SMBUS
scripts/config --enable CRYPTO
scripts/config --enable CRYPTO_LZO
scripts/config --enable CRYPTO_LZ4
scripts/config --enable CRYPTO_ZSTD
scripts/config --enable ZRAM







# ============================================================
# Final
# ============================================================
make olddefconfig
