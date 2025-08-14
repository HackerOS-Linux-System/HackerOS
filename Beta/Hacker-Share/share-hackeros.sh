#!/bin/bash

# ===========================
# HackerOS ISO Creator
# ===========================
# Autor: Michał + Grok
# Opis: Tworzy bootowalny obraz ISO z aktualnego systemu Fedora z użytkownikiem live i GRUB z opcjami Live Mode i Installer Mode
# Wymaga: zenity, mksquashfs, xorriso, grub2, syslinux
# ===========================

set -e

# Sprawdzanie wymaganych pakietów
for pkg in zenity mksquashfs xorriso grub2-mkimage syslinux; do
    if ! command -v $pkg &>/dev/null; then
        zenity --error --text="Brak wymaganego pakietu: $pkg\nZainstaluj go i spróbuj ponownie."
        exit 1
    fi
done

# Wybór lokalizacji ISO
ISO_PATH=$(zenity --file-selection --save --confirm-overwrite --title="Wybierz miejsce zapisu ISO" --filename="HackerOS-Live.iso")
[ -z "$ISO_PATH" ] && exit 1

# Tworzenie katalogów roboczych
WORKDIR=$(mktemp -d)
ROOTFS_DIR="$WORKDIR/rootfs"
ISO_DIR="$WORKDIR/iso"

mkdir -p "$ROOTFS_DIR" "$ISO_DIR/LiveOS" "$ISO_DIR/isolinux"

# Komunikat startowy
zenity --info --text="Rozpoczynam tworzenie obrazu ISO.\nMoże to chwilę potrwać."

# Kopiowanie systemu do rootfs (bez katalogów runtime)
rsync -aAXv / "$ROOTFS_DIR" \
    --exclude={"/proc/*","/sys/*","/dev/*","/tmp/*","/run/*","/mnt/*","/media/*","$WORKDIR/*"}

# Tworzenie użytkownika live "HackerOS-Live" z hasłem "hacker"
mkdir -p "$ROOTFS_DIR/etc"
echo "HackerOS-Live:x:1000:1000:HackerOS Live User:/home/HackerOS-Live:/bin/bash" >> "$ROOTFS_DIR/etc/passwd"
echo "HackerOS-Live:!:19364:0:99999:7:::" >> "$ROOTFS_DIR/etc/shadow"
echo "HackerOS-Live:x:1000:" >> "$ROOTFS_DIR/etc/group"
mkdir -p "$ROOTFS_DIR/home/HackerOS-Live"
chown 1000:1000 "$ROOTFS_DIR/home/HackerOS-Live"
chmod 700 "$ROOTFS_DIR/home/HackerOS-Live"

# Ustawianie hasła dla użytkownika HackerOS-Live
echo "HackerOS-Live:hacker" | chroot "$ROOTFS_DIR" chpasswd

# Tworzenie squashfs
mksquashfs "$ROOTFS_DIR" "$ISO_DIR/LiveOS/squashfs.img" -comp xz -e boot

# Kopiowanie kernela i initramfs
cp -v /boot/vmlinuz-* "$ISO_DIR/isolinux/vmlinuz"
cp -v /boot/initramfs-* "$ISO_DIR/isolinux/initrd.img"

# Tworzenie konfiguracji GRUB
mkdir -p "$ISO_DIR/boot/grub"
cat > "$ISO_DIR/boot/grub/grub.cfg" <<EOF
set timeout=5
set default=0

menuentry "HackerOS Live Mode" {
    linux /isolinux/vmlinuz root=live:CDLABEL=HackerOS-Live ro rd.live.image quiet splash
    initrd /isolinux/initrd.img
}

menuentry "HackerOS Installer Mode" {
    linux /isolinux/vmlinuz root=live:CDLABEL=HackerOS-Live ro rd.live.image quiet splash cage /usr/share/HackerOS/Installation/hacker-install.sh
    initrd /isolinux/initrd.img
}
EOF

# Tworzenie obrazu GRUB dla ISO
grub2-mkimage -o "$ISO_DIR/isolinux/grub.efi" -O x86_64-efi \
    -p "/boot/grub" iso9660 normal linux ext2
grub2-mkimage -o "$ISO_DIR/isolinux/grub.bin" -O i386-pc \
    -p "/boot/grub" iso9660 normal linux ext2

# Kopiowanie niezbędnych plików syslinux
cp /usr/share/syslinux/isolinux.bin "$ISO_DIR/isolinux/"
cp /usr/share/syslinux/ldlinux.c32 "$ISO_DIR/isolinux/"

# Tworzenie pliku konfiguracyjnego isolinux
cat > "$ISO_DIR/isolinux/isolinux.cfg" <<EOF
DEFAULT vesamenu.c32
TIMEOUT 50
PROMPT 0
MENU TITLE HackerOS Boot Menu

LABEL live
    MENU LABEL HackerOS Live Mode
    KERNEL /isolinux/vmlinuz
    APPEND initrd=/isolinux/initrd.img root=live:CDLABEL=HackerOS-Live ro rd.live.image quiet splash startplasma-wayland

LABEL installer
    MENU LABEL HackerOS Installer Mode
    KERNEL /isolinux/vmlinuz
    APPEND initrd=/isolinux/initrd.img root=live:CDLABEL=HackerOS-Live ro rd.live.image quiet splash cage /usr/share/HackerOS/Installation/hacker-install.sh
EOF

# Tworzenie obrazu ISO z xorriso
xorriso -as mkisofs \
    -isolevel 3 \
    -o "$ISO_PATH" \
    -full-iso9660-filenames \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot \
    -e isolinux/grub.efi \
    -no-emul-boot \
    -V "HackerOS-Live" \
    "$ISO_DIR"

# Czyszczenie
rm -rf "$WORKDIR"

# Komunikat końcowy
zenity --info --text="Obraz ISO został utworzony!\nLokalizacja: $ISO_PATH"
