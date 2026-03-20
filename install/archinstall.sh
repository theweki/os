#!/usr/bin/env bash

# Fail fast and safer defaults
set -euo pipefail
IFS=$'\n\t'

# Error handling trap
trap 'rc=$?; echo "Error: script exited with status $rc at line ${LINENO:-?}" >&2; exit $rc' ERR

########################
### PRE INSTALLATION ###
########################

loadkeys us
timedatectl set-timezone Asia/Kolkata
timedatectl set-ntp true

#########################
### DISK PARTITIONING ###
#########################

# Create GPT Partition Table & Partitions
lsblk

read -p "DISK   |   nvme0n1 / sda / vda :   " DISK

# Wipe Disk and Partition Table
sgdisk --zap-all "/dev/$DISK"

{
    echo "label: gpt"

    echo "size=1G, type=U, bootable"
    echo "size=8G, type=S"
    echo "type=L"

} | sfdisk "/dev/$DISK"

# Inform kernel of partition table changes and wait for udev to settle
partprobe /dev/"$DISK" || true
udevadm settle
sleep 2

# Format Partitions
if [[ "$DISK" == nvme* || "$DISK" == mmcblk* ]]; then
    PART_SUFFIX="p"
else
    PART_SUFFIX=""
fi

EFI="/dev/${DISK}${PART_SUFFIX}1"
SWAP="/dev/${DISK}${PART_SUFFIX}2"
ROOT="/dev/${DISK}${PART_SUFFIX}3"

##########################
### FORMATTING & LABEL ###
##########################

for DEV in "$EFI" "$SWAP" "$ROOT"; do
    if [ ! -b "$DEV" ]; then
        echo "Waiting for $DEV to appear..."
        for i in {1..10}; do
            sleep 1
            [ -b "$DEV" ] && break
        done
    fi
    if [ ! -b "$DEV" ]; then
        lsblk
        echo "Error: device $DEV not found; aborting."
        exit 1
    fi
done

mkfs.fat -F 32 -n ARCH_EFI "$EFI"
mkswap -L ARCH_SWAP "$SWAP"
mkfs.ext4 -L ARCH_ROOT "$ROOT"

#########################
### MOUNTING BY LABEL ###
#########################

mount -o noatime /dev/disk/by-label/ARCH_ROOT /mnt

mkdir -p /mnt/boot/efi
mount -o umask=0077 /dev/disk/by-label/ARCH_EFI /mnt/boot/efi

swapon /dev/disk/by-label/ARCH_SWAP

#########################
### MIRRORLIST SETUP  ###
#########################

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
reflector --latest 20 --protocol https --connection-timeout 5 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

####################
### INSTALLATION ###
####################

# --- Hardware Specifics ---
INTEL_UC_PKGS=(intel-ucode)
INTEL_GPU_PKGS=(mesa libva-utils vulkan-intel intel-media-driver libva-intel-driver)

# AMD_UC_PKGS=(amd-ucode)
# AMD_GPU_PKGS=(mesa libva-utils libva-mesa-driver vulkan-radeon xf86-video-amdgpu xf86-video-ati)

# --- Functional Groups ---
CORE_PKGS=(base base-devel linux linux-headers grub efibootmgr)
FIRMWARE_PKGS=(linux-firmware linux-firmware-marvell sof-firmware fwupd)
FILESYSTEM_PKGS=(e2fsprogs dosfstools exfatprogs)

# Desktop Environment
# DISPLAY_SERVER_PKGS=(xorg xorg-xinit)
DESKTOP_PKGS=(gnome power-profiles-daemon gnome-remote-desktop gdm xdg-user-dirs)
# gnome gnome-tweaks gnome-themes-extra power-profiles-daemon gnome-remote-desktop

AUDIO_PKGS=(wireplumber pipewire pipewire-audio pipewire-alsa pipewire-pulse pipewire-jack gst-plugin-pipewire)
BT_PKGS=(bluez bluez-utils)
NET_PKGS=(networkmanager openssh firewalld)

TOOLS_PKGS=(cups usbutils thermald plocate git curl wget reflector pacman-contrib)
FONTS_PKGS=(noto-fonts noto-fonts-extra noto-fonts-cjk noto-fonts-emoji ttf-jetbrains-mono-nerd)
SHELL_PKGS=(bash-completion man-db man-pages zip unzip 7zip unrar vi nano)

PKGS=(
    "${CORE_PKGS[@]}"
    "${FIRMWARE_PKGS[@]}"
    "${INTEL_UC_PKGS[@]}"
    "${INTEL_GPU_PKGS[@]}"
    "${FILESYSTEM_PKGS[@]}"
    "${DESKTOP_PKGS[@]}"
    "${AUDIO_PKGS[@]}"
    "${BT_PKGS[@]}"
    "${NET_PKGS[@]}"
    "${TOOLS_PKGS[@]}"
    "${FONTS_PKGS[@]}"
    "${SHELL_PKGS[@]}"
)

pacstrap -K /mnt "${PKGS[@]}"
sleep 2
genfstab -U /mnt >> /mnt/etc/fstab

#####################
### CONFIGURATION ###
#####################

mkdir -p /mnt/archinstall

curl -s -o /mnt/archinstall/config.sh https://raw.githubusercontent.com/theweki/os/refs/heads/main/install/config.sh
chmod +x /mnt/archinstall/config.sh

# Chroot and Execute Post Installation Scripts
arch-chroot /mnt /archinstall/config.sh
rm -rf /mnt/archinstall

# Unmount all partitions safely
umount -R /mnt

echo "--------------------------------------------------"
echo "Installation Completed"
echo "You can now type: reboot"
echo "--------------------------------------------------"
