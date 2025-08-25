#!/usr/bin/env bash

# Sprawdzenie czy zenity jest zainstalowane
if ! command -v zenity &> /dev/null; then
  echo "Błąd: zenity nie jest zainstalowane. Zainstaluj je i spróbuj ponownie."
  exit 1
fi

# Automatyczne wykrywanie użytkownika o UID 1000
USER=$(id -nu 1000)

# Plik autologowania SDDM
AUTOLOGIN_CONF="/etc/sddm.conf.d/zz-autologin-session.conf"

# Jeśli plik nie istnieje, twórz go z domyślną konfiguracją penetration-mode
if [[ ! -f "$AUTOLOGIN_CONF" ]]; then
  echo "Plik $AUTOLOGIN_CONF nie istnieje. Tworzę z domyślną sesją penetration-mode.desktop..."
  sudo tee "$AUTOLOGIN_CONF" > /dev/null <<EOF
[Autologin]
User=$USER
Session=penetration-mode.desktop
EOF
  echo "Plik został utworzony."
fi

# Wyświetl dialog wyboru sesji
SESSION=$(zenity --list --title="Wybierz sesję do autologowania" \
  --column="Sesja" --column="Opis" \
  "HackerOS TV" "Przełącz na sesję HackerOS TV" \
  "Hacker-Mode" "Przełącz na sesję Hacker-Mode" \
  "Penetration-Mode" "Przełącz na sesję Penetration-Mode")

# Sprawdź czy użytkownik anulował okno
if [[ -z "$SESSION" ]]; then
  echo "Anulowano wybór sesji."
  exit 0
fi

# Mapowanie nazwy sesji na nazwę pliku sesji (Session=)
case "$SESSION" in
  "HackerOS TV")
    SESSION_FILE="HackerOS-TV.desktop"
    ;;
  "Hacker-Mode")
    SESSION_FILE="Hacker-Mode.desktop"
    ;;
  "Penetration-Mode")
    SESSION_FILE="penetration-mode.desktop"
    ;;
  *)
    echo "Nieznana sesja: $SESSION"
    exit 1
    ;;
esac

echo "Wybrano sesję: $SESSION ($SESSION_FILE)"

# Tworzenie (nadpisanie) pliku autologowania z wybraną sesją
sudo tee "$AUTOLOGIN_CONF" > /dev/null <<EOF
[Autologin]
User=$USER
Session=$SESSION_FILE
EOF

echo "Plik $AUTOLOGIN_CONF został zaktualizowany."

# Próba wylogowania użytkownika z Plasma (jeśli jest aktywna)
echo "Wylogowuję użytkownika (jeśli jest w sesji Plasma)..."
sudo -Eu "$USER" qdbus org.kde.Shutdown /Shutdown org.kde.Shutdown.logout 2>/dev/null || echo "Nie udało się wylogować (może użytkownik nie jest w KDE)."
