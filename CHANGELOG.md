# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

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
