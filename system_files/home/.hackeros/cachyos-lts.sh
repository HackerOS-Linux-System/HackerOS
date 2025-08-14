#!/bin/bash

# Czekamy na internet
until ping -c1 google.com &>/dev/null; do sleep 2; done

# Aktualizacja systemu
sudo hacker-update

# Kernel CachyOS
sudo /usr/lib/HackerOS/dnf copr enable -y bieszczaders/kernel-cachyos
sudo /usr/lib/HackerOS/dnf install -y kernel-cachyos-lts kernel-cachyos-lts-devel-matched

# Dodatki do kernela
sudo /usr/lib/HackerOS/dnf copr enable -y bieszczaders/kernel-cachyos-addons
sudo /usr/lib/HackerOS/dnf install -y libcap-ng libcap-ng-devel procps-ng procps-ng-devel

# uksmd
sudo /usr/lib/HackerOS/dnf install -y uksmd
sudo systemctl enable --now uksmd.service

# Sprawdzenie GPU NVIDIA
if lspci | grep -iq nvidia ; then
    sudo hacker install akmod-nvidia
    sudo /usr/lib/HackerOS/dnf config-manager --add-repo=https://developer.download.nvidia.com/compute/cuda/repos/fedora$(rpm -E %fedora)/x86_64/cuda-fedora$(rpm -E %fedora).repo
    sudo /usr/lib/HackerOS/dnf clean all
    sudo /usr/lib/HackerOS/dnf install cuda nvidia-settings
fi

# Usunięcie autostartu
rm -rf "/home/$SUDO_USER/.hackeros/cachyos-lts.sh"
rm -f "/home/$SUDO_USER/.config/autostart/cachyos-lts-kernel.desktop"

# Restart z opóźnieniem
echo "Instalacja zakończona. System uruchomi się ponownie za 10 sekund."
sleep 10
sudo reboot
