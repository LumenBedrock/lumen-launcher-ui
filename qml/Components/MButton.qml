import QtQuick
import QtQuick.Templates as T

T.Button {
    id: control
    padding: 10
    implicitWidth: 12 + contentItem.implicitWidth + leftPadding + rightPadding
    implicitHeight: 40
    opacity: enabled ? 1 : 0.3

    background: Rectangle {
        anchors.fill: parent
        border.color: control.down ? "#888" : (control.hovered ? "#666" : "#4a3d80")
        color: control.down ? "#2a2250" : "#16112e"
        radius: 2
        FocusBorder {
            visible: control.visualFocus
        }
    }

    contentItem: Text {
        anchors.fill: parent
        text: control.text
        font.pointSize: 10
        color: "#fff"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}
