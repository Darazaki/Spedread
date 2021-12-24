#!/bin/sh

echo '######## Lax validation:'
flatpak run org.freedesktop.appstream-glib validate data/com.github.Darazaki.Spedread.appdata.xml.in

echo
echo '######## Strict validation:'
flatpak run org.freedesktop.appstream-glib validate-strict data/com.github.Darazaki.Spedread.appdata.xml.in
