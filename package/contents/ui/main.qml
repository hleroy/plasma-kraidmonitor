import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.private.kraidmonitor 1.0 as KRaidMonitorPrivate

Item {
    id: root

    Plasmoid.fullRepresentation: ColumnLayout {
        PlasmaCore.IconItem {
            Layout.alignment: Qt.AlignHCenter
            source: kraidMonitor.icon
            width: PlasmaCore.Units.iconSizes.huge
            height: width
        }

        PlasmaComponents3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: kraidMonitor.selectedArray + ": " + kraidMonitor.status
        }
    }

    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    KRaidMonitorPrivate.KRaidMonitor {
        id: kraidMonitor
    }

    function updateConfig() {
        kraidMonitor.updateInterval = plasmoid.configuration.updateInterval
    }

    Component.onCompleted: {
        kraidMonitor.updateAvailableArrays()
        if (kraidMonitor.availableArrays.length > 0) {
            kraidMonitor.selectedArray = kraidMonitor.availableArrays[0].value
        }
        updateConfig()
    }

    Connections {
        target: plasmoid.configuration
        function onUpdateIntervalChanged() {
            updateConfig()
        }
    }
}
