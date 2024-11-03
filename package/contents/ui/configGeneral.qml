import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

Item {
    id: generalPage

    implicitWidth: mainLayout.implicitWidth
    implicitHeight: mainLayout.implicitHeight

    property alias cfg_updateInterval: updateIntervalSpinBox.value

    Kirigami.FormLayout {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right

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
    }
}
