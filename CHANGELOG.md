# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Show the array's RAID level and its active/total disk count next to the status,
  so the desktop face reads `md127` / `RAID1 · 2/2 · OK` instead of `md127: OK`.
- Show a progress bar, transfer rate and ETA while an array is syncing, read from
  `sync_completed` and `sync_speed`. Rate and ETA are formatted with
  `KCoreAddons.Format`, so they follow the desktop locale; this adds a dependency
  on `qml6-module-org-kde-coreaddons`.
- Colour the status line from the array state, using the theme's positive,
  neutral and negative text colours rather than fixed values.

### Changed

- Replaced the plugin's `icon` property with a `state` enum
  (`NoArray`/`Ok`/`Syncing`/`Degraded`/`Error`). The QML picks the icon, emblem
  and colour from the enum, so the view no longer keys off English status text.
- The plugin now emits a property's change signal only when the value actually
  changed, instead of signalling on every timer tick.
- Document both plasmoidviewer invocations in the README: a source-tree path to
  test uncommitted changes, and the plugin id to test the installed copy.

### Fixed

- Show a usable icon when the array is not healthy. The widget asked for
  `drive-harddisk-updating`, `-warning` and `-error`, none of which exist in
  Breeze, so it rendered correctly only while the array was OK and showed nothing
  at all once it degraded. A `drive-harddisk` base icon now carries an
  `emblem-ok-symbolic`, `emblem-synchronizing-symbolic`, `emblem-warning` or
  `emblem-error` overlay.
- Report a rebuilding array as Syncing. `sync_action` was matched against
  `check`, `repair` and `resync` only, so `recover` — the value md uses while
  rebuilding onto a replacement disk — fell through to the error branch.
- Report an array with a failed member as Degraded. The check required
  `array_state` to read `degraded`, but a real array with a dead disk reports
  `clean` and records the failure in `degraded`, so a lost disk displayed as OK.
- Apply the configured icon size. The icon set `width`/`height` while being a
  child of a `ColumnLayout`, which owns that geometry, so the size was silently
  discarded; the icon now scales with the widget.
- Install the packaged files world-readable. `build-deb.sh` copied the plugin and
  the plasmoid package with `cp`, which preserves the working tree's modes, so a
  non-readable source tree produced a `.deb` whose `contents/` directory and
  `qmldir` were unreadable by the running user. Plasma then reported the widget as
  non-existent ("le paquet org.kde.plasma.kraidmonitor n'existe pas") and QML
  reported `module "org.kde.plasma.private.kraidmonitor" is not installed`. The
  plugin library and `qmldir` are now placed with explicit modes via `install`, and
  the whole staging tree is normalized to 755/644 before packaging.

## [0.2] - 2026-01-24

### Added

- `build-deb.sh`, a clean-build script producing a Debian package in `dist/`, with
  version and metadata read from `package/metadata.json`.

### Changed

- Ported the widget to Plasma 6, Qt 6 and KF6.
- Replaced `package/metadata.desktop` with `package/metadata.json`.

### Fixed

- Constrained the status label's width so it no longer resizes the widget to fit
  long array names; the text elides instead.

## [0.1] - 2024-07-27

Initial release, for Plasma 5.

### Added

- RAID array monitoring via `/sys/block/*/md/array_state`, with automatic
  detection of the available arrays.
- Status icon reflecting the array state, and a configurable update interval.

[Unreleased]: https://github.com/hleroy/plasma-kraidmonitor/compare/v0.2...HEAD
[0.2]: https://github.com/hleroy/plasma-kraidmonitor/compare/216580b...v0.2
[0.1]: https://github.com/hleroy/plasma-kraidmonitor/commit/216580b
