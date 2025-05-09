#!/bin/bash
set -e

#pacman
sudo pacman -S --noconfirm \
    vivaldi \
    dolphin \
    konsole \
    spectacle \
    reflector \
    fail2ban \
    openssh \
    filelight \
    ark \
    zsh zsh-completions \
    flatpak \
    qt5ct qt6ct \
    kcalc krunner partitionmanager packagekit-qt \
    alsa-utils bluez bluez-utils \
    qbittorrent audacious wget screen git fastfetch cups \
    pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse easyeffects \
    pacman-contrib lib32-mesa

sudo systemctl enable bluetooth.service
sudo systemctl enable sshd.service
sudo systemctl enable --now cups.service

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd .
rm -rf yay # To delete the yay folder as it isn't necessary anymore

yay -S nushell
chsh -s /usr/bin/nu # To set NuShell as the default SHELL

sudo mkdir /etc/pacman.d/hooks
sudo cat <<EOL >> /etc/pacman.d/hooks/clean_cache.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *
[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk
EOL

#get theming config from github and install later on