# Packaging Guide

Instructions for building the plasma-kraidmonitor Debian package.

## Build Package

```bash
./build-deb.sh
```

Output: `dist/plasma-kraidmonitor_<version>_<arch>.deb`

## Build Dependencies

```bash
sudo apt install \
    cmake \
    extra-cmake-modules \
    plasma-sdk \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-tools-dev \
    libplasma-dev \
    libkf6i18n-dev \
    libkf6service-dev \
    libkf6package-dev \
    plasma-workspace-dev \
    qt6-base-private-dev \
    qt6-declarative-private-dev \
    dpkg-dev \
    jq
```

## Version Management

Version is extracted from `package/metadata.json`. To release a new version, update the version there and run `./build-deb.sh`.
