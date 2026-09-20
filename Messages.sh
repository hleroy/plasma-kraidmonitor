#! /usr/bin/env bash
# Extract translatable strings for the plasmoid's own catalog. The domain must
# match the one Plasma sets up for this applet: plasma_applet_<plugin id>.
$XGETTEXT $(find package -name '*.qml') \
    -o $podir/plasma_applet_org.kde.plasma.kraidmonitor.pot
