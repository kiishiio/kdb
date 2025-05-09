#!/bin/bash

#keymap
read -p "enter keymap (default: us): " KEYMAP
KEYMAP=${KEYMAP:-us}
loadkeys "$KEYMAP"

clear

#list & ask drives
lsblk
read -p "enter drive to install on (eg. /dev/sda): " DRIVE

#confirm
read -p "this will erase $DRIVE, and all its data. are you sure you want to continue? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && exit 1

clear

#root size
read -p "what size shall the root partition in GB be? (default: 40): " ROOTSIZE
ROOTSIZE=${ROOTSIZE:-40}

#wipe drive
sgdisk --zap-all "$DRIVE"
sgdisk -n 1:0:+1G -t 1:ef00 "$DRIVE"
sgdisk -n 2:0:+16G -t 2:8200 "$DRIVE"
sgdisk -n 3:0:+${ROOTSIZE}G -t 3:8300 "$DRIVE"
sgdisk -n 4:0:0 -t 4:8300 "$DRIVE"

#format drive
mkfs.fat -F32 "${DRIVE}1"
mkswap "${DRIVE}2"
swapon "${DRIVE}2"
mkfs.btrfs -f "${DRIVE}3"
mkfs.btrfs -f "${DRIVE}4"

#mount
mount "${DRIVE}3" /mnt
mkdir -p /mnt/boot /mnt/home
mount "${DRIVE}1" /mnt/boot
mount "${DRIVE}4" /mnt/home

clear

#base system
pacstrap -K /mnt base linux-lts linux-firmware sudo nano vim \
    btrfs-progs networkmanager plasma kde-applications sddm sddm-kcm \
    xorg-server nvidia nvidia-utils nvidia-settings lib32-mesa \
    kvantum-qt5 kvantum-qt6

clear

#fstab
genfstab -U /mnt >> /mnt/etc/fstab

#
ROOT_UUID=$(blkid -s PARTUUID -o value "${DRIVE}3")
export ROOT_UUID

#chroot
arch-chroot /mnt /bin/bash <<'EOF'
set -e

#set keymap
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

#timezone
ls /usr/share/zoneinfo/
read -p "enter timezone (eg. Europe/Berlin): " ZONE
ln -sf "/usr/share/zoneinfo/\$ZONE" /etc/localtime
hwclock --systohc

#locale
read -p "enter locale (default: en_US.UTF-8): " LOCALE
LOCALE=\${LOCALE:-en_US.UTF-8}
echo "\$LOCALE UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=\$LOCALE" > /etc/locale.conf

#hostname
read -p "enter hostname: " HOST
echo "\$HOST" > /etc/hostname
cat <<EOL >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   \$HOST.localdomain \$HOST
EOL

#root pw
echo "set root password"
passwd

#useradd
read -p "enter username: " USER
useradd -m -G wheel "\$USER"
echo "set password for \$USER"
passwd "\$USER"
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

#multilib
sed -i '/\\[multilib\\]/,/Include/ s/^#//' /etc/pacman.conf
pacman -Sy

#autologin
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat <<EOL2 > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin \$USER --noclear %I \$TERM
EOL2

#enable services
systemctl enable NetworkManager
systemctl enable sddm

#bootloader
bootctl install
cat <<EOL3 > /boot/loader/loader.conf
default arch
timeout 2
console-mode max
editor no
EOL3

cat <<EOL4 > /boot/loader/entries/arch.conf
title   Arch Linux LTS
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options root=PARTUUID=\$ROOT_UUID rw quiet
EOL4

#download post-install script
curl -o /home/$USER/post-install.sh https://raw.githubusercontent.com/kiishiio/kdb/refs/heads/main/postinstall.sh
chmod +x /home/$USER/post-install.sh
chown $USER:$USER /home/$USER/post-install.sh

EOF

echo "installation complete, you may reboot."