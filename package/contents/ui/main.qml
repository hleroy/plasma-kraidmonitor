import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.private.kraidmonitor as KRaidMonitorPrivate
import org.kde.kirigami as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.notification


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

    readonly property string statusText: {
        switch (root.arrayState) {
        case KRaidMonitorPrivate.KRaidMonitor.Ok:
            return i18nc("@info RAID array status", "OK")
        case KRaidMonitorPrivate.KRaidMonitor.Syncing:
            return i18nc("@info RAID array status", "Syncing")
        case KRaidMonitorPrivate.KRaidMonitor.Degraded:
            return i18nc("@info RAID array status", "Degraded")
        case KRaidMonitorPrivate.KRaidMonitor.NoArray:
            return i18nc("@info RAID array status", "No array selected")
        default:
            return kraidMonitor.rawState === ""
                ? i18nc("@info RAID array status", "Cannot read array state")
                : i18nc("@info RAID array status, %1 is the raw md array_state value",
                        "Error: %1", kraidMonitor.rawState)
        }
    }

    readonly property string detailText: {
        var parts = []
        if (kraidMonitor.level !== "") {
            parts.push(kraidMonitor.level)
        }
        if (kraidMonitor.totalDisks > 0) {
            parts.push(i18nc("@info number of working disks out of the array's total",
                             "%1/%2", kraidMonitor.activeDisks, kraidMonitor.totalDisks))
        }
        parts.push(root.statusText)
        return parts.join(" · ")
    }

    readonly property string syncDetailText: {
        var parts = []
        if (kraidMonitor.syncSpeed > 0) {
            parts.push(i18nc("@info sync transfer rate, %1 is a formatted size such as 84 MiB",
                             "%1/s", KCoreAddons.Format.formatByteSize(kraidMonitor.syncSpeed * 1024)))
        }
        if (kraidMonitor.syncEtaSeconds >= 0) {
            // formatSpelloutDuration spells out every unit ("12 minutes and 18
            // seconds"), which elides away at the widget's default width.
            parts.push(i18nc("@info estimated time until the sync completes",
                             "~%1 left",
                             KCoreAddons.Format.formatDecimalDuration(kraidMonitor.syncEtaSeconds * 1000, 0)))
        }
        return parts.join(" · ")
    }

    // md reports a member's state as a comma-separated list of flags.
    function memberStateText(rawMemberState) {
        var labels = {
            "in_sync": i18nc("@info state of a disk in the array", "in sync"),
            "faulty": i18nc("@info state of a disk in the array", "faulty"),
            "spare": i18nc("@info state of a disk in the array", "spare"),
            "write_mostly": i18nc("@info state of a disk in the array", "write-mostly"),
            "blocked": i18nc("@info state of a disk in the array", "blocked"),
            "want_replacement": i18nc("@info state of a disk in the array", "replacement wanted"),
            "replacement": i18nc("@info state of a disk in the array", "replacement"),
            "remove": i18nc("@info state of a disk in the array", "removed"),
        }
        var flags = rawMemberState.split(",")
        var out = []
        for (var i = 0; i < flags.length; i++) {
            var flag = flags[i].trim()
            if (flag !== "") {
                out.push(labels[flag] !== undefined ? labels[flag] : flag)
            }
        }
        return out.join(", ")
    }

    toolTipMainText: kraidMonitor.selectedArray !== ""
                     ? kraidMonitor.selectedArray
                     : i18nc("@title widget name used when no array is being watched", "RAID Monitor")

    toolTipSubText: {
        var lines = [root.detailText]
        if (root.arrayState === KRaidMonitorPrivate.KRaidMonitor.Syncing
            && kraidMonitor.syncProgress >= 0) {
            var progress = i18nc("@info sync progress", "%1%", Math.round(kraidMonitor.syncProgress * 100))
            lines.push(root.syncDetailText !== "" ? progress + " · " + root.syncDetailText : progress)
        }
        var members = kraidMonitor.members
        for (var i = 0; i < members.length; i++) {
            lines.push(i18nc("@info a member disk and its state, e.g. \"sdb: in sync\"",
                             "%1: %2", members[i].name, root.memberStateText(members[i].state)))
        }
        return lines.join("\n")
    }

    compactRepresentation: MouseArea {
        Layout.minimumWidth: Kirigami.Units.iconSizes.small
        Layout.minimumHeight: Kirigami.Units.iconSizes.small

        onClicked: root.expanded = !root.expanded

        StatusIcon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            emblem: root.stateEmblem
            emblemIsMask: root.stateEmblemIsMask
            emblemColor: root.stateColor
        }
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

                StatusIcon {
                    anchors.centerIn: parent
                    width: Math.max(Kirigami.Units.iconSizes.smallMedium,
                                    Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.enormous))
                    height: width
                    emblem: root.stateEmblem
                    emblemIsMask: root.stateEmblemIsMask
                    emblemColor: root.stateColor
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
                        text: i18nc("@info sync progress", "%1%", Math.round(kraidMonitor.syncProgress * 100))
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

    preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar
                             ? fullRepresentation
                             : compactRepresentation

    KRaidMonitorPrivate.KRaidMonitor {
        id: kraidMonitor
    }

    // The last state a notification decision was made on. A change is only
    // announced when it happens on the same array and follows a real reading,
    // so loading the widget or switching arrays stays silent.
    property string notifiedArray: ""
    property int notifiedState: KRaidMonitorPrivate.KRaidMonitor.NoArray

    // Deferred with Qt.callLater: the plugin emits stateChanged before it
    // refreshes the disk counts and members, which the text is built from.
    onArrayStateChanged: Qt.callLater(root.checkStateChange)

    Connections {
        target: kraidMonitor
        function onSelectedArrayChanged() {
            Qt.callLater(root.checkStateChange)
        }
    }

    function checkStateChange() {
        var previous = root.notifiedState
        var sameArray = kraidMonitor.selectedArray === root.notifiedArray
        root.notifiedArray = kraidMonitor.selectedArray
        root.notifiedState = root.arrayState

        if (!sameArray || previous === root.arrayState
            || previous === KRaidMonitorPrivate.KRaidMonitor.NoArray
            || root.arrayState === KRaidMonitorPrivate.KRaidMonitor.NoArray) {
            return
        }
        if (Plasmoid.configuration.notificationsEnabled) {
            root.sendStateNotification(previous)
        }
    }

    // Event ids must match the [Event/...] groups in kraidmonitor.notifyrc.
    function sendStateNotification(previous) {
        var eventId
        var iconName
        var summary
        switch (root.arrayState) {
        case KRaidMonitorPrivate.KRaidMonitor.Ok:
            eventId = "ok"
            iconName = "drive-harddisk"
            summary = previous === KRaidMonitorPrivate.KRaidMonitor.Syncing
                ? i18nc("@info notification", "Sync finished.")
                : i18nc("@info notification", "The array is healthy again.")
            break
        case KRaidMonitorPrivate.KRaidMonitor.Syncing:
            eventId = "syncing"
            iconName = "drive-harddisk"
            summary = i18nc("@info notification", "Sync started.")
            break
        case KRaidMonitorPrivate.KRaidMonitor.Degraded:
            eventId = "degraded"
            iconName = "dialog-warning"
            summary = i18nc("@info notification", "The array is degraded.")
            break
        default:
            eventId = "error"
            iconName = "dialog-error"
            summary = i18nc("@info notification", "The array is in an error state.")
            break
        }

        var lines = [summary, root.detailText]
        if (root.arrayState === KRaidMonitorPrivate.KRaidMonitor.Degraded) {
            var members = kraidMonitor.members
            for (var i = 0; i < members.length; i++) {
                if (members[i].state !== "in_sync") {
                    lines.push(i18nc("@info a member disk and its state, e.g. \"sdb: in sync\"",
                                     "%1: %2", members[i].name, root.memberStateText(members[i].state)))
                }
            }
        }

        var notification = notificationComponent.createObject(root, {
            eventId: eventId,
            iconName: iconName,
            title: i18nc("@title notification, %1 is the array name such as md0",
                         "RAID array %1", kraidMonitor.selectedArray),
            text: lines.join("\n"),
        })
        notification.sendEvent()
    }

    Component {
        id: notificationComponent
        // componentName must match the kraidmonitor.notifyrc basename.
        Notification {
            componentName: "kraidmonitor"
        }
    }

    function updateConfig() {
        kraidMonitor.updateInterval = Plasmoid.configuration.updateInterval
    }

    // Honour the configured array when it is still present. A missing one falls
    // back to the first array without overwriting the setting, so unplugging a
    // disk does not silently discard the choice.
    function selectConfiguredArray() {
        kraidMonitor.updateAvailableArrays()
        var arrays = kraidMonitor.availableArrays
        if (arrays.length === 0) {
            return
        }
        var wanted = Plasmoid.configuration.selectedArray
        for (var i = 0; i < arrays.length; i++) {
            if (arrays[i].value === wanted) {
                kraidMonitor.selectedArray = wanted
                return
            }
        }
        kraidMonitor.selectedArray = arrays[0].value
    }

    Component.onCompleted: {
        selectConfiguredArray()
        updateConfig()
    }

    Connections {
        target: Plasmoid.configuration
        function onUpdateIntervalChanged() {
            updateConfig()
        }
        function onSelectedArrayChanged() {
            selectConfiguredArray()
        }
    }
}
