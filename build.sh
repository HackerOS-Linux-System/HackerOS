#!/usr/bin/env bash

# Włączenie trybu awaryjnego - skrypt przerwie działanie w razie błędu
set -euo pipefail

# --- ZMIENNE Z WERSJAMI APLIKACJI ---
# Kategoria: HackerOS-Apps
VER_STORE="v0.6"
VER_LAUNCHER="v0.9"
VER_PROTON="v0.0.1"
VER_TERM="v0.8"
VER_WELCOME="v0.6"

# Kategoria: /usr/bin
VER_CLI="v2.4.2"
VER_NIX="v0.1"
VER_LANG="gen-1"
VER_HPM="v0.8"
VER_CHKER="v0.1"
VER_GETIT="v0.4"
VER_STEAM="v0.4"
VER_HSH="v0.4"
VER_NGT="v0.4"
VER_HEDIT="v0.5"

# --- DEFINICJE ŚCIEŻEK DOCELOWYCH ---
TARGET_SHARE="config/includes.chroot_after_packages/usr/share"
TARGET_APPS="${TARGET_SHARE}/HackerOS/Scripts/HackerOS-Apps"
TARGET_BIN="config/includes.chroot_after_packages/usr/bin"
REPO_TMP="/tmp/HackerOS-Updates"

echo "=== Rozpoczynanie przygotowania struktury systemu HackerOS ==="

# 1. Klonowanie repozytorium aktualizacji do /tmp
echo "-> Klonowanie HackerOS-Updates..."
rm -rf "$REPO_TMP"
git clone --depth 1 https://github.com/HackerOS-Linux-System/HackerOS-Updates.git "$REPO_TMP"

# 2. Tworzenie wymaganych katalogów bazowych
mkdir -p "$TARGET_SHARE"
mkdir -p "$TARGET_APPS"
mkdir -p "$TARGET_BIN"

# 3. Kopiowanie zawartości z ze sklonowanego repozytorium
echo "-> Kopiowanie tapet i katalogu HackerOS..."
# Kopiowanie zawartości wallpaper-updates/wallpapers/ do usr/share/
if [ -d "$REPO_TMP/wallpaper-updates/wallpapers" ]; then
    cp -r "$REPO_TMP/wallpaper-updates/wallpapers/"* "$TARGET_SHARE/"
fi

# Kopiowanie folderu HackerOS do usr/share/
if [ -d "$REPO_TMP/HackerOS" ]; then
    cp -r "$REPO_TMP/HackerOS" "$TARGET_SHARE/"
fi

# 4. Pobieranie plików do HackerOS-Apps
echo "-> Pobieranie aplikacji do HackerOS-Apps..."
curl -L -o "${TARGET_APPS}/HackerOS-Store" "https://github.com/HackerOS-Linux-System/HackerOS-Store/releases/download/${VER_STORE}/HackerOS-Store"
curl -L -o "${TARGET_APPS}/Hacker_Launcher" "https://github.com/HackerOS-Linux-System/Hacker_Launcher/releases/download/${VER_LAUNCHER}/Hacker_Launcher"
curl -L -o "${TARGET_APPS}/proton-manager" "https://github.com/HackerOS-Linux-System/Proton-Manager/releases/download/${VER_PROTON}/proton-manager"
curl -L -o "${TARGET_APPS}/Hacker-Term" "https://github.com/HackerOS-Linux-System/Hacker-Term/releases/download/${VER_TERM}/Hacker-Term"
curl -L -o "${TARGET_APPS}/HackerOS-Welcome" "https://github.com/HackerOS-Linux-System/HackerOS-Welcome/releases/download/${VER_WELCOME}/HackerOS-Welcome"

# Nadanie praw wykonywania pobranym binarkom narzędziowym
chmod +x "${TARGET_APPS}/"*

# 5. Pobieranie narzędzi do /usr/bin/
echo "-> Pobieranie narzędzi systemowych do /usr/bin..."
curl -L -o "${TARGET_BIN}/hacker" "https://github.com/HackerOS-Linux-System/Hacker-CLI-Tool/releases/download/${VER_CLI}/hacker"
curl -L -o "${TARGET_BIN}/hnm" "https://github.com/HackerOS-Linux-System/HackerOS-Nix-Manager/releases/download/${VER_NIX}/hnm"
curl -L -o "${TARGET_BIN}/hl" "https://github.com/HackerOS-Linux-System/Hacker-Lang/releases/download/${VER_LANG}/hl"
curl -L -o "${TARGET_BIN}/hpm" "https://github.com/HackerOS-Linux-System/HackerOS-Package-Manager/releases/download/${VER_HPM}/hpm"
curl -L -o "${TARGET_BIN}/chker" "https://github.com/HackerOS-Linux-System/chker/releases/download/${VER_CHKER}/chker"
curl -L -o "${TARGET_BIN}/getit" "https://github.com/HackerOS-Linux-System/getit/releases/download/${VER_GETIT}/getit"
curl -L -o "${TARGET_BIN}/hackeros-steam" "https://github.com/HackerOS-Linux-System/HackerOS-Steam/releases/download/${VER_STEAM}/hackeros-steam"
curl -L -o "${TARGET_BIN}/hsh" "https://github.com/HackerOS-Linux-System/hsh/releases/download/${VER_HSH}/hsh"
curl -L -o "${TARGET_BIN}/ngt" "https://github.com/HackerOS-Linux-System/ngt/releases/download/${VER_NGT}/ngt"
curl -L -o "${TARGET_BIN}/hedit" "https://github.com/HackerOS-Linux-System/hedit/releases/download/${VER_HEDIT}/hedit"

# Nadanie praw wykonywania binarkom w /usr/bin
chmod +x "${TARGET_BIN}/"*

# 6. Rozpakowywanie archiwów i ich usuwanie
echo "-> Rozpakowywanie archiwów..."

# .oh-my-zsh.tar.gz
ZSH_ARCHIVE="config/includes.chroot_after_packages/etc/skel/.config/.oh-my-zsh.tar.gz"
if [ -f "$ZSH_ARCHIVE" ]; then
    # Rozpakowanie w katalogu, w którym znajduje się plik tar.gz
    tar -xzf "$ZSH_ARCHIVE" -C "config/includes.chroot_after_packages/etc/skel/.config/"
    rm "$ZSH_ARCHIVE"
else
    echo "Ostrzeżenie: Nie znaleziono archiwum $ZSH_ARCHIVE"
fi

# icons.tar.gz
ICONS_ARCHIVE="config/includes.chroot_after_packages/usr/share/icons.tar.gz"
if [ -f "$ICONS_ARCHIVE" ]; then
    # Rozpakowanie w config/includes.chroot_after_packages/usr/share/
    tar -xzf "$ICONS_ARCHIVE" -C "$TARGET_SHARE/"
    rm "$ICONS_ARCHIVE"
else
    echo "Ostrzeżenie: Nie znaleziono archiwum $ICONS_ARCHIVE"
fi

# 7. Czyszczenie katalogu tymczasowego
rm -rf "$REPO_TMP"

# 8. Uruchomienie skryptu budującego system
echo "-> Wszystkie operacje plikowe zakończone. Uruchamianie build-hackeros..."
if [ -f "build/build-hackeros" ]; then
    chmod +x build/build-hackeros
    ./build/build-hackeros
else
    echo "Błąd: Skrypt build/build-hackeros nie istnieje!"
    exit 1
fi
