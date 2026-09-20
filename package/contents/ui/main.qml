import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.kraidmonitor as KRaidMonitorPrivate
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons


PlasmoidItem {
    id: root

    readonly property int arrayState: kraidMonitor.state

    readonly property color stateColor: {
        switch (root.arrayState) {
        case KRaidMonitorPrivate.KRaidMonitor.Ok:
            return Kirigami.Theme.positiveTextColor
        case KRaidMonitorPrivate.KRaidMonitor.Syncing:
            return Kirigami.Theme.neutralTextColor
        case KRaidMonitorPrivate.KRaidMonitor.NoArray:
            return Kirigami.Theme.textColor
        default:
            return Kirigami.Theme.negativeTextColor
        }
    }

    // Breeze has no drive-harddisk-{updating,warning,error}, so the state is
    // signalled with an emblem drawn over the plain drive icon instead.
    readonly property string stateEmblem: {
        switch (root.arrayState) {
        case KRaidMonitorPrivate.KRaidMonitor.Ok:
            return "emblem-ok-symbolic"
        case KRaidMonitorPrivate.KRaidMonitor.Syncing:
            return "emblem-synchronizing-symbolic"
        case KRaidMonitorPrivate.KRaidMonitor.Degraded:
            return "emblem-warning"
        case KRaidMonitorPrivate.KRaidMonitor.Error:
            return "emblem-error"
        default:
            return ""
        }
    }

    // The two symbolic emblems are monochrome and get tinted; the warning and
    // error ones carry their own colours.
    readonly property bool stateEmblemIsMask: root.arrayState === KRaidMonitorPrivate.KRaidMonitor.Ok
                                           || root.arrayState === KRaidMonitorPrivate.KRaidMonitor.Syncing

    readonly property string detailText: {
        var parts = []
        if (kraidMonitor.level !== "") {
            parts.push(kraidMonitor.level)
        }
        if (kraidMonitor.totalDisks > 0) {
            parts.push(kraidMonitor.activeDisks + "/" + kraidMonitor.totalDisks)
        }
        parts.push(kraidMonitor.status)
        return parts.join(" · ")
    }

    readonly property string syncDetailText: {
        var parts = []
        if (kraidMonitor.syncSpeed > 0) {
            parts.push(KCoreAddons.Format.formatByteSize(kraidMonitor.syncSpeed * 1024) + "/s")
        }
        if (kraidMonitor.syncEtaSeconds >= 0) {
            parts.push("~" + KCoreAddons.Format.formatSpelloutDuration(kraidMonitor.syncEtaSeconds * 1000))
        }
        return parts.join(" · ")
    }

    fullRepresentation: Item {
        id: container

        Layout.minimumWidth: Kirigami.Units.gridUnit * 6
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        implicitWidth: layout.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // The icon lives in a filler item rather than directly in the
            // layout, so it can be sized to the space actually left over.
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.iconSizes.medium

                Kirigami.Icon {
                    id: driveIcon

                    anchors.centerIn: parent
                    width: Math.max(Kirigami.Units.iconSizes.smallMedium,
                                    Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.enormous))
                    height: width
                    source: "drive-harddisk"
                    fallback: "drive-harddisk"

                    Kirigami.Icon {
                        width: Math.round(parent.width * 0.45)
                        height: width
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        visible: root.stateEmblem !== ""
                        source: root.stateEmblem
                        isMask: root.stateEmblemIsMask
                        color: root.stateColor
                    }
                }
            }

            Kirigami.Heading {
                Layout.fillWidth: true
                level: 3
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: kraidMonitor.selectedArray
                visible: text !== ""
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                color: root.stateColor
                text: root.detailText
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                visible: root.arrayState === KRaidMonitorPrivate.KRaidMonitor.Syncing
                         && kraidMonitor.syncProgress >= 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 1
                        value: kraidMonitor.syncProgress
                    }

                    PlasmaComponents.Label {
                        text: Math.round(kraidMonitor.syncProgress * 100) + " %"
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    font: Kirigami.Theme.smallFont
                    opacity: 0.8
                    text: root.syncDetailText
                    visible: text !== ""
                }
            }
        }
    }

    preferredRepresentation: fullRepresentation

    KRaidMonitorPrivate.KRaidMonitor {
        id: kraidMonitor
    }

    function updateConfig() {
        kraidMonitor.updateInterval = Plasmoid.configuration.updateInterval
    }

    Component.onCompleted: {
        kraidMonitor.updateAvailableArrays()
        if (kraidMonitor.availableArrays.length > 0) {
            kraidMonitor.selectedArray = kraidMonitor.availableArrays[0].value
        }
        updateConfig()
    }

    Connections {
        target: Plasmoid.configuration
        function onUpdateIntervalChanged() {
            updateConfig()
        }
    }
}
