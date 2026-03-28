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
	echo "size=8G, type=S"
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

mkfs.fat -F 32 "$EFI"
mkswap "$SWAP"
mkfs.ext4 "$ROOT"

#########################
### MOUNTING BY LABEL ###
#########################

mount -o noatime "$ROOT" /mnt

mkdir -p /mnt/boot/efi
mount -o umask=0077 "$EFI" /mnt/boot/efi

swapon "$SWAP"

#########################
### MIRRORLIST SETUP  ###
#########################

sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -Sy archlinux-keyring --noconfirm
reflector --country India,Singapore --latest 10 --protocol https --connection-timeout 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

####################
### INSTALLATION ###
####################

core=(
	base
	base-devel
	linux
	linux-headers

	linux-firmware
	linux-firmware-marvell
	sof-firmware

	grub
	efibootmgr

	pacman-contrib
	bash-completion
	reflector

	man-db
	man-pages

	vi
	nano

	btop
	fastfetch

	git
)

hardware=(
	intel-ucode

	mesa
	libva-utils
	vulkan-intel
	intel-media-driver
	libva-intel-driver

	thermald
)

filesystem=(
	e2fsprogs
	dosfstools
	exfatprogs

	usbutils
	plocate

	zip
	unzip
	7zip
	unrar
)

connectivity=(
	networkmanager
	openssh

	bluez
	bluez-utils

	curl
	wget
)

audio=(
	wireplumber
	pipewire
	pipewire-audio
	pipewire-alsa
	pipewire-pulse
	pipewire-jack
	gst-plugin-pipewire
)

fonts=(

	noto-fonts
	noto-fonts-extra
	noto-fonts-cjk
	noto-fonts-emoji
	ttf-jetbrains-mono-nerd
)

essentials=(
	# fwupd
	# firewalld
	# cups
	# bluez-cups

	udisks2

	gvfs
	gvfs-mtp
	gvfs-gphoto2
	gvfs-afc
	gvfs-smb

	xdg-utils
	xdg-user-dirs-gtk

	libsecret
	gnome-keyring
	polkit-gnome

	power-profiles-daemon
)

gnome=(
	gdm
	gnome-shell
	gnome-session
	gnome-settings-daemon
	gnome-control-center
	gnome-tweaks
	gnome-backgrounds
	gnome-themes-extra
	xdg-desktop-portal-gnome
	adwaita-icon-theme
	hicolor-icon-theme

	nautilus
	loupe
	alacritty
	chromium
	mpv
	gnome-text-editor
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
