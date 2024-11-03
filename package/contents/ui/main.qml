import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents // Change to version 3.0
import org.kde.plasma.private.kraidmonitor as KRaidMonitorPrivate
import org.kde.kirigami 2.0 as Kirigami


PlasmoidItem {
    id: root

    fullRepresentation: ColumnLayout {
        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            source: kraidMonitor.icon
            width: Kirigami.Units.iconSizes.huge
            height: width
        }

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: kraidMonitor.selectedArray + ": " + kraidMonitor.status
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
