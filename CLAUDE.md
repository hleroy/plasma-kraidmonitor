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

# Throwaway RAID1 on loop devices (/dev/md99): menu to fail, re-add, scrub,
# stop… an array and watch the widget's states and notifications
tools/raid-testbed.sh
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

A third, smaller file — `notifications/kraidmonitor.notifyrc` — is needed only for
notifications (see below).

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
  `Degraded`/`Error`) from `array_state`, `sync_action` and `degraded`, and fills
  `rawState`, `level`, `totalDisks`, `activeDisks`, `syncProgress`, `syncSpeed`,
  `syncEtaSeconds` and `members` (one `{ name, state, slot }` map per `dev-*`).

The plugin exposes **no display strings**. It reports the state and the raw
`array_state` behind it; every visible string is built in `main.qml` so it goes
through `i18n()`. Adding a user-visible string in C++ would make it
untranslatable — put it in QML instead.

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

The QML side is a thin view: `main.qml` binds to `state`/`rawState`/`level`/the
disk counts/the sync properties/`members`, and owns nothing else beyond
formatting. `StatusIcon.qml` holds the icon-plus-emblem so the compact and full
representations cannot drift apart.

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
and the two are wired differently. `updateInterval` round-trips through
`configGeneral.qml`'s `cfg_updateInterval` alias and is pushed to the plugin by
`main.qml`'s `updateConfig()`. `selectedArray` cannot use an alias, because
`ComboBox.currentValue` is read-only: the page declares a plain
`property string cfg_selectedArray`, writes it in `onActivated`, and *binds*
`currentIndex` back to `indexOfValue(cfg_selectedArray)`. Do not convert that
binding into a `Component.onCompleted` assignment — Plasma populates the `cfg_`
properties after the page is constructed, so a one-shot lookup can run against an
empty value and silently select the wrong array.

`main.qml`'s `selectConfiguredArray()` falls back to `availableArrays[0]` when the
configured array is absent, but deliberately does **not** write that fallback
back to the config, so a temporarily missing array does not discard the setting.

The config page instantiates its own `KRaidMonitor` purely to enumerate
`availableArrays`; it therefore runs a second poll timer while the dialog is open.

### Notifications

State-change notifications are sent from `main.qml` through `org.kde.notification`
(`qml6-module-org-kde-notifications`), gated by the `notificationsEnabled` config
entry. The events are declared in `notifications/kraidmonitor.notifyrc`, a
**third installed artifact** (`${KDE_INSTALL_KNOTIFYRCDIR}`, staged by hand in
`build-deb.sh`); without it KNotification has no event and nothing pops up. The
QML `componentName` must match that file's basename, and each `eventId` one of its
`[Event/...]` groups.

`checkStateChange()` only announces a change on the same array after a real
reading, so loading the widget or switching arrays stays silent. It runs through
`Qt.callLater`, because the plugin emits `stateChanged` before it refreshes the
disk counts and members the notification text is built from.

### Screenshots

`screenshots/*.png` are generated, not captured — regenerate with
`./tools/shotgen/run.sh` after any change to the widget's appearance. The script
renders `package/contents/ui/main.qml` itself, so the images cannot drift from
the real QML; only the data source is swapped. Two stub QML modules shadow the
real ones via `QML2_IMPORT_PATH`:

- `tools/shotgen/mockimports` replaces the C++ plugin with a `KRaidMonitor`
  whose values come from `states.json`, which is what lets a degraded or syncing
  array be pictured without breaking one.
- `tools/shotgen/plasmoidstub` replaces `PlasmoidItem` and `Plasmoid`, so
  `main.qml` loads outside a running shell.

Keep those two roots separate. Putting the `PlasmoidItem` stub on the import path
used with `plasmoidviewer` breaks the viewer's own containment, which needs the
real `org.kde.plasma.plasmoid`.

The render runs under Xephyr rather than `QT_QPA_PLATFORM=offscreen`: offscreen
loads no KDE platform theme, and Kirigami then ignores `isMask`/`color`, so the
OK and syncing emblems come out grey instead of green and orange. The script also
forces `LC_ALL=C.UTF-8 LANGUAGE=en`, because the plasmoid's own catalog is not
loaded outside a real applet while KCoreAddons' is — without it the rate and
duration come out French inside otherwise English text.

### Translations

Visible strings live in QML and are extracted by `Messages.sh` into
`po/<lang>/plasma_applet_org.kde.plasma.kraidmonitor.po`. The domain name is not
free-form: Plasma resolves an applet's `i18n()` against
`plasma_applet_<KPlugin.Id>`, so the `.po` basename must track the plugin id if
that ever changes. `ki18n_install(po)` compiles the catalogs into `build/locale/`
during a normal `make` and installs them under `share/locale/`.

Re-extract after touching any string:

```bash
xgettext --from-code=UTF-8 -C --kde -ci18n \
    -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 \
    --package-name=plasma-kraidmonitor --msgid-bugs-address=hleroy@hleroy.com \
    $(find package -name '*.qml') \
    -o po/plasma_applet_org.kde.plasma.kraidmonitor.pot
msgmerge -U po/fr/plasma_applet_org.kde.plasma.kraidmonitor.po \
    po/plasma_applet_org.kde.plasma.kraidmonitor.pot
```

Note `ki18n_install` silently does nothing when `po/` is missing, so a broken
catalog path fails by shipping English rather than by failing the build.

## Changelog and release notes

Keep entries to **one line each**: what changed, plus a short clause of why only
when it is not self-evident. No paragraphs, no narrating the investigation, no
restating what the diff already shows. The `[0.3]` section is the reference for
the intended density — if an entry wraps past two lines, it is too long. The same
applies to GitHub release notes.

## Packaging

`package/metadata.json`'s `KPlugin.Version` is the single source of truth for the
version; `build-deb.sh` extracts it with `jq`, along with the package id, author
and homepage, to generate `DEBIAN/control`. Bump it there, then rebuild.

`build-deb.sh` never runs `make install` — it stages the plugin, `qmldir`, the
package directory and `build/locale/` by hand. Anything new that the CMake install
rules place on disk has to be mirrored into that staging block or it silently goes
missing from the `.deb` while working fine from a source install.

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
