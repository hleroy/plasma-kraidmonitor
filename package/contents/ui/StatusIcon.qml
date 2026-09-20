import QtQuick
import org.kde.kirigami as Kirigami

// The drive icon with a state emblem over its corner. Breeze ships no
// drive-harddisk-{updating,warning,error}, so the state cannot be carried by
// the base icon name and is overlaid instead. Shared by both representations.
Kirigami.Icon {
    id: statusIcon

    property string emblem: ""
    property bool emblemIsMask: false
    property color emblemColor: Kirigami.Theme.textColor

    source: "drive-harddisk"
    fallback: "drive-harddisk"

    Kirigami.Icon {
        width: Math.round(parent.width * 0.38)
        height: width
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: statusIcon.emblem !== ""
        source: statusIcon.emblem
        isMask: statusIcon.emblemIsMask
        color: statusIcon.emblemColor
    }
}
