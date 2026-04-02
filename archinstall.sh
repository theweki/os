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

########################
### CLEANUP & PREP   ###
########################

echo "Cleaning up existing mounts and swap..."

# 1. Swap off all active swap devices
swapoff -a || true

# 2. Unmount everything under /mnt recursively
# We use tac to unmount in reverse order (child first, then parent)
if mountpoint -q /mnt; then
	umount -R /mnt || true
fi

# 3. Final check: if /mnt is still busy, force it (optional/dangerous)
# lsof /mnt | awk '{print $2}' | xargs kill -9 2>/dev/null || true

echo "System cleaned. Starting installation..."

#########################
### DISK PARTITIONING ###
#########################

# Create GPT Partition Table & Partitions
lsblk

read -p "DISK   |   nvme0n1 / sda / vda :   " DISK

# Wipe Disk and Partition Table
wipefs --all --force "/dev/$DISK"
sgdisk --zap-all "/dev/$DISK"

{
	echo "label: gpt"
	echo "size=1G, type=U, bootable"
	echo "type=L"

} | sfdisk --force --wipe always --wipe-partitions always "/dev/$DISK"

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
ROOT="/dev/${DISK}${PART_SUFFIX}2"

##########################
### FORMATTING & LABEL ###
##########################

for DEV in "$EFI" "$ROOT"; do
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

mkfs.fat -F 32 "$EFI"
mkfs.ext4 "$ROOT"

#########################
### MOUNTING BY LABEL ###
#########################

mount -o noatime "$ROOT" /mnt

mkdir -p /mnt/boot/efi
mount -o umask=0077 "$EFI" /mnt/boot/efi

#########################
### MIRRORLIST SETUP  ###
#########################

pacman -Sy archlinux-keyring --noconfirm
reflector --country India,Singapore --latest 10 --protocol https --connection-timeout 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

####################
### INSTALLATION ###
####################

core=(
	base base-devel
	linux linux-headers
	linux-firmware linux-firmware-marvell
	sof-firmware
	grub efibootmgr
	zram-generator
  pacman-contrib bash-completion reflector
	man-db man-pages
	vi nano btop git
)

hardware=(
	intel-ucode
	mesa libva-utils
	intel-media-driver vulkan-intel
	thermald
	# vpl-gpu-rt
)

filesystem=(
	e2fsprogs dosfstools exfatprogs
	usbutils plocate
	zip unzip 7zip unrar
)

connectivity=(
	networkmanager openssh
	usb_modeswitch
	bluez bluez-obex bluez-utils
	curl wget
)

audio=(
	pipewire pipewire-audio
	wireplumber
	pipewire-alsa pipewire-pulse pipewire-jack
	gst-plugin-pipewire
	gst-plugins-base gst-plugins-good gst-plugins-bad gst-libav
)

fonts=(
	noto-fonts noto-fonts-extra noto-fonts-cjk noto-fonts-emoji
	ttf-jetbrains-mono-nerd
)

essentials=(
	# fwupd
	# firewalld
	# cups bluez-cups
	udisks2
	gvfs gvfs-afc gvfs-mtp gvfs-gphoto2
	xdg-utils xdg-user-dirs-gtk
	polkit
  libsecret gnome-keyring
	power-profiles-daemon
)

gnome=(
	gdm
	xdg-desktop-portal-gnome
	gnome-shell gnome-control-center
	gnome-disk-utility gnome-text-editor gnome-backgrounds
	gnome-tweaks extension-manager
	snapshot nautilus loupe
	ghostty chromium mpv
)

BASE_ARCH=(
	"${core[@]}"
	"${hardware[@]}"
	"${filesystem[@]}"
	"${connectivity[@]}"
	"${audio[@]}"
	"${fonts[@]}"
	"${essentials[@]}"
)

PKGS=(
	"${BASE_ARCH[@]}"
	"${gnome[@]}"
)

pacstrap -K /mnt "${PKGS[@]}"
sleep 2
genfstab -U /mnt >>/mnt/etc/fstab
# genfstab -U /mnt | grep -v "swap" >>/mnt/etc/fstab

#####################
### CONFIGURATION ###
#####################

mkdir -p /mnt/archinstall

curl -s -o /mnt/archinstall/config.sh https://raw.githubusercontent.com/theweki/os/refs/heads/main/config.sh
chmod +x /mnt/archinstall/config.sh

# Chroot and Execute Post Installation Scripts
arch-chroot /mnt /archinstall/config.sh
rm -rf /mnt/archinstall

# Unmount all partitions safely
swapoff -a || true
umount -R /mnt

echo "--------------------------------------------------"
echo "Installation Completed"
echo "You can now type: reboot"
echo "--------------------------------------------------"
