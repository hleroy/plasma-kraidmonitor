# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build (out-of-source). Prefix matters: Plasma scans /usr, not /usr/local.
mkdir -p build && cd build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr && make -j$(nproc)
sudo make install

# Clean build + Debian package into dist/
./build-deb.sh

# Run the widget without installing it (from the repo root)
plasmoidviewer -a ./package

# Reload after installing
kquitapp6 plasmashell && kstart plasmashell
```

There is no test suite, linter, or formatter. `plasmoidviewer` is the development
loop: QML errors and `console.log` go to its stdout/stderr.

## Architecture

The widget ships as **two separately installed artifacts** that must both be
present, and this coupling is the main source of confusion:

1. **The plasmoid package** — `package/` → `/usr/share/plasma/plasmoids/org.kde.plasma.kraidmonitor/`
   (installed by `plasma_install_package` in `CMakeLists.txt`). Pure QML + metadata.
2. **The C++ QML extension plugin** — `plugin/` → `${KDE_INSTALL_QMLDIR}/org/kde/plasma/private/kraidmonitor/`,
   as `libkraidmonitorplugin.so` plus `qmldir`.

`package/contents/ui/main.qml` reaches the C++ side by importing the plugin's URI,
`org.kde.plasma.private.kraidmonitor`. That URI is repeated in four places and all
must agree: `plugin/qmldir`, `registerTypes()`'s `Q_ASSERT` and `qmlRegisterType`
(`plugin/kraidmonitor.cpp:113`), the import in `main.qml:6`, and the install
destination in `CMakeLists.txt`.

Consequence for debugging: `plasmoidviewer -a ./package` reads the QML from the
working tree, but resolves the plugin import from the **installed** system path.
Editing QML alone needs no rebuild; touching `plugin/` requires a reinstall (or
pointing `QML2_IMPORT_PATH` at a directory holding the freshly built `.so` and a
copy of `qmldir`) before plasmoidviewer will see the change.

### Where the logic lives

All RAID monitoring is in `plugin/kraidmonitor.cpp`. It reads sysfs directly —
never `mdadm`, so no elevated privileges are needed:

- Array discovery: `md*` entries under `/sys/block/` (`updateAvailableArrays()`).
- Status: every attribute is read through `readAttr()`, which resolves
  `/sys/block/<selectedArray>/md/<attr>` and returns a null string when the read
  fails. `updateArrayStatus()` derives a `state` enum (`NoArray`/`Ok`/`Syncing`/
  `Degraded`/`Error`) plus a `status` display string from `array_state`,
  `sync_action` and `degraded`, and fills `level`, `totalDisks`, `activeDisks`,
  `syncProgress`, `syncSpeed` and `syncEtaSeconds`.

Two ordering rules in `updateArrayStatus()` are deliberate and easy to break:

- `sync_action` is checked **before** `array_state`, so a syncing array reports
  Syncing regardless of its state. The match must include `recover` (rebuilding
  onto a replacement disk) and `reshape`, not just `check`/`repair`/`resync`.
- Degraded is decided by `degraded > 0`, **not** by `array_state == "degraded"`.
  A real array with a failed member reports `array_state = clean`, so keying off
  the state alone reports a dead disk as OK.

Every property emits its change signal only when the value actually changed;
`updateArrayStatus()` runs on a timer, so emitting unconditionally would
re-evaluate every QML binding on every tick.

The QML side is a thin view: `main.qml` binds to `state`/`status`/`level`/the
disk counts/the sync properties and owns nothing else beyond formatting.

Icon names are **freedesktop theme names**, not the SVGs in
`package/contents/icons/`. Those three `raid*.svg` files are installed by
`CMakeLists.txt` but referenced by nothing — leftovers from the Plasma 5 version.
Note that Breeze ships **no** `drive-harddisk-updating`, `-warning` or `-error`;
earlier versions named them anyway and rendered nothing whenever the array was
not healthy. State is now signalled by a `drive-harddisk` base icon with an
emblem (`emblem-ok-symbolic`, `emblem-synchronizing-symbolic`, `emblem-warning`,
`emblem-error`) drawn over its corner in `main.qml`. Verify any icon name against
`/usr/share/icons` before using it.

`main.qml` imports `org.kde.coreaddons` for `Format.formatByteSize` and
`Format.formatSpelloutDuration` (localized sync speed and ETA), which is why
`build-deb.sh` lists `qml6-module-org-kde-coreaddons` in `Depends`.

### Configuration

`package/contents/config/main.xml` declares `updateInterval` and `selectedArray`,
but the two are wired differently, which is easy to misread as a bug in the wrong
place: `updateInterval` round-trips through `configGeneral.qml`'s
`cfg_updateInterval` alias and is pushed to the plugin by `main.qml`'s
`updateConfig()`. `selectedArray` is **never** read back from config — `main.qml`
picks `availableArrays[0]` on every load, and no config UI exposes it.

## Packaging

`package/metadata.json`'s `KPlugin.Version` is the single source of truth for the
version; `build-deb.sh` extracts it with `jq`, along with the package id, author
and homepage, to generate `DEBIAN/control`. Bump it there, then rebuild.

`build-deb.sh` stages files, then normalizes the staging tree to 755/644 before
calling `dpkg-deb`. Do not remove that step or go back to bare `cp` for the plugin
files: `cp` preserves the working tree's modes, and any file or directory that is
not world-readable makes the installed widget fail with "package
org.kde.plasma.kraidmonitor does not exist" (Plasma cannot traverse `contents/`) or
"module org.kde.plasma.private.kraidmonitor is not installed" (unreadable
`qmldir`). Git tracks only the executable bit, so a bad mode can exist in a working
tree without ever showing up in a diff.

## If the `kde-plasmoid-dev` plugin skill is active

That third-party skill describes the common single-package plasmoid, installed to
user scope with `kpackagetool6`. This widget does not fit that shape, and following
the skill's workflow here produces a half-installed widget:

- **User-scope install does not work.** `kpackagetool6 -t Plasma/Applet -i ./package`
  installs only the QML into `~/.local/share/plasma/plasmoids/`. The C++ plugin must
  be in the system QML import path for `main.qml`'s import to resolve, so the widget
  loads but immediately fails with `module ... is not installed`. Use the CMake or
  `.deb` install instead.
- **A `.plasmoid` archive cannot ship this widget.** That format is a zip of
  `package/` alone, with no way to carry `libkraidmonitorplugin.so` — so
  store.kde.org / GHNS distribution is not available without moving the sysfs logic
  out of C++ and into QML. The `.deb` is the distribution channel.
- **The binary here is `plasmoidviewer`, not `plasmoidviewer6`.**
