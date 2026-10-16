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
        border.color: control.down || control.hovered ? Qt.lighter(window.lumenAccent, 1.15) : window.lumenLine
        color: control.down ? window.lumenAlpha(window.lumenAccent, 0.23) : (control.hovered ? window.lumenAlpha(window.lumenAccent, 0.15) : window.lumenAlpha(window.lumenSurfaceLow, 0.8))
        radius: 10
        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
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
