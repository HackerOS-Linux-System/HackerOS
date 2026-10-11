#!/bin/sh
# Uruchamiany WYLACZNIE w sesji live (patrz ConditionPathExists=/run/live w
# blue-live-autologin.service), przed startem display managera. Zapisuje
# autologin dla menedzera wybranego przy budowie obrazu
# (/etc/hackeros/blue-default-dm: sddm | lightdm | gdm | hdm).
# W zainstalowanym systemie /run/live nie istnieje, wiec nic sie nie dzieje.
LIVE_USER="$(getent passwd 1000 | cut -d: -f1)"
[ -n "$LIVE_USER" ] || LIVE_USER="user"
SESSION="blue-environment"
DM="$(cat /etc/hackeros/blue-default-dm 2>/dev/null || echo sddm)"

case "$DM" in
sddm)
    # /etc/sddm.conf - plik o najwyzszym priorytecie w SDDM, wiec nie moze go
    # nadpisac ani live-config, ani zadna inna konfiguracja z conf.d.
    cat > /etc/sddm.conf <<CONF
[Autologin]
User=$LIVE_USER
Session=$SESSION.desktop
Relogin=true

[General]
Numlock=none
CONF
    ;;
lightdm)
    mkdir -p /etc/lightdm/lightdm.conf.d
    # 60- > 50-blue-environment.conf, wiec te wartosci wygrywaja.
    cat > /etc/lightdm/lightdm.conf.d/60-blue-live-autologin.conf <<CONF
[Seat:*]
autologin-user=$LIVE_USER
autologin-user-timeout=0
autologin-session=$SESSION
user-session=$SESSION
CONF
    ;;
gdm)
    # Debian czyta /etc/gdm3/daemon.conf (starsze wydania) albo
    # /etc/gdm3/custom.conf (nowsze) - zapisujemy ten sam, kompletny
    # plik do obu, zeby nie zgadywac, ktory obowiazuje.
    mkdir -p /etc/gdm3
    for f in /etc/gdm3/daemon.conf /etc/gdm3/custom.conf; do
        cat > "$f" <<CONF
[daemon]
WaylandEnable=true
AutomaticLoginEnable=true
AutomaticLogin=$LIVE_USER

[security]

[xdmcp]

[chooser]

[debug]
CONF
    done
    # Domyslna sesja uzytkownika - GDM czyta ja z AccountsService.
    mkdir -p /var/lib/AccountsService/users
    cat > "/var/lib/AccountsService/users/$LIVE_USER" <<CONF
[User]
Session=$SESSION
XSession=$SESSION
SystemAccount=false
CONF
    chmod 600 "/var/lib/AccountsService/users/$LIVE_USER"
    ;;
*)
    # hdm (i nieznane wartosci): HDM nie ma wlasnego pliku autologinu.
    ;;
esac
exit 0
