#!/usr/bin/env bash
#
# Build Spedread for Windows (x86_64) and package it as a self-contained ZIP
#
# Run it from the repository root (or anywhere) inside an MSYS2 UCRT64 shell
# (MINGW64 / CLANG64 also work) with these packages installed:
#
#   pacman -S --needed zip \
#     $MINGW_PACKAGE_PREFIX-{cc,meson,ninja,pkgconf,vala,gtk4,libadwaita,glib2,\
#       gdk-pixbuf2,librsvg,gettext-tools,libxml2,adwaita-icon-theme,\
#       hicolor-icon-theme,python}
#
# Output: dist/Spedread-<version>-windows-x86_64.zip
#
# Optional environment variables:
#   EMBED_ICON=0      do not embed the .ico into the executable; default 1

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
WORK=$ROOT/build-windows
OUT=$ROOT/dist

SRC=$WORK/src
BUILD=$WORK/build
STAGE=$WORK/stage
ICON_DIR=$WORK/icon

# Only a placeholder: the final location is chosen by the user who unzips the
# package, nothing depends on this path at runtime.
INSTALL_PREFIX=${INSTALL_PREFIX:-C:/spedread}
EMBED_ICON=${EMBED_ICON:-1}
# Set to 0 only to dry-run this script on a non-Windows machine
PATCH_LOCALEDIR=${PATCH_LOCALEDIR:-1}

APP_ID=com.github.Darazaki.Spedread
# Regex matching the shared libraries to bundle (overridable for tests)
LIB_REGEX=${LIB_REGEX:-'\.dll$'}

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Windows-style path with forward slashes, for native (non-MSYS) programs
winpath() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

project_version() {
    sed -n "s/^[[:space:]]*version:[[:space:]]*'\([^']*\)'.*/\1/p" \
        "$ROOT/meson.build" | head -n1
}

