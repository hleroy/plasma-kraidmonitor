#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running in a terminal for colored output
if [ ! -t 1 ]; then
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Helper functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_step() {
    echo ""
    echo -e "${GREEN}==>${NC} $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "Required command '$1' not found. Please install it first."
        exit 1
    fi
}

# Show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Build a Debian package for plasma-kraidmonitor.

OPTIONS:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output

DESCRIPTION:
    This script performs a clean build of the plasma-kraidmonitor Plasma 6
    widget and creates a Debian (.deb) package ready for distribution.

    The package version is automatically extracted from package/metadata.json.

OUTPUT:
    The resulting .deb file will be placed in the dist/ directory:
    dist/plasma-kraidmonitor_<version>_<arch>.deb

REQUIREMENTS:
    - cmake (>= 3.16)
    - make
    - dpkg-deb
    - dpkg-architecture
    - jq (for JSON parsing)
    - Build dependencies (qt6-base-dev, libplasma-dev, etc.)

EXAMPLES:
    ./build-deb.sh              # Build the package
    ./build-deb.sh --verbose    # Build with verbose output

EOF
}

# Parse command line arguments
VERBOSE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Enable verbose mode
if [ "$VERBOSE" = true ]; then
    set -x
fi

print_step "Checking prerequisites"

# Check required commands
check_command cmake
check_command make
check_command dpkg-deb
check_command dpkg-architecture
check_command jq

# Check if metadata.json exists
if [ ! -f "package/metadata.json" ]; then
    print_error "package/metadata.json not found!"
    exit 1
fi

print_step "Extracting package metadata"

# Extract version from metadata.json
VERSION=$(jq -r '.KPlugin.Version' package/metadata.json)
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
    print_error "Could not extract version from package/metadata.json"
    exit 1
fi
print_info "Version: $VERSION"

# Extract other metadata
PACKAGE_NAME=$(jq -r '.KPlugin.Id' package/metadata.json | sed 's/org\.kde\.plasma\.//')
DESCRIPTION=$(jq -r '.KPlugin.Description' package/metadata.json)
AUTHOR_NAME=$(jq -r '.KPlugin.Authors[0].Name' package/metadata.json)
AUTHOR_EMAIL=$(jq -r '.KPlugin.Authors[0].Email' package/metadata.json)
HOMEPAGE=$(jq -r '.KPlugin.Website' package/metadata.json)

print_info "Package: $PACKAGE_NAME"
print_info "Author: $AUTHOR_NAME <$AUTHOR_EMAIL>"

# Detect architecture
ARCH=$(dpkg --print-architecture)
print_info "Architecture: $ARCH"

# Detect multiarch path
MULTIARCH=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
print_info "Multiarch: $MULTIARCH"

print_step "Cleaning old build artifacts"

# Remove old build directory
if [ -d "build" ]; then
    rm -rf build
    print_info "Removed old build/ directory"
fi

# Create build directory
mkdir -p build
cd build

print_step "Configuring with CMake"

cmake .. \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=Release \
    -DQT_MAJOR_VERSION=6

print_step "Building project"

make -j$(nproc)

print_info "Build completed successfully"

cd "$SCRIPT_DIR"

print_step "Creating Debian package staging area"

# Define staging directory
STAGING_DIR="build/debian-package"
DEBIAN_DIR="$STAGING_DIR/DEBIAN"
USR_DIR="$STAGING_DIR/usr"

# Create directory structure
mkdir -p "$DEBIAN_DIR"
mkdir -p "$USR_DIR/lib/$MULTIARCH/qt6/qml/org/kde/plasma/private/kraidmonitor"
mkdir -p "$USR_DIR/share/plasma/plasmoids/org.kde.plasma.$PACKAGE_NAME"

print_info "Staging directory: $STAGING_DIR"

print_step "Installing files to staging area"

