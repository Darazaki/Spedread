#!/bin/sh
set -e
mkdir -p build/fltpk
flatpak-builder build/fltpk/ com.github.Darazaki.Spedread.json --user --force-clean --arch=x86_64 --keep-build-dirs "$@"
