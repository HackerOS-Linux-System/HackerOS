#!/bin/sh
# Uruchamiany WYLACZNIE w sesji live (patrz ConditionPathExists=/run/live w
# blue-live-autologin.service), przed startem SDDM. Zapisuje autologin do
# /etc/sddm.conf - plik o najwyzszym priorytecie w SDDM, wiec nie moze go
# nadpisac ani live-config, ani zadna inna konfiguracja z conf.d.
# W zainstalowanym systemie /run/live nie istnieje, wiec nic sie nie dzieje.
LIVE_USER="$(getent passwd 1000 | cut -d: -f1)"
[ -n "$LIVE_USER" ] || LIVE_USER="user"
cat > /etc/sddm.conf <<CONF
[Autologin]
User=$LIVE_USER
Session=blue-environment.desktop
Relogin=true

[General]
Numlock=none
CONF
exit 0