# Find and copy the compiled plugin library
PLUGIN_LIB="build/libkraidmonitorplugin.so"
if [ ! -f "$PLUGIN_LIB" ]; then
    print_error "Plugin library not found at $PLUGIN_LIB"
    print_error "Build may have failed or produced unexpected output"
    exit 1
fi

install -m 755 "$PLUGIN_LIB" "$USR_DIR/lib/$MULTIARCH/qt6/qml/org/kde/plasma/private/kraidmonitor/"
print_info "Copied plugin library"

# Copy qmldir
if [ ! -f "plugin/qmldir" ]; then
    print_error "plugin/qmldir not found"
    exit 1
fi

install -m 644 "plugin/qmldir" "$USR_DIR/lib/$MULTIARCH/qt6/qml/org/kde/plasma/private/kraidmonitor/"
print_info "Copied qmldir"

# Copy plasmoid package
if [ ! -d "package/contents" ]; then
    print_error "package/contents directory not found"
    exit 1
fi

cp -r package/* "$USR_DIR/share/plasma/plasmoids/org.kde.plasma.$PACKAGE_NAME/"
print_info "Copied plasmoid package"

# Copy the compiled translation catalogs. Staging here is manual rather than a
# `make install`, so anything the CMake install rules add must be mirrored or it
# silently goes missing from the .deb.
LOCALE_DIR="build/locale"
if [ -d "$LOCALE_DIR" ]; then
    mkdir -p "$USR_DIR/share/locale"
    cp -r "$LOCALE_DIR"/* "$USR_DIR/share/locale/"
    print_info "Copied $(find "$LOCALE_DIR" -name '*.mo' | wc -l) translation catalog(s)"
else
    print_warning "No compiled translations found in $LOCALE_DIR"
fi

# Normalize permissions: cp preserves the working tree's modes, and anything not
# world-readable makes Plasma report the package as non-existent once installed.
find "$USR_DIR" -type d -exec chmod 755 {} +
find "$USR_DIR" -type f ! -name '*.so' -exec chmod 644 {} +
find "$USR_DIR" -type f -name '*.so' -exec chmod 755 {} +
print_info "Normalized file permissions"

print_step "Generating DEBIAN/control file"

# Calculate installed size (in KB)
INSTALLED_SIZE=$(du -sk "$USR_DIR" | cut -f1)

# Create control file
cat > "$DEBIAN_DIR/control" << EOF
Package: plasma-$PACKAGE_NAME
Version: $VERSION
Section: kde
Priority: optional
Architecture: $ARCH
Maintainer: $AUTHOR_NAME <$AUTHOR_EMAIL>
Installed-Size: $INSTALLED_SIZE
Depends: plasma-workspace, qml6-module-qtquick, qml6-module-org-kde-coreaddons
Description: $DESCRIPTION
 KRaidMonitor is a KDE Plasma widget that monitors the status of RAID
 arrays on your system. It provides a quick and easy way to check the
 health of your RAID setup directly from your desktop.
 .
 Features:
  - Automatically detects RAID arrays on your system
  - Displays the current status of the selected RAID array
  - Shows different icons based on the RAID array's state
  - Configurable update interval
Homepage: $HOMEPAGE
EOF

print_info "Control file created"

print_step "Building .deb package"

# Build the package
dpkg-deb --build --root-owner-group "$STAGING_DIR"

print_info "Package built successfully"

print_step "Moving package to dist/"

# Create dist directory
mkdir -p dist

# Define final package name
PACKAGE_FILE="plasma-${PACKAGE_NAME}_${VERSION}_${ARCH}.deb"

# Move package to dist
mv "${STAGING_DIR}.deb" "dist/$PACKAGE_FILE"

print_step "Build complete!"

echo ""
print_info "Package created: ${GREEN}dist/$PACKAGE_FILE${NC}"
echo ""
print_info "To install the package, run:"
echo "    sudo dpkg -i dist/$PACKAGE_FILE"
echo "    sudo apt-get install -f  # Install any missing dependencies"
echo ""
print_info "Then restart Plasma Shell:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
echo ""
