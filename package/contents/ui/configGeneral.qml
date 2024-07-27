import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.5 as Kirigami
import org.kde.plasma.core 2.0 as PlasmaCore

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
