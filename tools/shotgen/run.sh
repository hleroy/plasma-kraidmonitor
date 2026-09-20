#!/usr/bin/env bash
#
# Regenerate the README screenshots in screenshots/.
#
# The widget is rendered offscreen from package/contents/ui/main.qml itself, so
# the images always match the real QML. Only the data source is swapped: the
# stub modules in mockimports/ shadow the C++ plugin and the Plasma applet API,
# which is what allows a degraded or syncing array to be pictured without
# breaking a real one. States are defined in states.json.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUT_DIR="$REPO_DIR/screenshots"
MOCK_DIR="$SCRIPT_DIR/mockimports/org/kde/plasma/private/kraidmonitor"

WIDTH=280
HEIGHT=250
# Matches Breeze Dark's window background, so the themed text sits on a
# plausible panel colour instead of a transparent void.
BACKGROUND="#31363b"
DISPLAY_NUM=:99

mkdir -p "$OUT_DIR"

# A nested X server: rendering under QT_QPA_PLATFORM=offscreen loads no KDE
# platform theme, and Kirigami then leaves isMask emblems untinted, so the OK
# and syncing emblems come out grey instead of green and orange. Xephyr gives a
# real platform with the desktop's colour scheme, without touching the session's
# screen or capturing anything from it.
if ! command -v Xephyr > /dev/null; then
    echo "Xephyr is required (package xserver-xephyr)." >&2
    exit 1
fi

Xephyr "$DISPLAY_NUM" -screen 600x500 -ac -br -noreset > /dev/null 2>&1 &
XEPHYR_PID=$!
trap 'kill $XEPHYR_PID 2> /dev/null' EXIT
sleep 3

if [ ! -x "$SCRIPT_DIR/render" ] || [ "$SCRIPT_DIR/render.cpp" -nt "$SCRIPT_DIR/render" ]; then
    echo "==> Building the renderer"
    g++ -std=c++17 -fPIC -o "$SCRIPT_DIR/render" "$SCRIPT_DIR/render.cpp" \
        $(pkg-config --cflags --libs Qt6Quick Qt6Gui Qt6Core)
fi

for state in $(python3 -c "import json,sys;print(' '.join(json.load(open(sys.argv[1]))))" "$SCRIPT_DIR/states.json"); do
    echo "==> Rendering $state"

    python3 - "$SCRIPT_DIR" "$state" <<'PYEOF'
import json, pathlib, sys

base = pathlib.Path(sys.argv[1])
state = json.load(open(base / "states.json"))[sys.argv[2]]
mock = base / "mockimports/org/kde/plasma/private/kraidmonitor"
text = (mock / "KRaidMonitor.qml.in").read_text()
for key, value in state.items():
    text = text.replace(f"@{key}@", str(value))
(mock / "KRaidMonitor.qml").write_text(text)
PYEOF

    # Force English: the plasmoid's own catalog is not loaded outside a running
    # applet, while KCoreAddons' is, which would otherwise mix a French rate and
    # duration into otherwise English text.
    env -u WAYLAND_DISPLAY DISPLAY="$DISPLAY_NUM" QT_QPA_PLATFORM=xcb \
    LC_ALL=C.UTF-8 LANGUAGE=en \
    QML2_IMPORT_PATH="$SCRIPT_DIR/mockimports:$SCRIPT_DIR/plasmoidstub" \
        "$SCRIPT_DIR/render" \
            "$REPO_DIR/package/contents/ui/main.qml" \
            "$OUT_DIR/$state.png" \
            "$WIDTH" "$HEIGHT" "$BACKGROUND" 2>/dev/null

    convert "$OUT_DIR/$state.png" \
        -alpha remove -alpha off \
        -bordercolor '#1b1e20' -border 1 \
        "$OUT_DIR/$state.png"

    echo "    $OUT_DIR/$state.png"
done

rm -f "$MOCK_DIR/KRaidMonitor.qml"
echo "==> Done"
