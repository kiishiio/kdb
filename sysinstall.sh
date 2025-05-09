#!/bin/bash

# ─── PROMPTS ──────────────────────────────────────────────────────

read -p "Enter keymap (default: us): " KEYMAP
KEYMAP=${KEYMAP:-us}
loadkeys "$KEYMAP"

clear
read -p "Enter username: " USER
clear

read -s -p "Root password: " ROOTPASS; echo
read -s -p "User password: " USERPASS; echo
clear

ls /usr/share/zoneinfo/
read -p "Enter timezone (e.g., Europe/Berlin): " ZONE
clear

read -p "Enter locale (default: en_US.UTF-8): " LOCALE
LOCALE=${LOCALE:-en_US.UTF-8}
clear

read -p "Enter hostname: " HOST
clear

lsblk
read -p "Enter drive to install on (e.g., sda or nvme0n1): " DRIVE
DRIVE="/dev/${DRIVE##/dev/}"

read -p "This will erase $DRIVE. Are you sure? (y/n): " CONFIRM
[[ "$CONFIRM" != "y" ]] && exit 1
clear

read -p "Root partition size in GB (default: 40): " ROOTSIZE
ROOTSIZE=${ROOTSIZE:-40}

# ─── PARTITIONING ─────────────────────────────────────────────────

if [[ "$DRIVE" =~ nvme ]]; then
    P1="${DRIVE}p1"
    P2="${DRIVE}p2"
    P3="${DRIVE}p3"
    P4="${DRIVE}p4"
else
    P1="${DRIVE}1"
    P2="${DRIVE}2"
    P3="${DRIVE}3"
    P4="${DRIVE}4"
fi

sgdisk --zap-all "$DRIVE"
sgdisk -n 1:0:+1G     -t 1:ef00 "$DRIVE"
sgdisk -n 2:0:+16G    -t 2:8200 "$DRIVE"
sgdisk -n 3:0:+${ROOTSIZE}G -t 3:8300 "$DRIVE"
sgdisk -n 4:0:0       -t 4:8300 "$DRIVE"

mkfs.fat -F32 "$P1"
mkswap "$P2" && swapon "$P2"
mkfs.btrfs -f "$P3"
mkfs.btrfs -f "$P4"

mount "$P3" /mnt
mkdir -p /mnt/{boot,home}
mount "$P1" /mnt/boot
mount "$P4" /mnt/home

for dir in dev proc sys run; do
    mount --bind /$dir /mnt/$dir
done

# ─── BASE INSTALL ────────────────────────────────────────────────

pacstrap /mnt \
    base base-devel linux-lts linux-lts-headers linux-firmware \
    btrfs-progs amd-ucode nano sudo reflector mtools dosfstools \
    xorg-server xorg-xrandr arandr \
    plasma-meta konsole dolphin ark kwrite kcalc spectacle krunner partitionmanager packagekit-qt5 systemsettings \
    kvantum-qt5 \
    sddm sddm-kcm \
    nvidia nvidia-utils nvidia-settings nvidia-dkms --noconfirm

genfstab -U /mnt >> /mnt/etc/fstab

# ─── EXPORT VARS ──────────────────────────────────────────────────

export KEYMAP USER USERPASS ROOTPASS ZONE LOCALE HOST
export DRIVE
ROOT_UUID=$(blkid -s PARTUUID -o value "$P3")
export ROOT_UUID

# ─── CHROOT CONFIG ───────────────────────────────────────────────

arch-chroot /mnt /bin/bash <<EOF
set -e

echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf
echo "LANG=$LOCALE" > /etc/locale.conf
echo "$HOST" > /etc/hostname

ln -sf "/usr/share/zoneinfo/$ZONE" /etc/localtime
hwclock --systohc

echo "$LOCALE UTF-8" >> /etc/locale.gen
locale-gen

cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOST.localdomain $HOST
EOL

echo -e "KEYMAP=$KEYMAP\nXKBMODEL=pc105\nXKBLAYOUT=$KEYMAP\nXKBVARIANT=\nXKBOPTIONS=" > /etc/X11/xorg.conf.d/00-keyboard.conf

useradd -m -G wheel "$USER"
echo "root:$ROOTPASS" | chpasswd
echo "$USER:$USERPASS" | chpasswd
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel

sed -i '/\\[multilib\\]/,/Include/ s/^#//' /etc/pacman.conf
pacman -Sy

mkdir -p /etc/sddm.conf.d
cat <<EOL > /etc/sddm.conf.d/autologin.conf
[Autologin]
User=$USER
Session=plasma
DisplayServer=X11
EOL

systemctl enable NetworkManager
systemctl enable sddm

bootctl install
cat <<EOL > /boot/loader/loader.conf
default arch
timeout 2
console-mode max
editor no
EOL

cat <<EOL > /boot/loader/entries/arch.conf
title   Arch Linux LTS
linux   /vmlinuz-linux-lts
initrd  /initramfs-linux-lts.img
options root=PARTUUID=$ROOT_UUID rw quiet nvidia-drm.modeset=1
EOL

curl -o /home/$USER/postinstall.sh https://raw.githubusercontent.com/kiishiio/kdb/main/postinstall.sh
chmod +x /home/$USER/postinstall.sh
chown $USER:$USER /home/$USER/postinstall.sh

EOF

echo "Installation complete. You may reboot now."
