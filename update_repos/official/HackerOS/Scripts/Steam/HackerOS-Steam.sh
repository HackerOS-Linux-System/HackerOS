#!/bin/bash

# Lokalizacja skryptu do podmiany animacji
ANIMATION_SCRIPT="/usr/share/HackerOS/Scripts/Steam/HackerOS-Steam-Animation.sh"

# Instalacja Steam jeśli potrzeba
if ! command -v steam &> /dev/null; then
    zenity --info --text="Steam nie jest zainstalowany. Instaluję..."
    sudo apt update && sudo apt install -y steam
fi

# GUI wyboru trybu uruchomienia
CHOICE=$(zenity --list --title="Wybierz tryb Steama" \
  --column="Tryb" --height=250 --width=300 \
  "Zwykły Steam" \
  "Steam Big Picture" \
  "Nie uruchamiaj")

case "$CHOICE" in
  "Zwykły Steam"|"Steam Big Picture")
    # Wywołanie zewnętrznego skryptu do podmiany animacji
    if [ -x "$ANIMATION_SCRIPT" ]; then
        "$ANIMATION_SCRIPT"
    else
        zenity --error --text="Nie znaleziono lub brak uprawnień do wykonania:\n$ANIMATION_SCRIPT"
        exit 1
    fi
    ;;
  "Nie uruchamiaj")
    echo "Nie uruchamiam Steama."
    exit 0
    ;;
  *)
    echo "Anulowano lub zamknięto okno."
    exit 1
    ;;
esac

# Uruchamianie odpowiedniego trybu
if [[ "$CHOICE" == "Zwykły Steam" ]]; then
  steam
elif [[ "$CHOICE" == "Steam Big Picture" ]]; then
  steam -gamepadui
fi
