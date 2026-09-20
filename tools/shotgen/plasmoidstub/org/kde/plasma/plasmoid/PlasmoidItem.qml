import QtQuick

// Minimal stand-in for PlasmoidItem: it accepts the properties main.qml sets
// and renders the full representation at whatever size the renderer asks for,
// which is what lets the screenshots show the widget without Plasma's
// containment, wallpaper and viewer chrome around it.
Item {
    id: root

    property Component fullRepresentation
    property Component compactRepresentation
    property var preferredRepresentation
    property string toolTipMainText
    property string toolTipSubText
    property bool expanded: false

    Loader {
        anchors.fill: parent
        sourceComponent: root.fullRepresentation
    }
}
