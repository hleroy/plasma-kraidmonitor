pragma Singleton
import QtQuick

// Minimal stand-in for the applet context object, so main.qml can be loaded
// outside a running Plasma shell.
QtObject {
    property QtObject configuration: QtObject {
        property int updateInterval: 3
        property string selectedArray: "md127"
    }
    // PlasmaCore.Types.Planar, i.e. the desktop form factor.
    property int formFactor: 0
}
