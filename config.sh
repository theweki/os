#!/usr/bin/env bash

set -e          # Exit immediately if a command exits with a non-zero status
set -u          # Treat unset variables as an error and exit immediately
set -o pipefail # Return the exit status of the last command in the pipeline that failed
IFS=$'\n\t'     # Set the Internal Field Separator to newline and tab

keyboardlayout="us"
zoneinfo="Asia/Kolkata"
hostname="arch"
username="weki"
password="root"

# --- Localization ---
ln -sf /usr/share/zoneinfo/$zoneinfo /etc/localtime
hwclock --systohc

# Mirror Selection
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
reflector --country India,Singapore --latest 10 --protocol https --connection-timeout 10 --sort rate --save /etc/pacman.d/mirrorlist
pacman -Syy --noconfirm

# --- Locale & Keyboard ---
sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=$keyboardlayout" >>/etc/vconsole.conf

# --- Network Config ---
echo "$hostname" >/etc/hostname
{
	echo "127.0.0.1   localhost"
	echo "::1         localhost"
	echo "127.0.1.1   $hostname.localdomain $hostname"
} >/etc/hosts

# --- Users & Permissions ---
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
useradd -m -G wheel $username
echo "root:$password" | chpasswd
echo "$username:$password" | chpasswd

# Early KMS for Intel
sed -i 's/^MODULES=()/MODULES=(i915)/' /etc/mkinitcpio.conf

# zRAM Configuration (8GB Target for 16GB RAM)
cat <<EOF >/etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

# Kernel Swappiness (Prioritize zRAM)
cat <<EOF >/etc/sysctl.d/99-vm-zram-parameters.conf
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
vm.vfs_cache_pressure = 125
EOF

# Generate initramfs
mkinitcpio -P

# Bootloader
sed -i 's/loglevel=3 quiet/loglevel=3 quiet vt.global_cursor_default=0/g' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# --- Services ---
systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable thermald.service
systemctl enable power-profiles-daemon.service

systemctl enable paccache.timer
systemctl enable fstrim.timer
systemctl enable reflector.timer
systemctl enable plocate-updatedb.timer

# systemctl enable sshd.service
# systemctl enable firewalld.service
# systemctl enable cups.socket
# systemctl enable avahi-daemon.socket

systemctl enable gdm.service
