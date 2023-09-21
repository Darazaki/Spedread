# <img height="32" src="./data/icons/normal.svg" /> Spedread

GTK speed reading software: Read like a speedrunner!

This program will show one word at a time rapidly to allow focusing on the general idea rather than single words
along with less eye movements

## Features

![screenshot](./demo.gif)

- International
- Play, pause, next word & previous word
- Control the speed at which words are shown

## Install

### Flatpak

This application is available as a Flatpak on Flathub:

<a href='https://flathub.org/apps/details/com.github.Darazaki.Spedread'>
    <img width='180' alt='Download on Flathub'
    src='https://flathub.org/assets/badges/flathub-badge-en.png'/>
</a>

### Snap (maintained by [CapeCrusader321](https://github.com/CapeCrusader321))

A snap version is available on Canonical's Snap Store:

<a href='https://snapcraft.io/spedread'>
    <img width='180' alt='Get it from the Snap Store'
    src='https://snapcraft.io/static/images/badges/en/snap-store-black.svg'/>
</a>

### AUR

Two packages are available on the AUR:
[spedread](https://aur.archlinux.org/packages/spedread)
and [spedread-git](https://aur.archlinux.org/packages/spedread-git)

These packages are maintained by both Igor Dyatlov and me so if you have any
issues with the packaging please report them directly onto the AUR

### Build from source (native install)

This will require a valid Vala compiler and the GTK4 and libadwaita development files:

```sh
git clone https://github.com/Darazaki/Spedread spedread
cd spedread
meson build --buildtype=release --prefix=/usr
cd build
ninja
sudo ninja install
```

You can also run `sudo ninja uninstall` from the `build/` directory to
uninstall Spedread after having installed it

### Build from source (Flatpak install)

This will require having the `flatpak-builder` command installed along with
version 45 of the `org.gnome.Sdk` Flatpak package:

```sh
git clone https://github.com/Darazaki/Spedread spedread
cd spedread
dev-scripts/build.sh --install
```

Spedread will then be installed as a Flatpak application and can be managed as
such
