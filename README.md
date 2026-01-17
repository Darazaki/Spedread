# Spedread

**GTK speed reading software: Read like a speedrunner!**

This program will show one word at a time rapidly to allow focusing on the general idea rather than single words along with less eye movements.

---

## ✨ Features

- **International** — Multi-language support
- **Intuitive controls** — Play, pause, next word & previous word
- **Adjustable speed** — Control the speed at which words are shown

---

## 📦 Install

### Flatpak

This application is available as a Flatpak on Flathub:

<a href='https://flathub.org/apps/details/com.github.Darazaki.Spedread'>
    <img width='180' alt='Download on Flathub'
    src='https://flathub.org/assets/badges/flathub-badge-en.png'/>
</a>

### Snap

A snap version is available on Canonical's Snap Store:

<a href='https://snapcraft.io/spedread'>
    <img width='180' alt='Get it from the Snap Store'
    src='https://snapcraft.io/static/images/badges/en/snap-store-black.svg'/>
</a>

*This snap was originally created and maintained by @sameersharma2006*

### AUR

Two packages are available on the AUR:

- [spedread](https://aur.archlinux.org/packages/spedread)
- [spedread-git](https://aur.archlinux.org/packages/spedread-git)

*These packages are maintained by both Igor Dyatlov and me so if you have any issues with the packaging please report them directly onto the AUR.*

---

## 🔧 Build from Source

### Native Install

**Requirements:** Valid Vala compiler and the GTK4 and libadwaita development files

```sh
git clone https://github.com/Darazaki/Spedread spedread
cd spedread
meson build --buildtype=release --prefix=/usr
cd build
ninja
sudo ninja install
```

**To uninstall:** Run `sudo ninja uninstall` from the `build/` directory

### Flatpak Install

**Requirements:** `flatpak-builder` & `appstream-compose` commands installed along with version 49 of the `org.gnome.Sdk` Flatpak package

```sh
git clone https://github.com/Darazaki/Spedread spedread
cd spedread
dev-scripts/build.sh --install
```

Spedread will then be installed as a Flatpak application and can be managed as such.

---

**Repository:** [github.com/Darazaki/Spedread](https://github.com/Darazaki/Spedread)
