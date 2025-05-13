#!/bin/bash
set -e

# ─────────────────────────────
# PACMAN INSTALLATION
# ─────────────────────────────

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
    flatpak \
    qt5ct qt6ct \
    alsa-utils bluez bluez-utils \
    qbittorrent audacious wget screen git fastfetch cups \
    pipewire wireplumber pipewire-audio pipewire-alsa pipewire-pulse easyeffects \
    pacman-contrib lib32-mesa \
    lutris \
    obsidian \
    code \
    lib32-nvidia-utils

# ─────────────────────────────
# ENABLE SERVICES
# ─────────────────────────────

sudo systemctl enable bluetooth.service
sudo systemctl enable sshd.service
sudo systemctl enable --now cups.service

# ─────────────────────────────
# INSTALL YAY (AUR HELPER)
# ─────────────────────────────

git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si --noconfirm
cd ..
rm -rf yay

# ─────────────────────────────
# INSTALL AUR PACKAGES
# ─────────────────────────────

yay -S --noconfirm \
    nushell \
    cssloader-desktop-git \
    polyversal-coz-linux-patcher-git \
    wallpaper-engine-kde-plugin-git \
    kwin-effects-forceblur-git \
    latte-dock

# ─────────────────────────────
# SET DEFAULT SHELL TO NUSHELL
# ─────────────────────────────

chsh -s /usr/bin/nu

# ─────────────────────────────
# CONFIGURE PACMAN HOOK FOR CACHE CLEANUP
# ─────────────────────────────

sudo mkdir -p /etc/pacman.d/hooks
sudo tee /etc/pacman.d/hooks/clean_cache.hook > /dev/null <<EOL
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk2
EOL

# ─────────────────────────────
# KDE CONFIGURATIONS
# ─────────────────────────────

# Enable NVIDIA DRM KMS
echo "options nvidia_drm modeset=1" | sudo tee /etc/modprobe.d/nvidia_drm.conf
sudo mkinitcpio -P

# Create Xorg configuration for NVIDIA
sudo mkdir -p /etc/X11/xorg.conf.d
cat <<EOL > /etc/X11/xorg.conf.d/10-nvidia.conf
Section "Device"
    Identifier "Nvidia Card"
    Driver "nvidia"
    Option "Coolbits" "28"
EndSection
EOL

# Set Digital Vibrance and Force Composition Pipeline on startup
mkdir -p ~/.config/autostart
tee ~/.config/autostart/nvidia-settings.sh > /dev/null <<EOL
#!/bin/bash
nvidia-settings --assign "[gpu:0]/DigitalVibrance=200"
nvidia-settings --assign CurrentMetaMode="DPY-1: nvidia-auto-select +0+0 { ForceCompositionPipeline = On }"
EOL
chmod +x ~/.config/autostart/nvidia-settings.sh

# Configure KDE to hide titlebars on maximized windows
kwinrc=~/.config/kwinrc
if ! grep -q "BorderlessMaximizedWindows=true" "$kwinrc"; then
    echo -e "\n[Windows]\nBorderlessMaximizedWindows=true" >> "$kwinrc"
fi

# ─────────────────────────────
# FLATPAK CONFIGURATION
# ─────────────────────────────

# Add Flathub repository
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# Install additional Flatpak applications if needed
# Example:
# flatpak install flathub com.spotify.Client -y

# ─────────────────────────────
# THEME AND CUSTOMIZATION PLACEHOLDER
# ─────────────────────────────

# Placeholder for future theming configurations:
# - Custom cursor
# - Custom icons
# - Custom themes
# - Custom animations
# These can be added here in the future as needed.

echo "Post-installation setup complete. Please reboot your system to apply all changes."
