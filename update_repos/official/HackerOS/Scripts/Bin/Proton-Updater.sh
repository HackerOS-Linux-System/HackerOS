#!/bin/bash

# ==========================================
# Skrypt aktualizacji Proton-GE z ulepszeniami
# HackerOS Team
# ==========================================

# Ścieżki i zmienne
VERSION_FILE="$HOME/.hackeros/proton-version"
PROTON_DIR="$HOME/.steam/root/compatibilitytools.d"
TMP_DIR="/tmp/proton-ge-update"
LOG_FILE="$HOME/.hackeros/proton-update.log"

# Tworzenie katalogów
for dir in "$PROTON_DIR" "$(dirname "$VERSION_FILE")" "$TMP_DIR"; do
    mkdir -p "$dir" || { echo "Nie udało się utworzyć katalogu $dir"; exit 1; }
done

# Logowanie
exec > >(tee -a "$LOG_FILE") 2>&1

# Trap do czyszczenia
trap 'rm -rf "$TMP_DIR"' EXIT

# Sprawdzenie zależności
for cmd in zenity curl tar; do
    if ! command -v $cmd &>/dev/null; then
        echo "Brakuje '$cmd'. Zainstaluj go najpierw."
        exit 1
    fi
done

# Informacja wstępna
zenity --info \
    --title="Aktualizacja Proton-GE" \
    --text="Trwa sprawdzanie dostępności najnowszej wersji Proton-GE..." \
    --timeout=2

# Pobranie najnowszej wersji (tag_name)
LATEST_VERSION=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
    | grep '"tag_name":' | cut -d '"' -f 4)

if [[ -z "$LATEST_VERSION" ]]; then
    zenity --error \
        --title="Błąd" \
        --text="Nie udało się pobrać informacji o najnowszej wersji z GitHuba. Sprawdź połączenie internetowe."
    exit 1
fi

LATEST_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/$LATEST_VERSION/$LATEST_VERSION.tar.gz"
FILENAME="${LATEST_VERSION}.tar.gz"

# Sprawdzenie zainstalowanej wersji
if [[ -f "$VERSION_FILE" ]]; then
    INSTALLED_VERSION=$(cat "$VERSION_FILE")
else
    INSTALLED_VERSION="Brak"
fi

# Jeśli najnowsza wersja już zainstalowana
if [[ -d "$PROTON_DIR/$LATEST_VERSION" ]]; then
    echo "$LATEST_VERSION" > "$VERSION_FILE"
    zenity --info \
        --title="Proton-GE" \
        --text="Najnowsza wersja Proton-GE ($LATEST_VERSION) jest już zainstalowana."
    exit 0
fi

# Pytanie o instalację
zenity --question \
    --title="Dostępna aktualizacja Proton-GE" \
    --text="Dostępna jest nowa wersja Proton-GE: $LATEST_VERSION\nZainstalowana wersja: $INSTALLED_VERSION\n\nCzy chcesz zainstalować aktualizację?" \
    --width=400

if [[ $? -ne 0 ]]; then
    zenity --info \
        --title="Anulowano" \
        --text="Aktualizacja Proton-GE została anulowana."
    exit 0
fi

# Usuwanie starej wersji (jeśli istnieje i pasuje do schematu nazwy)
if [[ -d "$PROTON_DIR/$INSTALLED_VERSION" && "$INSTALLED_VERSION" =~ ^proton-.* ]]; then
    rm -rf "$PROTON_DIR/$INSTALLED_VERSION"
fi

# Pobieranie i rozpakowanie z postępem
cd "$TMP_DIR" || exit 1

(
    echo "10"; echo "# Pobieranie nowej wersji Proton-GE..."
    if ! curl -L "$LATEST_URL" -o "$FILENAME"; then
        zenity --error --title="Błąd pobierania" --text="Nie udało się pobrać pliku $FILENAME"
        exit 1
    fi

    echo "60"; echo "# Rozpakowywanie..."
    if ! tar -xf "$FILENAME" -C "$PROTON_DIR"; then
        zenity --error --title="Błąd" --text="Nie udało się rozpakować $FILENAME"
        exit 1
    fi

    echo "90"; echo "# Czyszczenie..."
    rm -f "$FILENAME"

    echo "100"; echo "# Zakończono."
) | zenity --progress \
    --title="Aktualizacja Proton-GE" \
    --percentage=0 \
    --auto-close \
    --width=400

# Zapisanie nowej wersji
echo "$LATEST_VERSION" > "$VERSION_FILE"

# Zakończenie
zenity --info \
    --title="Zakończono" \
    --text="Nowa wersja Proton-GE ($LATEST_VERSION) została pomyślnie zainstalowana."

exit 0