preflight() {
    case "${MSYSTEM:-}" in
        UCRT64|MINGW64|CLANG64) ;;
        *) die "run this from an MSYS2 UCRT64/MINGW64/CLANG64 shell (MSYSTEM='${MSYSTEM:-}')" ;;
    esac
    : "${MINGW_PREFIX:?MINGW_PREFIX is not set}"

    local tools=(meson ninja valac glib-compile-schemas glib-compile-resources
                 msgfmt xmllint zip ldd python gdk-pixbuf-query-loaders)
    if [[ $EMBED_ICON == 1 ]]; then
        tools+=(rsvg-convert windres)
    fi
    local missing=() t
    for t in "${tools[@]}"; do
        command -v "$t" >/dev/null 2>&1 || missing+=("$t")
    done
    ((${#missing[@]} == 0)) || die "missing tools: ${missing[*]}"

    # libadwaita must ship its Vala bindings for this project to compile
    local vapi found=0
    for vapi in "$MINGW_PREFIX"/share/vala*/vapi/libadwaita-1.vapi; do
        [[ -f $vapi ]] && found=1
    done
    ((found)) || die "libadwaita-1.vapi not found under $MINGW_PREFIX/share/vala*/vapi"

    [[ -d $MINGW_PREFIX/share/icons/Adwaita ]] \
        || die "Adwaita icon theme is missing (install adwaita-icon-theme)"
}

# The original code bakes an absolute LOCALEDIR (the install prefix) into the
# binary, which cannot work in a ZIP that gets unpacked anywhere. Work on a copy
# of the tree and make gettext look in <exe dir>/../share/locale instead
prepare_source() {
    log "Preparing a patched copy of the sources"
    rm -rf "$SRC"
    mkdir -p "$SRC"
    tar -C "$ROOT" --exclude=./.git --exclude=./build-windows --exclude=./dist \
        -cf - . | tar -C "$SRC" -xf -

    [[ $PATCH_LOCALEDIR == 1 ]] || return 0
    local file=$SRC/src/App.vala
    local needle='Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);'
    local repl='Intl.bindtextdomain (GETTEXT_PACKAGE, Win32.locale_filename_from_utf8 (Path.build_filename (Win32.get_package_installation_directory_of_module (null), "share", "locale")));'

    grep -qF -- "$needle" "$file" \
        || die "could not find the bindtextdomain call in src/App.vala (code changed?)"
    local content
    content=$(<"$file")
    printf '%s\n' "${content/"$needle"/"$repl"}" >"$file"
    grep -qF -- 'Win32.locale_filename_from_utf8' "$file" || die "patching App.vala failed"
}

# Build a multi-resolution .ico from the SVG and compile it into a COFF object
# that gets linked into the executable (Explorer / taskbar icon)
make_icon_object() {
    log "Generating the executable icon"
    rm -rf "$ICON_DIR"
    mkdir -p "$ICON_DIR"
    local s
    for s in 16 24 32 48 64 128 256; do
        rsvg-convert -w "$s" -h "$s" -o "$ICON_DIR/icon-$s.png" \
            "$ROOT/data/icons/normal.svg"
    done
    (
        cd "$ICON_DIR"
        python - <<'PY'
import struct

sizes = [16, 24, 32, 48, 64, 128, 256]
images = [open(f"icon-{s}.png", "rb").read() for s in sizes]
header = struct.pack("<HHH", 0, 1, len(images))
offset = 6 + 16 * len(images)
entries = b""
for size, data in zip(sizes, images):
    dim = 0 if size >= 256 else size
    entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
with open("spedread.ico", "wb") as f:
    f.write(header + entries + b"".join(images))
PY
        printf '1 ICON "spedread.ico"\n' >spedread.rc
        windres -O coff -i spedread.rc -o spedread-icon.o
    )
    ICON_OBJ=$(winpath "$ICON_DIR/spedread-icon.o")
}

build_app() {
    log "Configuring and building"
    local ldflags=()
    [[ -n ${ICON_OBJ:-} ]] && ldflags+=("$ICON_OBJ")

    rm -rf "$BUILD" "$STAGE"
    # Arguments are already native paths: stop MSYS2 from rewriting them
    MSYS2_ARG_CONV_EXCL='*' LDFLAGS="${ldflags[*]:-}" \
        meson setup "$(winpath "$BUILD")" "$(winpath "$SRC")" \
        --buildtype=release --prefix="$INSTALL_PREFIX" --wrap-mode=nodownload
    meson compile -C "$(winpath "$BUILD")"

    # DESTDIR also makes the project's post-install script (icon cache, schema
    # compilation against the *system*) skip itself; we do that ourselves below
    MSYS2_ARG_CONV_EXCL='*' \
        meson install -C "$(winpath "$BUILD")" --no-rebuild \
            --destdir "$(winpath "$STAGE")"

    local rel=${INSTALL_PREFIX#[A-Za-z]:}
    rel=${rel#/}
    APP_ROOT=$STAGE/$rel
    # Test the .exe name first and explicitly: under MSYS2, "spedread" also
    # matches "spedread.exe", which native programs (python...) cannot open
    if [[ -f $APP_ROOT/bin/spedread.exe ]]; then
        EXE=$APP_ROOT/bin/spedread.exe
    elif [[ -f $APP_ROOT/bin/spedread ]]; then
        EXE=$APP_ROOT/bin/spedread
    else
        find "$STAGE" | head -50
        die "installed executable not found"
    fi
}

# Direct dependencies of $1 that live inside the MSYS2 environment (system DLLs
# such as KERNEL32.dll are intentionally left out)
list_deps() {
    [[ -e $1 ]] || die "cannot scan dependencies of missing file $1"
    { ldd "$1" | awk '/=>/ {print $3}' \
        | grep -i "^$MINGW_PREFIX/" | grep -iE "$LIB_REGEX"; } || true
}

# collect_dlls DEST EXE...: copy every non-system DLL needed by EXE... (and,
# transitively, by what gets copied) into DEST
collect_dlls() {
    local dest=$1
    shift
    local -a queue=("$@")
    local item dll base
    while ((${#queue[@]} > 0)); do
        item=${queue[0]}
        queue=("${queue[@]:1}")
        while IFS= read -r dll; do
            base=${dll##*/}
            [[ -e $dest/$base ]] && continue
            cp -- "$dll" "$dest/$base"
            queue+=("$dest/$base")
        done < <(list_deps "$item")
    done
}

bundle_runtime() {
    log "Bundling the GTK4 / libadwaita runtime"
    local bin=$APP_ROOT/bin share=$APP_ROOT/share
    mkdir -p "$bin" "$share"

    # DLLs
    collect_dlls "$bin" "$EXE"

    # gdk-pixbuf image loaders (SVG symbolic icons need the librsvg one)
    local pbsrc pbdir=$APP_ROOT/lib/gdk-pixbuf-2.0/2.10.0/loaders
    pbsrc=$(ls -d "$MINGW_PREFIX"/lib/gdk-pixbuf-2.0/2.10.0/loaders 2>/dev/null || true)
    [[ -d $pbsrc ]] || die "gdk-pixbuf loaders not found in $MINGW_PREFIX"
    mkdir -p "$pbdir"
    cp -- "$pbsrc"/*.dll "$pbdir"/ 2>/dev/null || cp -- "$pbsrc"/*.so "$pbdir"/
    local loader
    for loader in "$pbdir"/*; do
        collect_dlls "$bin" "$loader"
    done
    # Regenerate the cache with paths relative to the install root so that it
    # keeps working wherever the ZIP is extracted.
    local -a loaders=()
    for loader in "$pbdir"/*; do loaders+=("$(winpath "$loader")"); done
    gdk-pixbuf-query-loaders "${loaders[@]}" \
        | awk '/^"[^"]*"$/ {
                   p = $0
                   sub(/^".*[\\\/]/, "", p); sub(/"$/, "", p)
                   print "\"lib\\\\gdk-pixbuf-2.0\\\\2.10.0\\\\loaders\\\\" p "\""
                   next
               }
               { print }' \
        >"$APP_ROOT/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"

    # GSettings schemas: ours (already installed) + GTK's, then compile
    local schemas=$share/glib-2.0/schemas
    mkdir -p "$schemas"
    cp -- "$MINGW_PREFIX"/share/glib-2.0/schemas/*.xml "$schemas"/
    cp -- "$MINGW_PREFIX"/share/glib-2.0/schemas/*.override "$schemas"/ 2>/dev/null || true
    glib-compile-schemas "$(winpath "$schemas")"

    # Icons: Adwaita (symbolic icons used by the UI) + hicolor index so the
    # application icon installed by meson can be found
    mkdir -p "$share/icons"
    tar -C "$MINGW_PREFIX/share/icons" --exclude='Adwaita/cursors' -cf - Adwaita \
        | tar -C "$share/icons" -xf -
    mkdir -p "$share/icons/hicolor"
    cp -n -- "$MINGW_PREFIX/share/icons/hicolor/index.theme" "$share/icons/hicolor/" 2>/dev/null || true

    # Translations of the toolkits for the languages the app supports
    local lang domain mo
    while read -r lang; do
        [[ -z $lang || $lang == \#* ]] && continue
        for domain in gtk40 libadwaita glib20 gdk-pixbuf; do
            mo=$MINGW_PREFIX/share/locale/$lang/LC_MESSAGES/$domain.mo
            if [[ -f $mo ]]; then
                mkdir -p "$share/locale/$lang/LC_MESSAGES"
                cp -- "$mo" "$share/locale/$lang/LC_MESSAGES/"
            fi
        done
    done <"$ROOT/po/LINGUAS"

    # Fontconfig configuration and third-party license texts
    if [[ -d $MINGW_PREFIX/etc/fonts ]]; then
        mkdir -p "$APP_ROOT/etc"
        cp -r -- "$MINGW_PREFIX/etc/fonts" "$APP_ROOT/etc/"
    fi
    if [[ -d $MINGW_PREFIX/share/licenses ]]; then
        mkdir -p "$share/licenses"
        cp -r -- "$MINGW_PREFIX"/share/licenses/. "$share/licenses/"
    fi

    cp -- "$ROOT/LICENSE.txt" "$APP_ROOT/LICENSE.txt"
    cat >"$APP_ROOT/README.txt" <<EOF
Spedread $VERSION for Windows (x86_64)

Run Spedread.exe (it starts bin\\spedread.exe).

Everything this program needs (GTK 4, libadwaita, icons, translations) is in
this folder. Keep the folder structure intact; you can move it anywhere.
Settings are stored in the registry under HKEY_CURRENT_USER\\Software\\GSettings.
EOF
}

# Tiny GUI-subsystem launcher placed at the root of the package: it starts
# bin\spedread.exe (forwarding the command-line arguments) so users do not have
# to dig through the folder full of DLLs. A .lnk shortcut cannot be used because
# those store absolute paths
make_launcher() {
    log "Building the launcher"
    local dir=$WORK/launcher
    rm -rf "$dir"
    mkdir -p "$dir"
    cat >"$dir/launcher.c" <<'EOF'
#include <windows.h>
#include <wchar.h>

#define BUF 4096

int WINAPI WinMain(HINSTANCE inst, HINSTANCE prev, LPSTR cmd, int show)
{
    static wchar_t self[BUF], exe[BUF], cmdline[BUF * 2];
    wchar_t *slash;
    const wchar_t *args;
    DWORD n = GetModuleFileNameW(NULL, self, BUF);
    STARTUPINFOW si = { sizeof si };
    PROCESS_INFORMATION pi;

    if (n == 0 || n >= BUF || !(slash = wcsrchr(self, L'\\')))
        return 1;
    *slash = 0;
    if (swprintf(exe, BUF, L"%ls\\bin\\spedread.exe", self) < 0)
        return 1;

    /* Forward our arguments: skip argv[0] in the raw command line */
    args = GetCommandLineW();
    if (*args == L'"') {
        for (args++; *args && *args != L'"'; args++) ;
        if (*args) args++;
    } else {
        while (*args && *args != L' ' && *args != L'\t') args++;
    }
    if (swprintf(cmdline, BUF * 2, L"\"%ls\"%ls", exe, args) < 0)
        return 1;

    if (!CreateProcessW(exe, cmdline, NULL, NULL, FALSE, 0, NULL, NULL, &si, &pi)) {
        MessageBoxW(NULL, L"Could not start bin\\spedread.exe.\n"
                          L"Please keep the folder structure of the ZIP intact.",
                    L"Spedread", MB_OK | MB_ICONERROR);
        return 1;
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
EOF
    local objs=()
    [[ -n ${ICON_OBJ:-} ]] && objs+=("$ICON_OBJ")
    "${LAUNCHER_CC:-gcc}" -O2 -s -mwindows -o "$dir/Spedread.exe" "$dir/launcher.c" "${objs[@]}"
    cp -- "$dir/Spedread.exe" "$APP_ROOT/Spedread.exe"
}

# check_gui_subsystem FILE: verify that a file uses Windows's GUI subsystem
check_gui_subsystem() {
    python - "$1" <<'PY'
import struct, sys
path = sys.argv[1]
d = open(path, "rb").read(4096)
if d[:2] != b"MZ":
    sys.exit(0)  # not a Windows executable (dry run on another OS)
pe = struct.unpack_from("<I", d, 0x3C)[0]
subsystem = struct.unpack_from("<H", d, pe + 24 + 68)[0]
print(path.rsplit("/", 1)[-1], "-> PE subsystem:", {2: "GUI", 3: "console"}.get(subsystem, subsystem))
sys.exit(0 if subsystem == 2 else 1)
PY
}

# Make sure nothing needed lives outside the package
verify_package() {
    local dir=$1 f
    log "Verifying the package"
    for f in \
        "bin/$(basename "$EXE")" \
        share/glib-2.0/schemas/gschemas.compiled \
        "share/icons/hicolor/scalable/apps/$APP_ID.svg" \
        share/icons/Adwaita/index.theme \
        lib/gdk-pixbuf-2.0/2.10.0/loaders.cache \
        Spedread.exe \
        LICENSE.txt; do
        [[ -e $dir/$f ]] || die "package is missing $f"
    done
    ls "$dir"/bin/ | grep -qiE 'libgtk-4|libgtk4' || die "no GTK 4 library bundled"
    ls "$dir"/bin/ | grep -qi 'libadwaita' || die "no libadwaita library bundled"
    ! grep -qE '^"([A-Za-z]:|/)[^"]*"$' "$dir/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" \
        || die "loaders.cache contains absolute paths"

    check_gui_subsystem "$dir/bin/$(basename "$EXE")" || die "wrong executable subsystem"
    check_gui_subsystem "$dir/Spedread.exe" || die "the launcher must be a GUI program"

    # Resolve dependencies with a PATH that does not contain the MSYS2
    # environment: anything reported missing would also be missing for users
    local sysroot=${SYSTEMROOT:-/c/Windows}
    local out
    out=$(PATH="$dir/bin:/usr/bin:$sysroot/system32:$sysroot" ldd "$dir/bin/$(basename "$EXE")" 2>&1 || true)
    if grep -qi 'not found' <<<"$out"; then
        grep -i 'not found' <<<"$out" >&2
        die "the executable has unresolved dependencies"
    fi
}

package() {
    log "Creating the ZIP"
    local name=Spedread-$VERSION-windows-x86_64
    local pkg=$WORK/pkg/$name
    rm -rf "$WORK/pkg"
    mkdir -p "$pkg" "$OUT"
    cp -a -- "$APP_ROOT"/. "$pkg"/
    verify_package "$pkg"
    rm -f "$OUT/$name.zip"
    (cd "$WORK/pkg" && zip -qr -9 "$OUT/$name.zip" "$name")
    python -m zipfile -t "$OUT/$name.zip" >/dev/null
    ZIP_FILE=$OUT/$name.zip
    printf 'Created %s (%s)\n' "$ZIP_FILE" "$(du -h "$ZIP_FILE" | cut -f1)"
}

main() {
    cd "$ROOT"
    preflight
    VERSION=$(project_version)
    [[ -n $VERSION ]] || die "could not read the project version from meson.build"
    ICON_OBJ=
    prepare_source
    if [[ $EMBED_ICON == 1 ]]; then make_icon_object; fi
    build_app
    bundle_runtime
    make_launcher
    package
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
