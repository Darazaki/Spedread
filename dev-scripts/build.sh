#!/bin/sh
set -e
mkdir -p build/fltpk
flatpak-builder build/fltpk/ com.github.Darazaki.Spedread.json --user --force-clean --keep-build-dirs "$@"
