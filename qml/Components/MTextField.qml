import QtQuick
import QtQuick.Controls

TextField {
    id: control
    padding: 8
    implicitWidth: contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: 35
    verticalAlignment: TextInput.AlignVCenter
    font.pointSize: 10
    selectByMouse: true
    selectionColor: window.lumenAccent
    color: "#fff"
    placeholderTextColor: "#6f6894"
    opacity: control.enabled ? 1.0 : 0.3

    background: Rectangle {
        border.color: control.activeFocus || control.hovered ? Qt.lighter(window.lumenAccent, 1.15) : window.lumenLine
        color: window.lumenAlpha(window.lumenSurfaceLow, 0.8)
        radius: 10
        Behavior on border.color { ColorAnimation { duration: 150 } }

        FocusBorder {
            visible: control.focus ? control.focusReason == Qt.TabFocusReason || control.focusReason == Qt.BacktabFocusReason : false
        }
    }
}
