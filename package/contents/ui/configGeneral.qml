import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kraidmonitor as KRaidMonitorPrivate

Item {
    id: generalPage

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    property string cfg_selectedArray
    property alias cfg_updateInterval: updateIntervalSpinBox.value
    property alias cfg_notificationsEnabled: notificationsCheckBox.checked

    // Its own instance, purely to enumerate the arrays for the combo box.
    KRaidMonitorPrivate.KRaidMonitor {
        id: raidMonitor
    }

    Kirigami.FormLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.ComboBox {
            id: arrayComboBox

            Kirigami.FormData.label: i18n("Array:")
            model: raidMonitor.availableArrays
            textRole: "text"
            valueRole: "value"
            enabled: raidMonitor.availableArrays.length > 0

            onActivated: generalPage.cfg_selectedArray = currentValue

            // Bound rather than set once on completion: Plasma assigns the
            // cfg_ properties after the page is built, so a one-shot lookup can
            // run against an empty value and silently show the wrong array. A
            // configured array that is no longer present leaves indexOfValue at
            // -1; show the first one rather than an empty box.
            currentIndex: {
                var index = indexOfValue(generalPage.cfg_selectedArray)
                return index >= 0 ? index : 0
            }
        }

        QQC2.Label {
            visible: raidMonitor.availableArrays.length === 0
            text: i18n("No RAID array found on this system.")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Update interval:")

            QQC2.SpinBox {
                id: updateIntervalSpinBox
                from: 1
                to: 3600
                stepSize: 1
            }

            QQC2.Label {
                text: i18np("second", "seconds", updateIntervalSpinBox.value)
            }
        }

        QQC2.CheckBox {
            id: notificationsCheckBox
            Kirigami.FormData.label: i18n("Notifications:")
            text: i18n("Notify when the array state changes")
        }
    }
}
