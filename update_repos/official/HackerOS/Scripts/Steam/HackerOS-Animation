#!/bin/bash

# Ustawienia
ANIMATION_SOURCE="/usr/share/HackerOS/Animations/HackerOS.webm"
STEAM_MOVIES_PATH="$HOME/.steam/steam/steamui/movies"

# Sprawdzenie czy Steam jest zainstalowany (APT)
if ! command -v steam &> /dev/null; then
    echo "Steam nie jest zainstalowany. Instaluję..."
    sudo apt update && sudo apt install -y steam
fi

# Sprawdzenie istnienia animacji
if [ ! -f "$ANIMATION_SOURCE" ]; then
    echo "❌ Nie znaleziono pliku animacji: $ANIMATION_SOURCE"
    exit 1
fi

# Sprawdzenie katalogu docelowego
if [ ! -d "$STEAM_MOVIES_PATH" ]; then
    echo "❌ Katalog animacji Steam nie istnieje: $STEAM_MOVIES_PATH"
    echo "Uruchom Steam przynajmniej raz, aby utworzyć strukturę katalogów."
    exit 1
fi

# Podmiana animacji
echo "🔁 Podmieniam animacje startowe Steam..."
cp "$ANIMATION_SOURCE" "$STEAM_MOVIES_PATH/bigpicture_startup.webm"
cp "$ANIMATION_SOURCE" "$STEAM_MOVIES_PATH/steam_os_startup.webm"
cp "$ANIMATION_SOURCE" "$STEAM_MOVIES_PATH/steam_os_suspend_form_throbber.webm"

echo "✅ Animacje zostały podmienione."
exit 0
